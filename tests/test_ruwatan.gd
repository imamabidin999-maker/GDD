extends SceneTree
## Tes Mode Ruwatan: jalur delapan langkah, aturan Tingkat Pagebluk, profil
## pemain, simpan-muat, catatan hasil di GameState, dan battle Ruwatan di
## scene battle yang asli.
##   godot --headless -s tests/test_ruwatan.gd

var _failures: int = 0
var _checks: int = 0


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _initialize() -> void:
	_run()


func _starter() -> Array[String]:
	var deck: Array[String] = []
	deck.assign(root.get_node("GameState").get("STARTER_DECK"))
	return deck


func _make_buto(spec: EnemySpec) -> EnemyButo:
	var buto := spec.create_buto()
	root.add_child(buto)
	return buto


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_save.cfg")
	gs.call("new_game")
	gs.call("abandon_ruwatan")
	gs.set("ruwatan_best", {})
	gs.set("stage_stars", {})
	gs.set("ruwatan_unlocked", false)

	print("[Jalur delapan langkah]")
	var run := RuwatanRun.create(1, 7, _starter())
	check(run.foes.size() == 8 and run.events.size() == 8, "delapan langkah")
	var kinds_ok := true
	for i: int in 8:
		var is_event := RuwatanRun.STEPS[i] == RuwatanRun.Step.EVENT
		kinds_ok = kinds_ok and (run.foes[i].is_empty() == is_event) and ((run.events[i] != "") == is_event)
	check(kinds_ok, "langkah 3 dan 6 kejadian, sisanya battle")
	check(run.events[2] != run.events[5] and JourneyEvents.exists(run.events[2]) and JourneyEvents.exists(run.events[5]),
		"dua kejadian berbeda")
	var first := run.enemy_specs(0)
	check(first.size() == 2 and first[0].buto_type != first[1].buto_type and not first[0].murka, "langkah 1: dua Buto biasa berbeda warna")
	check(run.enemy_specs(1)[0].buto_type != first[0].buto_type, "pemimpin langkah 2 berbeda dari langkah 1")
	var murka := run.enemy_specs(3)
	check(murka[0].murka and murka[0].can_ngamuk and not murka[1].murka, "langkah 4: Buto Murka dan pendamping")
	var twin := run.enemy_specs(6)
	check(twin.size() == 2 and twin[0].murka and twin[1].murka and twin[0].start_amuk != twin[1].start_amuk,
		"langkah 7: sepasang Buto Murka, Ngamuknya tidak bersamaan")
	var boss := run.build_stage(7)
	check(boss.is_boss and boss.music == "boss" and boss.enemies[0].buto_type == EnemyButo.ButoType.HITAM, "langkah 8: Buto Hitam")
	var tracks: Array[String] = []
	for i: int in RuwatanRun.STEPS.size():
		tracks.append(RuwatanRun.music_for(i))
	check(tracks == ["battle", "battle", "battle", "battle_murka", "battle_murka", "battle", "battle_candi", "boss"],
		"lagu tiap langkah mengikuti bagian cerita yang setara")
	check(run.enemy_specs(1)[0].max_hp == roundi(RuwatanRun.LEAD[run.enemy_specs(1)[0].buto_type][0] * RuwatanRun.SECOND_HP_MULT),
		"battle kedua sedikit lebih alot")
	var bg_ok := true
	for i: int in 8:
		var bg := run.build_stage(i).background
		if run.is_battle_step(i) and not ResourceLoader.exists(bg):
			bg_ok = false
	check(bg_ok and run.build_stage(7).background.ends_with("stage_10.png") and run.build_stage(6).background.ends_with("stage_9.png"),
		"setiap battle punya latar: candi di langkah 7, Candi Pagebluk di langkah 8")
	var same := RuwatanRun.create(1, 7, _starter())
	check(str(same.foes) == str(run.foes) and same.events == run.events, "seed sama, jalur sama")
	var differs := false
	for s: int in range(8, 20):
		if str(RuwatanRun.create(1, s, _starter()).foes) != str(run.foes):
			differs = true
	check(differs, "seed lain, jalur lain")

	print("[Tingkat Pagebluk]")
	var l1 := RuwatanRun.create(1, 1, _starter())
	var l4 := RuwatanRun.create(4, 1, _starter())
	var l6 := RuwatanRun.create(6, 1, _starter())
	var l10 := RuwatanRun.create(10, 1, _starter())
	check(l1.enemy_hp_mult() == 1.0 and RuwatanRun.create(2, 1, _starter()).enemy_hp_mult() == 1.1 and l10.enemy_hp_mult() == 1.2,
		"Nyawa Buto +10% di tingkat 2, +20% di tingkat 8")
	check(l1.enemy_attack_mult() == 1.0 and RuwatanRun.create(3, 1, _starter()).enemy_attack_mult() == 1.1, "serangan +10% di tingkat 3")
	check(l1.heal_ratio() == RuwatanRun.HEAL_RATIO and l4.heal_ratio() == RuwatanRun.HEAL_RATIO_HARD
		and RuwatanRun.HEAL_RATIO_HARD < RuwatanRun.HEAL_RATIO, "pemulihan berkurang mulai tingkat 4")
	check(l1.blessing_choices() == 3 and l6.blessing_choices() == 2, "pilihan berkah 3, lalu 2 di tingkat 6")
	check(l6.start_poison() == 0 and l10.start_poison() == RuwatanRun.START_POISON, "Lara di awal battle mulai tingkat 7")
	check(RuwatanRun.rule_keys(1).is_empty() and RuwatanRun.rule_keys(10).size() == 9, "daftar aturan bertumpuk")
	var plain := _make_buto(l1.enemy_specs(0)[0])
	var plain_hp := plain.health.max_hp
	l1.modify_buto(plain)
	check(plain.health.max_hp == plain_hp and not plain.can_ngamuk, "tingkat 1: Buto apa adanya")
	var angry := _make_buto(l10.enemy_specs(0)[1])
	var angry_hp := angry.health.max_hp
	var angry_atk := angry.attack_power
	l10.modify_buto(angry)
	check(angry.health.max_hp == roundi(angry_hp * 1.2) and angry.health.current_hp == angry.health.max_hp
		and angry.attack_power == roundi(angry_atk * 1.1), "tingkat 10: Nyawa x1,2 dan serangan x1,1")
	check(angry.can_ngamuk, "tingkat 5 ke atas: Buto biasa bisa Ngamuk")
	var hitam := _make_buto(l10.enemy_specs(7)[0])
	var ajian_before := hitam.ajian_break_threshold
	var pagebluk_before := hitam.pagebluk_poison
	l10.modify_buto(hitam)
	check(hitam.bala_count == 3 and hitam.ajian_break_threshold == ajian_before + 10 and hitam.pagebluk_poison == pagebluk_before + 1,
		"tingkat 9-10: 3 Bala, Ajian +10, Pagebluk Merata +1")
	for n: Node in [plain, angry, hitam]:
		n.free()

	print("[Profil pemain Ruwatan]")
	var p := RuwatanRun.create(1, 3, _starter())
	check(p.get_max_hp() == 70 and p.hp == 70 and p.get_blessings().is_empty(), "mulai 70 Nyawa tanpa berkah")
	p.hp = 40
	p.change_max_hp(5)
	check(p.max_hp == 75 and p.hp == 45, "Nyawa maksimal +5 ikut mengisi Nyawa")
	p.change_max_hp(-500)
	check(p.max_hp == 30 and p.hp == 30, "Nyawa maksimal paling rendah 30, Nyawa ikut terpotong")
	p.apply_blessing(Blessings.Kind.JAMU_KUNYIT_ASAM)
	check(p.max_hp == 40 and p.hp == 40 and p.blessings.has("JAMU_KUNYIT_ASAM"), "Jamu Kunyit Asam: +10 Nyawa")
	var up: Array[String] = p.apply_blessing(Blessings.Kind.TEMPA_SABET)
	check(up.size() == 2 and p.deck.count("serang:2") == 4, "Tempa Sabet menaikkan dua Sabet")
	var swap := p.place_tabuh(5, "gong")
	check(swap.size() == 2 and swap[0] == "fokus:1" and swap[1] == "gong:2", "kartu Tabuh dipasang: %s" % str(swap))
	var upgraded := p.upgrade_card(5)
	check(upgraded == "gong:3" and p.deck[5] == upgraded, "tempa kartu pilihan")
	check(p.downgrade_card(5) == "gong:2", "kartu turun bintang")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var roll3: Array[Blessings.Kind] = p.roll_blessings(rng)
	var p6 := RuwatanRun.create(6, 3, _starter(), [Blessings.Kind.TABUH_KENONG])
	var no_kenong := true
	for i: int in 40:
		var roll: Array[Blessings.Kind] = p6.roll_blessings(rng)
		no_kenong = no_kenong and roll.size() == 2 and not roll.has(Blessings.Kind.TABUH_KENONG)
	check(roll3.size() == 3 and no_kenong, "undian berkah: 3 pilihan, 2 di tingkat 6, Kenong tetap terkunci")
	var event_line := JourneyEvents.apply("hp:+8", p, rng)
	check(p.max_hp == 48 and event_line != "", "kejadian bekerja pada profil Ruwatan")

	print("[Cabang jalan Ruwatan]")
	var forked := RuwatanRun.create(1, 11, _starter())
	var same_seed := RuwatanRun.create(1, 11, _starter())
	var forks_ok := forked.alt_events.size() == RuwatanRun.STEPS.size() and forked.alt_events == same_seed.alt_events
	var all_events: Array[String] = []
	for i: int in RuwatanRun.STEPS.size():
		var main: String = forked.events[i]
		var alt: String = forked.alt_events[i]
		forks_ok = forks_ok and (alt == "") == (main == "")
		for id: String in [main, alt]:
			if id != "":
				forks_ok = forks_ok and not all_events.has(id)
				all_events.append(id)
	check(forks_ok and all_events.size() == 4, "dua langkah kejadian, masing-masing dua cabang yang berbeda, sama untuk seed yang sama")
	forked.step = 2
	check(forked.current_paths() == [forked.events[2], forked.alt_events[2]], "langkah kejadian menawarkan dua cabang")
	forked.step = 0
	check(forked.current_paths().is_empty(), "langkah battle tidak punya cabang")

	print("[Jalannya Ruwatan]")
	var r := RuwatanRun.create(1, 11, _starter())
	var saves := [0]
	r.changed.connect(func() -> void: saves[0] += 1)
	var healed := r.win_battle(30)
	var heal := roundi(70 * RuwatanRun.HEAL_RATIO)
	check(healed == heal and r.hp == 30 + heal and r.step == 1 and r.pending_blessing, "menang dengan 30 Nyawa: pulih %d" % heal)
	r.finish_blessing()
	r.win_battle(70)
	check(r.hp == 70 and r.current_step() == RuwatanRun.Step.EVENT, "pemulihan tidak melewati Nyawa maksimal")
	check(r.win_battle(10) == 0 and r.step == 2 and r.hp == 70, "langkah kejadian tidak bisa dimenangkan sebagai battle")
	r.finish_event()
	check(r.step == 3 and r.current_step() == RuwatanRun.Step.MURKA, "kejadian selesai: lanjut ke Buto Murka")
	for i: int in 2:
		r.win_battle(r.hp)
	r.finish_event()
	r.win_battle(r.hp)
	check(r.current_step() == RuwatanRun.Step.BOSS and not r.is_over(), "langkah 8: Buto Hitam")
	r.win_battle(12)
	check(r.state == RuwatanRun.State.WON and r.steps_cleared() == 8 and r.hp == 12, "Buto Hitam tumbang: Ruwatan berhasil")
	check(saves[0] >= 8, "setiap perubahan minta disimpan")
	var lost := RuwatanRun.create(3, 11, _starter())
	lost.win_battle(20)
	lost.lose_battle()
	check(lost.state == RuwatanRun.State.LOST and lost.steps_cleared() == 1 and lost.is_over(), "kalah: Ruwatan selesai di langkah 2")

	print("[Simpan dan muat]")
	var a := RuwatanRun.create(7, 99, _starter())
	a.win_battle(33)
	a.apply_blessing(Blessings.Kind.KENDANG_PEMBUKA)
	a.place_tabuh(4, "bedug")
	var b := RuwatanRun.from_dict(a.to_dict())
	check(b != null and b.level == 7 and b.step == 1 and b.hp == a.hp and b.max_hp == a.max_hp and b.deck == a.deck
		and b.blessings == a.blessings and b.pending_blessing and str(b.foes) == str(a.foes) and b.events == a.events,
		"Ruwatan tersimpan utuh, jalurnya tetap sama")
	var broken := a.to_dict()
	broken["deck"] = ["serang:1", "palsu:9"]
	check(RuwatanRun.from_dict(broken) == null, "simpanan rusak diabaikan")

	print("[Ruwatan di GameState]")
	check(not bool(gs.get("ruwatan_unlocked")) and int(gs.call("ruwatan_max_level")) == 1, "awalnya terkunci, tingkat 1")
	gs.call("complete_stage", 10)
	gs.call("new_game")
	check(bool(gs.get("ruwatan_unlocked")), "tamat membuka Ruwatan, petualangan baru tidak menguncinya lagi")
	var grng := RandomNumberGenerator.new()
	grng.seed = 21
	var g: RuwatanRun = gs.call("start_ruwatan", 5, grng)
	check(g != null and g.level == 1, "tingkat yang belum terbuka turun ke tingkat tertinggi yang boleh")
	check(g.blessings.is_empty(), "tanpa 24 bintang: tanpa berkah awal")
	g.win_battle(50)
	gs.call("load_game")
	var loaded: RuwatanRun = gs.get("ruwatan")
	check(loaded != null and loaded != g and loaded.step == 1 and loaded.hp == g.hp, "Ruwatan yang berjalan tersimpan dan bisa dilanjutkan")
	loaded.lose_battle()
	check(int(gs.call("ruwatan_best_of", 1)) == 1, "hasil terbaik dicatat begitu Ruwatan selesai")
	gs.call("abandon_ruwatan")
	check(gs.get("ruwatan") == null, "hasil dilihat: Ruwatan ditutup")
	var w: RuwatanRun = gs.call("start_ruwatan", 1, grng)
	w.step = 7
	w.win_battle(5)
	check(int(gs.call("ruwatan_best_of", 1)) == 8 and int(gs.call("ruwatan_max_level")) == 2, "berhasil di tingkat 1 membuka tingkat 2")
	gs.call("abandon_ruwatan")
	gs.call("load_game")
	check(int(gs.call("ruwatan_max_level")) == 2 and gs.get("ruwatan") == null, "catatan tingkat ikut tersimpan")
	var stars := {}
	for n: int in range(1, 9):
		stars[n] = 7
	gs.set("stage_stars", stars)
	var bonus: RuwatanRun = gs.call("start_ruwatan", 2, grng)
	check(bonus.level == 2 and bonus.blessings.size() == 1 and bonus.start_blessing == bonus.blessings[0]
		and not Blessings.TABUH_FAMILY.has(Blessings.from_name(bonus.start_blessing)), "24 bintang: satu berkah awal yang bukan kartu Tabuh")
	gs.call("abandon_ruwatan")
	check(int(gs.call("ruwatan_best_of", 2)) == 0, "Ruwatan yang diakhiri tetap dicatat")

	print("[Battle Ruwatan di scene asli]")
	gs.set("ruwatan_best", {1: 8, 2: 8, 3: 8, 4: 8, 5: 8, 6: 8})
	var battle_run: RuwatanRun = gs.call("start_ruwatan", 7, grng)
	battle_run.hp = 41
	gs.set("play_mode", 1)
	var scene: Node = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var bm: BattleManager = scene.get_node("Systems/BattleManager")
	for i: int in 300:
		await process_frame
		if bm.is_battle_running():
			break
	check(bm.is_battle_running(), "battle Ruwatan dimulai")
	check(bm.hero_health.current_hp == 41 and bm.hero_health.max_hp == battle_run.max_hp, "Nyawa Eyang Palang terbawa (41)")
	check(bm.player.poison == RuwatanRun.START_POISON, "tingkat 7: battle dimulai dengan Lara")
	var specs := battle_run.enemy_specs(0)
	var enemies: Array = scene.get("_enemies")
	check(enemies.size() == 2 and enemies[0].health.max_hp == roundi(specs[0].max_hp * 1.1) and enemies[1].can_ngamuk,
		"lawan langkah 1 dengan Nyawa +10% dan Ngamuk")
	scene.queue_free()
	await process_frame
	gs.call("abandon_ruwatan")
	gs.set("play_mode", 0)

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
