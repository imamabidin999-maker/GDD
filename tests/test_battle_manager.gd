extends SceneTree

var _failures: int = 0
var _checks: int = 0


class Fixture:
	var bm: BattleManager
	var deck: DeckController
	var hand: HandManager
	var player: PlayerState
	var hero: HealthComponent
	var enemies: Array[EnemyUnit] = []
	var states: Array[String] = []
	var history: Array[String] = [] # tidak pernah di-clear
	var resolved: Array[BattleAction] = []
	var turns: Array[int] = []
	var ended: Array[bool] = []
	var targets: Array[String] = []
	var deck_list: Array[CardData] = []


class MultiHitAction extends BattleAction:
	var target: HealthComponent
	var hits: int = 0

	func _init(t: HealthComponent) -> void:
		target = t

	func _apply(battle: BattleManager) -> void:
		for i: int in 3:
			target.take_damage(1)
			hits += 1
			await battle.get_tree().create_timer(0.05).timeout


class MultiHitEnemy extends EnemyUnit:
	func decide_action(battle: BattleManager) -> BattleAction:
		return MultiHitAction.new(battle.hero_health)


class SlowEnemy extends EnemyUnit:
	func decide_action(battle: BattleManager) -> BattleAction:
		await battle.get_tree().create_timer(0.05).timeout
		return EnemyAttackAction.new(self, battle.hero_health, attack_power)


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func make_card(id: String, type: CardData.CardType, rank: int, power: int) -> CardData:
	var c := CardData.new()
	c.id = StringName(id)
	c.display_name = id
	c.card_type = type
	c.rank = rank
	c.base_power = power
	return c


func make_recipes() -> Array[MergeRecipe]:
	var S := CardData.CardType.SERANG
	var F := CardData.CardType.FOKUS
	var T := CardData.CardType.TAKTIK
	var out: Array[MergeRecipe] = []
	for pair: Array in [[S, F, "Crimson Focus"], [S, T, "Piercing Strike"], [F, T, "Flow State"]]:
		var r := MergeRecipe.new()
		r.type_a = pair[0]
		r.type_b = pair[1]
		for rank: int in [1, 2, 3]:
			r.results.append(make_card(str(pair[2]), CardData.CardType.HYBRID, rank, 20))
		out.append(r)
	return out


func default_deck() -> Array[CardData]:
	var list: Array[CardData] = []
	for i: int in 5:
		list.append(make_card("Serang", CardData.CardType.SERANG, 1, 10))
		list.append(make_card("Fokus", CardData.CardType.FOKUS, 1, 0))
		list.append(make_card("Taktik", CardData.CardType.TAKTIK, 1, 5))
	return list


func make_fixture(enemy_hps: Array[int], hero_hp: int, delay: float, deck_list: Array[CardData], custom: Array[EnemyUnit] = []) -> Fixture:
	var f := Fixture.new()
	var holder := Node.new()
	f.deck = DeckController.new()
	f.deck.shuffle_seed = 7
	f.hand = HandManager.new()
	f.hand.merge_recipes = make_recipes()
	f.player = PlayerState.new()
	f.hero = HealthComponent.new()
	f.hero.max_hp = hero_hp
	f.bm = BattleManager.new()
	f.bm.deck = f.deck
	f.bm.hand = f.hand
	f.bm.player = f.player
	f.bm.hero_health = f.hero
	f.bm.presentation_delay = delay
	for n: Node in [f.deck, f.hand, f.player, f.hero, f.bm]:
		holder.add_child(n)
	for i: int in enemy_hps.size():
		var e: EnemyUnit = custom[i] if i < custom.size() else EnemyUnit.new()
		e.display_name = "Buto%d" % i
		var h := HealthComponent.new()
		h.max_hp = enemy_hps[i]
		e.add_child(h)
		e.health = h
		e.attack_power = 10
		holder.add_child(e)
		f.enemies.append(e)
	root.add_child(holder)
	f.deck_list = deck_list
	f.bm.state_changed.connect(func(p: BattleManager.State, c: BattleManager.State) -> void:
		var entry := "%s>%s" % [BattleManager.State.keys()[p], BattleManager.State.keys()[c]]
		f.states.append(entry)
		f.history.append(entry))
	f.bm.action_resolved.connect(func(a: BattleAction) -> void: f.resolved.append(a))
	f.bm.turn_started.connect(func(t: int) -> void: f.turns.append(t))
	f.bm.battle_ended.connect(func(w: bool) -> void: f.ended.append(w))
	f.bm.target_changed.connect(func(e: EnemyUnit) -> void:
		f.targets.append(e.display_name if e != null else "null"))
	return f


func state_name(f: Fixture) -> String:
	return BattleManager.State.keys()[f.bm.get_state()]


func log_is_consistent(f: Fixture) -> bool:
	var last := "IDLE"
	for entry: String in f.history:
		var parts := entry.split(">")
		if parts[0] != last:
			return false
		last = parts[1]
	return last == state_name(f)


func first_index(f: Fixture, want_damage: bool) -> int:
	for i: int in f.hand.get_card_count():
		if (f.hand.get_card(i).data.base_power > 0) == want_damage:
			return i
	return -1


func wait_until_settled(f: Fixture) -> void:
	for i: int in 100:
		if f.bm.is_accepting_input() or not f.bm.is_battle_running():
			return
		await create_timer(0.02).timeout


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	print("[Validasi start_battle]")
	var bad := BattleManager.new()
	root.add_child(bad)
	var no_enemies: Array[EnemyUnit] = []
	check(not bad.start_battle(default_deck(), no_enemies), "referensi kosong -> ditolak")
	var f := make_fixture([40, 40], 100, 0.0, default_deck())
	check(not f.bm.start_battle(f.deck_list, no_enemies), "tanpa musuh -> ditolak")
	check(f.bm.get_state() == BattleManager.State.IDLE, "state tetap IDLE")

	print("[Mulai battle]")
	check(f.bm.start_battle(f.deck_list, f.enemies), "start_battle berhasil")
	check(state_name(f) == "PLAYER_TURN" and f.bm.turn_number == 1, "PLAYER_TURN, turn 1")
	check(f.player.current_ap == 4 and f.hand.get_card_count() == 7, "AP 4, tangan 7")
	check(f.states == ["IDLE>PLAYER_TURN"] and f.turns == [1], "signal state & turn_started benar")
	check(f.bm.get_target() == f.enemies[0], "target awal = Buto0")
	check(not f.bm.start_battle(f.deck_list, f.enemies), "start saat battle berjalan -> ditolak")

	print("[Main kartu (sinkron)]")
	var idx := first_index(f, true)
	var dmg := f.hand.get_card(idx).data.base_power
	f.states.clear()
	check(f.bm.request_play_card(idx), "request_play_card diterima")
	check(f.enemies[0].health.current_hp == 40 - dmg, "Buto0 kena %d damage" % dmg)
	check(f.player.current_ap == 3 and f.hand.get_card_count() == 6, "AP 3, tangan 6 (tidak ditarik ulang)")
	check(f.deck.get_discard_count() == 1, "kartu masuk discard")
	check(f.states == ["PLAYER_TURN>RESOLVE_ACTIONS", "RESOLVE_ACTIONS>CHECK_WIN_LOSE", "CHECK_WIN_LOSE>PLAYER_TURN"], "urutan state P>R>C>P")
	check(f.bm.turn_number == 1 and f.turns == [1], "masih turn 1")
	check(f.resolved.size() == 1 and f.resolved[0] is PlayCardAction, "action_resolved terkirim")
	check(not f.bm.request_play_card(99), "index tidak valid -> ditolak")
	check(f.player.current_ap == 3, "AP tidak terpotong untuk index tidak valid")

	print("[Geser kartu]")
	f.states.clear()
	check(not f.bm.request_move_card(0, 0), "geser ke posisi sama -> ditolak")
	check(not f.bm.request_move_card(0, 50), "geser ke luar tangan -> ditolak")
	check(f.player.current_ap == 3, "AP utuh setelah geser yang ditolak")
	var before_count := f.hand.get_card_count()
	check(f.bm.request_move_card(0, before_count - 1), "geser 0 -> ujung diterima")
	check(f.player.current_ap == 2 and f.states.is_empty(), "AP 2, state tidak berubah")

	print("[AP habis]")
	f.bm.request_play_card(0)
	f.bm.request_play_card(0)
	check(f.player.current_ap == 0, "AP 0")
	var hand_before := f.hand.get_card_count()
	check(not f.bm.request_play_card(0) and f.hand.get_card_count() == hand_before, "AP 0 -> main kartu ditolak, tangan utuh")
	check(not f.bm.request_ultimate(), "Moxie kurang -> Ultimate ditolak")
	check(f.deck.verify_integrity(f.hand.get_cards()), "integritas 15 kartu")

	print("[End turn -> giliran musuh]")
	var hero_before := f.hero.current_hp
	var living_before := f.bm.get_living_enemies().size()
	f.states.clear()
	f.resolved.clear()
	check(f.bm.request_end_turn(), "end turn diterima")
	check(f.hero.current_hp == hero_before - 10 * living_before, "hero kena %d serangan" % living_before)
	# 2 serangan Buto + 1 aksi racun di akhir (dilewati karena racun 0).
	check(f.states == ["PLAYER_TURN>ENEMY_TURN", "ENEMY_TURN>RESOLVE_ACTIONS", "RESOLVE_ACTIONS>CHECK_WIN_LOSE",
		"CHECK_WIN_LOSE>RESOLVE_ACTIONS", "RESOLVE_ACTIONS>CHECK_WIN_LOSE",
		"CHECK_WIN_LOSE>RESOLVE_ACTIONS", "RESOLVE_ACTIONS>CHECK_WIN_LOSE", "CHECK_WIN_LOSE>PLAYER_TURN"], "urutan state giliran musuh")
	check(f.bm.turn_number == 2 and f.turns == [1, 2], "turn 2 dimulai")
	check(f.player.current_ap == 4 and f.hand.get_card_count() == 7, "AP diisi ulang, tangan penuh lagi")
	check(f.deck.verify_integrity(f.hand.get_cards()), "integritas 15 kartu setelah turn baru")

	print("[Target pindah saat Buto mati]")
	f.enemies[0].health.reset(1)
	f.bm.request_play_card(first_index(f, true))
	check(not f.enemies[0].is_alive(), "Buto0 mati")
	check(f.bm.get_target() == f.enemies[1] and f.targets.back() == "Buto1", "target otomatis pindah ke Buto1")
	check(not f.bm.select_target(f.enemies[0]), "pilih Buto mati -> ditolak")
	check(state_name(f) == "PLAYER_TURN", "battle lanjut (Buto1 masih hidup)")

	print("[Buto mati tidak menyerang]")
	hero_before = f.hero.current_hp
	f.resolved.clear()
	f.bm.request_end_turn()
	check(f.hero.current_hp == hero_before - 10 and f.resolved.size() == 1, "hanya Buto1 yang menyerang")

	print("[Menang]")
	f.enemies[1].health.reset(1)
	f.bm.request_play_card(first_index(f, true))
	check(state_name(f) == "VICTORY" and f.ended == [true], "VICTORY + battle_ended(true)")
	check(not f.bm.is_battle_running() and not f.bm.request_end_turn() and not f.bm.request_play_card(0), "semua input ditolak setelah menang")
	check(log_is_consistent(f), "log state konsisten (prev selalu = current sebelumnya)")

	print("[Battle ulang setelah selesai]")
	for e: EnemyUnit in f.enemies:
		e.health.reset()
	check(f.bm.start_battle(f.deck_list, f.enemies), "start_battle lagi setelah VICTORY")
	check(f.bm.turn_number == 1 and f.hand.get_card_count() == 7 and f.deck.get_draw_count() == 8, "battle baru bersih")
	check(f.deck.verify_integrity(f.hand.get_cards()), "integritas 15 kartu di battle baru")

	print("[Kalah: Buto kedua tidak sempat menyerang]")
	var g := make_fixture([50, 50], 10, 0.0, default_deck())
	g.bm.start_battle(g.deck_list, g.enemies)
	g.resolved.clear()
	g.bm.request_end_turn()
	check(state_name(g) == "DEFEAT" and g.ended == [false], "DEFEAT + battle_ended(false)")
	check(g.resolved.size() == 1, "hanya 1 serangan yang di-resolve")
	check(log_is_consistent(g), "log state konsisten")

	print("[Ultimate]")
	var u := make_fixture([1000], 100, 0.0, default_deck())
	u.bm.ultimate_base_damage = 100
	u.bm.start_battle(u.deck_list, u.enemies)
	u.player.gain_moxie(200.0)
	u.player.ultimate_damage_multiplier = 1.5
	u.bm.ultimate_ap_cost = 5
	check(not u.bm.request_ultimate() and is_equal_approx(u.player.moxie, 200.0), "AP kurang -> Ultimate ditolak, Moxie utuh")
	u.bm.ultimate_ap_cost = 1
	check(u.bm.request_ultimate(), "Ultimate diterima")
	check(u.enemies[0].health.current_hp == 1000 - 300, "damage 100 x 1.5 x 2 = 300")
	check(u.player.moxie == 0.0 and u.player.current_ap == 3, "Moxie habis, AP 3")
	check(state_name(u) == "PLAYER_TURN", "kembali ke PLAYER_TURN")

	print("[Auto-merge saat geser]")
	var md: Array[CardData] = []
	for i: int in 8:
		md.append(make_card("Serang", CardData.CardType.SERANG, 1, 10))
	for i: int in 7:
		md.append(make_card("Fokus", CardData.CardType.FOKUS, 1, 0))
	var m := make_fixture([100], 100, 0.0, md)
	m.bm.start_battle(m.deck_list, m.enemies)
	var first_type := m.hand.get_card(0).get_type()
	var k := -1
	for i: int in range(2, m.hand.get_card_count()):
		if m.hand.get_card(i).get_type() != first_type:
			k = i
			break
	check(k != -1, "ada kartu beda tipe untuk dites (k=%d)" % k)
	if k != -1:
		check(m.bm.request_move_card(k, 1), "geser kartu ke sebelah kartu beda tipe")
		check(m.hand.get_card_count() == 6 and m.hand.get_card(0).is_hybrid(), "otomatis jadi Crimson Focus")
		check(m.player.current_ap == 3, "geser + merge cuma 1 AP")
		m.bm.request_play_card(0)
		check(m.deck.verify_integrity(m.hand.get_cards()), "main kartu hybrid: integritas 15 tetap")

	print("[Buang tangan saat end turn]")
	var dh := make_fixture([500], 500, 0.0, default_deck())
	dh.bm.discard_hand_on_turn_end = true
	dh.bm.start_battle(dh.deck_list, dh.enemies)
	dh.bm.request_end_turn()
	check(dh.hand.get_card_count() == 7 and dh.deck.verify_integrity(dh.hand.get_cards()), "tangan dibuang lalu ditarik ulang 7")

	print("[Async: input terkunci selama animasi]")
	var a := make_fixture([100, 100], 100, 0.05, default_deck())
	a.bm.start_battle(a.deck_list, a.enemies)
	check(a.bm.request_play_card(0), "main kartu dengan animasi 0.05s")
	check(state_name(a) == "RESOLVE_ACTIONS", "masih RESOLVE_ACTIONS selama animasi")
	check(not a.bm.is_accepting_input(), "is_accepting_input false")
	check(not a.bm.request_play_card(0) and not a.bm.request_end_turn() and not a.bm.request_move_card(0, 1), "semua request ditolak saat animasi")
	check(a.player.current_ap == 3, "AP hanya terpotong sekali")
	await create_timer(0.2).timeout
	check(state_name(a) == "PLAYER_TURN" and a.resolved.size() == 1, "setelah animasi kembali ke PLAYER_TURN")
	a.bm.request_end_turn()
	check(state_name(a) == "RESOLVE_ACTIONS", "giliran musuh juga menunggu animasi")
	await create_timer(0.5).timeout
	check(state_name(a) == "PLAYER_TURN" and a.bm.turn_number == 2, "turn 2 setelah 2 serangan selesai")
	check(a.hero.current_hp == 80, "hero kena 2 x 10")
	check(log_is_consistent(a), "log state konsisten (async)")

	print("[Re-entrancy: request dari listener ditolak (async)]")
	var r := make_fixture([100, 100], 100, 0.05, default_deck())
	var nested_results: Array[bool] = []
	r.player.ap_changed.connect(func(cur: int, _max: int) -> void:
		if cur == 0:
			nested_results.append(r.bm.request_end_turn()))
	r.bm.start_battle(r.deck_list, r.enemies)
	for i: int in 4:
		r.bm.request_play_card(0)
		await wait_until_settled(r)
	check(nested_results.size() == 1 and nested_results[0] == false, "request_end_turn dari ap_changed ditolak")
	check(not r.history.has("RESOLVE_ACTIONS>RESOLVE_ACTIONS"), "tidak ada dua coroutine RESOLVE")
	check(r.bm.turn_number == 1 and r.resolved.size() == 4, "masih turn 1, 4 kartu ter-resolve berurutan")
	var all_play := true
	for act: BattleAction in r.resolved:
		all_play = all_play and act is PlayCardAction
	check(all_play and r.hero.current_hp == 100, "tidak ada serangan musuh yang menyelip")

	print("[Re-entrancy (sinkron) lewat card_removed]")
	var rs := make_fixture([100, 100], 100, 0.0, default_deck())
	var rs_nested: Array[bool] = []
	rs.hand.card_removed.connect(func(_c: CardInstance, _i: int) -> void: rs_nested.append(rs.bm.request_end_turn()))
	rs.bm.start_battle(rs.deck_list, rs.enemies)
	rs.bm.request_play_card(0)
	check(rs_nested == [false] and rs.bm.turn_number == 1 and rs.hand.get_card_count() == 6, "End Turn bersarang ditolak, turn & tangan utuh")
	check(log_is_consistent(rs), "log state konsisten")

	print("[Auto End Turn lewat player_input_ready]")
	var ae := make_fixture([200, 200], 100, 0.0, default_deck())
	var ready_count: Array[int] = [0]
	ae.bm.player_input_ready.connect(func() -> void:
		ready_count[0] += 1
		if ae.player.current_ap == 0:
			ae.bm.request_end_turn())
	ae.bm.start_battle(ae.deck_list, ae.enemies)
	check(ready_count[0] == 0, "player_input_ready deferred: belum terpancar di dalam start_battle")
	await process_frame
	await process_frame
	check(ready_count[0] == 1, "player_input_ready terpancar sekali setelah start")
	for i: int in 4:
		ae.bm.request_play_card(0)
	await process_frame
	await process_frame
	check(ae.turns == [1, 2] and ae.bm.turn_number == 2, "AP habis -> turn otomatis berakhir, turn 2 dimulai")
	check(ae.hero.current_hp == 80 and ae.player.current_ap == 4, "musuh menyerang sekali saja, AP turn 2 penuh")
	check(state_name(ae) == "PLAYER_TURN" and ae.bm.is_accepting_input(), "pemain bisa beraksi di turn 2")

	print("[state_changed melihat data turn baru]")
	var sc := make_fixture([200, 200], 100, 0.0, default_deck())
	var seen: Array[String] = []
	var sc_nested: Array[bool] = []
	sc.bm.state_changed.connect(func(_p: BattleManager.State, c: BattleManager.State) -> void:
		if c == BattleManager.State.PLAYER_TURN:
			seen.append("t%d ap%d h%d" % [sc.bm.turn_number, sc.player.current_ap, sc.hand.get_card_count()])
			sc_nested.append(sc.bm.request_end_turn()))
	sc.bm.start_battle(sc.deck_list, sc.enemies)
	sc.bm.request_play_card(0)
	sc.bm.request_end_turn()
	check(seen == ["t1 ap4 h7", "t1 ap3 h6", "t2 ap4 h7"], "AP & tangan sudah siap saat diumumkan: %s" % [seen])
	check(not sc_nested.has(true) and sc.bm.turn_number == 2, "request dari state_changed ditolak")

	print("[Pause]")
	var pz := make_fixture([100], 100, 0.05, default_deck())
	pz.bm.start_battle(pz.deck_list, pz.enemies)
	pz.bm.request_play_card(0)
	paused = true
	await create_timer(0.2, true).timeout
	check(state_name(pz) == "RESOLVE_ACTIONS", "saat pause, animasi tidak jalan")
	paused = false
	await create_timer(0.2).timeout
	check(state_name(pz) == "PLAYER_TURN", "setelah unpause, lanjut ke PLAYER_TURN")

	print("[Guard start_battle]")
	var sg := make_fixture([100], 10, 0.0, default_deck())
	sg.hero.take_damage(10)
	check(not sg.bm.start_battle(sg.deck_list, sg.enemies) and state_name(sg) == "IDLE", "hero mati -> ditolak")
	sg.hero.reset()
	sg.enemies[0].health.take_damage(999)
	check(not sg.bm.start_battle(sg.deck_list, sg.enemies), "semua musuh mati -> ditolak")
	sg.enemies[0].health.reset(1)
	sg.bm.start_battle(sg.deck_list, sg.enemies)
	sg.bm.request_play_card(first_index(sg, true))
	check(state_name(sg) == "VICTORY", "menang")
	sg.enemies[0].health.reset() # supaya yang gagal benar-benar validasi deck
	var hand_after_win := sg.hand.get_card_count()
	var short_deck: Array[CardData] = sg.deck_list.slice(0, 14)
	check(not sg.bm.start_battle(short_deck, sg.enemies), "deck 14 kartu -> ditolak")
	check(sg.hand.get_card_count() == hand_after_win and sg.deck.verify_integrity(sg.hand.get_cards()), "start gagal tidak merusak tangan & deck")

	print("[select_target saat animasi]")
	var st := make_fixture([100, 100], 100, 0.05, default_deck())
	st.bm.start_battle(st.deck_list, st.enemies)
	st.bm.request_play_card(0)
	check(not st.bm.select_target(st.enemies[1]), "select_target ditolak di RESOLVE_ACTIONS")
	await wait_until_settled(st)
	check(st.bm.select_target(st.enemies[1]) and st.bm.get_target() == st.enemies[1], "select_target diterima di PLAYER_TURN")

	print("[_apply & decide_action async]")
	var mh_units: Array[EnemyUnit] = [MultiHitEnemy.new()]
	var mh := make_fixture([100], 100, 0.0, default_deck(), mh_units)
	mh.bm.start_battle(mh.deck_list, mh.enemies)
	mh.bm.request_end_turn()
	check(state_name(mh) == "RESOLVE_ACTIONS", "serangan beruntun menahan RESOLVE_ACTIONS")
	await wait_until_settled(mh)
	check(mh.hero.current_hp == 97 and mh.bm.turn_number == 2, "3 hit masuk sebelum turn 2")
	var slow_units: Array[EnemyUnit] = [SlowEnemy.new()]
	var sl := make_fixture([100], 100, 0.0, default_deck(), slow_units)
	sl.bm.start_battle(sl.deck_list, sl.enemies)
	sl.bm.request_end_turn()
	check(state_name(sl) == "ENEMY_TURN" and not sl.bm.request_play_card(0), "AI yang berpikir: tetap ENEMY_TURN, input terkunci")
	await wait_until_settled(sl)
	check(sl.hero.current_hp == 90 and sl.bm.turn_number == 2, "AI selesai -> serangan masuk, turn 2")

	print("[request_merge manual]")
	var mmd: Array[CardData] = []
	for i: int in 8:
		mmd.append(make_card("Serang", CardData.CardType.SERANG, 1, 10))
	for i: int in 7:
		mmd.append(make_card("Fokus", CardData.CardType.FOKUS, 1, 0))
	var mm := make_fixture([100], 100, 0.0, mmd)
	mm.bm.auto_merge_on_move = false
	mm.bm.start_battle(mm.deck_list, mm.enemies)
	var pair := -1
	for i: int in mm.hand.get_card_count() - 1:
		if mm.hand.can_merge_at(i, i + 1):
			pair = i
			break
	check(pair != -1, "ada pasangan bersebelahan yang cocok (i=%d)" % pair)
	if pair != -1:
		check(mm.bm.request_merge(pair, pair + 1) and mm.hand.get_card_count() == 6, "request_merge berhasil")
		check(mm.player.current_ap == 4, "merge manual gratis AP")
	check(not mm.bm.request_merge(0, 3), "pasangan tidak bersebelahan -> ditolak")

	print("[Signal battle_started & turn_ended]")
	var sig := make_fixture([100], 100, 0.0, default_deck())
	var sig_log: Array[String] = []
	sig.bm.battle_started.connect(func() -> void: sig_log.append("start"))
	sig.bm.turn_ended.connect(func(t: int) -> void: sig_log.append("end%d" % t))
	sig.bm.start_battle(sig.deck_list, sig.enemies)
	sig.bm.request_end_turn()
	check(sig_log == ["start", "end1"], "battle_started & turn_ended(1)")

	print("[Auto-battle delay 0: tidak stack overflow]")
	var ab := make_fixture([3000], 100000, 0.0, default_deck())
	var ab_count: Array[int] = [0]
	ab.bm.player_input_ready.connect(func() -> void:
		ab_count[0] += 1
		if ab.player.current_ap > 0:
			ab.bm.request_play_card(0)
		else:
			ab.bm.request_end_turn())
	ab.bm.start_battle(ab.deck_list, ab.enemies)
	for i: int in 5000:
		if not ab.bm.is_battle_running():
			break
		await process_frame
	check(state_name(ab) == "VICTORY", "auto-battle selesai VICTORY (turn %d, %d ready)" % [ab.bm.turn_number, ab_count[0]])
	check(ab.bm.turn_number > 103, "lewat titik stack overflow lama (turn 103)")

	print("[Driver coroutine menunggu player_input_ready (delay 0)]")
	var cd := make_fixture([100000], 100000, 0.0, default_deck())
	cd.bm.start_battle(cd.deck_list, cd.enemies)
	var actions: Array[int] = [0]
	for i: int in 12:
		await cd.bm.player_input_ready
		if cd.player.current_ap > 0:
			cd.bm.request_play_card(0)
		else:
			cd.bm.request_end_turn()
		actions[0] += 1
	check(actions[0] == 12 and cd.bm.turn_number >= 3, "driver tidak macet: %d aksi, turn %d" % [actions[0], cd.bm.turn_number])

	print("[select_target terkunci saat target_changed]")
	var tl := make_fixture([200, 200], 100, 0.0, default_deck())
	tl.bm.start_battle(tl.deck_list, tl.enemies)
	var tl_nested: Array[bool] = []
	tl.bm.target_changed.connect(func(_e: EnemyUnit) -> void: tl_nested.append(tl.bm.request_play_card(0)))
	check(tl.bm.select_target(tl.enemies[1]), "select_target diterima")
	check(tl_nested == [false] and tl.player.current_ap == 4 and state_name(tl) == "PLAYER_TURN", "request dari target_changed ditolak")

	print("[start_battle dari listener ditolak, call_deferred jalan]")
	var rb := make_fixture([1], 100, 0.0, default_deck())
	var rb_results: Array[bool] = []
	var rb_started: Array[int] = [0]
	rb.bm.battle_started.connect(func() -> void:
		rb_started[0] += 1
		rb_results.append(rb.bm.start_battle(rb.deck_list, rb.enemies)))
	rb.bm.start_battle(rb.deck_list, rb.enemies)
	check(rb_results == [false] and rb_started[0] == 1 and rb.bm.turn_number == 1, "start dari battle_started ditolak, tetap turn 1")
	var restart := func(_won: bool) -> void:
		for e: EnemyUnit in rb.enemies:
			e.health.reset()
		rb_results.append(rb.bm.start_battle(rb.deck_list, rb.enemies))
	rb.bm.battle_ended.connect(restart)
	rb.bm.request_play_card(first_index(rb, true))
	check(rb_results == [false, false] and state_name(rb) == "VICTORY", "start langsung dari battle_ended ditolak")
	rb.bm.battle_ended.disconnect(restart)
	rb.bm.battle_ended.connect(func(_won: bool) -> void:
		for e: EnemyUnit in rb.enemies:
			e.health.reset()
		rb.bm.start_battle.call_deferred(rb.deck_list, rb.enemies))
	for e: EnemyUnit in rb.enemies:
		e.health.reset(1)
	rb_started[0] = 0
	rb.bm.start_battle(rb.deck_list, rb.enemies)
	rb.bm.request_play_card(first_index(rb, true))
	await process_frame
	await process_frame
	check(state_name(rb) == "PLAYER_TURN" and rb.bm.turn_number == 1 and rb_started[0] == 2, "restart lewat call_deferred berhasil")

	print("[process_mode BattleManager dihormati]")
	var pm := make_fixture([100], 100, 0.05, default_deck())
	pm.bm.start_battle(pm.deck_list, pm.enemies)
	pm.bm.process_mode = Node.PROCESS_MODE_DISABLED
	pm.bm.request_play_card(0)
	await create_timer(0.2).timeout
	check(state_name(pm) == "RESOLVE_ACTIONS", "node DISABLED -> animasi tertahan")
	pm.bm.process_mode = Node.PROCESS_MODE_INHERIT
	await create_timer(0.2).timeout
	check(state_name(pm) == "PLAYER_TURN", "node aktif lagi -> lanjut")

	print("[HealthComponent]")
	var h := HealthComponent.new()
	var pre_ready: Array[int] = [0]
	h.hp_changed.connect(func(_c: int, _m: int) -> void: pre_ready[0] += 1)
	h.max_hp = 300
	check(h.current_hp == 300, "max_hp dari Inspector -> HP awal penuh tanpa _ready")
	check(pre_ready[0] == 0, "setter tidak memancarkan hp_changed sebelum node siap")
	root.add_child(h)
	check(h.take_damage(500) == 300 and h.is_dead(), "overkill dibatasi sisa HP")
	check(h.take_damage(5) == 0 and h.heal(50) == 0, "unit mati tidak bisa kena damage / heal")
	h.reset(120)
	check(h.current_hp == 120 and h.heal(1000) == 180, "reset(120) lalu heal dibatasi max")
	var hp_log: Array[String] = []
	h.hp_changed.connect(func(c: int, m: int) -> void: hp_log.append("%d/%d" % [c, m]))
	h.max_hp = 150
	h.take_damage(50)
	h.max_hp = 200
	check(hp_log == ["150/150", "100/150", "100/200"], "max_hp setter memancarkan hp_changed: %s" % [hp_log])
	h.free()

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
