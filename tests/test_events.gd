extends SceneTree
## Tes kejadian di perjalanan: data, efek pilihan, dan antrean kejadian di
## GameState.
##   godot --headless -s tests/test_events.gd

const KNOWN := ["hp", "tabuh", "upgrade_pick", "upgrade_random", "upgrade_random_tabuh",
	"downgrade_random", "blessing", "nothing"]

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


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_save.cfg")
	gs.call("new_game")

	print("[Data kejadian]")
	var ids := JourneyEvents.ids()
	check(ids.size() == 10, "sepuluh kejadian")
	var perot_ok := true
	for id: String in JourneyEvents.PEROT_EVENTS:
		perot_ok = perot_ok and ids.has(id)
	check(perot_ok and JourneyEvents.PEROT_EVENTS.size() == 2, "dua kejadian bersama Roro Perot")
	var effects_ok := true
	var texts_ok := true
	var icons_ok := true
	for id: String in ids:
		for choice: String in ["a", "b"]:
			var effects := JourneyEvents.effects_of(id, choice)
			if effects.is_empty():
				effects_ok = false
			for effect: String in effects:
				if not KNOWN.has(effect.get_slice(":", 0)):
					effects_ok = false
					print("    efek tidak dikenal: ", effect)
				if effect.begins_with("tabuh:") and not Blessings.TABUH_FAMILIES.has(effect.get_slice(":", 1)):
					effects_ok = false
			for key: String in ["EV_%s_%s" % [id.to_upper(), choice.to_upper()], "EV_%s_%s_RESULT" % [id.to_upper(), choice.to_upper()]]:
				if tr(key) == key:
					texts_ok = false
					print("    belum diterjemahkan: ", key)
		for key: String in ["EV_%s_TITLE" % id.to_upper(), "EV_%s_TEXT" % id.to_upper()]:
			if tr(key) == key:
				texts_ok = false
				print("    belum diterjemahkan: ", key)
		if load(str(JourneyEvents.get_event(id)["icon"])) == null:
			icons_ok = false
	check(effects_ok, "semua efek dikenal")
	check(texts_ok, "semua teks kejadian punya terjemahan")
	check(icons_ok, "semua gambar kejadian ada")
	check(JourneyEvents.needs_picker("tabuh:gong") and JourneyEvents.needs_picker("upgrade_pick") and not JourneyEvents.needs_picker("hp:+5"), "efek yang butuh pemilih kartu")

	print("[Undian kejadian]")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen: Array[String] = []
	for i: int in 10:
		var id := JourneyEvents.pick(rng, seen)
		if seen.has(id):
			break
		seen.append(id)
	check(seen.size() == 10, "sepuluh undian tanpa pengulangan")
	check(JourneyEvents.pick(rng, seen) == "", "semua sudah dialami: kosong")

	print("[Efek pada profil (GameState)]")
	var hp_line := JourneyEvents.apply("hp:+5", gs, rng)
	check(gs.get("max_hp") == 75 and hp_line.contains("70") and hp_line.contains("75"), "hp:+5 -> 75: %s" % hp_line)
	JourneyEvents.apply("hp:-500", gs, rng)
	check(gs.get("max_hp") == 30, "Nyawa maksimal tidak turun di bawah 30")
	gs.call("new_game")
	var deck_before: Array = (gs.get("deck") as Array).duplicate()
	var up_line := JourneyEvents.apply("upgrade_random", gs, rng)
	var sum_before := 0
	var sum_after := 0
	for spec: String in deck_before:
		sum_before += int(spec.get_slice(":", 1))
	for spec: String in gs.get("deck"):
		sum_after += int(spec.get_slice(":", 1))
	check(sum_after == sum_before + 1 and up_line != "", "upgrade_random: satu kartu naik: %s" % up_line)
	var tabuh_line := JourneyEvents.apply("upgrade_random_tabuh", gs, rng)
	check(tabuh_line != "", "upgrade_random_tabuh tanpa kartu Tabuh: kartu acak naik")
	(gs.get("deck") as Array)[0] = "gong:1"
	JourneyEvents.apply("upgrade_random_tabuh", gs, rng)
	check((gs.get("deck") as Array)[0] == "gong:2", "upgrade_random_tabuh menaikkan kartu Tabuh")
	var down_before := 0
	for spec: String in gs.get("deck"):
		down_before += int(spec.get_slice(":", 1))
	JourneyEvents.apply("downgrade_random", gs, rng)
	var down_after := 0
	for spec: String in gs.get("deck"):
		down_after += int(spec.get_slice(":", 1))
	check(down_after == down_before - 1, "downgrade_random: satu kartu turun")
	var bless_line := JourneyEvents.apply("blessing:JAMU_BERAS_KENCUR|hp:+5", gs, rng)
	check((gs.get("blessings") as Array).has("JAMU_BERAS_KENCUR") and bless_line != "", "berkah dari kejadian")
	var hp_before: int = gs.get("max_hp")
	JourneyEvents.apply("blessing:JAMU_BERAS_KENCUR|hp:+5", gs, rng)
	check(gs.get("max_hp") == hp_before + 5 and (gs.get("blessings") as Array).count("JAMU_BERAS_KENCUR") == 1, "sudah punya: cadangan Nyawa +5")
	check(JourneyEvents.apply("nothing", gs, rng) == "", "nothing: tidak ada perubahan")

	print("[Persimpangan jalan di GameState]")
	gs.call("new_game")
	check(gs.call("queue_event_after", 1, rng) == "" and gs.get("pending_event") == "", "babak 1: tidak ada kejadian")
	var queued: String = gs.call("queue_event_after", 2, rng)
	var paths: Array = gs.get("pending_paths")
	check(queued != "" and paths.size() == 2 and paths.has(queued) and paths[0] != paths[1] and gs.get("pending_event") == "",
		"babak 2: dua jalan menunggu di persimpangan")
	check((gs.get("seen_events") as Array).is_empty(), "sebelum memilih, belum ada kejadian yang dialami")
	gs.call("load_game")
	paths = gs.get("pending_paths")
	check(paths.size() == 2 and paths.has(queued), "persimpangan yang menunggu tersimpan")
	check(gs.call("queue_event_after", 4, rng) == "", "selama masih ada yang menunggu, tidak ditimpa")
	var taken: String = paths[1]
	var skipped: String = paths[0]
	gs.call("choose_path", "bukan_jalan")
	check((gs.get("pending_paths") as Array).size() == 2, "jalan yang tidak ada di persimpangan ditolak")
	gs.call("choose_path", taken)
	check(gs.get("pending_event") == taken and (gs.get("pending_paths") as Array).is_empty()
		and (gs.get("seen_events") as Array) == [taken], "memilih jalan: kejadiannya menunggu dan tercatat")
	check(not (gs.get("seen_events") as Array).has(skipped), "kejadian di jalan yang tidak dipilih belum dialami")
	gs.call("finish_event")
	var second: String = gs.call("queue_event_after", 4, rng)
	paths = gs.get("pending_paths")
	check(second != "" and not paths.has(taken), "persimpangan berikutnya tidak mengulang kejadian yang sudah dialami")
	# Hanya satu kejadian tersisa: langsung menunggu tanpa persimpangan.
	gs.call("new_game")
	var all_but_one := JourneyEvents.ids()
	var last: String = all_but_one.pop_back()
	(gs.get("seen_events") as Array).assign(all_but_one)
	check(gs.call("queue_event_after", 6, rng) == last and gs.get("pending_event") == last and (gs.get("pending_paths") as Array).is_empty(),
		"tinggal satu kejadian: langsung menunggu tanpa persimpangan")
	gs.call("new_game")
	check(gs.get("pending_event") == "" and (gs.get("pending_paths") as Array).is_empty() and (gs.get("seen_events") as Array).is_empty(),
		"petualangan baru mengosongkan kejadian")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
