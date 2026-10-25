class_name HintToast
extends PanelContainer
## Petunjuk singkat di atas layar saat sebuah mekanik pertama kali muncul
## (Lara, Sirep, Ngamuk, dan lainnya). Tidak menghentikan permainan: hilang
## sendiri setelah beberapa detik atau saat diklik. Petunjuk yang datang
## bersamaan diantre.

const SHOW_SECONDS := 9.0
const WIDTH := 330.0

var _queue: Array[String] = []
var _title: Label
var _text: Label
var _timer: SceneTreeTimer
var _showing: bool = false


func _ready() -> void:
	theme_type_variation = &"GoldPanel"
	custom_minimum_size = Vector2(WIDTH, 0)
	size = Vector2(WIDTH, 0)
	position = Vector2((640.0 - WIDTH) * 0.5, 24)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false
	var col := UIKit.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := UIKit.hbox(4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_title = UIKit.label("", &"", UIKit.COLOR_GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	head.add_child(UIKit.small_label(tr("HINT_CLOSE"), UIKit.COLOR_DIM))
	_text = UIKit.label("", &"", UIKit.COLOR_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 12, 0)
	col.add_child(_text)


## Menampilkan petunjuk `id` kalau belum pernah tampil (lihat GameState.take_hint).
func offer(id: String) -> void:
	if _queue.has(id) or not GameState.take_hint(id):
		return
	_queue.append(id)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	var id: String = _queue.pop_front()
	_title.text = tr("HINT_%s_TITLE" % id.to_upper())
	_text.text = tr("HINT_%s" % id.to_upper())
	size = Vector2(WIDTH, 0)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	AudioManager.play_sfx("kentongan", 0.05, -6.0)
	var timer := get_tree().create_timer(SHOW_SECONDS)
	_timer = timer
	timer.timeout.connect(func() -> void:
		if _timer == timer:
			_show_next())


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_timer = null
		_show_next()
		accept_event()
