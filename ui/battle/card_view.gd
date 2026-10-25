class_name CardView
extends Control
## Satu kartu di tangan, digambar dari bingkai desain asli (76x106):
## lencana bintang di kiri atas, nama di bar judul, ikon di jendela gambar,
## dan angka efek di bawahnya. HandView yang mengatur posisi dan input seret.

signal pressed(view: CardView)
signal hover_changed(view: CardView, hovering: bool)

const CARD_SIZE := Vector2(76, 106)
const ART_RECT := Rect2(14, 34, 48, 36)

const ACCENTS := {
	"serang": Color(1.0, 0.56, 0.5),
	"fokus": Color(0.55, 0.82, 1.0),
	"taktik": Color(0.58, 0.95, 0.6),
	"crimson": Color(1.0, 0.55, 0.92),
	"piercing": Color(1.0, 0.75, 0.42),
	"flow": Color(0.5, 1.0, 0.92),
}

const MINI_ATTACK := preload("res://assets/ui/mini_attack.png")
const MINI_BLOCK := preload("res://assets/ui/mini_block.png")
const MINI_MOXIE := preload("res://assets/ui/mini_moxie.png")
const MINI_AP := preload("res://assets/ui/mini_ap.png")
const PADLOCK := preload("res://assets/ui/padlock.png")

var card: CardInstance
## Moxie yang didapat kalau kartu ini dimainkan (diisi HandView dari PlayerState).
var moxie_gain: float = 0.0
## Disorot emas kalau bisa digabung dengan tetangganya.
var mergeable: bool = false:
	set(value):
		mergeable = value
		queue_redraw()
var hovering: bool = false
## Posisi tujuan di dalam tangan (HandView menggerakkan kartu ke sini).
var slot_position := Vector2.ZERO

var _frame: TextureRect
var _icon: TextureRect
var _title: Label
var _rank: Label
var _stats: GridContainer
var _lock_layer: Control
var _lock_label: Label
var _accent := Color.WHITE
var _glow_phase: float = 0.0


## Kartu pajangan untuk layar Deck dan Pustaka (di luar battle).
## Kalau `components` diisi dua CardData, kartunya dibuat sebagai hybrid dari
## bahan itu supaya angka Moxie-nya sama persis dengan di battle.
static func preview(data: CardData, components: Array[CardData] = []) -> CardView:
	var inst: CardInstance
	if components.size() == 2:
		inst = CardInstance.create_hybrid(data, CardInstance.new(components[0]), CardInstance.new(components[1]))
	else:
		inst = CardInstance.new(data)
	var rules := PlayerState.new()
	var moxie := rules.get_moxie_gain_from_card(inst)
	rules.free()
	var view := CardView.new()
	view.setup(inst, moxie)
	view.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return view


func setup(card_instance: CardInstance, moxie: float) -> void:
	card = card_instance
	moxie_gain = moxie
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build()
	refresh()
	mouse_entered.connect(func() -> void:
		hovering = true
		hover_changed.emit(self, true))
	mouse_exited.connect(func() -> void:
		hovering = false
		hover_changed.emit(self, false))


func _build() -> void:
	_frame = TextureRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	_icon = TextureRect.new()
	_icon.position = ART_RECT.position
	_icon.size = ART_RECT.size
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_title = UIKit.small_label("")
	_title.position = Vector2(10, 10)
	_title.size = Vector2(56, 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	add_child(_title)

	_rank = UIKit.small_label("", Color(1, 1, 1))
	_rank.position = Vector2(1, 1)
	_rank.size = Vector2(10, 10)
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_rank)

	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.position = Vector2(9, 72)
	_stats.size = Vector2(58, 24)
	_stats.add_theme_constant_override("h_separation", 2)
	_stats.add_theme_constant_override("v_separation", 0)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats)

	_lock_layer = Control.new()
	_lock_layer.size = CARD_SIZE
	_lock_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.1, 0.68)
	shade.position = Vector2(3, 3)
	shade.size = CARD_SIZE - Vector2(6, 6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_layer.add_child(shade)
	var pad := UIKit.icon(PADLOCK)
	pad.position = Vector2(28, 36)
	pad.size = Vector2(20, 24)
	_lock_layer.add_child(pad)
	_lock_label = UIKit.label("", &"", UIKit.COLOR_GOLD)
	_lock_label.position = Vector2(0, 62)
	_lock_label.size = Vector2(CARD_SIZE.x, 12)
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_layer.add_child(_lock_label)
	add_child(_lock_layer)


func refresh() -> void:
	var data := card.data
	var family := data.get_family()
	_accent = ACCENTS.get(family, Color.WHITE)
	_frame.texture = data.frame
	_icon.texture = data.icon
	# Kunci terjemahan langsung, supaya judul ikut berganti saat bahasa diubah.
	_title.text = data.display_name + "_SHORT"
	_title.add_theme_color_override("font_color", _accent)
	_rank.text = str(data.rank)

	for child: Node in _stats.get_children():
		child.queue_free()
	if data.base_power > 0:
		_add_stat(MINI_ATTACK, str(data.base_power), Color(1, 0.9, 0.85))
	if data.shield > 0:
		_add_stat(MINI_BLOCK, str(data.shield), UIKit.COLOR_GREEN)
	if moxie_gain > 0.0:
		_add_stat(MINI_MOXIE, "+%d" % roundi(moxie_gain), UIKit.COLOR_BLUE)
	if data.ap_gain > 0:
		_add_stat(MINI_AP, "+%d" % data.ap_gain, UIKit.COLOR_GOLD)

	_lock_layer.visible = card.is_locked()
	_lock_label.text = str(card.lock_turns) if card.is_locked() else ""
	queue_redraw()


func _add_stat(texture: Texture2D, text: String, color: Color) -> void:
	var row := UIKit.hbox(1)
	row.add_child(UIKit.icon(texture))
	row.add_child(UIKit.small_label(text, color))
	_stats.add_child(row)


func _process(delta: float) -> void:
	if mergeable:
		_glow_phase += delta * 4.0
		queue_redraw()


func _draw() -> void:
	# Lencana bintang di kiri atas, menimpa lencana bawaan bingkai.
	draw_circle(Vector2(6, 6), 5.5, Color(0.05, 0.05, 0.1))
	draw_circle(Vector2(6, 6), 4.5, _accent.darkened(0.35))
	# Bintang kecil sesuai rank di bawah angka efek.
	var rank := card.data.rank if card != null else 1
	var start_x := CARD_SIZE.x * 0.5 - (rank * 7 - 2) * 0.5
	for i: int in rank:
		_draw_star(Vector2(start_x + i * 7 + 2.5, 100), Color(1.0, 0.84, 0.35))
	if mergeable:
		var a := 0.55 + 0.45 * sin(_glow_phase)
		draw_rect(Rect2(Vector2(0.5, 0.5), CARD_SIZE - Vector2(1, 1)), Color(1.0, 0.86, 0.4, a), false, 1.0)
		draw_rect(Rect2(Vector2(-0.5, -0.5), CARD_SIZE + Vector2(1, 1)), Color(1.0, 0.86, 0.4, a * 0.5), false, 1.0)


func _draw_star(c: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var r := 3.0 if i % 2 == 0 else 1.3
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, color)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		pressed.emit(self)
		accept_event()


## Teks keterangan lengkap untuk tooltip.
func get_tooltip_bbcode() -> String:
	var data := card.data
	var lines: Array[String] = []
	lines.append("[b][color=#%s]%s[/color][/b]  [color=#ffd36e]%s[/color]" % [_accent.to_html(false), tr(data.display_name), tr("CARD_RANK") % data.rank])
	if data.base_power > 0:
		lines.append(tr("EFFECT_DAMAGE") % data.base_power)
	if data.shield > 0:
		lines.append(tr("EFFECT_BLOCK") % data.shield)
	if moxie_gain > 0.0:
		lines.append(tr("EFFECT_MOXIE") % roundi(moxie_gain))
	if data.ap_gain > 0:
		lines.append(tr("EFFECT_AP") % data.ap_gain)
	lines.append("[color=#9aa0b8]%s[/color]" % tr(data.display_name + "_DESC"))
	if card.is_locked():
		lines.append("[color=#ffd36e]%s[/color]" % (tr("CARD_LOCKED_TIP") % card.lock_turns))
	elif data.is_base_type():
		lines.append("[color=#9aa0b8]%s[/color]" % tr("CARD_MERGE_HINT"))
	return "\n".join(lines)
