extends SceneTree

var _failures: int = 0
var _checks: int = 0


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func card(type: CardData.CardType, rank: int, name: String = "") -> CardInstance:
	var d := CardData.new()
	d.card_type = type
	d.rank = rank
	d.display_name = name if name != "" else str(type)
	return CardInstance.new(d)


func hybrid(a: CardInstance, b: CardInstance, name: String) -> CardInstance:
	var d := CardData.new()
	d.card_type = CardData.CardType.HYBRID
	d.rank = a.get_rank()
	d.display_name = name
	return CardInstance.create_hybrid(d, a, b)


func _initialize() -> void:
	var S := CardData.CardType.SERANG
	var F := CardData.CardType.FOKUS
	var T := CardData.CardType.TAKTIK

	# Dipakai SEBELUM masuk tree, untuk memastikan tidak bergantung pada _ready().
	var p := PlayerState.new()
	var rejected: Array[int] = []
	var ready_count: Array[int] = [0]
	var full_count: Array[int] = [0]
	var chain_events: Array[float] = []
	p.ap_rejected.connect(func(req: int, _avail: int) -> void: rejected.append(req))
	p.ultimate_ready.connect(func() -> void: ready_count[0] += 1)
	p.overcharge_full.connect(func() -> void: full_count[0] += 1)
	p.evolutionary_chain_triggered.connect(func(_s: int, m: float) -> void: chain_events.append(m))

	print("[AP]")
	p.begin_battle()
	check(p.current_ap == 4 and p.moxie == 0.0 and p.ultimate_damage_multiplier == 1.0, "begin_battle: AP 4, Moxie 0, multiplier 1")
	check(p.consume_ap(PlayerState.AP_COST_MOVE_CARD) and p.current_ap == 3, "geser kartu: AP 4 -> 3")
	check(not p.consume_ap(5) and p.current_ap == 3, "minta 5 AP saat sisa 3 -> ditolak, AP tetap")
	check(rejected == [5], "signal ap_rejected terkirim")
	check(p.consume_ap(0) and p.current_ap == 3, "consume 0 AP -> boleh, AP tetap")
	check(p.consume_ap(3) and p.current_ap == 0, "habiskan 3 AP")
	check(not p.consume_ap(1) and p.current_ap == 0, "AP 0 -> aksi 1 AP ditolak")
	p.start_turn()
	check(p.current_ap == 4, "start_turn mengisi ulang AP")

	print("[Moxie dari kartu]")
	p.register_card_played(card(F, 1))
	check(is_equal_approx(p.moxie, 10.0), "Fokus ★1 -> +10")
	p.register_card_played(card(S, 1))
	check(is_equal_approx(p.moxie, 10.0), "Serang -> +0")
	p.register_card_played(hybrid(card(S, 2), card(F, 2), "Crimson Focus"))
	check(is_equal_approx(p.moxie, 25.0), "Crimson Focus ★2 -> +15")
	p.register_card_played(hybrid(card(S, 2), card(T, 2), "Piercing Strike"))
	check(is_equal_approx(p.moxie, 25.0), "Piercing Strike -> +0")

	print("[Batas Moxie]")
	check(is_equal_approx(p.gain_moxie(100.0, false), 75.0) and is_equal_approx(p.moxie, 100.0), "tanpa overcharge berhenti di 100")
	check(ready_count[0] == 1 and p.is_ultimate_ready() and not p.is_overcharged(), "signal ultimate_ready sekali")
	check(is_equal_approx(p.gain_moxie(60.0), 60.0) and p.is_overcharged(), "overcharge ke 160")
	check(is_equal_approx(p.gain_moxie(10.0, false), 0.0) and is_equal_approx(p.moxie, 160.0), "sumber non-overcharge tidak menambah di atas 100")
	check(is_equal_approx(p.gain_moxie(999.0), 40.0) and is_equal_approx(p.moxie, 200.0), "di-clamp di 200")
	check(full_count[0] == 1, "signal overcharge_full sekali")
	p.gain_moxie(10.0)
	check(full_count[0] == 1 and ready_count[0] == 1, "tidak ada signal ganda di 200")
	check(is_equal_approx(p.spend_moxie_for_ultimate(), 200.0) and p.moxie == 0.0, "Ultimate menghabiskan 200")
	p.gain_moxie(50.0)
	check(p.spend_moxie_for_ultimate() == 0.0 and is_equal_approx(p.moxie, 50.0), "Moxie 50 -> Ultimate ditolak")

	print("[Evolutionary Chain, berturut-turut]")
	p.start_turn()
	for r: int in [3, 3, 1, 3, 3]:
		p.register_card_played(card(S, r))
	check(chain_events.is_empty(), "★3 ★3 ★1 ★3 ★3 -> belum terpicu")
	check(p.get_chain_progress() == 2, "progress 2/3")
	p.register_card_played(card(T, 3))
	check(chain_events == [1.25] and p.evolution_stacks == 1, "★3 ketiga berturut -> multiplier 1.25")
	p.register_card_played(hybrid(card(S, 3), card(T, 3), "Piercing Strike"))
	check(chain_events.size() == 1 and p.get_chain_progress() == 3, "maksimal sekali per turn")
	p.start_turn()
	check(is_equal_approx(p.ultimate_damage_multiplier, 1.25), "buff bertahan setelah ganti turn")
	check(p.get_chain_progress() == 0 and p.get_cards_played_this_turn() == 0, "riwayat turn direset")
	for i: int in 3:
		p.register_card_played(card(F, 3))
	check(is_equal_approx(p.ultimate_damage_multiplier, 1.5) and p.evolution_stacks == 2, "turn berikutnya menumpuk -> 1.5")

	print("[Evolutionary Chain, mode bebas & batas]")
	p.chain_requires_consecutive = false
	p.max_ultimate_damage_multiplier = 1.6
	p.start_turn()
	for r: int in [3, 1, 3, 2, 3]:
		p.register_card_played(card(S, r))
	check(is_equal_approx(p.ultimate_damage_multiplier, 1.6), "★3 ★1 ★3 ★2 ★3 terpicu, di-cap 1.6")
	check(not p.check_evolutionary_chain(), "check manual setelah terpicu -> false")

	print("[Battle baru]")
	p.begin_battle(30.0, p.ultimate_damage_multiplier)
	check(is_equal_approx(p.moxie, 30.0) and is_equal_approx(p.ultimate_damage_multiplier, 1.6) and p.evolution_stacks == 0, "begin_battle bisa membawa multiplier & Moxie awal")
	p.begin_battle()
	check(is_equal_approx(p.ultimate_damage_multiplier, 1.0), "begin_battle default -> multiplier kembali 1")

	p.free()
	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
