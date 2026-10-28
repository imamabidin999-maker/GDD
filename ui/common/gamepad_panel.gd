class_name GamepadPanel
extends Control
## Panel tombol gamepad: tombol kursor (tetap), tombol aksi battle yang bisa
## diganti, kecepatan kursor, dan gamepad yang sedang tersambung. Klik kotak
## tombol lalu tekan tombol gamepad baru; klik kanan mengosongkan, Start atau
## Esc membatalkan. Dibuka dari Pengaturan.

signal closed

const SLOT_WIDTH := 56.0
## Baris tombol kursor: [nama aksi, nama tombol]. Tidak bisa diganti.
const CURSOR_ROWS := [
	["PAD_MOVE", "PAD_MOVE_BUTTON"],
	["PAD_CLICK", ""],
	["PAD_DRAG", "PAD_DRAG_BUTTON"],
	["PAD_SCROLL", "PAD_SCROLL_BUTTON"],
]

# aksi -> Button
var _slots := {}
var _waiting_action := ""
var _notice: Label
var _status: Label
var _speed_label: Label
var _speed_slider: HSlider


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
	var title := UIKit.label(tr("PAD_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var intro := UIKit.label(tr("PAD_INTRO"), &"", UIKit.COLOR_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.custom_minimum_size.x = 460
	col.add_child(intro)
	_status = UIKit.label("", &"", UIKit.COLOR_TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	var columns := UIKit.hbox(32)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(columns)
	columns.add_child(_cursor_group())
	columns.add_child(_battle_group())

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
		GameState.reset_pad()
		_speed_slider.set_value_no_signal(GameState.pad_cursor_speed)
		_refresh()
		_notice.text = tr("PAD_RESET_DONE"))
	buttons.add_child(reset)
	var close := UIKit.button(tr("BTN_CLOSE"), 120, true)
	close.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_close())
	buttons.add_child(close)
	col.add_child(buttons)

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh()


## Tombol kursor (tetap) dan kecepatan kursor.
func _cursor_group() -> VBoxContainer:
	var box := UIKit.vbox(2)
	box.add_child(UIKit.label(tr("PAD_GROUP_CURSOR"), &"BigLabel", UIKit.COLOR_GOLD))
	var grid := _grid(2)
	box.add_child(grid)
	for row: Array in CURSOR_ROWS:
		grid.add_child(_action_label(tr(row[0])))
		var fixed := UIKit.button("A" if row[1] == "" else tr(row[1]), 80)
		fixed.disabled = true
		fixed.tooltip_text = tr("PAD_FIXED_NOTE")
		fixed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(fixed)

	var speed_row := UIKit.hbox(6)
	_speed_label = UIKit.label("", &"BigLabel")
	_speed_label.custom_minimum_size.x = 64
	speed_row.add_child(_speed_label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.5
	_speed_slider.max_value = 2.0
	_speed_slider.step = 0.25
	_speed_slider.value = GameState.pad_cursor_speed
	_speed_slider.custom_minimum_size = Vector2(80, 12)
	_speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed_slider.focus_mode = Control.FOCUS_NONE
	_speed_slider.value_changed.connect(func(value: float) -> void:
		GameState.set_pad_cursor_speed(value)
		_refresh())
	speed_row.add_child(_speed_slider)
	box.add_child(speed_row)
	return box


## Aksi battle: nama aksi, tombol pilihan, dan Start yang selalu untuk jeda.
func _battle_group() -> VBoxContainer:
	var box := UIKit.vbox(2)
	box.add_child(UIKit.label(tr("KEYS_GROUP_BATTLE"), &"BigLabel", UIKit.COLOR_GOLD))
	var grid := _grid(3)
	box.add_child(grid)
	for action: String in PadBindings.ACTIONS:
		grid.add_child(_action_label(ControlsPanel.action_name(action)))
		var b := UIKit.button("", SLOT_WIDTH)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: _start_waiting(action))
		b.gui_input.connect(func(event: InputEvent) -> void: _on_slot_input(event, action))
		_slots[action] = b
		grid.add_child(b)
		if action == "pause":
			var start := UIKit.button(PadBindings.button_name(PadBindings.PAUSE_FIXED), SLOT_WIDTH)
			start.disabled = true
			start.tooltip_text = tr("PAD_START_NOTE")
			start.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(start)
		else:
			grid.add_child(Control.new())
	return box


func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 1)
	return grid


func _action_label(text: String) -> Label:
	var label := UIKit.label(text, &"BigLabel")
	label.custom_minimum_size.x = 64
	return label


func _refresh() -> void:
	for action: String in _slots:
		var b: Button = _slots[action]
		var waiting := action == _waiting_action
		b.text = "..." if waiting else PadBindings.button_name(GameState.pad_button(action))
		b.modulate = Color(1.4, 1.2, 0.6) if waiting else Color.WHITE
	_speed_label.text = tr("PAD_SPEED") % roundi(GameState.pad_cursor_speed * 100.0)
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_status.text = tr("PAD_NONE")
		_status.add_theme_color_override("font_color", UIKit.COLOR_DIM)
	else:
		_status.text = tr("PAD_CONNECTED") % Input.get_joy_name(pads[0])
		_status.add_theme_color_override("font_color", UIKit.COLOR_GREEN)
	if _waiting_action == "" and _notice.text == "":
		_notice.text = tr("PAD_HINT")


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	if is_inside_tree():
		_refresh()


func _start_waiting(action: String) -> void:
	AudioManager.play_sfx("click")
	_waiting_action = action
	_notice.text = tr("PAD_WAITING") % ControlsPanel.action_name(action)
	_refresh()


func _stop_waiting() -> void:
	_waiting_action = ""


# Klik kanan di kotak tombol langsung mengosongkannya.
func _on_slot_input(event: InputEvent, action: String) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		AudioManager.play_sfx("click")
		_stop_waiting()
		GameState.clear_pad_button(action)
		_notice.text = tr("KEYS_CLEARED") % ControlsPanel.action_name(action)
		_refresh()
		accept_event()


func _input(event: InputEvent) -> void:
	var pad := event as InputEventJoypadButton
	if pad != null:
		if _waiting_action != "":
			# Selama menunggu, tekanan gamepad tidak boleh menjadi klik atau aksi.
			get_viewport().set_input_as_handled()
			if pad.pressed:
				press_button(pad.button_index)
		elif event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_close()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return
	if _waiting_action == "":
		_close()
	else:
		_stop_waiting()
		_notice.text = tr("PAD_HINT")
		_refresh()


## Memasang tombol gamepad ke aksi yang sedang menunggu. Dipisah supaya bisa dites.
func press_button(button: int) -> void:
	if _waiting_action == "":
		return
	var action := _waiting_action
	if button == PadBindings.PAUSE_FIXED:
		_stop_waiting()
		_notice.text = tr("PAD_HINT")
		_refresh()
		return
	var displaced := GameState.set_pad_button(action, button)
	_stop_waiting()
	var pad_name := PadBindings.button_name(button)
	if displaced == "!":
		_notice.text = tr("PAD_RESERVED") % pad_name
	elif displaced != "":
		AudioManager.play_sfx("click")
		_notice.text = tr("KEYS_MOVED") % [pad_name, ControlsPanel.action_name(displaced), ControlsPanel.action_name(action)]
	else:
		AudioManager.play_sfx("click")
		_notice.text = tr("KEYS_SET") % [pad_name, ControlsPanel.action_name(action)]
	_refresh()


func is_waiting() -> bool:
	return _waiting_action != ""


func _close() -> void:
	closed.emit()
	queue_free()
