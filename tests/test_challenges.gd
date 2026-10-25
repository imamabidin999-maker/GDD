extends SceneTree
## Tes tantangan babak dan Bintang Dongkrek: aturan tiap tantangan, pencatat
## statistik battle, penyimpanan bintang, dan hadiah yang terbuka.
##   godot --headless -s tests/test_challenges.gd

var _failures: int = 0
var _checks: int = 0


class Fixture:
	var bm: BattleManager
	var deck: DeckController
	var hand: HandManager
	var player: PlayerState
	var hero: HealthComponent
	var enemies: Array[EnemyUnit] = []
	var stats: BattleStats


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func card_db() -> Node:
	return root.get_node("CardDB")


func make_buto(type: EnemyButo.ButoType, hp: int, attack: int = 5) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = 5
	b.attack_power = attack
	var h := HealthComponent.new()
	h.max_hp = hp
	b.add_child(h)
	b.health = h
	return b


func make_fixture(butos: Array[EnemyUnit], hero_hp: int = 200) -> Fixture:
	var f := Fixture.new()
	var holder := Node.new()
	f.deck = DeckController.new()
	f.deck.shuffle_seed = 3
	f.hand = HandManager.new()
	f.hand.merge_recipes = card_db().call("get_recipes")
	f.player = PlayerState.new()
	f.hero = HealthComponent.new()
	f.hero.max_hp = hero_hp
	f.bm = BattleManager.new()
	f.bm.deck = f.deck
	f.bm.hand = f.hand
	f.bm.player = f.player
	f.bm.hero_health = f.hero
	f.bm.presentation_delay = 0.0
	for n: Node in [f.deck, f.hand, f.player, f.hero, f.bm]:
		holder.add_child(n)
	for b: EnemyUnit in butos:
		holder.add_child(b)
		f.enemies.append(b)
	root.add_child(holder)
	var specs: Array[String] = []
	specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	f.stats = BattleStats.new()
	f.stats.attach(f.bm, f.enemies)
	f.bm.start_battle(card_db().call("build_deck_list", specs), f.enemies)
	return f


func set_hand(f: Fixture, specs: Array[String]) -> void:
	f.hand.take_all_cards()
	for spec: String in specs:
		f.hand.add_card(CardInstance.new(card_db().call("card_from_spec", spec)))


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[Aturan tantangan]")
	var s := BattleStats.new()
	s.won = true
	s.turns = 4
	s.hp_left = 56
	s.max_hp = 70
	check(Challenges.is_met("turns:4", s) and not Challenges.is_met("turns:3", s), "turns: paling lama N giliran")
	check(Challenges.is_met("hp:80", s) and not Challenges.is_met("hp:81", s), "hp: 56/70 = 80%")
	s.merges = 3
	check(Challenges.is_met("merges:3", s) and not Challenges.is_met("merges:4", s), "merges")
	check(Challenges.is_met("no_ult", s), "no_ult tanpa Gebrakan")
	s.ultimates_used = 1
	check(not Challenges.is_met("no_ult", s), "no_ult gagal setelah Gebrakan")
	s.max_poison = 3
	check(Challenges.is_met("max_lara:3", s) and not Challenges.is_met("max_lara:2", s), "max_lara")
	s.first_killed = "putih"
	check(Challenges.is_met("first:putih", s) and not Challenges.is_met("first:merah", s), "first:warna")
	check(not Challenges.is_met("calm_ready", s), "calm_ready belum")
	s.calmed_ready = 1
	check(Challenges.is_met("calm_ready", s), "calm_ready tercapai")
	s.block_absorbed = 60
	check(Challenges.is_met("blocked:60", s) and not Challenges.is_met("blocked:61", s), "blocked")
	s.sirep_received = 2
	check(Challenges.is_met("max_sirep:2", s) and not Challenges.is_met("max_sirep:1", s), "max_sirep")
	check(Challenges.is_met("no_ngamuk", s), "no_ngamuk")
	s.ajian_breaks = 2
	check(Challenges.is_met("ajian:2", s), "ajian")
	check(not Challenges.is_met("bala_first", s), "bala_first: belum ada Bala")
	s.bala_summoned = 2
	s.bala_killed_before_boss = 2
	check(Challenges.is_met("bala_first", s), "bala_first: kedua Bala lebih dulu")
	var results := Challenges.evaluate(PackedStringArray(["turns:4", "hp:90"]), s)
	check(results == [true, true, false], "evaluate: [menang, tantangan 1, tantangan 2]")
	s.won = false
	check(Challenges.evaluate(PackedStringArray(["turns:4", "hp:50"]), s) == [false, false, false], "kalah: tidak ada bintang")
	var lines := Challenges.describe_stage(PackedStringArray(["turns:4", "first:putih"]))
	check(lines.size() == 3 and lines[1].contains("4") and lines[2].contains("Putih") and not lines[0].begins_with("CH_"), "kalimat tantangan diterjemahkan: %s" % [lines])

	print("[Semua babak punya dua tantangan yang dikenal]")
	var catalog := StageCatalog.load_default()
	var all_ok := true
	for stage: StageData in catalog.stages:
		if stage.challenges.size() != 2:
			all_ok = false
		for id: String in stage.challenges:
			if Challenges.describe(id).begins_with("CH_"):
				all_ok = false
	check(all_ok, "10 babak x 2 tantangan, semuanya punya teks")

	print("[Pencatat statistik battle]")
	var kb := make_buto(EnemyButo.ButoType.KUNING, 500, 10)
	var f1 := make_fixture([kb] as Array[EnemyUnit])
	set_hand(f1, ["serang:1", "fokus:1", "taktik:2", "taktik:2"])
	check(f1.bm.request_merge(0, 1), "gabung kartu")
	f1.bm.request_play_card(1)
	f1.bm.request_end_turn()
	check(f1.stats.merges == 1, "gabungan tercatat")
	check(f1.stats.block_absorbed == 8, "Tameng menahan 8 dari serangan 10")
	f1.player.gain_moxie(100.0)
	f1.bm.request_ultimate()
	check(f1.stats.ultimates_used == 1, "Gebrakan tercatat")

	var hj := make_buto(EnemyButo.ButoType.HIJAU, 500, 6)
	var pt := make_buto(EnemyButo.ButoType.PUTIH, 30, 6)
	var f2 := make_fixture([hj, pt] as Array[EnemyUnit])
	f2.bm.request_end_turn()
	check(f2.stats.max_poison == 3 and f2.stats.sirep_received == 1, "Lara tertinggi 3 dan satu kartu tersirep")
	pt.health.take_damage(999)
	check(f2.stats.first_killed == "putih", "Buto Putih tumbang lebih dulu")

	var ng := make_buto(EnemyButo.ButoType.KUNING, 500, 2)
	ng.can_ngamuk = true
	ng.start_amuk = 3
	var f3 := make_fixture([ng] as Array[EnemyUnit])
	f3.player.gain_moxie(100.0)
	f3.bm.request_ultimate()
	check(f3.stats.calmed_ready == 1, "Gebrakan membuyarkan Buto yang siap Ngamuk")
	ng.amuk = 3
	f3.bm.request_end_turn()
	check(f3.stats.ngamuk_count == 1, "Ngamuk tercatat")
	ng.amuk = 3
	set_hand(f3, ["korek:1"])
	f3.player.current_ap = 4
	f3.bm.request_play_card(0)
	check(f3.stats.calmed_ready == 2 and f3.stats.tabuh_played == 1, "Korek juga membuyarkan, kartu Tabuh tercatat")

	var hitam := make_buto(EnemyButo.ButoType.HITAM, 400, 10)
	var f4 := make_fixture([hitam] as Array[EnemyUnit], 5000)
	for i: int in 3:
		f4.bm.request_end_turn()
	hitam.break_power()
	check(f4.stats.ajian_breaks == 1, "Ajian buyar tercatat")
	f4.bm.request_end_turn()
	hitam.health.take_damage(200)
	f4.bm.request_end_turn()
	var bala := hitam.get_living_bala()
	check(f4.stats.bala_summoned == 2, "dua Bala tercatat")
	bala[0].health.take_damage(999)
	hitam.health.take_damage(9999)
	f4.bm.request_end_turn() # pemeriksaan menang berjalan setelah aksi berikutnya
	check(f4.stats.bala_killed_before_boss == 1, "Bala yang lenyap bersama Buto Hitam tidak dihitung")
	check(f4.stats.won and not Challenges.is_met("bala_first", f4.stats), "bala_first gagal kalau satu Bala masih hidup")
	check(f4.stats.turns == f4.bm.turn_number and f4.stats.hp_left == f4.hero.current_hp, "giliran dan sisa Nyawa dicatat saat battle selesai")

	print("[Bintang Dongkrek di GameState]")
	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_save.cfg")
	gs.call("new_game")
	(gs.get("stage_stars") as Dictionary).clear()
	check(gs.call("total_stars") == 0 and not gs.call("kenong_unlocked"), "awal: 0 bintang, Kenong terkunci")
	var fresh: Array = gs.call("record_stars", 1, [true, false, true] as Array[bool])
	check(fresh == [true, false, true] and gs.call("stars_of", 1) == 5, "babak 1: bintang 1 dan 3")
	fresh = gs.call("record_stars", 1, [true, true, false] as Array[bool])
	check(fresh == [false, true, false] and gs.call("stars_of", 1) == 7 and gs.call("total_stars") == 3, "bintang lama tetap, bintang 2 baru")
	for stage: int in [2, 3]:
		gs.call("record_stars", stage, [true, true, true] as Array[bool])
	check(gs.call("total_stars") == 9 and gs.call("kenong_unlocked") and not gs.call("reroll_unlocked"), "9 bintang: Kenong terbuka")
	var locked: Array = gs.call("locked_blessings")
	check(locked.is_empty(), "Kenong tidak lagi dikunci di undian berkah")
	gs.call("load_game")
	check(gs.call("total_stars") == 9 and gs.call("stars_of", 2) == 7, "bintang tersimpan")
	gs.call("new_game")
	check(gs.call("total_stars") == 9, "petualangan baru tidak menghapus Bintang Dongkrek")
	for stage: int in range(4, 11):
		gs.call("record_stars", stage, [true, true, true] as Array[bool])
	check(gs.call("total_stars") == 30 and gs.call("reroll_unlocked") and gs.call("ruwatan_blessing_unlocked") and gs.call("master_unlocked"), "30 bintang: semua hadiah terbuka")
	(gs.get("stage_stars") as Dictionary).clear()
	gs.call("new_game")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
