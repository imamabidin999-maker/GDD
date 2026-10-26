extends SceneTree
## Tes Buto Hitam: pola empat langkah, Ajian Lebur Saketi yang bisa
## dibuyarkan, terhuyung, Memanggil Bala, Pagebluk Merata, dan Ngamuk yang
## ditunda di giliran Ajian.
##   godot --headless -s tests/test_buto_hitam.gd

var _failures: int = 0
var _checks: int = 0


class Fixture:
	var bm: BattleManager
	var deck: DeckController
	var hand: HandManager
	var player: PlayerState
	var hero: HealthComponent
	var enemies: Array[EnemyUnit] = []
	var deck_list: Array[CardData] = []


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func card_db() -> Node:
	return root.get_node("CardDB")


func make_hitam(hp: int, attack: int) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = EnemyButo.ButoType.HITAM
	b.rng_seed = 7
	b.attack_power = attack
	var h := HealthComponent.new()
	h.max_hp = hp
	b.add_child(h)
	b.health = h
	return b


func make_fixture(hitam: EnemyButo, hero_hp: int) -> Fixture:
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
	holder.add_child(hitam)
	f.enemies.append(hitam)
	root.add_child(holder)
	var specs: Array[String] = []
	specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	f.deck_list = card_db().call("build_deck_list", specs)
	return f


func kind_name(intent: EnemyIntent) -> String:
	return EnemyIntent.Kind.find_key(intent.kind)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[Fase 1: Gebug Pagebluk, Gebug, ancang-ancang, Ajian]")
	var h1 := make_hitam(1000, 10)
	var f1 := make_fixture(h1, 500)
	f1.bm.start_battle(f1.deck_list, f1.enemies)
	check(not h1.can_ngamuk, "fase 1: Buto Hitam belum bisa Ngamuk")
	var first := h1.get_intent(f1.bm)
	check(first.kind == EnemyIntent.Kind.PLAGUE_STRIKE and first.damage == 10 and first.extra == 2, "niat pertama: Gebug Pagebluk 10 + 2 Lara")
	var kinds: Array[String] = []
	var hp_log: Array[int] = []
	for i: int in 5:
		kinds.append(kind_name(h1.get_intent(f1.bm)))
		f1.bm.request_end_turn()
		hp_log.append(f1.hero.current_hp)
	check(kinds == ["PLAGUE_STRIKE", "ATTACK", "AJIAN_CHARGE", "AJIAN", "PLAGUE_STRIKE"], "pola: %s" % [kinds])
	# 10+2 Lara, 10+1 Lara, ancang-ancang, Ajian 22 + 3 Lara, 10 + Lara (2+2)
	check(hp_log == [488, 477, 477, 452, 438], "Nyawa Eyang: %s" % [hp_log])

	print("[Membuyarkan Ajian dengan damage]")
	var h2 := make_hitam(1000, 10)
	var f2 := make_fixture(h2, 500)
	var progress_log: Array[int] = []
	var broken: Array[int] = [0]
	h2.ajian_progress_changed.connect(func(p: int, _t: int) -> void: progress_log.append(p))
	h2.ajian_broken.connect(func() -> void: broken[0] += 1)
	f2.bm.start_battle(f2.deck_list, f2.enemies)
	f2.bm.request_end_turn()
	h2.health.take_damage(30) # sebelum ancang-ancang: tidak dihitung
	f2.bm.request_end_turn()
	var ic := h2.get_intent(f2.bm)
	check(ic.kind == EnemyIntent.Kind.AJIAN_CHARGE and ic.block == 15, "niat: ancang-ancang Ajian sambil bertameng 15")
	f2.bm.request_end_turn() # ancang-ancang
	check(h2.is_ajian_charged() and h2.get_ajian_progress() == 0, "damage sebelum ancang-ancang tidak mengisi bar Buyarkan")
	check(h2.health.block == 15, "ancang-ancang Ajian memberi Buto Hitam Tameng 15")
	var ia := h2.get_intent(f2.bm)
	check(ia.kind == EnemyIntent.Kind.AJIAN and ia.damage == 22 and ia.extra == 3, "niat: Ajian Lebur Saketi 22 + 3 Lara")
	h2.health.take_damage(29)
	check(h2.is_ajian_charged() and h2.get_ajian_progress() == 14 and h2.health.block == 0, "Tameng menahan 15 dari 29 damage, bar hanya terisi 14")
	h2.health.take_damage(15)
	check(h2.is_ajian_charged() and h2.get_ajian_progress() == 29 and broken[0] == 0, "29 damage ke Nyawa belum cukup")
	h2.health.take_damage(1)
	check(not h2.is_ajian_charged() and broken[0] == 1, "30 damage ke Nyawa membuyarkan Ajian")
	check(progress_log.has(0) and progress_log.has(29) and progress_log[-1] == -1, "bar Buyarkan muncul, terisi, lalu disembunyikan")
	check(h2.get_intent(f2.bm).kind == EnemyIntent.Kind.STAGGER, "niat berikutnya: terhuyung")
	var hp_before := f2.hero.current_hp
	var lara_before := f2.player.poison
	f2.bm.request_end_turn()
	check(f2.hero.current_hp == hp_before - lara_before and f2.player.poison == maxi(lara_before - 1, 0), "terhuyung: tidak menyerang, tidak memberi Lara")
	check(h2.get_intent(f2.bm).kind == EnemyIntent.Kind.PLAGUE_STRIKE, "lalu pola mulai lagi dari Gebug Pagebluk")

	print("[Gebrakan Dongkrek membuyarkan Ajian]")
	var h3 := make_hitam(1000, 10)
	# Ambang tinggi supaya yang membuyarkan benar-benar bunyi Gebrakan, bukan
	# damage-nya (damage Gebrakan sendiri biasanya sudah melewati ambang).
	h3.ajian_break_threshold = 999
	var f3 := make_fixture(h3, 500)
	var ults: Array[UltimateAction] = []
	f3.bm.action_presentation_started.connect(func(a: BattleAction) -> void:
		if a is UltimateAction:
			ults.append(a as UltimateAction))
	f3.bm.start_battle(f3.deck_list, f3.enemies)
	for i: int in 3:
		f3.bm.request_end_turn()
	check(h3.is_ajian_charged(), "Ajian disiapkan")
	f3.player.gain_moxie(100.0)
	check(f3.bm.request_ultimate(), "Gebrakan Dongkrek dipakai")
	check(not h3.is_ajian_charged() and ults.size() == 1 and ults[0].broken == 1, "Ajian buyar oleh Gebrakan (UltimateAction.broken = 1)")
	check(h3.get_intent(f3.bm).kind == EnemyIntent.Kind.STAGGER, "Buto Hitam terhuyung")

	print("[Fase 2: Memanggil Bala dan Pagebluk Merata]")
	var h4 := make_hitam(200, 10)
	var f4 := make_fixture(h4, 2000)
	var spawned: Array[EnemyUnit] = []
	var shield_log: Array[bool] = []
	f4.bm.enemy_spawned.connect(func(e: EnemyUnit, s: EnemyUnit) -> void:
		if s == h4:
			spawned.append(e))
	h4.bala_shield_changed.connect(func(on: bool) -> void: shield_log.append(on))
	f4.bm.start_battle(f4.deck_list, f4.enemies)
	h4.health.take_damage(100)
	check(h4.phase == 2 and h4.can_ngamuk and f4.player.poison_decay_paused, "fase 2: Ngamuk aktif dan Lara tidak berkurang")
	var isum := h4.get_intent(f4.bm)
	check(isum.kind == EnemyIntent.Kind.SUMMON and isum.extra == 2, "niat: Memanggil 2 Bala")
	f4.bm.request_end_turn()
	var types := {}
	var bala_ok := true
	for e: EnemyUnit in spawned:
		var b := e as EnemyButo
		types[b.buto_type] = true
		bala_ok = bala_ok and b.is_bala and not b.can_ngamuk and b.health.max_hp == h4.bala_hp and b.attack_power == h4.bala_attack and b.buto_type != EnemyButo.ButoType.HITAM
	check(spawned.size() == 2 and types.size() == 2 and bala_ok, "dua Bala berbeda warna dengan Nyawa dan serangan Bala")
	check(f4.bm.get_living_enemies().size() == 3 and spawned[0].get_parent() == h4.get_parent(), "Bala ikut battle dan diletakkan di samping Buto Hitam")
	check(f4.bm.get_target() == spawned[0], "sasaran pindah ke Bala pertama")
	check(f4.player.poison == 1 and f4.hero.current_hp == 1999, "Pagebluk Merata: +1 Lara di akhir giliran Buto, langsung bekerja")
	check(shield_log == [true] and is_equal_approx(h4.health.damage_taken_multiplier, 0.5), "perisai Bala aktif")
	var hp_h4 := h4.health.current_hp
	h4.health.take_damage(20)
	check(h4.health.current_hp == hp_h4 - 10, "selama Bala hidup Buto Hitam hanya menerima separuh damage")
	spawned[0].health.take_damage(999)
	check(is_equal_approx(h4.health.damage_taken_multiplier, 0.5), "masih ada satu Bala: perisai tetap")
	spawned[1].health.take_damage(999)
	check(shield_log[-1] == false and is_equal_approx(h4.health.damage_taken_multiplier, 1.0), "Bala habis: damage penuh lagi")
	check(h4.get_intent(f4.bm).kind == EnemyIntent.Kind.PLAGUE_STRIKE, "Bala hanya dipanggil sekali; pola lanjut dari Gebug Pagebluk")
	f4.bm.request_end_turn()
	# Lara 1 + Gebug Pagebluk 2 + Pagebluk Merata 1, dan tidak berkurang setelah bekerja.
	check(f4.player.poison == 4, "Lara terus bertambah dan tidak berkurang (Lara %d)" % f4.player.poison)

	print("[Bala lenyap saat Buto Hitam tumbang]")
	var h5 := make_hitam(200, 10)
	var f5 := make_fixture(h5, 2000)
	f5.bm.start_battle(f5.deck_list, f5.enemies)
	h5.health.take_damage(100)
	f5.bm.request_end_turn()
	check(f5.bm.get_living_enemies().size() == 3, "dua Bala hidup")
	var ended: Array[bool] = []
	f5.bm.battle_ended.connect(func(won: bool) -> void: ended.append(won))
	var pi := 0
	for i: int in f5.hand.get_card_count():
		if f5.hand.get_card(i).data.base_power > 0:
			pi = i
	h5.health.take_damage(h5.health.current_hp * 2 - 2)
	f5.bm.select_target(h5)
	f5.bm.request_play_card(pi)
	check(not h5.is_alive() and f5.bm.get_living_enemies().is_empty(), "Buto Hitam tumbang, Bala ikut lenyap")
	check(ended == [true] and f5.bm.get_state() == BattleManager.State.VICTORY, "battle dimenangkan")

	print("[Ngamuk ditunda di giliran Ajian]")
	var h6 := make_hitam(400, 10)
	var f6 := make_fixture(h6, 5000)
	f6.bm.start_battle(f6.deck_list, f6.enemies)
	h6.health.take_damage(200)
	f6.bm.request_end_turn() # Memanggil Bala
	for b: EnemyUnit in h6.get_living_bala():
		b.health.take_damage(999) # supaya tes fokus ke Buto Hitam
	h6.amuk = 3
	var i6 := h6.get_intents(f6.bm)
	check(h6.get_action_count() == 2 and i6.size() == 2 and i6[0].kind == EnemyIntent.Kind.PLAGUE_STRIKE and i6[1].kind == EnemyIntent.Kind.ATTACK,
		"Ngamuk biasa: Gebug Pagebluk lalu Gebug")
	check(h6.get_intents(f6.bm).size() == 2 and h6.get_intent(f6.bm).kind == EnemyIntent.Kind.PLAGUE_STRIKE, "mengintip niat tidak mengubah pola")
	f6.bm.request_end_turn()
	check(h6.amuk == 0 and h6.get_intent(f6.bm).kind == EnemyIntent.Kind.AJIAN_CHARGE, "setelah Ngamuk: giliran ancang-ancang")
	h6.amuk = 3
	check(h6.get_action_count() == 1 and h6.get_intents(f6.bm).size() == 1 and not f6.bm.is_any_enemy_ngamuk_ready(),
		"Amuk penuh tapi ancang-ancang Ajian: Ngamuk ditunda (tanpa Prayitna)")
	f6.bm.request_end_turn()
	check(h6.is_ajian_charged() and h6.amuk == 3 and h6.get_action_count() == 1, "giliran Ajian juga tidak Ngamuk")
	f6.bm.request_end_turn()
	check(not h6.is_ajian_charged() and h6.get_action_count() == 2, "setelah Ajian dilepas, Ngamuk-nya jalan")

	print("[Terhuyung tidak mengisi Amuk]")
	var h7 := make_hitam(400, 10)
	var f7 := make_fixture(h7, 5000)
	f7.bm.start_battle(f7.deck_list, f7.enemies)
	h7.health.take_damage(200)
	f7.bm.request_end_turn() # Memanggil Bala
	f7.bm.request_end_turn() # Gebug Pagebluk
	f7.bm.request_end_turn() # Gebug
	f7.bm.request_end_turn() # ancang-ancang
	check(h7.break_power() and h7.get_intent(f7.bm).kind == EnemyIntent.Kind.STAGGER, "break_power() membuyarkan Ajian")
	h7.amuk = 1
	f7.bm.request_end_turn() # terhuyung
	check(h7.amuk == 1, "Amuk tetap 1 setelah terhuyung")
	f7.bm.request_end_turn()
	check(h7.amuk == 2, "aksi biasa berikutnya mengisi Amuk lagi")

	print("[Battle diulang mereset Buto Hitam]")
	h4.on_battle_started(f4.bm)
	check(h4.phase == 1 and not h4.can_ngamuk and h4.get_living_bala().is_empty() and is_equal_approx(h4.health.damage_taken_multiplier, 1.0),
		"fase, Ngamuk, Bala, dan perisai kembali seperti awal")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
