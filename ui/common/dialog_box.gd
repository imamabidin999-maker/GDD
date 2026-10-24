class_name DialogBox
extends Control
## Kotak dialog cerita: potret, nama pembicara, dan teks yang muncul huruf demi
## huruf. Klik (atau Spasi/Enter) untuk mempercepat, lalu lanjut ke baris
## berikutnya. Tombol "Lewati" melompati semua sisa baris.
##
## Pemakaian:
##   var box := DialogBox.new()
##   add_child(box)
##   await box.play(stage.intro_dialog)

signal finished

const CHARS_PER_SECOND := 55.0
const PORTRAITS := {
	"eyang": preload("res://assets/ui/portrait_eyang_palang.png"),
	"buto_kuning": preload("res://assets/ui/portrait_buto_kuning.png"),
	"buto_hijau": preload("res://assets/ui/portrait_buto_hijau.png"),
	"buto_merah": preload("res://assets/ui/portrait_buto_merah.png"),
	"buto_putih": preload("res://assets/ui/portrait_buto_putih.png"),
	"buto_hitam": preload("res://assets/ui/portrait_buto_hitam.png"),
}
const NAME_COLORS := {
	"eyang": Color(1.0, 0.86, 0.5),
	"warga": Color(0.75, 0.85, 1.0),
	"roro_ayu": Color(1.0, 0.7, 0.8),
	"narator": Color(0.7, 0.72, 0.82),
}

var _lines: PackedStringArray = []
var _index: int = 0
var _typing: bool = false
var _type_tween: Tween
var _portrait: TextureRect
var _portrait_frame: Panel
var _name: Label
var _text: RichTextLabel
var _hint: Label
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dimmer(0.35))

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"GoldPanel"
	_panel.position = Vector2(14, 238)
	_panel.size = Vector2(612, 112)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := UIKit.hbox(8)
	_panel.add_child(row)

	_portrait_frame = Panel.new()
	_portrait_frame.custom_minimum_size = Vector2(84, 84)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = TextureRect.new()
	_portrait.position = Vector2(2, 2)
	_portrait.size = Vector2(80, 80)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	row.add_child(_portrait_frame)

	var col := UIKit.vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = UIKit.label("", &"HeaderLabel")
	col.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)

	_hint = UIKit.small_label(tr("HINT_CLICK_CONTINUE"), UIKit.COLOR_DIM)
	_hint.position = Vector2(520, 337)
	_hint.size = Vector2(100, 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_hint)

	var skip := UIKit.button(tr("BTN_SKIP"))
	skip.position = Vector2(566, 214)
	skip.size = Vector2(60, 20)
	skip.pressed.connect(_finish)
	add_child(skip)


## Memutar daftar baris "pembicara|KUNCI" lalu menunggu sampai selesai.
func play(lines: PackedStringArray) -> void:
	_lines = lines
	_index = 0
	if _lines.is_empty():
		_finish.call_deferred()
	else:
		_show_line()
	await finished


func _show_line() -> void:
	var parts := _lines[_index].split("|")
	var speaker := parts[0] if parts.size() > 1 else "narator"
	var key := parts[1] if parts.size() > 1 else parts[0]
	var has_portrait := PORTRAITS.has(speaker)
	_portrait_frame.visible = has_portrait
	_portrait.texture = PORTRAITS.get(speaker)
	_portrait.flip_h = speaker.begins_with("buto")
	_name.text = tr("SPEAKER_" + speaker.to_upper())
	_name.add_theme_color_override("font_color", NAME_COLORS.get(speaker, Color(0.95, 0.55, 0.5)))
	var body := tr(key)
	if speaker == "narator":
		body = "[color=#c9cbe0][i]%s[/i][/color]" % body
	_text.text = body
	_text.visible_ratio = 0.0
	_typing = true
	if _type_tween != null:
		_type_tween.kill()
	var length := maxf(float(tr(key).length()), 1.0)
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, length / CHARS_PER_SECOND)
	_type_tween.tween_callback(func() -> void: _typing = false)
	AudioManager.play_sfx("click", 0.1, -8.0)


func _advance() -> void:
	if _typing:
		_type_tween.kill()
		_text.visible_ratio = 1.0
		_typing = false
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	if _type_tween != null:
		_type_tween.kill()
	finished.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ESCAPE:
			_finish()
			get_viewport().set_input_as_handled()
