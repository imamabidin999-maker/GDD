extends SceneTree
## Tes Jurus Tabuh: data kartu, efek tiap kartu, biaya Ketukan, penguat Kenong,
## larangan menggabung, dan berkah kartu Tabuh.
##   godot --headless -s tests/test_tabuh.gd

var _failures: int = 0
var _checks: int = 0


class Fixture:
	var bm: BattleManager
	var deck: DeckController
	var hand: HandManager
	var player: PlayerState
	var hero: HealthComponent
	var enemies: Array[EnemyUnit] = []


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func card_db() -> Node:
	return root.get_node("CardDB")


func card(spec: String) -> CardData:
	return card_db().call("card_from_spec", spec)


func make_buto(type: EnemyButo.ButoType, hp: int) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = 5
	b.attack_power = 5
	var h := HealthComponent.new()
	h.max_hp = hp
	b.add_child(h)
	b.health = h
	return b


func make_fixture(butos: Array[EnemyUnit], deck_specs: Array[String] = []) -> Fixture:
	var f := Fixture.new()
	var holder := Node.new()
	f.deck = DeckController.new()
	f.deck.shuffle_seed = 3
	f.hand = HandManager.new()
	f.hand.merge_recipes = card_db().call("get_recipes")
	f.player = PlayerState.new()
	f.hero = HealthComponent.new()
	f.hero.max_hp = 200
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
	var specs: Array[String] = deck_specs
	if specs.is_empty():
		specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	f.bm.start_battle(card_db().call("build_deck_list", specs), f.enemies)
	return f


## Mengosongkan tangan lalu mengisinya dengan kartu-kartu ini (urutan sama).
func set_hand(f: Fixture, specs: Array[String]) -> void:
	f.hand.take_all_cards()
	for spec: String in specs:
		f.hand.add_card(CardInstance.new(card(spec)))


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[Data kartu Tabuh]")
	var all_ok := true
	for family: String in Blessings.TABUH_FAMILIES:
		for rank: int in range(1, 4):
			var data := card("%s:%d" % [family, rank])
			all_ok = all_ok and data != null and data.is_tabuh() and data.is_base_type() and data.rank == rank
	check(all_ok, "lima kartu Tabuh, masing-masing bintang 1-3")
	check(card("gong:1").ap_cost == 2 and card("serang:1").ap_cost == 1, "Gong butuh 2 Ketukan, kartu lain 1")
	check(card("bedug:3").hits_all and card("bedug:3").base_power == 12, "Tabuh Bedug bintang 3: 12 ke semua")
	check(card("kentongan:1").draw == 2 and card("kentongan:3").draw == 3 and card("kentongan:2").shield == 3 and card("kentongan:1").ap_gain == 1,
		"Kentongan: tarik 2/2/3, Tameng 0/3/5, Ketukan kembali 1")
	check(card("korek:1").calm_target and is_equal_approx(card("korek:2").moxie_gain, 15.0), "Korek meredam Amuk dan memberi Greget")
	check(is_equal_approx(card("kenong:2").next_boost, 0.6) and card("kenong:1").ap_cost == 0, "Kenong bintang 2 +60%, tanpa Ketukan")

	print("[Deck dengan kartu Tabuh]")
	var tabuh_deck: Array[String] = []
	tabuh_deck.assign(root.get_node("GameState").get("STARTER_DECK"))
	tabuh_deck[0] = "bedug:1"
	tabuh_deck[5] = "gong:2"
	var fd := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 300)] as Array[EnemyUnit], tabuh_deck)
	check(fd.bm.is_battle_running(), "deck berisi kartu Tabuh diterima")

	print("[Tabuh Bedug: semua Buto]")
	var b1 := make_buto(EnemyButo.ButoType.KUNING, 100)
	var b2 := make_buto(EnemyButo.ButoType.HIJAU, 100)
	var f1 := make_fixture([b1, b2] as Array[EnemyUnit])
	set_hand(f1, ["bedug:2"])
	check(f1.bm.request_play_card(0), "Bedug dimainkan")
	check(b1.health.current_hp == 92 and b2.health.current_hp == 92, "kedua Buto terkena 8")

	print("[Kentongan Titir: tarik kartu]")
	var f2 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 300)] as Array[EnemyUnit])
	set_hand(f2, ["kentongan:2", "serang:1", "fokus:1"])
	var ap_before := f2.player.current_ap
	f2.bm.request_play_card(0)
	check(f2.hand.get_card_count() == 4 and f2.hero.block == 3, "tangan 2 kartu + tarik 2, Tameng 3")
	check(f2.player.current_ap == ap_before, "Kentongan mengembalikan Ketukannya")
	set_hand(f2, ["kentongan:3", "serang:1", "serang:1", "serang:1", "serang:1", "serang:1", "serang:1"])
	f2.bm.request_play_card(0)
	check(f2.hand.get_card_count() == 7, "tangan penuh: tarikan berhenti di 7 kartu")

	print("[Korek: membuyarkan Amuk sasaran]")
	var ka := make_buto(EnemyButo.ButoType.KUNING, 300)
	var kb := make_buto(EnemyButo.ButoType.MERAH, 300)
	ka.can_ngamuk = true
	kb.can_ngamuk = true
	var f3 := make_fixture([ka, kb] as Array[EnemyUnit])
	ka.amuk = 3
	kb.amuk = 3
	var acts: Array[PlayCardAction] = []
	f3.bm.action_presentation_started.connect(func(a: BattleAction) -> void:
		if a is PlayCardAction:
			acts.append(a as PlayCardAction))
	f3.bm.select_target(ka)
	set_hand(f3, ["korek:1"])
	f3.bm.request_play_card(0)
	check(ka.amuk == 0 and kb.amuk == 3 and ka.health.current_hp == 296, "hanya Amuk sasaran yang kosong, damage 4")
	check(is_equal_approx(f3.player.moxie, 10.0), "Korek bintang 1 memberi Greget 10%")
	check(acts.size() == 1 and acts[0].calmed and acts[0].calmed_ready, "aksi mencatat amukan yang dibuyarkan")

	print("[Gong: 2 Ketukan]")
	var f4 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 300)] as Array[EnemyUnit])
	set_hand(f4, ["gong:1", "serang:1", "serang:1", "serang:1"])
	f4.player.current_ap = 1
	check(not f4.bm.request_play_card(0) and f4.player.current_ap == 1 and f4.hand.get_card_count() == 4, "Ketukan 1: Gong ditolak, tidak ada yang berubah")
	f4.player.current_ap = 4
	check(f4.bm.request_play_card(0) and f4.player.current_ap == 2, "Ketukan 4: Gong dimainkan, sisa 2")
	check(f4.enemies[0].health.current_hp == 282, "Gong bintang 1: 18 damage")

	print("[Kenong: kartu berikutnya lebih kuat]")
	var kn := make_buto(EnemyButo.ButoType.KUNING, 300)
	var f5 := make_fixture([kn] as Array[EnemyUnit])
	set_hand(f5, ["kenong:1", "serang:1", "serang:1"])
	var ap_kenong := f5.player.current_ap
	f5.bm.request_play_card(0)
	check(is_equal_approx(f5.player.next_card_boost, 0.4) and f5.player.current_ap == ap_kenong, "Kenong memasang penguat +40% tanpa Ketukan")
	check(f5.player.get_card_damage(f5.hand.get_card(0)) == 9, "Sabet 6 tampil sebagai 9 (6 x 1,4 dibulatkan ke atas)")
	f5.bm.request_play_card(0)
	check(kn.health.current_hp == 291 and is_equal_approx(f5.player.next_card_boost, 0.0), "Sabet berikutnya memberi 9 lalu penguat habis")
	f5.bm.request_play_card(0)
	check(kn.health.current_hp == 285, "Sabet sesudahnya kembali 6")
	set_hand(f5, ["kenong:2", "taktik:2"])
	f5.player.current_ap = 4
	f5.bm.request_play_card(0)
	f5.bm.request_play_card(0)
	check(f5.hero.block == 13, "Kenong +60% juga menguatkan Tameng (8 -> 13)")
	set_hand(f5, ["kenong:1"])
	f5.player.current_ap = 4
	f5.bm.request_play_card(0)
	f5.bm.request_end_turn()
	check(is_equal_approx(f5.player.next_card_boost, 0.0), "penguat yang tidak terpakai hilang saat giliran berganti")

	print("[Kartu Tabuh tidak bisa digabung]")
	var f6 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 300)] as Array[EnemyUnit])
	set_hand(f6, ["bedug:1", "serang:1", "korek:1", "fokus:1"])
	check(not f6.hand.can_merge_at(0, 1) and not f6.hand.can_merge_at(1, 2) and not f6.hand.can_merge_at(2, 3), "Tabuh dengan kartu dasar bintang sama: tidak bisa digabung")

	print("[Berkah kartu Tabuh]")
	var deck := starter()
	var pool := Blessings.available(deck, [], [Blessings.Kind.TABUH_KENONG])
	check(pool.has(Blessings.Kind.TABUH_BEDUG) and not pool.has(Blessings.Kind.TABUH_KENONG), "Tabuh masuk undian, Kenong bisa dikunci")
	check(not pool.has(Blessings.Kind.LARAS_GAMELAN), "Laras Gamelan belum muncul tanpa kartu Tabuh")
	var owned: Array[String] = ["TABUH_GONG"]
	check(not Blessings.available(deck, owned).has(Blessings.Kind.TABUH_GONG), "berkah Tabuh hanya sekali")
	deck[0] = "gong:1"
	deck[1] = "bedug:2"
	check(Blessings.available(deck, owned).has(Blessings.Kind.LARAS_GAMELAN), "Laras Gamelan muncul setelah punya Tabuh")
	var up := Blessings.upgrade_tabuh(deck)
	check(up == ["gong:2", "gong:3"], "Laras Gamelan menaikkan Tabuh terendah dua kali: %s" % [up])
	check(Blessings.upgrade_at(deck, 0) == "" and Blessings.upgrade_at(deck, 1) == "bedug:3", "tempa kartu pilihan, bintang 3 tidak bisa")

	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_save.cfg")
	gs.call("new_game")
	var swap: Array = gs.call("place_tabuh", 2, "korek")
	check(swap == ["serang:2", "korek:3"] and (gs.get("deck") as Array)[2] == "korek:3", "Korek menggantikan Sabet bintang 2 dan menjadi bintang 3")
	var swap1: Array = gs.call("place_tabuh", 0, "gong")
	check(swap1 == ["serang:1", "gong:2"], "Sabet bintang 1 diganti Gong bintang 2")
	check(Blessings.tabuh_spec_for("bedug", "taktik:3") == "bedug:3", "bintang paling tinggi tetap 3")
	check(gs.call("replace_card", 2, "tidak:1") == "" and gs.call("replace_card", 99, "bedug:1") == "", "kartu tidak dikenal atau index salah ditolak")
	check(gs.call("upgrade_card", 0) == "gong:3" and gs.call("upgrade_card", 2) == "", "upgrade_card menaikkan kartu pilihan, bintang 3 ditolak")
	gs.call("new_game")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


func starter() -> Array[String]:
	var specs: Array[String] = []
	specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	return specs
