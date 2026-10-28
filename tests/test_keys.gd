extends SceneTree
## Tes tombol keyboard: tombol bawaan, mengganti dan mengosongkan tombol,
## bentrok antar aksi, Esc yang dikunci, simpanan, panel Tombol Keyboard, dan
## tombol yang benar-benar menggerakkan battle. Juga tombol gamepad dan
## pilihan Teks besar.
##   godot --headless -s tests/test_keys.gd

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


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _key(code: Key, pressed: bool = true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	root.push_input(e)


func _tap(code: Key) -> void:
	_key(code, true)
	await process_frame
	_key(code, false)
	await process_frame


func _pad_bound(action: String, button: JoyButton) -> bool:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return InputMap.event_is_action(e, action, true)


func _has_pad_events(action: String) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return true
	return false


func _bound(action: String, code: Key) -> bool:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return InputMap.event_is_action(e, action, true)


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


# Skrip yang memakai autoload dimuat lewat load(), bukan nama kelasnya: skrip
# tes dikompilasi sebelum autoload terdaftar (lihat test_campaign_flow.gd).
func _new(path: String) -> Node:
	return (load(path) as GDScript).new()


func _find_button(node: Node, text: String) -> Button:
	for b: Node in node.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.set("save_path", "user://test_save.cfg")
	gs.call("set_locale", "id")
	gs.call("reset_keys")

	print("[Aturan tombol]")
	var b := {}
	check(_same(KeyBindings.codes(b, "ultimate"), [KEY_Q, 0]), "bawaan Sapu Jagad: Q")
	check(_same(KeyBindings.codes(b, "end_turn"), [KEY_E, KEY_SPACE]), "bawaan Akhiri giliran: E dan Spasi")
	check(_same(KeyBindings.codes(b, "card_9"), [KEY_9, 0]), "bawaan kartu ke-9: angka 9")
	check(KeyBindings.assign(b, "end_turn", 1, KEY_Q) == "ultimate", "memasang Q ke Akhiri giliran melepasnya dari Sapu Jagad")
	check(_same(KeyBindings.codes(b, "ultimate"), [0, 0]) and _same(KeyBindings.codes(b, "end_turn"), [KEY_E, KEY_Q]),
		"satu tombol hanya punya satu arti")
	check(KeyBindings.assign(b, "ultimate", 0, KEY_ESCAPE) == "!", "Esc tidak bisa dipasang ke aksi lain")
	check(KeyBindings.assign(b, "pause", 0, KEY_P) == "!", "slot pertama Jeda terkunci")
	check(KeyBindings.assign(b, "pause", 1, KEY_P) == "" and _same(KeyBindings.codes(b, "pause"), [KEY_ESCAPE, KEY_P]),
		"slot kedua Jeda bisa diisi")
	check(KeyBindings.assign(b, "end_turn", 0, KEY_E) == "", "memasang tombol yang sama ke slotnya sendiri aman")
	KeyBindings.clear(b, "end_turn", 0)
	check(_same(KeyBindings.codes(b, "end_turn"), [0, KEY_Q]), "slot bisa dikosongkan")
	KeyBindings.clear(b, "pause", 0)
	check(KeyBindings.codes(b, "pause")[0] == KEY_ESCAPE, "Esc di Jeda tidak bisa dikosongkan")
	var clean := KeyBindings.sanitize({"ultimate": [KEY_ESCAPE, KEY_R], "ngawur": [1, 2], "card_1": "x", "end_turn": [KEY_T]})
	check(clean.size() == 2 and _same(clean["ultimate"], [0, KEY_R]) and _same(clean["end_turn"], [KEY_T, 0]),
		"simpanan rusak dibersihkan")
	check(KeyBindings.sanitize(null).is_empty(), "simpanan kosong tidak membuat error")
	check(KeyBindings.fill("{ultimate} | {end_turn} | {ngawur}", {}) == "Q | E / Spasi | {ngawur}", "teks diisi nama tombol")
	check(KeyBindings.names({"target_next": [0, 0]}, "target_next") == "-", "aksi tanpa tombol ditulis -")

	print("[GameState dan InputMap]")
	check(_bound("ultimate", KEY_Q) and _bound("end_turn", KEY_SPACE) and _bound("card_1", KEY_1) and _bound("pause", KEY_ESCAPE),
		"tombol bawaan terpasang di InputMap")
	check(String(gs.call("set_key", "ultimate", 0, KEY_R)) == "", "Sapu Jagad dipindah ke R")
	check(_bound("ultimate", KEY_R) and not _bound("ultimate", KEY_Q), "InputMap ikut berubah")
	check(String(gs.call("set_key", "card_1", 0, KEY_R)) == "ultimate", "R dipakai kartu ke-1, Sapu Jagad kehilangan R")
	check(String(gs.call("fill_keys", "tekan {ultimate}")) == "tekan -", "teks ikut berubah")
	gs.call("set_key", "ultimate", 0, KEY_G)
	gs.call("set_key", "end_turn", 1, KEY_ENTER)
	gs.set("key_bindings", {})
	gs.call("load_game")
	check((gs.call("key_codes", "ultimate") as Array)[0] == KEY_G and (gs.call("key_codes", "end_turn") as Array)[1] == KEY_ENTER,
		"pilihan tombol tersimpan")
	gs.call("apply_settings")
	check(_bound("ultimate", KEY_G), "dipasang lagi setelah dimuat")
	gs.call("reset_keys")
	check(_bound("ultimate", KEY_Q) and _bound("card_1", KEY_1) and not _bound("ultimate", KEY_G), "Kembalikan bawaan")

	print("[Gamepad]")
	check(_pad_bound("end_turn", JOY_BUTTON_X) and _pad_bound("ultimate", JOY_BUTTON_Y) and _pad_bound("target_next", JOY_BUTTON_RIGHT_SHOULDER)
		and _pad_bound("toggle_speed", JOY_BUTTON_LEFT_SHOULDER), "X, Y, RB, dan LB terpasang ke aksi battle")
	check(_pad_bound("pause", JOY_BUTTON_START) and _pad_bound("pause", JOY_BUTTON_B), "Start dan B untuk jeda")
	check(not _pad_bound("end_turn", JOY_BUTTON_A) and not _pad_bound("ultimate", JOY_BUTTON_A), "A tidak dipakai aksi (A adalah klik)")
	gs.call("set_key", "ultimate", 0, KEY_R)
	check(_pad_bound("ultimate", JOY_BUTTON_Y), "mengganti tombol keyboard tidak melepas tombol gamepad")
	gs.call("reset_keys")
	check(not _has_pad_events("ui_accept") and not _has_pad_events("ui_left") and not _has_pad_events("ui_cancel"),
		"aksi ui_* bawaan tidak membaca gamepad, supaya A tidak terhitung dua kali")
	var cursor := root.get_node_or_null("GamepadCursor")
	check(cursor != null, "autoload GamepadCursor terpasang")
	if cursor != null:
		var consts: Dictionary = (cursor.get_script() as GDScript).get_script_constant_map()
		var speed := float(consts["SPEED"])
		var v := func(stick: Vector2, dpad: Vector2, moving_for: float) -> Vector2:
			return cursor.call("cursor_velocity", stick, dpad, moving_for)
		check(v.call(Vector2(0.15, 0.1), Vector2.ZERO, 0.0) == Vector2.ZERO, "stik yang sedikit miring (zona mati) tidak menggerakkan kursor")
		check((v.call(Vector2(1, 0), Vector2.ZERO, 0.0) as Vector2).is_equal_approx(Vector2(speed, 0)), "stik penuh: %d piksel per detik" % speed)
		check((v.call(Vector2(0, -1), Vector2.ZERO, 5.0) as Vector2).is_equal_approx(Vector2(0, -speed * float(consts["BOOST_MAX"]))),
			"setelah bergerak lama kursor makin cepat")
		check(is_equal_approx((v.call(Vector2.ZERO, Vector2(1, 1), 0.0) as Vector2).length(), float(consts["DPAD_SPEED"])),
			"D-pad miring tidak lebih cepat dari lurus")

	print("[Panel Tombol Keyboard]")
	var settings := _new("res://ui/common/settings_panel.gd")
	root.add_child(settings)
	await process_frame
	var open := _find_button(settings, tr("KEYS_OPEN"))
	check(open != null, "Pengaturan punya tombol Atur untuk keyboard")
	open.pressed.emit()
	await process_frame
	var panel: Node = null
	for child: Node in settings.get_children():
		if child.has_method("press_key"):
			panel = child
	check(panel != null, "panel Tombol Keyboard terbuka")
	check(_find_button(panel, "Q") != null and _find_button(panel, "Spasi") != null and _find_button(panel, "Tab") != null,
		"panel menampilkan Q, Spasi, dan Tab")
	var esc_button := _find_button(panel, "Esc")
	check(esc_button != null and esc_button.disabled, "Esc di Jeda tampil tapi terkunci")
	panel.call("_start_waiting", "target_next", 1)
	check(panel.call("is_waiting") and _find_button(panel, "...") != null, "menunggu tombol baru")
	await _tap(KEY_T)
	check((gs.call("key_codes", "target_next") as Array)[1] == KEY_T and not panel.call("is_waiting"), "menekan T memasangnya ke Ganti sasaran")
	check(_find_button(panel, "T") != null, "kotak tombol menampilkan T")
	panel.call("_start_waiting", "card_2", 0)
	await _tap(KEY_T)
	var notice: Label = panel.get("_notice")
	check((gs.call("key_codes", "target_next") as Array)[1] == 0 and notice.text.contains("Ganti sasaran"),
		"bentrok: T pindah ke kartu ke-2 dan pemain diberi tahu")
	panel.call("_start_waiting", "ultimate", 0)
	await _tap(KEY_ESCAPE)
	check(not panel.call("is_waiting") and (gs.call("key_codes", "ultimate") as Array)[0] == KEY_Q and is_instance_valid(panel)
		and not panel.is_queued_for_deletion(), "Esc saat menunggu hanya membatalkan")
	panel.call("_start_waiting", "end_turn", 1)
	await _tap(KEY_BACKSPACE)
	check((gs.call("key_codes", "end_turn") as Array)[1] == 0, "Backspace mengosongkan slot")
	await _tap(KEY_ESCAPE)
	await process_frame
	check(not is_instance_valid(panel) and is_instance_valid(settings), "Esc menutup panel tombol saja, Pengaturan tetap terbuka")
	settings.queue_free()
	gs.call("reset_keys")
	await process_frame

	print("[Teks besar]")
	check(not UIKit.large_text() and UIKit.small_text_variation() == &"", "bawaannya mati: teks kecil 8 piksel")
	gs.call("set_large_text", true)
	check(UIKit.large_text() and UIKit.small_text_variation() == &"BigLabel", "dinyalakan: teks kecil jadi 16 piksel")
	check(ThemeDB.get_project_theme().get_font_size("font_size", "TooltipLabel") == UIKit.TEXT_LARGE, "keterangan bawaan Godot (di Pengaturan) ikut membesar")
	gs.set("large_text", false)
	gs.call("load_game")
	check(bool(gs.get("large_text")), "pilihan Teks besar tersimpan")
	var tip := GameTooltip.new()
	root.add_child(tip)
	tip.show_text("Buto Kuning", Vector2(100, 100))
	var tip_label: RichTextLabel = tip.get("_label")
	check(tip_label.custom_minimum_size.x == GameTooltip.MAX_WIDTH_LARGE and tip_label.get_theme_font_size("normal_font_size") == UIKit.TEXT_LARGE,
		"keterangan kartu dan Buto ikut membesar")
	gs.call("set_large_text", false)
	tip.show_text("Buto Kuning", Vector2(100, 100))
	check(tip_label.custom_minimum_size.x == GameTooltip.MAX_WIDTH and tip_label.get_theme_font_size("normal_font_size") < UIKit.TEXT_LARGE,
		"dimatikan lagi: kembali kecil")
	check(ThemeDB.get_project_theme().get_font_size("font_size", "TooltipLabel") == 8, "keterangan bawaan Godot kembali 8 piksel")
	tip.queue_free()
	settings = _new("res://ui/common/settings_panel.gd")
	root.add_child(settings)
	await process_frame
	var large_row := false
	for l: Node in settings.find_children("*", "Label", true, false):
		large_row = large_row or (l as Label).text == tr("SETTINGS_LARGE_TEXT")
	check(large_row, "Pengaturan punya pilihan Teks besar")
	settings.queue_free()
	await process_frame

	print("[Tombol di battle]")
	gs.set("ruwatan_best", {})
	gs.call("start_ruwatan", 1, RandomNumberGenerator.new())
	gs.set("play_mode", 1)
	gs.set("hints_enabled", false)
	var scene: Node = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var bm: BattleManager = scene.get_node("Systems/BattleManager")
	for i: int in 600:
		await process_frame
		if bm.is_accepting_input():
			break
	check(bm.is_accepting_input(), "battle siap menerima tombol")
	var alive := bm.get_living_enemies()
	if alive.size() >= 2:
		var before := bm.get_target()
		await _tap(KEY_TAB)
		check(bm.get_target() != before and bm.get_target() == alive[(alive.find(before) + 1) % alive.size()], "Tab mengganti sasaran")
	gs.call("set_key", "card_1", 0, KEY_Z)
	var hand_before := bm.hand.get_cards().size()
	await _tap(KEY_1)
	await _wait(0.2)
	check(bm.hand.get_cards().size() == hand_before, "angka 1 tidak lagi memainkan kartu setelah diganti")
	await _tap(KEY_Z)
	for i: int in 120:
		await process_frame
		if bm.hand.get_cards().size() != hand_before:
			break
	check(bm.hand.get_cards().size() < hand_before, "Z memainkan kartu pertama")
	var speed: float = gs.get("battle_speed")
	await _tap(KEY_F)
	check(not is_equal_approx(float(gs.get("battle_speed")), speed), "F mengganti kecepatan battle")
	await _tap(KEY_F)
	scene.queue_free()
	await process_frame
	gs.call("abandon_ruwatan")
	gs.set("play_mode", 0)
	gs.call("reset_keys")

	print("\n%d/%d cek lolos" % [_checks - _failures, _checks])
	quit(1 if _failures > 0 else 0)
