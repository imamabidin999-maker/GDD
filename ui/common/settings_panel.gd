class_name SettingsPanel
extends Control
## Panel pengaturan: bahasa, volume musik & efek suara, layar penuh.
## Dipakai di menu utama dan di menu jeda battle.

signal closed

var _title: Label
var _lang_label: Label
var _music_label: Label
var _sfx_label: Label
var _full_label: Label
var _close: Button
var _lang_id: Button
var _lang_en: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dimmer(0.6))

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.custom_minimum_size = Vector2(300, 0)
	add_child(UIKit.center(panel))

	var col := UIKit.vbox(8)
	panel.add_child(col)
	_title = UIKit.label("", &"HeaderLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)

	_lang_label = UIKit.label("")
	grid.add_child(_lang_label)
	var lang_row := UIKit.hbox(4)
	_lang_id = UIKit.button("ID", 44)
	_lang_en = UIKit.button("EN", 44)
	_lang_id.toggle_mode = true
	_lang_en.toggle_mode = true
	_lang_id.pressed.connect(func() -> void: _set_locale("id"))
	_lang_en.pressed.connect(func() -> void: _set_locale("en"))
	lang_row.add_child(_lang_id)
	lang_row.add_child(_lang_en)
	grid.add_child(lang_row)

	_music_label = UIKit.label("")
	grid.add_child(_music_label)
	grid.add_child(_make_slider(GameState.music_volume, func(v: float) -> void: GameState.set_music_volume(v)))

	_sfx_label = UIKit.label("")
	grid.add_child(_sfx_label)
	grid.add_child(_make_slider(GameState.sfx_volume, func(v: float) -> void:
		GameState.set_sfx_volume(v)
		AudioManager.play_sfx("kentongan", 0.05)))

	_full_label = UIKit.label("")
	grid.add_child(_full_label)
	var full := CheckBox.new()
	full.button_pressed = GameState.fullscreen
	full.focus_mode = Control.FOCUS_NONE
	full.toggled.connect(func(on: bool) -> void: GameState.set_fullscreen(on))
	grid.add_child(full)

	_close = UIKit.button("", 120)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		closed.emit()
		queue_free())
	col.add_child(_close)
	_refresh_texts()


func _make_slider(value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(140, 14)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(on_change)
	return s


func _set_locale(locale: String) -> void:
	GameState.set_locale(locale)
	AudioManager.play_sfx("click")
	_refresh_texts()


func _refresh_texts() -> void:
	_title.text = tr("SETTINGS_TITLE")
	_lang_label.text = tr("SETTINGS_LANGUAGE")
	_music_label.text = tr("SETTINGS_MUSIC")
	_sfx_label.text = tr("SETTINGS_SFX")
	_full_label.text = tr("SETTINGS_FULLSCREEN")
	_close.text = tr("BTN_CLOSE")
	_lang_id.button_pressed = GameState.locale == "id"
	_lang_en.button_pressed = GameState.locale == "en"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
