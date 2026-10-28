extends SceneTree
## Tes berkah v2: aturan undian (sekali, batas Jamu, naik bintang) dan efek
## setiap berkah di battle.
##   godot --headless -s tests/test_blessings.gd

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


func starter() -> Array[String]:
	var specs: Array[String] = []
	specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	return specs


func make_buto(type: EnemyButo.ButoType, attack: int) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = 5
	b.attack_power = attack
	var h := HealthComponent.new()
	h.max_hp = 999
	b.add_child(h)
	b.health = h
	return b


func make_fixture(butos: Array[EnemyUnit], owned: Array[String]) -> Fixture:
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
	f.deck_list = card_db().call("build_deck_list", starter())
	Blessings.prepare_player(f.player, owned)
	f.bm.start_battle(f.deck_list, f.enemies)
	return f


func names(kinds: Array[Blessings.Kind]) -> Array[String]:
	var out: Array[String] = []
	for k: Blessings.Kind in kinds:
		out.append(Blessings.kind_name(k))
	return out


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[Undian berkah]")
	var deck := starter()
	var owned: Array[String] = []
	var pool := Blessings.available(deck, owned)
	# 9 berkah dasar + 6 berkah Tabuh; Laras Gamelan baru muncul setelah ada kartu Tabuh.
	check(pool.size() == 15 and not pool.has(Blessings.Kind.LARAS_GAMELAN), "awal permainan: 15 berkah bisa muncul")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen := {}
	var rolls_ok := true
	for i: int in 80:
		var r := Blessings.roll(rng, deck, owned)
		var unique := {}
		for k: Blessings.Kind in r:
			unique[k] = true
			seen[k] = true
		rolls_ok = rolls_ok and r.size() == 3 and unique.size() == 3
	check(rolls_ok, "setiap undian berisi 3 berkah berbeda")
	check(seen.size() == 15, "dalam 80 undian semua jenis berkah pernah muncul")

	owned.append("KENDANG_PEMBUKA")
	check(not Blessings.available(deck, owned).has(Blessings.Kind.KENDANG_PEMBUKA), "berkah sekali hilang setelah dimiliki")
	owned.append_array(["JAMU_KUNYIT_ASAM", "JAMU_KUNYIT_ASAM"])
	check(Blessings.available(deck, owned).has(Blessings.Kind.JAMU_KUNYIT_ASAM), "Jamu Kunyit Asam ke-3 masih boleh")
	owned.append("JAMU_KUNYIT_ASAM")
	check(not Blessings.available(deck, owned).has(Blessings.Kind.JAMU_KUNYIT_ASAM), "Jamu Kunyit Asam paling banyak 3 kali")

	var maxed: Array[String] = []
	for spec: String in deck:
		maxed.append(spec.split(":")[0] + ":3" if spec.begins_with("serang") else spec)
	check(not Blessings.available(maxed, []).has(Blessings.Kind.TEMPA_SABET), "Tempa Sabet hilang kalau semua Sabet sudah bintang 3")
	var up_deck := starter()
	var up := Blessings.upgrade_family(up_deck, "fokus")
	check(up == ["fokus:2", "fokus:2"], "Olah Semedi menaikkan dua kartu Semedi terendah: %s" % [up])

	var all_once: Array[String] = ["KENDANG_PEMBUKA", "GREGET_LELUHUR", "TAMENG_PUSAKA", "JIMAT_PENOLAK_SIREP",
		"JAMU_BERAS_KENCUR", "JAMU_KUNYIT_ASAM", "JAMU_KUNYIT_ASAM", "JAMU_KUNYIT_ASAM",
		"TABUH_BEDUG", "TABUH_KENTONGAN", "TABUH_KOREK", "TABUH_GONG", "TABUH_KENONG", "TABUH_BERI"]
	var only_upgrades := names(Blessings.available(starter(), all_once))
	check(only_upgrades == ["TEMPA_SABET", "OLAH_SEMEDI", "LAKU_TANGKIS"], "sisa undian: hanya berkah naik bintang")
	check(Blessings.roll(rng, maxed_all(), all_once).is_empty(), "semua habis: undian kosong")
	check(Blessings.from_name("TIDAK_ADA") == -1 and Blessings.from_name("TAMENG_PUSAKA") == Blessings.Kind.TAMENG_PUSAKA, "nama berkah dari simpanan")

	print("[Tanpa berkah]")
	var f0 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 5)] as Array[EnemyUnit], [])
	check(f0.player.current_ap == 4 and f0.hero.block == 0 and is_equal_approx(f0.player.moxie, 0.0), "battle biasa: 4 Ketukan, tanpa Tameng, Greget 0%")

	print("[Kendang Pembuka]")
	var f1 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 5)] as Array[EnemyUnit], ["KENDANG_PEMBUKA"])
	check(f1.player.current_ap == 5, "giliran pertama: 5 Ketukan")
	f1.bm.request_end_turn()
	check(f1.player.current_ap == 4, "giliran kedua kembali 4 Ketukan")

	print("[Greget Leluhur]")
	var f2 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 5)] as Array[EnemyUnit], ["GREGET_LELUHUR"])
	check(is_equal_approx(f2.player.moxie, 30.0), "battle dimulai dengan Greget 30%")

	print("[Tameng Pusaka]")
	var f3 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 15)] as Array[EnemyUnit], ["TAMENG_PUSAKA"])
	check(f3.hero.block == 10, "Tameng 10 di giliran pertama")
	f3.bm.request_end_turn()
	check(f3.hero.current_hp == 195, "Tameng menahan 10 dari 15 damage")
	check(f3.hero.block == 0, "giliran kedua tidak dapat Tameng lagi")

	print("[Jimat Penolak Sirep]")
	var putih := make_buto(EnemyButo.ButoType.PUTIH, 5)
	putih.skill_cooldown_turns = 1
	var f4 := make_fixture([putih] as Array[EnemyUnit], ["JIMAT_PENOLAK_SIREP"])
	var warded: Array[int] = [0]
	f4.player.sirep_warded.connect(func() -> void: warded[0] += 1)
	f4.bm.request_end_turn()
	check(warded[0] == 1 and f4.hand.count_unlocked() == f4.hand.get_card_count() and f4.hero.current_hp == 200,
		"Sirep pertama ditangkal (tidak ada kartu tersirep, tidak ada serangan)")
	f4.bm.request_end_turn()
	check(warded[0] == 1 and f4.hand.count_unlocked() == f4.hand.get_card_count() - 1, "Sirep kedua tetap kena")

	print("[Jamu Beras Kencur]")
	var hijau := make_buto(EnemyButo.ButoType.HIJAU, 6)
	var f5 := make_fixture([hijau] as Array[EnemyUnit], ["JAMU_BERAS_KENCUR"])
	f5.bm.request_end_turn()
	# Semburan 3 + Lara 3-1 = 2 yang langsung bekerja.
	check(f5.hero.current_hp == 200 - 3 - 2 and f5.player.poison == 1, "Lara dari semburan berkurang 1")
	f5.player.add_poison(1)
	check(f5.player.poison == 1, "Lara 1 (misalnya Pagebluk Merata) jadi 0")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)


func maxed_all() -> Array[String]:
	var out: Array[String] = []
	for spec: String in starter():
		out.append(spec.split(":")[0] + ":3")
	return out
