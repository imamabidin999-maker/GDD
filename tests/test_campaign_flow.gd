extends SceneTree
## Tes ujung-ke-ujung: menamatkan kampanye lewat scene asli dengan klik mouse
## sungguhan (menu -> peta -> 10 babak -> berkah -> ending -> peta -> menu).
## Battle dimainkan bot sederhana. Waktu game dipercepat 8x.
##   godot --headless -s tests/test_campaign_flow.gd

var _failures: int = 0
var _checks: int = 0
var _last_reward_already: bool = false


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
			if not bm.hand.can_play_at(i):
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


func _stage_count() -> int:
	return int(root.get_node("GameState").get("STAGE_COUNT"))


func _scene_name() -> String:
	return current_scene.scene_file_path.get_file().get_basename() if current_scene != null else ""


func _play_stage(n: int) -> bool:
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
				if not already:
					await click_button(tr("BTN_CONTINUE"))
				await _wait(1.2)
			return true
		await _wait(1.0)
		await click_button(tr("BTN_RETRY"))
		await _wait(1.5)
	return false


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
	gs.call("set_locale", "id")

	print("[Menu utama -> peta]")
	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await _wait(1.0)
	check(await click_button(tr("MENU_NEW")), "tombol Petualangan Baru bisa diklik")
	await _wait(1.2)
	check(_scene_name() == "stage_map", "masuk ke peta")
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
	await _wait(2.0)
	check(gs.get("game_completed") == true, "game tercatat tamat")
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
	check((gs.get("blessings") as Array).size() == _stage_count() - 1, "satu berkah untuk setiap babak 1-9")

	print("[Mengulang babak 1]")
	await click_button(tr("MENU_CONTINUE"))
	await _wait(1.2)
	check(_scene_name() == "stage_map", "Lanjutkan membuka peta")
	var replay_won := await _play_stage(1)
	check(replay_won and _last_reward_already, "babak ulang dimenangkan tanpa berkah baru")
	check((gs.get("blessings") as Array).size() == _stage_count() - 1, "jumlah berkah tetap")
	check(_scene_name() == "stage_map", "kembali ke peta")

	Engine.time_scale = 1.0
	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
