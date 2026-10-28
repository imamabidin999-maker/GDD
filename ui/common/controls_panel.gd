class_name ControlsPanel
extends Control
## Panel tombol keyboard: daftar aksi beserta tombolnya, dan pemain bisa
## menggantinya. Klik kotak tombol lalu tekan tombol baru; klik kanan atau
## Backspace mengosongkan, Esc membatalkan. Dibuka dari Pengaturan.

signal closed

const BATTLE_ACTIONS: Array[String] = ["ultimate", "end_turn", "target_next", "toggle_speed", "pause"]
const SLOT_WIDTH := 56.0

# "aksi:slot" -> Button
var _slots := {}
var _waiting_action := ""
var _waiting_slot := -1
var _notice: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dimmer(0.75))

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))

	var col := UIKit.vbox(6)
	panel.add_child(col)
	var title := UIKit.label(tr("KEYS_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var mouse := UIKit.label(tr("KEYS_MOUSE"), &"", UIKit.COLOR_DIM)
	mouse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse.custom_minimum_size.x = 460
	col.add_child(mouse)

	var columns := UIKit.hbox(32)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(columns)
	var cards: Array[String] = []
	for i: int in KeyBindings.CARD_KEYS:
		cards.append("card_%d" % (i + 1))
	columns.add_child(_group("KEYS_GROUP_BATTLE", BATTLE_ACTIONS))
	columns.add_child(_group("KEYS_GROUP_CARDS", cards))

	# Gamepad: tetap, tidak bisa diubah (lihat GamepadCursor dan KeyBindings.JOYPAD).
	var pad := UIKit.vbox(1)
	pad.add_child(UIKit.label(tr("KEYS_GAMEPAD_TITLE"), &"", UIKit.COLOR_GOLD))
	var pad_text := UIKit.label(tr("KEYS_GAMEPAD"), &"", UIKit.COLOR_TEXT)
	pad_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pad_text.custom_minimum_size.x = 460
	pad.add_child(pad_text)
	col.add_child(pad)

	_notice = UIKit.label("", &"", UIKit.COLOR_GOLD)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(460, 20)
	col.add_child(_notice)

	var buttons := UIKit.hbox(8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var reset := UIKit.button(tr("KEYS_RESET"), 120, true)
	reset.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_stop_waiting()
		GameState.reset_keys()
		_refresh()
		_notice.text = tr("KEYS_RESET_DONE"))
	buttons.add_child(reset)
	var close := UIKit.button(tr("BTN_CLOSE"), 120, true)
	close.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_close())
	buttons.add_child(close)
	col.add_child(buttons)
	_refresh()


## Satu kelompok aksi: judul, lalu baris "nama aksi | slot 1 | slot 2".
func _group(title_key: String, actions: Array[String]) -> VBoxContainer:
	var box := UIKit.vbox(2)
	box.add_child(UIKit.label(tr(title_key), &"BigLabel", UIKit.COLOR_GOLD))
	var grid := GridContainer.new()
	grid.columns = 1 + KeyBindings.SLOTS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 1)
	box.add_child(grid)
	for action: String in actions:
		var label := UIKit.label(action_name(action), &"BigLabel")
		label.custom_minimum_size.x = 64
		grid.add_child(label)
		for slot: int in KeyBindings.SLOTS:
			var b := UIKit.button("", SLOT_WIDTH)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if KeyBindings.is_locked(action, slot):
				b.disabled = true
				b.tooltip_text = tr("KEYS_ESC_NOTE")
			else:
				b.pressed.connect(func() -> void: _start_waiting(action, slot))
				b.gui_input.connect(func(event: InputEvent) -> void: _on_slot_input(event, action, slot))
			_slots["%s:%d" % [action, slot]] = b
			grid.add_child(b)
	return box


## Nama aksi untuk pemain, misalnya "Akhiri giliran" atau "Kartu ke-3".
static func action_name(action: String) -> String:
	if action.begins_with("card_"):
		return TranslationServer.translate("KEY_ACTION_CARD") % int(action.trim_prefix("card_"))
	return TranslationServer.translate("KEY_ACTION_" + action.to_upper())


func _refresh() -> void:
	for key: String in _slots:
		var parts := key.split(":")
		var action := parts[0]
		var slot := int(parts[1])
		var b: Button = _slots[key]
		var waiting := action == _waiting_action and slot == _waiting_slot
		b.text = "..." if waiting else KeyBindings.key_name(GameState.key_codes(action)[slot])
		b.modulate = Color(1.4, 1.2, 0.6) if waiting else Color.WHITE
	if _waiting_action == "" and _notice.text == "":
		_notice.text = tr("KEYS_HINT")


func _start_waiting(action: String, slot: int) -> void:
	AudioManager.play_sfx("click")
	_waiting_action = action
	_waiting_slot = slot
	_notice.text = tr("KEYS_WAITING") % action_name(action)
	_refresh()


func _stop_waiting() -> void:
	_waiting_action = ""
	_waiting_slot = -1


# Klik kanan di kotak tombol langsung mengosongkannya.
func _on_slot_input(event: InputEvent, action: String, slot: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		_clear(action, slot)
		accept_event()


func _clear(action: String, slot: int) -> void:
	AudioManager.play_sfx("click")
	_stop_waiting()
	GameState.clear_key(action, slot)
	_notice.text = tr("KEYS_CLEARED") % action_name(action)
	_refresh()


func _input(event: InputEvent) -> void:
	# B atau Start di gamepad juga menutup panel (lihat KeyBindings.JOYPAD).
	if event is InputEventJoypadButton and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _waiting_action == "":
			_close()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	# Selama panel terbuka, tombol tidak boleh tembus ke battle atau Pengaturan.
	get_viewport().set_input_as_handled()
	var code := int(key.physical_keycode)
	if code == 0:
		code = int(key.keycode)
	if _waiting_action == "":
		if code == KeyBindings.RESERVED:
			_close()
		return
	match code:
		KeyBindings.RESERVED:
			_stop_waiting()
			_notice.text = tr("KEYS_HINT")
			_refresh()
		KEY_BACKSPACE, KEY_DELETE:
			_clear(_waiting_action, _waiting_slot)
		_:
			press_key(code)


## Memasang tombol ke slot yang sedang menunggu. Dipisah supaya bisa dites.
func press_key(code: int) -> void:
	if _waiting_action == "":
		return
	var action := _waiting_action
	var displaced := GameState.set_key(action, _waiting_slot, code)
	_stop_waiting()
	if displaced == "!":
		_notice.text = tr("KEYS_ESC_NOTE")
	elif displaced != "":
		AudioManager.play_sfx("click")
		_notice.text = tr("KEYS_MOVED") % [KeyBindings.key_name(code), action_name(displaced), action_name(action)]
	else:
		AudioManager.play_sfx("click")
		_notice.text = tr("KEYS_SET") % [KeyBindings.key_name(code), action_name(action)]
	_refresh()


func is_waiting() -> bool:
	return _waiting_action != ""


func _close() -> void:
	closed.emit()
	queue_free()
