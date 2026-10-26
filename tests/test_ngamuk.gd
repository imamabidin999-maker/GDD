extends SceneTree
## Tes sistem Ngamuk, Prayitna, Gelap Ngampar yang membuyarkan amukan,
## dan ilmu Buto Murka.
##   godot --headless -s tests/test_ngamuk.gd

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


func make_buto(type: EnemyButo.ButoType, hp: int, attack: int, ngamuk: bool = true, start: int = 0) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = 5
	b.attack_power = attack
	b.can_ngamuk = ngamuk
	b.start_amuk = start
	var h := HealthComponent.new()
	h.max_hp = hp
	b.add_child(h)
	b.health = h
	return b


func make_fixture(butos: Array[EnemyUnit], hero_hp: int) -> Fixture:
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
	f.deck_list = card_db().call("build_deck_list", specs)
	return f


func give_card(f: Fixture, spec: String) -> int:
	var card := CardInstance.new(card_db().call("card_from_spec", spec))
	if f.hand.is_full():
		f.hand.remove_card_at(f.hand.get_card_count() - 1)
	f.hand.add_card(card)
	return f.hand.get_card_count() - 1


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[Ngamuk: tiga aksi lalu dua aksi]")
	var kuning := make_buto(EnemyButo.ButoType.KUNING, 999, 5)
	var f := make_fixture([kuning] as Array[EnemyUnit], 200)
	var ngamuk_log: Array[EnemyUnit] = []
	f.bm.enemy_ngamuk.connect(func(e: EnemyUnit) -> void: ngamuk_log.append(e))
	f.bm.start_battle(f.deck_list, f.enemies)
	check(kuning.amuk == 0 and not kuning.is_ngamuk_ready(), "awal battle: Amuk 0")
	check(kuning.get_intents(f.bm).size() == 1, "niat biasa: satu aksi")
	for i: int in 3:
		f.bm.request_end_turn()
	check(kuning.amuk == 3 and kuning.is_ngamuk_ready(), "setelah 3 aksi Amuk penuh")
	check(f.hero.current_hp == 200 - 15, "tiga serangan biasa masuk (3 x 5)")
	check(kuning.get_intents(f.bm).size() == 2, "niat Ngamuk: dua aksi")
	check(f.player.prayitna, "Prayitna aktif karena ada Buto yang akan Ngamuk")
	f.bm.request_end_turn()
	check(ngamuk_log.size() == 1 and ngamuk_log[0] == kuning, "signal enemy_ngamuk terpancar sekali")
	check(f.hero.current_hp == 200 - 15 - 10, "Ngamuk: dua serangan dalam satu giliran")
	check(kuning.amuk == 0 and not f.player.prayitna, "Amuk kosong lagi dan Prayitna berakhir")
	f.bm.request_end_turn()
	check(kuning.amuk == 1 and f.hero.current_hp == 200 - 30, "siklus berikutnya mulai dari satu aksi")

	print("[Semua aksi mengisi Amuk, termasuk ilmu tanpa damage]")
	var putih := make_buto(EnemyButo.ButoType.PUTIH, 999, 5)
	var fp := make_fixture([putih] as Array[EnemyUnit], 200)
	fp.bm.start_battle(fp.deck_list, fp.enemies)
	fp.bm.request_end_turn() # Sirep
	check(putih.amuk == 1 and fp.hero.current_hp == 200, "Sirep (tanpa damage) tetap mengisi Amuk")
	fp.bm.request_end_turn()
	fp.bm.request_end_turn()
	var intents := putih.get_intents(fp.bm)
	# Sirep terakhir di aksi ke-3, jadi aksi pertama Ngamuk masih jeda (serang)
	# dan aksi keduanya sudah siap menyirep lagi.
	check(intents.size() == 2 and intents[0].kind == EnemyIntent.Kind.ATTACK and intents[1].kind == EnemyIntent.Kind.LOCK,
		"niat Ngamuk Putih: serang lalu Sirep")
	fp.bm.request_end_turn()
	var sirep_count := 0
	for i: int in fp.hand.get_card_count():
		if fp.hand.is_locked_at(i):
			sirep_count += 1
	check(fp.hero.current_hp == 190 and sirep_count == 1, "Ngamuk Putih benar-benar menyerang lalu menyirep")

	print("[Buto biasa tidak pernah Ngamuk]")
	var biasa := make_buto(EnemyButo.ButoType.KUNING, 999, 5, false)
	var fb := make_fixture([biasa] as Array[EnemyUnit], 200)
	fb.bm.start_battle(fb.deck_list, fb.enemies)
	for i: int in 5:
		fb.bm.request_end_turn()
	check(biasa.amuk == 0 and fb.hero.current_hp == 200 - 25 and not fb.player.prayitna, "tanpa can_ngamuk Amuk tetap 0")

	print("[Titik awal negatif menunda Ngamuk]")
	var lambat := make_buto(EnemyButo.ButoType.KUNING, 999, 5, true, -1)
	var fl := make_fixture([lambat] as Array[EnemyUnit], 200)
	fl.bm.start_battle(fl.deck_list, fl.enemies)
	check(lambat.amuk == -1, "start_amuk -1 terpasang")
	for i: int in 3:
		fl.bm.request_end_turn()
	check(not lambat.is_ngamuk_ready() and lambat.amuk == 2, "tiga aksi belum cukup")
	fl.bm.request_end_turn()
	check(lambat.is_ngamuk_ready(), "aksi keempat memenuhi Amuk")

	print("[Pola Merah saat Ngamuk]")
	var merah := make_buto(EnemyButo.ButoType.MERAH, 999, 6, true, 3)
	var fm := make_fixture([merah] as Array[EnemyUnit], 200)
	fm.bm.start_battle(fm.deck_list, fm.enemies)
	var mi := merah.get_intents(fm.bm)
	check(mi.size() == 2 and mi[0].kind == EnemyIntent.Kind.ATTACK and mi[1].kind == EnemyIntent.Kind.CHARGE,
		"niat Merah Ngamuk: serang lalu ancang-ancang")
	check(merah.get_intents(fm.bm).size() == 2 and merah.get_intent(fm.bm).kind == EnemyIntent.Kind.ATTACK,
		"mengintip niat tidak mengubah pola")
	fm.bm.request_end_turn()
	check(fm.hero.current_hp == 194 and merah.get_intent(fm.bm).kind == EnemyIntent.Kind.HEAVY,
		"setelah Ngamuk giliran depan Gebug Raksasa")

	print("[Prayitna: Tameng kartu +50%]")
	var kp := make_buto(EnemyButo.ButoType.KUNING, 999, 5, true, 3)
	var fk := make_fixture([kp] as Array[EnemyUnit], 200)
	fk.bm.start_battle(fk.deck_list, fk.enemies)
	check(fk.player.prayitna, "Prayitna aktif sejak giliran pertama (Amuk awal 3)")
	var ti := give_card(fk, "taktik:2")
	check(fk.player.get_card_shield(fk.hand.get_card(ti)) == 12, "get_card_shield: 8 -> 12")
	fk.bm.request_play_card(ti)
	check(fk.hero.block == 12, "Tangkis bintang 2 memberi Tameng 12 saat Prayitna")
	var pi := give_card(fk, "piercing:1")
	fk.bm.request_play_card(pi)
	check(fk.hero.block == 18, "Tangkis Balik ikut bertambah (4 -> 6)")

	print("[Gelap Ngampar membuyarkan amukan]")
	var kg := make_buto(EnemyButo.ButoType.KUNING, 999, 5, true, 3)
	var kg2 := make_buto(EnemyButo.ButoType.HIJAU, 999, 5, true, 1)
	var fg := make_fixture([kg, kg2] as Array[EnemyUnit], 200)
	fg.bm.start_battle(fg.deck_list, fg.enemies)
	fg.player.gain_moxie(100.0)
	var ult_actions: Array[UltimateAction] = []
	fg.bm.action_presentation_started.connect(func(a: BattleAction) -> void:
		if a is UltimateAction:
			ult_actions.append(a as UltimateAction))
	check(fg.bm.request_ultimate(), "Gelap Ngampar dipakai")
	check(kg.amuk == 0 and kg2.amuk == 0 and not kg.is_ngamuk_ready(), "semua titik Amuk kosong")
	check(ult_actions.size() == 1 and ult_actions[0].calmed == 2, "UltimateAction mencatat 2 Buto yang buyar")
	var hp_before := fg.hero.current_hp
	fg.bm.request_end_turn()
	check(kg.amuk == 1 and kg2.amuk == 1, "Buto yang batal Ngamuk hanya beraksi sekali")
	# Kuning menyerang 5, Hijau menyembur 3 + Lara 3 yang langsung bekerja.
	check(fg.hero.current_hp == hp_before - 11, "damage hanya dari satu aksi per Buto")

	print("[Buto Kuning Murka: Hisap Greget di level berapa pun]")
	var km := make_buto(EnemyButo.ButoType.KUNING, 999, 6, false)
	km.apply_murka()
	var fkm := make_fixture([km] as Array[EnemyUnit], 200)
	fkm.bm.start_battle(fkm.deck_list, fkm.enemies)
	check(km.can_ngamuk, "apply_murka menyalakan Ngamuk")
	fkm.player.gain_moxie(50.0)
	var ikm := km.get_intent(fkm.bm)
	check(ikm.kind == EnemyIntent.Kind.DRAIN and ikm.murka and ikm.extra == 20, "niat: serang lalu hisap 20% Greget (ditandai murka)")
	fkm.bm.request_end_turn()
	check(is_equal_approx(fkm.player.moxie, 30.0) and fkm.hero.current_hp == 194, "Greget 50% -> 30% walau belum Memuncak")
	var kb := make_buto(EnemyButo.ButoType.KUNING, 999, 6, false)
	var fkb := make_fixture([kb] as Array[EnemyUnit], 200)
	fkb.bm.start_battle(fkb.deck_list, fkb.enemies)
	fkb.player.gain_moxie(50.0)
	fkb.bm.request_end_turn()
	check(is_equal_approx(fkb.player.moxie, 50.0), "Kuning biasa tidak menyentuh Greget di bawah 100%")

	print("[Buto Hijau Murka: Sembur Lara penuh]")
	var hm := make_buto(EnemyButo.ButoType.HIJAU, 999, 6, false)
	hm.apply_murka()
	var fhm := make_fixture([hm] as Array[EnemyUnit], 200)
	fhm.bm.start_battle(fhm.deck_list, fhm.enemies)
	var ihm := hm.get_intent(fhm.bm)
	check(ihm.kind == EnemyIntent.Kind.POISON and ihm.damage == 6 and ihm.extra == 5, "niat: sembur 6 (tenaga penuh) + 5 Lara")
	fhm.bm.request_end_turn()
	check(fhm.hero.current_hp == 200 - 6 - 5, "semburan 6 lalu Lara 5 langsung bekerja")

	print("[Buto Merah Murka: langsung ancang-ancang, bertameng, gebug x3]")
	var mm := make_buto(EnemyButo.ButoType.MERAH, 999, 6, false)
	mm.apply_murka()
	var fmm := make_fixture([mm] as Array[EnemyUnit], 200)
	fmm.bm.start_battle(fmm.deck_list, fmm.enemies)
	var imm := mm.get_intent(fmm.bm)
	check(imm.kind == EnemyIntent.Kind.CHARGE and imm.extra == 18, "giliran pertama sudah ancang-ancang (gebug 18)")
	fmm.bm.request_end_turn()
	check(mm.health.block == 10 and fmm.hero.current_hp == 200, "ancang-ancang memberi Tameng 10, belum menyerang")
	check(mm.get_intent(fmm.bm).kind == EnemyIntent.Kind.HEAVY, "lalu Gebug Raksasa")
	fmm.bm.request_end_turn()
	check(fmm.hero.current_hp == 182 and mm.health.block == 0, "Gebug Raksasa 18 masuk, Tameng Buto habis di giliran musuh berikutnya")
	check(mm.get_intent(fmm.bm).kind == EnemyIntent.Kind.CHARGE, "pola dua langkah berulang")

	print("[Buto Putih Murka: menyirep dua kartu]")
	var pm := make_buto(EnemyButo.ButoType.PUTIH, 999, 6, false)
	pm.apply_murka()
	var fpm := make_fixture([pm] as Array[EnemyUnit], 200)
	fpm.bm.start_battle(fpm.deck_list, fpm.enemies)
	check(pm.sirep_count == 2 and pm.get_intent(fpm.bm).extra == 2, "niat Sirep 2 kartu")
	fpm.bm.request_end_turn()
	var sirep_pm := 0
	for i: int in fpm.hand.get_card_count():
		if fpm.hand.is_locked_at(i):
			sirep_pm += 1
	check(sirep_pm == 2, "dua kartu tersirep")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
