extends SceneTree
## Tes Sapu Jagad berirama: penilaian ketukan, skor, bonus damage, dan
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
	check(RhythmGebrakan.judge(0) == 1.0 and RhythmGebrakan.judge(90) == 1.0 and RhythmGebrakan.judge(-90) == 1.0, "selisih 90 ms masih tepat")
	check(RhythmGebrakan.judge(91) == 0.5 and RhythmGebrakan.judge(-180) == 0.5, "91-180 ms cukup")
	check(RhythmGebrakan.judge(181) == 0.0, "lebih dari 180 ms meleset")
	check(is_equal_approx(RhythmGebrakan.bonus_for(1.0), 1.3) and is_equal_approx(RhythmGebrakan.bonus_for(0.0), 1.0)
		and is_equal_approx(RhythmGebrakan.bonus_for(0.5), 1.15), "bonus 0-30%")

	print("[Skor satu permainan]")
	var r := RhythmGebrakan.new()
	r.set_pattern(RhythmGebrakan.PATTERNS[0])
	check(r.note_times.size() == 6 and r.note_times[0] == RhythmGebrakan.first_note_ms()
		and RhythmGebrakan.first_note_ms() == RhythmGebrakan.PRE_ROLL_MS + 4 * RhythmGebrakan.BEAT_MS, "6 ketukan setelah empat hitungan kentongan")
	var gaps_ok := true
	for pattern: Array in RhythmGebrakan.PATTERNS:
		var probe := RhythmGebrakan.new()
		probe.set_pattern(pattern)
		for i: int in range(1, probe.note_times.size()):
			gaps_ok = gaps_ok and probe.note_times[i] - probe.note_times[i - 1] >= RhythmGebrakan.BEAT_MS
		probe.free()
	check(gaps_ok and RhythmGebrakan.BEAT_MS >= 650, "semua pola: jarak antar ketukan paling dekat satu ketukan penuh (%d ms)" % RhythmGebrakan.BEAT_MS)
	check(r.press(100) == -1.0, "tekanan jauh dari ketukan diabaikan")
	check(r.press(r.note_times[0] - 400) == -1.0 and r.judgements[0] == -1.0, "tekanan terlalu cepat tidak menghabiskan ketukan")
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
	panel.manual_time_ms = panel.note_times[-1] + RhythmGebrakan.BEAT_MS + 400
	var result: Array[float] = []
	panel.finished.connect(func(s: float) -> void: result.append(s))
	for i: int in 120:
		await process_frame
		if not result.is_empty():
			break
	check(result.size() == 1 and is_equal_approx(result[0], 1.0), "semua tepat: skor 1 dan panel selesai sendiri")
	await process_frame
	check(not is_instance_valid(panel), "panel menutup diri")

	print("[Cara bermain sebelum mulai]")
	var intro := RhythmGebrakan.new()
	intro.set_pattern(RhythmGebrakan.PATTERNS[2])
	intro.manual_time_ms = 0
	intro.show_intro = true
	root.add_child(intro)
	await process_frame
	intro.manual_time_ms = intro.note_times[0]
	var early := intro.press(intro.note_times[0])
	check(not bool(intro.get("_started")) and intro.find_child("*", true, false) != null, "layar cara bermain tampil, irama belum jalan")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	root.push_input(accept)
	await process_frame
	check(bool(intro.get("_started")), "Spasi/Enter di layar cara bermain memulai irama")
	intro.queue_free()
	await process_frame
	check(early == 1.0 or early == -1.0, "penilaian tetap aman sebelum mulai")

	print("[Arak-arakan penutup]")
	# Dimuat saat jalan (bukan lewat nama kelas) karena skripnya memakai autoload.
	var arak_script: GDScript = load("res://scenes/ending/arak_arakan.gd")
	var arak: Control = arak_script.new()
	var times: Array[int] = arak.get("note_times")
	var spaced := true
	for i: int in range(1, times.size()):
		spaced = spaced and times[i] - times[i - 1] >= int(arak_script.get("BEAT_MS"))
	check(times.size() == 26 and spaced, "26 ketukan dalam empat putaran, jaraknya paling dekat satu ketukan")
	check(int(arak_script.call("end_ms")) == 500 + 42 * 600, "arak-arakan selesai setelah 42 ketukan (25,7 detik)")
	var backing := load("res://assets/audio/bgm/arak_arakan.ogg") as AudioStream
	check(backing != null and backing.get_length() * 1000.0 >= float(arak_script.call("end_ms")), "iringan cukup panjang untuk seluruh arak-arakan")
	arak.set("manual_time_ms", 0)
	root.add_child(arak)
	await process_frame
	check(int(arak.call("joined_count")) == 0, "awal: hanya Eyang Palang")
	var joins_ok := true
	for round_index: int in 4:
		var start: int = arak_script.call("round_start_beat", round_index)
		arak.set("manual_time_ms", int(arak_script.call("beat_ms", start - 3)))
		arak.call("_update_beat", arak.get("manual_time_ms"))
		joins_ok = joins_ok and int(arak.call("joined_count")) == round_index
		arak.set("manual_time_ms", int(arak_script.call("beat_ms", start - 2)))
		arak.call("_update_beat", arak.get("manual_time_ms"))
		joins_ok = joins_ok and int(arak.call("joined_count")) == round_index + 1
	check(joins_ok, "setiap rombongan masuk dua ketukan sebelum putarannya")
	check(arak.call("press", times[0]) == 1.0 and arak.call("press", times[1] + 150) == 0.5, "tepat bernilai 1, selisih 150 ms bernilai setengah")
	check(arak.call("press", times[2] + 400) == -1.0, "tekanan yang jauh dari ketukan diabaikan")
	for i: int in range(2, times.size()):
		arak.call("press", times[i])
	check(is_equal_approx(float(arak.call("score")), 25.5 / 26.0), "semarak = rata-rata nilai ketukan")
	check(arak_script.call("rating_key", 0.9) == "ARAK_RATING_3" and arak_script.call("rating_key", 0.1) == "ARAK_RATING_0", "tingkat semarak")
	var results: Array[float] = []
	arak.connect("finished", func(v: float) -> void: results.append(v))
	arak.call("skip")
	check(results.size() == 1 and results[0] < 0.0 and int(arak.call("joined_count")) == 4, "dilewati: semua rombongan langsung ikut")
	arak.queue_free()
	# Bunyi dung dan krek dari tekanan tadi dibiarkan habis dulu sebelum keluar.
	await create_timer(1.5).timeout

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
