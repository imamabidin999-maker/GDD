extends SceneTree
## Tes konten game: kartu dari CardDB, Tameng, Racun, pola Buto, niat musuh,
## Ultimate area, data stage, dan berkah GameState.
##   godot --headless -s tests/test_game_content.gd

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


func game_state() -> Node:
	return root.get_node("GameState")


func make_buto(type: EnemyButo.ButoType, hp: int, attack: int) -> EnemyButo:
	var b := EnemyButo.new()
	b.buto_type = type
	b.rng_seed = 5
	b.attack_power = attack
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
	specs.assign(game_state().get("STARTER_DECK"))
	f.deck_list = card_db().call("build_deck_list", specs)
	return f


# Cari kartu dengan keluarga tertentu di tangan. -1 kalau tidak ada.
func find_family(hand: HandManager, family: String) -> int:
	for i: int in hand.get_card_count():
		if hand.get_card(i).data.get_family() == family:
			return i
	return -1


# Masukkan kartu tertentu langsung ke tangan (untuk tes efek).
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

	print("[CardDB & deck awal]")
	check((card_db().call("get_all_cards") as Array).size() == 36, "36 kartu (12 keluarga x 3 bintang, termasuk 6 Tabuh)")
	check((card_db().call("get_recipes") as Array).size() == 3, "3 resep merge")
	var crimson2: CardData = card_db().call("card_from_spec", "crimson:2")
	check(crimson2 != null and crimson2.base_power == 17 and not crimson2.is_base_type(), "crimson:2 ditemukan")
	var f := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 200, 6)] as Array[EnemyUnit], 70)
	check(f.deck_list.size() == 15, "deck awal 15 kartu")
	check(f.bm.start_battle(f.deck_list, f.enemies), "battle dengan deck asli bisa dimulai")

	print("[Tameng]")
	var ti := give_card(f, "taktik:2")
	check(f.bm.request_play_card(ti) and f.hero.block == 8, "Taktik bintang 2 -> Tameng 8")
	f.hero.take_damage(5)
	check(f.hero.block == 3 and f.hero.current_hp == 70, "damage 5 diserap Tameng")
	f.hero.take_damage(10)
	check(f.hero.block == 0 and f.hero.current_hp == 63, "sisa damage tembus ke HP")
	var pi := give_card(f, "piercing:1")
	f.bm.request_play_card(pi)
	check(f.hero.block == 4 and f.enemies[0].health.current_hp == 190, "Piercing Strike: damage 10 + Tameng 4")
	f.bm.request_end_turn()
	check(f.hero.block == 0, "Tameng hilang di awal turn berikutnya")

	print("[Flow State: AP kembali]")
	var ap_before := f.player.current_ap
	var fi := give_card(f, "flow:1")
	f.bm.request_play_card(fi)
	check(f.player.current_ap == ap_before, "main Flow State (1 AP) mengembalikan 1 AP")
	check(f.hero.block == 5, "dan memberi Tameng 5")

	print("[Ultimate area]")
	var f2 := make_fixture([make_buto(EnemyButo.ButoType.KUNING, 300, 6), make_buto(EnemyButo.ButoType.MERAH, 300, 6)] as Array[EnemyUnit], 70)
	f2.bm.start_battle(f2.deck_list, f2.enemies)
	f2.player.gain_moxie(200.0)
	check(f2.bm.request_ultimate(), "Ultimate diterima")
	check(f2.enemies[0].health.current_hp == 240 and f2.enemies[1].health.current_hp == 240, "kedua Buto kena 30 x 2 = 60")

	print("[Buto Hijau: Racun]")
	var hijau := make_buto(EnemyButo.ButoType.HIJAU, 300, 6)
	var f3 := make_fixture([hijau] as Array[EnemyUnit], 70)
	f3.bm.start_battle(f3.deck_list, f3.enemies)
	var intent := hijau.get_intent(f3.bm)
	check(intent.kind == EnemyIntent.Kind.POISON and intent.damage == 3 and intent.extra == 3, "niat: semburan 3 + Racun 3")
	f3.bm.request_end_turn()
	check(f3.player.poison == 2 and f3.hero.current_hp == 70 - 3 - 3, "semburan 3, racun langsung bekerja 3, sisa 2 tumpukan")
	check(hijau.get_intent(f3.bm).kind == EnemyIntent.Kind.ATTACK, "turn berikutnya cooldown: serangan biasa")
	var ti3 := give_card(f3, "taktik:3")
	f3.bm.request_play_card(ti3)
	f3.bm.request_end_turn()
	check(f3.hero.current_hp == 64 - 2 and f3.player.poison == 1, "racun menembus Tameng (serangan 6 diserap)")
	var f4 := make_fixture([make_buto(EnemyButo.ButoType.HIJAU, 300, 6)] as Array[EnemyUnit], 5)
	f4.bm.start_battle(f4.deck_list, f4.enemies)
	f4.bm.request_end_turn()
	check(f4.bm.get_state() == BattleManager.State.DEFEAT, "kalah karena racun ikut dicek")

	print("[Buto Merah: serang, ancang-ancang, pukulan berat]")
	var merah := make_buto(EnemyButo.ButoType.MERAH, 300, 8)
	var f5 := make_fixture([merah] as Array[EnemyUnit], 100)
	f5.bm.start_battle(f5.deck_list, f5.enemies)
	var kinds: Array[String] = []
	var hp_log: Array[int] = []
	for i: int in 4:
		kinds.append(EnemyIntent.Kind.find_key(merah.get_intent(f5.bm).kind))
		f5.bm.request_end_turn()
		hp_log.append(f5.hero.current_hp)
	check(kinds == ["ATTACK", "CHARGE", "HEAVY", "ATTACK"], "pola niat: %s" % [kinds])
	check(hp_log == [92, 92, 72, 64], "damage: 8, 0, 20, 8 -> %s" % [hp_log])

	print("[Buto Hitam: niat fase 1 dan 2]")
	var hitam := make_buto(EnemyButo.ButoType.HITAM, 100, 9)
	var f6 := make_fixture([hitam] as Array[EnemyUnit], 200)
	f6.bm.start_battle(f6.deck_list, f6.enemies)
	var i6a := hitam.get_intent(f6.bm)
	check(i6a.kind == EnemyIntent.Kind.PLAGUE_STRIKE and i6a.damage == 9, "fase 1: Gebug Pagebluk 9")
	hitam.health.take_damage(50)
	var i6 := hitam.get_intent(f6.bm)
	check(i6.kind == EnemyIntent.Kind.SUMMON and i6.extra == 2, "fase 2: Memanggil 2 Bala")

	print("[Niat Kuning & Putih]")
	var kuning := make_buto(EnemyButo.ButoType.KUNING, 50, 6)
	var putih := make_buto(EnemyButo.ButoType.PUTIH, 50, 6)
	var f7 := make_fixture([kuning, putih] as Array[EnemyUnit], 100)
	f7.bm.start_battle(f7.deck_list, f7.enemies)
	var ik := kuning.get_intent(f7.bm)
	check(ik.kind == EnemyIntent.Kind.DRAIN and ik.damage == 6 and ik.extra == 25, "Kuning: serang 6 + kuras 25%")
	check(putih.get_intent(f7.bm).kind == EnemyIntent.Kind.LOCK, "Putih: kunci kartu")

	print("[Data stage]")
	var catalog := StageCatalog.load_default()
	check(catalog != null and catalog.stages.size() == 10, "10 babak")
	check(catalog.get_stage(10).is_boss and catalog.get_stage(10).enemies[0].buto_type == EnemyButo.ButoType.HITAM, "babak 10: bos Buto Hitam")
	var all_lines_ok := true
	var all_translated := true
	for stage: StageData in catalog.stages:
		for key: String in [stage.title_key, "CHAPTER_%d" % stage.chapter]:
			if tr(key) == key:
				all_translated = false
				print("    belum diterjemahkan: ", key)
		for line: String in stage.intro_dialog + stage.victory_dialog + stage.tutorial_dialog:
			var parts := line.split("|")
			if parts.size() != 2:
				all_lines_ok = false
			elif tr(parts[1]) == parts[1]:
				all_translated = false
				print("    belum diterjemahkan: ", parts[1])
	check(all_lines_ok, "semua baris dialog berformat pembicara|KUNCI")
	check(all_translated, "semua judul, bagian, dan dialog babak punya terjemahan")
	var chapters_ok := true
	for n: int in range(1, 11):
		var expected := 1 if n <= 4 else (2 if n <= 8 else 3)
		if catalog.get_stage(n).chapter != expected:
			chapters_ok = false
	check(chapters_ok, "bagian cerita: 1-4, 5-8, 9-10")
	var normal_ok := true
	for n: int in range(1, 5):
		for spec: EnemySpec in catalog.get_stage(n).enemies:
			if spec.murka or spec.can_ngamuk:
				normal_ok = false
	check(normal_ok, "babak 1-4 tanpa Buto Murka")
	var murka_ok := true
	var murka_types := {}
	for n: int in range(5, 9):
		var enemies := catalog.get_stage(n).enemies
		if enemies.size() != 2 or not enemies[0].murka or not enemies[0].can_ngamuk or enemies[1].murka:
			murka_ok = false
		murka_types[enemies[0].buto_type] = true
	check(murka_ok and murka_types.size() == 4, "babak 5-8: satu Buto Murka (empat warna berbeda) dengan satu pendamping biasa")
	var s9 := catalog.get_stage(9).enemies
	var starts := {}
	var types9 := {}
	var s9_murka := true
	for spec: EnemySpec in s9:
		starts[spec.start_amuk] = true
		types9[spec.buto_type] = true
		s9_murka = s9_murka and spec.murka and spec.can_ngamuk
	check(s9.size() == 4 and s9_murka and types9.size() == 4, "babak 9: keempat Buto Murka sekaligus")
	check(starts.size() == 4, "babak 9: titik Amuk awal berbeda-beda supaya tidak Ngamuk bersamaan")
	var spread_ok := true
	var info_panel := Rect2(430, 196, 202, 156)
	for a: StageData in catalog.stages:
		if info_panel.grow(16).has_point(a.map_position):
			spread_ok = false
		for b: StageData in catalog.stages:
			if a != b and a.map_position.distance_to(b.map_position) < 60.0:
				spread_ok = false
	check(spread_ok, "titik peta tidak bertumpuk dan tidak tertutup panel info")
	var bg_ok := true
	var bg_seen := {}
	for stage: StageData in catalog.stages:
		var tex := load(stage.background) as Texture2D if ResourceLoader.exists(stage.background) else null
		if tex == null or tex.get_width() != 656 or tex.get_height() != 376:
			bg_ok = false
			print("    latar tidak ada atau ukurannya salah: ", stage.background)
		bg_seen[stage.background] = true
	check(bg_ok and bg_seen.size() == 10, "setiap babak punya latar sendiri berukuran 656x376")
	for path: String in ["res://assets/backgrounds/menu.png", "res://assets/backgrounds/ending.png"]:
		check(ResourceLoader.exists(path), "latar %s ada" % path.get_file())

	print("[Berkah GameState]")
	var gs := game_state()
	gs.set("save_path", "user://test_save.cfg")
	gs.call("new_game") # mulai dari deck awal, apa pun isi simpanan pemain
	var saved_deck: Array = (gs.get("deck") as Array).duplicate()
	var saved_hp: int = gs.get("max_hp")
	var serang_before := 0
	for spec: String in gs.get("deck"):
		if spec.begins_with("serang:"):
			serang_before += int(spec.split(":")[1])
	var upgraded: Array = gs.call("apply_blessing", 0)
	var serang_after := 0
	for spec: String in gs.get("deck"):
		if spec.begins_with("serang:"):
			serang_after += int(spec.split(":")[1])
	check(upgraded.size() == 2 and serang_after == serang_before + 2, "Tempa Tongkat: 2 kartu Serang naik bintang")
	gs.call("apply_blessing", 3)
	check(gs.get("max_hp") == saved_hp + 10, "Jamu: HP maksimal +10")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var options: Array = gs.call("roll_blessings", rng)
	var unique := {}
	for o: Variant in options:
		unique[o] = true
	check(options.size() == 3 and unique.size() == 3, "3 pilihan berkah berbeda")
	(gs.get("deck") as Array).assign(saved_deck)
	gs.set("max_hp", saved_hp)
	gs.call("save_game")

	print("[Simpanan lama (5 babak)]")
	var old_cfg := ConfigFile.new()
	old_cfg.set_value("progress", "unlocked_stage", 5)
	old_cfg.set_value("progress", "cleared_stages", [1, 2, 3, 4, 5])
	old_cfg.set_value("progress", "game_completed", true)
	old_cfg.set_value("progress", "max_hp", 90)
	old_cfg.set_value("progress", "seen_buto", ["kuning", "hitam"])
	old_cfg.save("user://test_save.cfg")
	gs.call("load_game")
	var cleared: Array = gs.get("cleared_stages")
	check(cleared == [1, 2, 3, 4], "babak 1-4 tetap selesai, babak 5 lama (Buto Hitam) dibuka ulang")
	check(gs.get("unlocked_stage") == 5 and not gs.get("game_completed"), "babak 5 terbuka, status tamat dihapus")
	check(gs.get("max_hp") == 90 and (gs.get("seen_buto") as Array).has("hitam"), "Nyawa dan Pustaka tetap terbawa")
	var new_cfg := ConfigFile.new()
	new_cfg.load("user://test_save.cfg")
	check(int(new_cfg.get_value("meta", "save_version", 0)) == 3, "simpanan langsung ditulis ulang ke versi 3")
	check((gs.get("blessed_stages") as Array) == [1, 2, 3, 4], "babak 1-4 dianggap sudah memberi berkah")
	check((gs.get("blessings") as Array) == ["JAMU_KUNYIT_ASAM", "JAMU_KUNYIT_ASAM"], "Nyawa 90 -> dua Jamu Kunyit Asam tercatat")
	gs.call("load_game")
	check((gs.get("cleared_stages") as Array) == [1, 2, 3, 4] and gs.get("unlocked_stage") == 5, "memuat versi 3 tidak memigrasi lagi")
	gs.call("complete_stage", 5)
	gs.call("load_game")
	check(gs.get("unlocked_stage") == 6, "simpanan baru menyimpan babak di atas 5")

	print("[Simpanan versi 2 (sebelum berkah v2)]")
	var v2_cfg := ConfigFile.new()
	v2_cfg.set_value("meta", "save_version", 2)
	v2_cfg.set_value("progress", "unlocked_stage", 7)
	v2_cfg.set_value("progress", "cleared_stages", [1, 2, 3, 4, 5, 6])
	v2_cfg.set_value("progress", "max_hp", 120)
	v2_cfg.save("user://test_save.cfg")
	gs.call("load_game")
	check((gs.get("cleared_stages") as Array) == [1, 2, 3, 4, 5, 6] and gs.get("unlocked_stage") == 7, "babak versi 2 tetap utuh")
	check((gs.get("blessed_stages") as Array) == [1, 2, 3, 4, 5, 6], "babak yang sudah selesai tidak memberi berkah lagi")
	check((gs.get("blessings") as Array).count("JAMU_KUNYIT_ASAM") == 3 and gs.get("max_hp") == 120, "Jamu dari Nyawa 120 dibatasi 3, Nyawa tetap 120")

	print("[Pengaturan baru: kesulitan, kecepatan, petunjuk]")
	gs.call("set_difficulty", 0)
	check(is_equal_approx(gs.call("difficulty_hp_multiplier"), 0.8) and is_equal_approx(gs.call("difficulty_attack_multiplier"), 0.85), "Santai: Nyawa Buto x0.8, serangan x0.85")
	gs.call("set_difficulty", 2)
	check(is_equal_approx(gs.call("difficulty_hp_multiplier"), 1.15), "Sulit: Nyawa Buto x1.15")
	gs.call("set_difficulty", 9)
	check(gs.get("difficulty") == 2, "nilai di luar batas dibatasi")
	gs.call("set_difficulty", 1)
	gs.call("set_battle_speed", 2.0)
	gs.call("load_game")
	check(is_equal_approx(gs.get("battle_speed"), 2.0) and gs.get("difficulty") == 1, "kecepatan dan kesulitan tersimpan")
	gs.call("set_battle_speed", 1.0)
	(gs.get("seen_hints") as Array).clear()
	gs.call("set_hints_enabled", true)
	check(gs.call("take_hint", "sirep") and not gs.call("take_hint", "sirep"), "petunjuk hanya tampil sekali")
	gs.call("set_hints_enabled", false)
	check(not gs.call("take_hint", "lara"), "petunjuk dimatikan: tidak tampil")
	gs.call("set_hints_enabled", true)

	print("[Berkah hanya untuk kemenangan pertama]")
	gs.call("new_game")
	check(not gs.call("is_stage_blessed", 1), "babak 1 belum memberi berkah")
	gs.call("apply_blessing", Blessings.Kind.TAMENG_PUSAKA, 1)
	check(gs.call("is_stage_blessed", 1) and (gs.get("blessings") as Array) == ["TAMENG_PUSAKA"], "berkah tercatat bersama babaknya")
	gs.call("load_game")
	check(gs.call("is_stage_blessed", 1) and (gs.get("blessings") as Array) == ["TAMENG_PUSAKA"], "berkah tersimpan dan termuat lagi")
	var ps := PlayerState.new()
	gs.call("prepare_player", ps)
	check(ps.first_turn_block == 10 and ps.first_turn_bonus_ap == 0, "prepare_player memasang efek berkah yang dimiliki")
	ps.free()
	gs.call("new_game")

	print("[Istilah Jawa dan Asli atau Rekaan]")
	var missing: Array[String] = []
	for locale: String in ["id", "en"]:
		TranslationServer.set_locale(locale)
		var keys: Array[String] = []
		for cat: String in GlossaryData.CATEGORIES:
			keys.append("GLOSS_CAT_" + cat.to_upper())
		for kind: String in GlossaryData.ORIGIN_KINDS:
			keys.append("ORIGIN_KIND_" + kind.to_upper())
		for entry: Dictionary in GlossaryData.TERMS:
			keys.append(entry["key"])
			if not GlossaryData.CATEGORIES.has(entry["cat"]):
				missing.append("kelompok " + str(entry["cat"]))
		for entry: Dictionary in GlossaryData.ORIGINS:
			keys.append(entry["key"] + "_TITLE")
			keys.append(entry["key"] + "_TEXT")
			if not GlossaryData.ORIGIN_KINDS.has(entry["kind"]):
				missing.append("jenis " + str(entry["kind"]))
		for key: String in keys:
			if tr(key) == key or tr(key).is_empty():
				missing.append("%s (%s)" % [key, locale])
	gs.call("set_locale", "id")
	check(missing.is_empty(), "semua istilah dan unsur asli/rekaan punya teks Indonesia dan Inggris" + ("" if missing.is_empty() else ": " + str(missing)))
	check(GlossaryData.TERMS.size() >= 60 and GlossaryData.ORIGINS.size() >= 15, "%d istilah, %d unsur asli/rekaan" % [GlossaryData.TERMS.size(), GlossaryData.ORIGINS.size()])
	var pustaka: Node = (load("res://scenes/pustaka/pustaka.tscn") as PackedScene).instantiate()
	root.add_child(pustaka)
	await process_frame
	var content: VBoxContainer = pustaka.get("_content")
	pustaka.call("_show", "istilah")
	await process_frame
	check(content.get_child_count() == 3 + GlossaryData.CATEGORIES.size() * 2, "halaman Istilah Jawa: judul, pengantar, tombol lompat, dan semua kelompok")
	pustaka.call("_show", "asli")
	await process_frame
	check(content.get_child_count() == 2 + GlossaryData.ORIGIN_KINDS.size() * 2, "halaman Asli atau Rekaan: tiga jenis asal beserta isinya")
	pustaka.queue_free()
	await process_frame

	print("[Istilah di teks cerita]")
	var glossary: GDScript = load("res://ui/common/glossary_text.gd")
	var term_keys := {}
	for entry: Dictionary in GlossaryData.TERMS:
		term_keys[entry["key"]] = true
	var bad_forms: Array[String] = []
	for form: String in GlossaryData.FORMS:
		for key: String in GlossaryData.FORMS[form]:
			if not term_keys.has(key):
				bad_forms.append(form)
	check(bad_forms.is_empty(), "semua bentuk kata menunjuk istilah yang ada" + ("" if bad_forms.is_empty() else ": " + str(bad_forms)))
	var marked: String = glossary.call("mark", "Eyang bersemedi, lalu Eyang menabuh bedug dua kali di Kali Watu.")
	check(marked.count("[url=gloss:") == 5 and marked.contains("[url=gloss:GLOSS_SEMEDI]bersemedi[/url]") and marked.contains("dua kali") \
		and marked.contains("[url=gloss:GLOSS_KALI]Kali Watu[/url]"), "kata berimbuhan ditandai, Eyang hanya sekali, dua kali bukan sungai")
	marked = glossary.call("mark", "Tangkis Balik lalu Tangkis")
	check(marked.contains("[url=gloss:GLOSS_TANGKIS_BALIK]Tangkis Balik[/url]") and marked.contains("[url=gloss:GLOSS_TANGKIS]Tangkis[/url]"), "frasa terpanjang didahulukan")
	marked = glossary.call("mark", "Eyang Palang datang.")
	check(marked.contains("[url=gloss:GLOSS_EYANG|GLOSS_PALANG]Eyang Palang[/url]"), "Eyang Palang menunjuk dua istilah sekaligus")
	var tip: String = glossary.call("tooltip_text", "gloss:GLOSS_EYANG|GLOSS_PALANG")
	check(tip.contains("Eyang") and tip.contains(tr("GLOSS_PALANG")), "keterangan berisi nama dan arti kedua istilah")
	marked = glossary.call("mark", "[color=#ffffff]Buto[/color] [url=x]Buto Sirep[/url] Sirep")
	check(marked.contains("[color=#ffffff][color=#") and marked.contains("[url=x]Buto Sirep[/url]") and marked.count("gloss:") == 2,
		"tag BBCode dan tautan yang sudah ada tidak diubah")
	var used := {}
	glossary.call("mark", "Buto datang.", used)
	check(not (glossary.call("mark", "Buto lagi.", used) as String).contains("[url"), "istilah yang sudah ditandai di percakapan tidak ditandai lagi")
	gs.set("glossary_marks", false)
	check(glossary.call("mark", "Buto datang.") == "Buto datang.", "tanda istilah bisa dimatikan di Pengaturan")
	gs.set("glossary_marks", true)
	# Tanda tidak boleh mengubah teks yang terbaca di cerita, kejadian, dan petunjuk.
	var probe := RichTextLabel.new()
	probe.bbcode_enabled = true
	var csv := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	var story_key := RegEx.create_from_string("^(S\\d+_|PROLOGUE|ENDING|TUT|EV_|HINT_|PUSTAKA_)")
	var story_keys: Array[String] = []
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() >= 3 and story_key.search(row[0]) != null:
			story_keys.append(row[0])
	var changed: Array[String] = []
	var total_marks := 0
	for locale: String in ["id", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in story_keys:
			probe.text = tr(key)
			var plain := probe.get_parsed_text()
			var with_marks: String = glossary.call("mark", tr(key))
			total_marks += with_marks.count("[url=gloss:")
			probe.text = with_marks
			if probe.get_parsed_text() != plain:
				changed.append("%s (%s)" % [key, locale])
	gs.call("set_locale", "id")
	probe.free()
	check(changed.is_empty() and story_keys.size() > 150, "%d teks cerita: tanda tidak mengubah isi yang terbaca" % story_keys.size() + ("" if changed.is_empty() else ": " + str(changed)))
	check(total_marks > 200, "%d istilah ditandai di seluruh teks cerita" % total_marks)
	# Musik menu dari Pustaka dihentikan dulu supaya tidak tertinggal saat keluar.
	root.get_node("AudioManager").call("stop_music")
	await create_timer(1.0).timeout

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
