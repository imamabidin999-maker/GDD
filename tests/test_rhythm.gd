extends SceneTree
## Tes Gebrakan Dongkrek berirama: penilaian ketukan, skor, bonus damage, dan
## jalannya panel irama sampai selesai.
##   godot --headless -s tests/test_rhythm.gd

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


func _make_battle(hp: int) -> Array:
	var holder := Node.new()
	var deck := DeckController.new()
	deck.shuffle_seed = 3
	var hand := HandManager.new()
	hand.merge_recipes = card_db().call("get_recipes")
	var player := PlayerState.new()
	var hero := HealthComponent.new()
	hero.max_hp = 100
	var bm := BattleManager.new()
	bm.deck = deck
	bm.hand = hand
	bm.player = player
	bm.hero_health = hero
	bm.presentation_delay = 0.0
	for n: Node in [deck, hand, player, hero, bm]:
		holder.add_child(n)
	var buto := EnemyButo.new()
	buto.attack_power = 1
	var h := HealthComponent.new()
	h.max_hp = hp
	buto.add_child(h)
	buto.health = h
	holder.add_child(buto)
	root.add_child(holder)
	var specs: Array[String] = []
	specs.assign(root.get_node("GameState").get("STARTER_DECK"))
	bm.start_battle(card_db().call("build_deck_list", specs), [buto] as Array[EnemyUnit])
	return [bm, buto]


func _run() -> void:
	await process_frame

	print("[Penilaian ketukan]")
	check(RhythmGebrakan.judge(0) == 1.0 and RhythmGebrakan.judge(70) == 1.0 and RhythmGebrakan.judge(-70) == 1.0, "selisih 70 ms masih tepat")
	check(RhythmGebrakan.judge(71) == 0.5 and RhythmGebrakan.judge(-140) == 0.5, "71-140 ms cukup")
	check(RhythmGebrakan.judge(141) == 0.0, "lebih dari 140 ms meleset")
	check(is_equal_approx(RhythmGebrakan.bonus_for(1.0), 1.3) and is_equal_approx(RhythmGebrakan.bonus_for(0.0), 1.0)
		and is_equal_approx(RhythmGebrakan.bonus_for(0.5), 1.15), "bonus 0-30%")

	print("[Skor satu permainan]")
	var r := RhythmGebrakan.new()
	r.set_pattern(RhythmGebrakan.PATTERNS[0])
	check(r.note_times.size() == 6 and r.note_times[0] == RhythmGebrakan.LEAD_IN_MS, "6 ketukan setelah jeda pembuka")
	var gaps_ok := true
	for i: int in range(1, r.note_times.size()):
		gaps_ok = gaps_ok and r.note_times[i] - r.note_times[i - 1] >= RhythmGebrakan.BEAT_MS / 2
	check(gaps_ok, "jarak antar ketukan paling dekat setengah ketukan")
	check(r.press(100) == -1.0, "tekanan jauh dari ketukan diabaikan")
	check(r.press(r.note_times[0] + 20) == 1.0, "ketukan 1 tepat")
	check(r.press(r.note_times[1] - 100) == 0.5, "ketukan 2 cukup")
	r._mark_misses(r.note_times[2] + 200)
	check(r.judgements[2] == 0.0, "ketukan 3 lewat tanpa ditekan: meleset")
	for i: int in range(3, 6):
		r.press(r.note_times[i])
	check(is_equal_approx(r.score(), (1.0 + 0.5 + 0.0 + 3.0) / 6.0), "skor rata-rata = 4,5/6")
	r.free()

	print("[Bonus masuk ke damage Gebrakan]")
	var plain: Array = _make_battle(9999)
	var bm1: BattleManager = plain[0]
	bm1.player.gain_moxie(100.0)
	bm1.request_ultimate()
	var dmg_plain := 9999 - (plain[1] as EnemyButo).health.current_hp
	var boosted: Array = _make_battle(9999)
	var bm2: BattleManager = boosted[0]
	bm2.player.gain_moxie(100.0)
	bm2.request_ultimate(1.3)
	var dmg_boost := 9999 - (boosted[1] as EnemyButo).health.current_hp
	check(dmg_plain > 0 and dmg_boost == roundi(dmg_plain * 1.3), "irama sempurna: damage x1,3 (%d -> %d)" % [dmg_plain, dmg_boost])
	var low: Array = _make_battle(9999)
	var bm3: BattleManager = low[0]
	bm3.player.gain_moxie(100.0)
	bm3.request_ultimate(0.5)
	check(9999 - (low[1] as EnemyButo).health.current_hp == dmg_plain, "bonus di bawah 1 tidak mengurangi damage")

	print("[Panel irama sampai selesai]")
	var panel := RhythmGebrakan.new()
	panel.set_pattern(RhythmGebrakan.PATTERNS[1])
	panel.manual_time_ms = 0
	root.add_child(panel)
	await process_frame
	for i: int in panel.note_times.size():
		panel.manual_time_ms = panel.note_times[i]
		panel.press(panel.manual_time_ms)
	panel.manual_time_ms = panel.note_times[-1] + 1000
	var result: Array[float] = []
	panel.finished.connect(func(s: float) -> void: result.append(s))
	for i: int in 120:
		await process_frame
		if not result.is_empty():
			break
	check(result.size() == 1 and is_equal_approx(result[0], 1.0), "semua tepat: skor 1 dan panel selesai sendiri")
	await process_frame
	check(not is_instance_valid(panel), "panel menutup diri")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
