extends SceneTree
## Tes ujung-ke-ujung: menamatkan kampanye lewat scene asli dengan klik mouse
## sungguhan (menu -> peta -> 10 babak -> berkah -> ending -> peta -> menu),
## lalu menempuh satu Ruwatan sampai selesai.
## Battle dimainkan bot sederhana. Waktu game dipercepat 8x.
##   godot --headless -s tests/test_campaign_flow.gd

var _failures: int = 0
var _checks: int = 0
var _last_reward_already: bool = false
var _picked_tabuh: int = 0
var _challenge_panels: int = 0
var _events_seen: int = 0
var _forks_seen: int = 0


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _initialize() -> void:
	_run()


# Skrip tes dikompilasi sebelum autoload (AudioManager, GameState) terdaftar.
# Menyebut kelas seperti DialogBox langsung akan ikut mengompilasinya terlalu
# dini dan gagal (Godot 4.7 tidak mengulang kompilasi itu), jadi kelasnya
# dicek lewat nama saja.
func _is_class(node: Node, class_title: String) -> bool:
	var script := node.get_script() as Script
	return script != null and script.get_global_name() == class_title


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


func _motion(pos: Vector2, held: bool) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(e, true)


func click(pos: Vector2) -> void:
	_motion(pos, false)
	await process_frame
	_mouse_button(pos, true)
	await process_frame
	_mouse_button(pos, false)
	await process_frame


func find_button(text: String) -> Button:
	for n: Node in current_scene.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and (b.text == text or tr(b.text) == text):
			return b
	return null


func click_button(text: String) -> bool:
	var b := find_button(text)
	if b == null:
		print("  tombol tidak ditemukan: ", text)
		return false
	await click(b.get_global_rect().get_center())
	return true


func clear_dialogs(max_clicks: int = 40) -> void:
	for i: int in max_clicks:
		var box: Node = null
		for n: Node in current_scene.find_children("*", "", true, false):
			if _is_class(n, "DialogBox"):
				box = n
		if box == null:
			return
		await click(Vector2(320, 300))
		await _wait(0.12)


func _wait_input(bm: BattleManager) -> void:
	for i: int in 600:
		if not is_instance_valid(bm) or not bm.is_battle_running() or bm.is_accepting_input():
			return
		await process_frame


func _bot_turn(bm: BattleManager) -> void:
	var guard := 0
	while is_instance_valid(bm) and bm.is_battle_running() and guard < 30:
		guard += 1
		await _wait_input(bm)
		if not bm.is_battle_running():
			return
		var merged := false
		for i: int in bm.hand.get_card_count() - 1:
			if bm.hand.can_merge_at(i, i + 1) and bm.request_merge(i, i + 1):
				merged = true
				break
		if merged:
			continue
		if bm.player.is_ultimate_ready() and (bm.player.moxie >= 200.0 or bm.hero_health.current_hp < 25):
			bm.request_ultimate()
			continue
		if bm.player.current_ap <= 0 or bm.hand.get_card_count() == 0:
			break
		var best := 0
		var best_score := -1.0
		for i: int in bm.hand.get_card_count():
			if not bm.hand.can_play_at(i) or bm.hand.get_card(i).data.ap_cost > bm.player.current_ap:
				continue
			var d := bm.hand.get_card(i).data
			var score := float(d.base_power + d.shield) + 6.0 * d.ap_gain
			if score > best_score:
				best_score = score
				best = i
		bm.request_play_card(best)
	await _wait_input(bm)
	if is_instance_valid(bm) and bm.is_battle_running():
		bm.request_end_turn()


func _find_node(class_title: String) -> Node:
	for n: Node in current_scene.find_children("*", "", true, false):
		if _is_class(n, class_title):
			return n
	return null


## Menunggu sampai node berkelas ini muncul (paling lama `seconds`).
func _wait_for_node(class_title: String, seconds: float) -> Node:
	var limit := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		var n := _find_node(class_title)
		if n != null:
			return n
		await process_frame
	return null


func _stage_count() -> int:
	return int(root.get_node("GameState").get("STAGE_COUNT"))


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


# Kejadian di perjalanan di peta: pilih pilihan pertama, pakai pemilih kartu
# kalau muncul, lalu Lanjut.
func _handle_event() -> void:
	# Persimpangan jalan dulu: pilih jalan pertama.
	var fork := _find_node("CrossroadsPanel")
	if fork != null:
		_forks_seen += 1
		var paths := fork.find_children("*", "Button", true, false)
		await click((paths[0] as Button).get_global_rect().get_center())
		await _wait(0.4)
	var ev := _find_node("EventPanel")
	if ev == null:
		return
	_events_seen += 1
	var buttons := ev.find_children("*", "Button", true, false)
	await click((buttons[0] as Button).get_global_rect().get_center())
	await _wait(0.4)
	var picker := _find_node("DeckPicker")
	if picker != null:
		for n: Node in picker.find_children("*", "Control", true, false):
			if _is_class(n, "CardView") and n.get("card").data.rank < 3:
				await click((n as Control).get_global_rect().get_center())
				break
		await _wait(0.2)
		var replace_mode: bool = picker.get("mode") == 0
		await click_button(tr("PICKER_CONFIRM_REPLACE" if replace_mode else "PICKER_CONFIRM_UPGRADE"))
		await _wait(0.4)
	await click_button(tr("BTN_CONTINUE"))
	await _wait(0.6)


func _play_stage(n: int) -> bool:
	await _handle_event()
	# Di peta: klik titik stage lalu tombol Bertarung.
	var catalog := StageCatalog.load_default()
	await click(catalog.get_stage(n).map_position)
	await _wait(0.3)
	if _scene_name() == "stage_map":
		await click_button(tr("BTN_FIGHT"))
	await _wait(1.0)
	for attempt: int in 4:
		await clear_dialogs(80)
		var bm: BattleManager = current_scene.get_node("Systems/BattleManager")
		while is_instance_valid(bm) and bm.is_battle_running() and bm.turn_number < 40:
			await _bot_turn(bm)
		await _wait(0.5)
		var won := is_instance_valid(bm) and bm.get_state() == BattleManager.State.VICTORY
		print("  babak %d percobaan %d: %s (giliran %d, Nyawa %d)" % [n, attempt + 1, "menang" if won else "kalah", bm.turn_number, bm.hero_health.current_hp])
		if won:
			await _wait(2.0)
			await clear_dialogs(40)
			await _wait(0.6)
			# Panel Hasil Tantangan muncul lebih dulu.
			var cp := _find_node("ChallengePanel")
			if cp != null:
				_challenge_panels += 1
				await click_button(tr("BTN_CONTINUE"))
				await _wait(0.6)
			if n < _stage_count():
				var rp: Node = null
				for c: Node in current_scene.find_children("*", "", true, false):
					if _is_class(c, "RewardPanel"):
						rp = c
				var already: bool = rp.get("already_received")
				_last_reward_already = already
				var choices := rp.find_children("*", "Button", true, false)
				await click((choices[0] as Button).get_global_rect().get_center())
				await _wait(0.4)
				# Berkah kartu Tabuh membuka pemilih kartu: pilih kartu pertama lalu Ganti.
				var picker := _find_node("DeckPicker")
				if picker != null:
					_picked_tabuh += 1
					var cards := picker.find_children("*", "Control", true, false).filter(
						func(n: Node) -> bool: return _is_class(n, "CardView"))
					await click((cards[0] as Control).get_global_rect().get_center())
					await _wait(0.2)
					await click_button(tr("PICKER_CONFIRM_REPLACE"))
					await _wait(0.4)
				if not already:
					await click_button(tr("BTN_CONTINUE"))
				await _wait(1.2)
			return true
		await _wait(1.0)
		await click_button(tr("BTN_RETRY"))
		await _wait(1.5)
	return false


# Satu Ruwatan tingkat 1 lewat layar Ruwatan: battle, berkah, kejadian,
# sampai panel hasil.
func _play_ruwatan(gs: Node) -> void:
	print("[Ruwatan]")
	check(bool(gs.get("ruwatan_unlocked")), "Ruwatan terbuka setelah tamat")
	await click_button(tr("MAP_MENU"))
	await _wait(0.4)
	await click_button(tr("BTN_MAIN_MENU"))
	await _wait(1.5)
	check(await click_button(tr("MENU_RUWATAN")), "tombol Ruwatan di menu utama")
	await _wait(1.2)
	check(_scene_name() == "ruwatan", "masuk ke layar Ruwatan")
	check(await click_button(tr("RUWATAN_START")), "mulai Ruwatan")
	await _wait(0.6)
	# Berkah awal (hadiah 24 bintang) diumumkan dengan panel kecil.
	if find_button(tr("BTN_CONTINUE")) != null:
		await click_button(tr("BTN_CONTINUE"))
		await _wait(0.4)
	var run: RefCounted = gs.get("ruwatan")
	check(run != null and int(run.get("level")) == 1 and int(run.get("step")) == 0, "Ruwatan tingkat 1 dimulai di langkah 1")
	# Seperti mode cerita: yang dites alurnya, jadi Nyawa dibesarkan.
	run.set("max_hp", 400)
	run.set("hp", 400)
	var battles := 0
	var events_before := _events_seen
	var forks_before := _forks_seen
	var rewards := 0
	for guard: int in 30:
		run = gs.get("ruwatan")
		if run == null or bool(run.call("is_over")):
			break
		if _scene_name() != "ruwatan":
			await _wait(1.0)
			continue
		if not bool(run.call("is_battle_step")):
			await click_button(tr("RUWATAN_GO_EVENT"))
			await _wait(0.6)
			await _handle_event()
			continue
		await click_button(tr("BTN_FIGHT"))
		await _wait(1.5)
		var bm: BattleManager = current_scene.get_node_or_null("Systems/BattleManager")
		if bm == null:
			break
		while is_instance_valid(bm) and bm.is_battle_running() and bm.turn_number < 40:
			await _bot_turn(bm)
		battles += 1
		await _wait(4.0)
		var rp := await _wait_for_node("RewardPanel", 3.0)
		if rp != null:
			rewards += 1
			var choices := rp.find_children("*", "Button", true, false)
			await click((choices[0] as Button).get_global_rect().get_center())
			await _wait(0.4)
			var picker := _find_node("DeckPicker")
			if picker != null:
				var cards := picker.find_children("*", "Control", true, false).filter(
					func(n: Node) -> bool: return _is_class(n, "CardView"))
				await click((cards[0] as Control).get_global_rect().get_center())
				await _wait(0.2)
				await click_button(tr("PICKER_CONFIRM_REPLACE"))
				await _wait(0.4)
			await click_button(tr("BTN_CONTINUE"))
			await _wait(0.6)
	run = gs.get("ruwatan")
	check(run != null and int(run.get("state")) == 1, "Ruwatan berhasil sampai Buto Hitam")
	print("  %d battle, %d berkah, %d kejadian" % [battles, rewards, _events_seen - events_before])
	check(battles == 6 and rewards == 5 and _events_seen - events_before == 2, "enam battle, lima berkah, dua kejadian")
	check(_forks_seen - forks_before == 2, "kedua kejadian Ruwatan didahului persimpangan jalan")
	await _wait(1.0)
	check(await click_button(tr("RUWATAN_DONE")), "panel hasil Ruwatan")
	await _wait(0.6)
	check(gs.get("ruwatan") == null and int(gs.call("ruwatan_best_of", 1)) == 8 and int(gs.call("ruwatan_max_level")) == 2,
		"hasil tercatat dan Tingkat Pagebluk 2 terbuka")
	var history: Array[Dictionary] = (gs.get("records") as PlayRecords).ruwatan_history
	check(not history.is_empty() and int(history[0]["level"]) == 1 and int(history[0]["steps"]) == 8 and bool(history[0]["won"]),
		"Ruwatan yang berhasil masuk riwayat")
	check(find_button(tr("RUWATAN_START")) != null, "kembali ke pilihan tingkat")


func _run() -> void:
	await process_frame
	# Mode headless memakai jendela palsu 64x64; dengan skala pecahan game
	# ikut mengecil dan klik tiruan meleset. Pakai ukuran jendela sungguhan.
	root.size = Vector2i(1280, 720)
	await process_frame
	Engine.time_scale = 8.0
	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_save.cfg")
	gs.call("new_game")
	gs.set("star_record", {})
	gs.call("abandon_ruwatan")
	gs.set("ruwatan_best", {})
	# Catatan permainan tidak ikut direset Petualangan Baru, jadi dimulai dari nol di sini.
	gs.set("records", PlayRecords.new())
	gs.call("set_locale", "id")

	print("[Menu utama -> peta]")
	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await _wait(1.0)
	check(await click_button(tr("MENU_NEW")), "tombol Petualangan Baru bisa diklik")
	await _wait(1.2)
	check(_scene_name() == "stage_map", "masuk ke peta")
	await _wait_for_node("DialogBox", 5.0)
	await clear_dialogs()
	check(gs.get("prologue_seen") == true, "prolog selesai dengan klik")
	# Bot di sini sengaja sederhana; yang dites alurnya, bukan keseimbangannya
	# (itu tugas tools/simulate_balance.gd). Nyawa besar supaya bot tidak
	# tersangkut di babak Murka. Dipasang setelah Petualangan Baru karena
	# tombol itu mereset Nyawa.
	gs.set("max_hp", 400)

	print("[Sepuluh babak]")
	for n: int in range(1, _stage_count() + 1):
		var won := await _play_stage(n)
		check(won, "babak %d dimenangkan" % n)
		if not won:
			break
		if n < _stage_count():
			check(_scene_name() == "stage_map", "kembali ke peta setelah berkah babak %d" % n)

	print("[Ending]")
	await _wait(1.5)
	check(_scene_name() == "ending", "masuk ke ending setelah babak terakhir")
	await clear_dialogs(40)
	var parade := await _wait_for_node("ArakArakan", 5.0)
	check(parade != null, "arak-arakan keliling desa dimulai setelah dialog penutup")
	if parade != null:
		await click_button(tr("BTN_SKIP"))
		await _wait(0.5)
		check(int(parade.call("joined_count")) == 4, "dilewati: semua rombongan ikut arak-arakan")
		await _wait(2.5)
	await clear_dialogs(40)
	await _wait(2.0)
	check(gs.get("game_completed") == true, "game tercatat tamat")
	var records: PlayRecords = gs.get("records")
	print("  catatan: %d menang, %d kalah, %d Buto, jurus favorit %s" % [records.battles_won, records.battles_lost,
		records.total_defeated(), records.favorite_card()])
	check(records.battles_won >= _stage_count() and records.stories_completed == 1 and records.total_defeated() >= 20
		and records.favorite_card() != "", "catatan permainan terisi: battle, Buto yang dikalahkan, jurus favorit, tamat")
	check((gs.get("cleared_stages") as Array).size() == _stage_count(), "semua babak tercatat selesai")
	check(await click_button(tr("BTN_TO_MAP")), "tombol Ke Peta di kredit")
	await _wait(1.5)
	check(find_button(tr("MAP_ENDING")) != null, "peta menampilkan tombol Akhir Cerita")
	await click_button(tr("MAP_MENU"))
	await _wait(0.4)
	await click_button(tr("BTN_MAIN_MENU"))
	await _wait(1.5)
	check(_scene_name() == "main_menu", "kembali ke menu utama")
	check(find_button(tr("MENU_CONTINUE")) != null, "menu utama menampilkan Lanjutkan")
	# Kejadian di perjalanan juga bisa memberi berkah, jadi yang dihitung babaknya.
	check((gs.get("blessed_stages") as Array).size() == _stage_count() - 1 and (gs.get("blessings") as Array).size() >= _stage_count() - 1,
		"satu berkah untuk setiap babak 1-9")
	check(_challenge_panels == _stage_count() and gs.call("total_stars") >= _stage_count(), "Hasil Tantangan setiap babak, minimal satu bintang per babak (%d bintang)" % gs.call("total_stars"))
	check(_events_seen == gs.get("EVENT_STAGES").size() and gs.get("pending_event") == "", "empat kejadian di perjalanan muncul dan selesai")
	check(_forks_seen == _events_seen and (gs.get("pending_paths") as Array).is_empty(), "setiap kejadian didahului persimpangan jalan")
	var tabuh_in_deck := 0
	for spec: String in gs.get("deck"):
		if Blessings.is_tabuh_spec(spec):
			tabuh_in_deck += 1
	print("  berkah kartu Tabuh dipilih %d kali" % _picked_tabuh)
	# Kejadian di perjalanan juga bisa memberi kartu Tabuh.
	check(tabuh_in_deck >= _picked_tabuh and (gs.get("deck") as Array).size() == 15, "kartu Tabuh masuk ke Jurus lewat pemilih kartu, deck tetap 15")

	print("[Mengulang babak 1]")
	var blessings_before := (gs.get("blessings") as Array).size()
	await click_button(tr("MENU_CONTINUE"))
	await _wait(1.2)
	check(_scene_name() == "stage_map", "Lanjutkan membuka peta")
	var replay_won := await _play_stage(1)
	check(replay_won and _last_reward_already, "babak ulang dimenangkan tanpa berkah baru")
	check((gs.get("blessings") as Array).size() == blessings_before, "jumlah berkah tetap")
	check(_scene_name() == "stage_map", "kembali ke peta")

	await _play_ruwatan(gs)

	Engine.time_scale = 1.0
	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
