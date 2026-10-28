class_name SettingsPanel
extends Control
## Panel pengaturan: bahasa, volume musik & efek suara, layar penuh, tombol
## keyboard (kolom kiri), lalu tingkat kesulitan cerita, kecepatan battle,
## petunjuk, tanda istilah Jawa, dan irama (kolom kanan). Dipakai di menu utama
## dan di menu jeda battle.

signal closed

var _title: Label
var _lang_label: Label
var _music_label: Label
var _sfx_label: Label
var _full_label: Label
var _close: Button
var _lang_id: Button
var _lang_en: Button
# Teks yang ditulis ulang saat bahasa diganti: Label/Button -> kunci terjemahan.
var _texts := {}
var _difficulty_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dimmer(0.6))

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))

	var col := UIKit.vbox(8)
	panel.add_child(col)
	_title = UIKit.label("", &"HeaderLabel")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	var columns := UIKit.hbox(22)
	col.add_child(columns)
	var grid := _grid()
	columns.add_child(grid)

	_lang_label = UIKit.label("", &"BigLabel")
	grid.add_child(_lang_label)
	var lang_row := UIKit.hbox(4)
	_lang_id = UIKit.button("ID", 44, true)
	_lang_en = UIKit.button("EN", 44, true)
	_lang_id.toggle_mode = true
	_lang_en.toggle_mode = true
	_lang_id.pressed.connect(func() -> void: _set_locale("id"))
	_lang_en.pressed.connect(func() -> void: _set_locale("en"))
	lang_row.add_child(_lang_id)
	lang_row.add_child(_lang_en)
	grid.add_child(lang_row)

	_music_label = UIKit.label("", &"BigLabel")
	grid.add_child(_music_label)
	grid.add_child(_make_slider(GameState.music_volume, func(v: float) -> void: GameState.set_music_volume(v)))

	_sfx_label = UIKit.label("", &"BigLabel")
	grid.add_child(_sfx_label)
	grid.add_child(_make_slider(GameState.sfx_volume, func(v: float) -> void:
		GameState.set_sfx_volume(v)
		AudioManager.play_sfx("kentongan", 0.05)))

	_full_label = UIKit.label("", &"BigLabel")
	grid.add_child(_full_label)
	grid.add_child(_checkbox(GameState.fullscreen, func(on: bool) -> void: GameState.set_fullscreen(on)))

	var large := _text_label("SETTINGS_LARGE_TEXT")
	large.mouse_filter = Control.MOUSE_FILTER_PASS
	large.tooltip_text = tr("SETTINGS_LARGE_TEXT_TIP")
	grid.add_child(large)
	grid.add_child(_checkbox(GameState.large_text, func(on: bool) -> void: GameState.set_large_text(on)))

	# Daftar tombol keyboard, dan pemain bisa menggantinya.
	grid.add_child(_text_label("SETTINGS_KEYS"))
	var keys := UIKit.button(tr("KEYS_OPEN"), 60)
	keys.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_texts[keys] = "KEYS_OPEN"
	keys.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		add_child(ControlsPanel.new()))
	grid.add_child(keys)

	grid = _grid()
	columns.add_child(grid)
	grid.add_child(_text_label("SETTINGS_DIFFICULTY"))
	var diff_row := UIKit.hbox(4)
	for i: int in 3:
		var b := UIKit.button("", 56, true)
		b.toggle_mode = true
		_texts[b] = ["DIFF_SANTAI", "DIFF_NORMAL", "DIFF_SULIT"][i]
		b.pressed.connect(func() -> void:
			GameState.set_difficulty(i)
			AudioManager.play_sfx("click")
			_refresh_texts())
		diff_row.add_child(b)
		_difficulty_buttons.append(b)
	grid.add_child(diff_row)

	grid.add_child(_text_label("SETTINGS_SPEED"))
	var speed_row := UIKit.hbox(4)
	for i: int in 2:
		var b := UIKit.button("%dx" % (i + 1), 44, true)
		b.toggle_mode = true
		b.pressed.connect(func() -> void:
			GameState.set_battle_speed(float(i + 1))
			AudioManager.play_sfx("click")
			_refresh_texts())
		speed_row.add_child(b)
		_speed_buttons.append(b)
	grid.add_child(speed_row)

	grid.add_child(_text_label("SETTINGS_HINTS"))
	grid.add_child(_checkbox(GameState.hints_enabled, func(on: bool) -> void: GameState.set_hints_enabled(on)))

	var glossary := _text_label("SETTINGS_GLOSSARY")
	glossary.mouse_filter = Control.MOUSE_FILTER_PASS
	glossary.tooltip_text = tr("SETTINGS_GLOSSARY_TIP")
	grid.add_child(glossary)
	grid.add_child(_checkbox(GameState.glossary_marks, func(on: bool) -> void: GameState.set_glossary_marks(on)))

	grid.add_child(_text_label("SETTINGS_RHYTHM"))
	var rhythm_row := UIKit.hbox(8)
	rhythm_row.add_child(_checkbox(GameState.rhythm_enabled, func(on: bool) -> void: GameState.set_rhythm_enabled(on)))
	# Latihan irama Gebrakan, lengkap dengan cara bermainnya.
	var practice := UIKit.button(tr("RHYTHM_PRACTICE"), 60)
	practice.tooltip_text = tr("RHYTHM_PRACTICE_TIP")
	_texts[practice] = "RHYTHM_PRACTICE"
	practice.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		var rhythm := RhythmGebrakan.new()
		rhythm.show_intro = true
		AudioManager.duck_music(true)
		rhythm.tree_exiting.connect(func() -> void: AudioManager.duck_music(false))
		add_child(rhythm))
	rhythm_row.add_child(practice)
	grid.add_child(rhythm_row)

	_close = UIKit.button("", 120, true)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		closed.emit()
		queue_free())
	col.add_child(_close)
	_refresh_texts()


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return grid


func _text_label(key: String) -> Label:
	var l := UIKit.label("", &"BigLabel")
	_texts[l] = key
	return l


func _checkbox(value: bool, on_toggle: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_NONE
	# CheckBox mewarisi gaya Button; tanpa ini ia tampil sebagai kotak lebar.
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		box.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	box.add_theme_icon_override("unchecked", _check_icon(false))
	box.add_theme_icon_override("checked", _check_icon(true))
	box.toggled.connect(on_toggle)
	return box


## Kotak centang 12x12 bergaya piksel: bingkai emas, isi emas saat dicentang.
static func _check_icon(checked: bool) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.07, 0.13))
	for i: int in 12:
		for edge: Vector2i in [Vector2i(i, 0), Vector2i(i, 11), Vector2i(0, i), Vector2i(11, i)]:
			img.set_pixelv(edge, UIKit.COLOR_GOLD)
	if checked:
		img.fill_rect(Rect2i(3, 3, 6, 6), UIKit.COLOR_GOLD)
	return ImageTexture.create_from_image(img)


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
	for node: Control in _texts:
		node.set("text", tr(_texts[node]))
	for i: int in _difficulty_buttons.size():
		_difficulty_buttons[i].button_pressed = GameState.difficulty == i
	for i: int in _speed_buttons.size():
		_speed_buttons[i].button_pressed = is_equal_approx(GameState.battle_speed, float(i + 1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
