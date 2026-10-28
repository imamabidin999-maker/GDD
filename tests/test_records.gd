extends SceneTree
## Tes catatan permainan: PlayRecords, catatan per battle (BattleStats), dan
## simpanannya di GameState.
##   godot --headless -s tests/test_records.gd

var _failures: int = 0
var _checks: int = 0


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func card_db() -> Node:
	return root.get_node("CardDB")


func _initialize() -> void:
	_run()


func make_buto(type: EnemyButo.ButoType, hp: int) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = 5
	b.attack_power = 3
	var h := HealthComponent.new()
	h.max_hp = hp
	b.add_child(h)
	b.health = h
	return b


func _run() -> void:
	await process_frame

	print("[PlayRecords]")
	var r := PlayRecords.new()
	check(r.favorite_card() == "" and r.total_defeated() == 0 and r.rhythm_best < 0.0, "catatan kosong di awal")
	var stats := BattleStats.new()
	stats.won = true
	stats.killed = {"kuning": 2, "murka": 1}
	stats.cards_played = {"serang": 5, "fokus": 2}
	stats.merges = 3
	stats.ultimates_used = 1
	stats.biggest_hit = 40
	r.add_battle(stats)
	var lost := BattleStats.new()
	lost.killed = {"kuning": 1}
	lost.cards_played = {"fokus": 4}
	lost.biggest_hit = 12
	r.add_battle(lost)
	check(r.battles_won == 1 and r.battles_lost == 1, "menang dan kalah dihitung")
	check(r.total_defeated() == 4 and int(r.buto_defeated["kuning"]) == 3, "Buto yang dikalahkan dijumlah per jenis")
	check(r.favorite_card() == "fokus" and r.merges == 3 and r.sapu_jagad == 1 and r.biggest_hit == 40, "jurus favorit, gabungan, Sapu Jagad, pukulan terbesar")
	r.add_rhythm(0.5)
	r.add_rhythm(0.9)
	r.add_rhythm(0.7)
	r.add_parade(-1.0)
	check(is_equal_approx(r.rhythm_best, 0.9) and r.parade_best < 0.0, "irama terbaik disimpan, arak-arakan yang dilewati tidak dihitung")
	r.add_parade(0.6)
	check(is_equal_approx(r.parade_best, 0.6), "arak-arakan terbaik")
	r.add_ruwatan(77, 2, 5, false, "2026-10-01")
	r.add_ruwatan(77, 2, 8, true, "2026-10-01")
	check(r.ruwatan_history.size() == 1 and bool(r.ruwatan_history[0]["won"]), "Ruwatan yang sama dilaporkan dua kali hanya tercatat sekali")
	for i: int in 12:
		r.add_ruwatan(100 + i, 1, i % 9, false, "2026-10-%02d" % (i + 2))
	check(r.ruwatan_history.size() == PlayRecords.HISTORY_LIMIT and int(r.ruwatan_history[0]["seed"]) == 111,
		"riwayat paling banyak %d, terbaru di depan" % PlayRecords.HISTORY_LIMIT)
	var copy := PlayRecords.from_dict(r.to_dict())
	check(copy.to_dict() == r.to_dict(), "simpan dan muat menghasilkan catatan yang sama")
	var broken := PlayRecords.from_dict({"battles_won": -5, "buto_defeated": {"kuning": "x", 3: 4}, "ruwatan_history": ["rusak", {"level": 99}]})
	check(broken.battles_won == 0 and broken.buto_defeated.is_empty() and broken.ruwatan_history.size() == 1
		and int(broken.ruwatan_history[0]["level"]) == RuwatanRun.MAX_LEVEL, "data rusak dibersihkan")
	check(PlayRecords.from_dict("bukan kamus").battles_won == 0, "simpanan tanpa catatan: mulai dari nol")

	print("[Catatan satu battle]")
	var holder := Node.new()
	var deck := DeckController.new()
	deck.shuffle_seed = 3
	var hand := HandManager.new()
	hand.merge_recipes = card_db().call("get_recipes")
	var player := PlayerState.new()
	var hero := HealthComponent.new()
	hero.max_hp = 200
	var bm := BattleManager.new()
	bm.deck = deck
	bm.hand = hand
	bm.player = player
	bm.hero_health = hero
	bm.presentation_delay = 0.0
	for n: Node in [deck, hand, player, hero, bm]:
		holder.add_child(n)
	var kuning := make_buto(EnemyButo.ButoType.KUNING, 10)
	var hijau := make_buto(EnemyButo.ButoType.HIJAU, 300)
	hijau.murka = true
	var enemies: Array[EnemyUnit] = [kuning, hijau]
	for e: EnemyUnit in enemies:
		holder.add_child(e)
	root.add_child(holder)
	var specs: Array[String] = []
	specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	var bstats := BattleStats.new()
	bstats.attach(bm, enemies)
	bm.start_battle(card_db().call("build_deck_list", specs), enemies)
	hand.take_all_cards()
	for spec: String in ["bedug:3", "serang:1", "serang:1"]:
		hand.add_card(CardInstance.new(card_db().call("card_from_spec", spec)))
	bm.request_play_card(0)
	bm.select_target(hijau)
	bm.request_play_card(0)
	check(int(bstats.killed.get("kuning", 0)) == 1 and not bstats.killed.has("hijau"), "Buto Kuning yang tumbang tercatat")
	check(int(bstats.cards_played.get("bedug", 0)) == 1 and int(bstats.cards_played.get("serang", 0)) == 1, "kartu yang dimainkan tercatat per keluarga")
	check(bstats.biggest_hit == 22, "pukulan terbesar: Bedug 12 ke dua Buto, tapi Kuning hanya punya 10 Nyawa (%d)" % bstats.biggest_hit)
	hijau.health.take_damage(9999)
	await process_frame
	check(int(bstats.killed.get("murka", 0)) == 1, "Buto Murka dihitung sebagai Murka")
	holder.queue_free()
	await process_frame

	print("[Simpanan GameState]")
	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_records.cfg")
	gs.call("new_game")
	gs.set("records", PlayRecords.new())
	# Buto Hijau ditumbangkan di luar aksi battle, jadi hasilnya diisi sendiri.
	bstats.won = true
	gs.call("record_battle", bstats)
	gs.call("record_rhythm", 0.8)
	gs.call("record_parade", 0.75)
	gs.call("complete_stage", gs.get("STAGE_COUNT"))
	gs.call("complete_stage", gs.get("STAGE_COUNT"))
	var saved: PlayRecords = gs.get("records")
	check(saved.stories_completed == 1, "tamat dihitung sekali walau babak terakhir dimenangkan lagi")
	gs.set("records", PlayRecords.new())
	gs.call("load_game")
	var loaded: PlayRecords = gs.get("records")
	check(loaded.battles_won == 1 and is_equal_approx(loaded.rhythm_best, 0.8) and is_equal_approx(loaded.parade_best, 0.75)
		and loaded.stories_completed == 1, "catatan ikut tersimpan dan dimuat")
	gs.call("new_game")
	check((gs.get("records") as PlayRecords).battles_won == 1, "petualangan baru tidak menghapus catatan")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var run: RuwatanRun = gs.call("start_ruwatan", 1, rng)
	run.lose_battle()
	gs.call("abandon_ruwatan")
	var history: Array[Dictionary] = (gs.get("records") as PlayRecords).ruwatan_history
	check(history.size() == 1 and not bool(history[0]["won"]) and int(history[0]["level"]) == 1, "Ruwatan yang gugur masuk riwayat, sekali saja")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_records.cfg"))

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
