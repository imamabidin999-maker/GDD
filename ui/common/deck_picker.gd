class_name DeckPicker
extends Control
## Memilih satu kartu dari Jurus (deck 15 kartu).
##
##   Mode.REPLACE : kartu baru (incoming_spec) menggantikan kartu pilihan.
##                  Kartu barunya tampil di slot ke-16 grid.
##   Mode.UPGRADE : kartu pilihan naik satu bintang. Kartu bintang 3 redup.
##
## Panel ini hanya memilih. Yang mengubah deck adalah pemanggilnya, setelah
## menerima signal picked(index). index -1 berarti pemain menekan Lewati.

signal picked(index: int)

enum Mode { REPLACE, UPGRADE }

## Urutan tampil kartu: tiga jurus dasar lalu kartu Tabuh.
const ORDER: Array[String] = ["serang", "fokus", "taktik", "bedug", "kentongan", "korek", "gong", "kenong"]

var mode: Mode = Mode.REPLACE
## Deck yang ditampilkan (spec "tipe:bintang"). Diisi sebelum masuk tree.
var deck: Array[String] = []
## Kartu baru untuk Mode.REPLACE, misalnya "bedug:1".
var incoming_spec: String = ""
## Kalau diisi (misalnya "gong"), kartu barunya kartu Tabuh yang bintangnya
## mengikuti kartu yang dipilih (lihat Blessings.tabuh_spec_for).
var tabuh_family: String = ""

var _selected: int = -1
var _views := {} # index deck -> CardView
var _confirm: Button
var _tooltip: GameTooltip
var _incoming_view: CardView


## Urutan kartu untuk tampilan: per tipe (lihat ORDER), lalu bintang.
static func compare_specs(a: String, b: String) -> bool:
	var fa := a.get_slice(":", 0)
	var fb := b.get_slice(":", 0)
	if fa != fb:
		return ORDER.find(fa) < ORDER.find(fb)
	return int(a.get_slice(":", 1)) < int(b.get_slice(":", 1))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.75))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	var col := UIKit.vbox(4)
	panel.add_child(col)

	var replace := mode == Mode.REPLACE
	var title := UIKit.label(tr("PICKER_REPLACE_TITLE" if replace else "PICKER_UPGRADE_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UIKit.small_label(tr("PICKER_REPLACE_HINT" if replace else "PICKER_UPGRADE_HINT"), UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	var order: Array[int] = []
	for i: int in deck.size():
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool: return compare_specs(deck[x], deck[y]))
	for i: int in order:
		grid.add_child(_card_slot(i))
	if replace and incoming_spec != "":
		grid.add_child(_incoming_slot())

	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var skip := UIKit.button(tr("PICKER_SKIP"), 110, true)
	skip.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_finish(-1))
	row.add_child(skip)
	_confirm = UIKit.button(tr("PICKER_CONFIRM_REPLACE" if replace else "PICKER_CONFIRM_UPGRADE"), 110, true)
	_confirm.disabled = true
	_confirm.pressed.connect(func() -> void:
		AudioManager.play_sfx("gong")
		_finish(_selected))
	row.add_child(_confirm)
	col.add_child(row)

	_tooltip = GameTooltip.new()
	add_child(_tooltip)


func _card_slot(index: int) -> Control:
	var data := CardDB.card_from_spec(deck[index])
	var view := CardView.preview(data)
	var selectable := mode == Mode.REPLACE or data.rank < CardData.MAX_RANK
	if selectable:
		view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		view.pressed.connect(func(_v: CardView) -> void: _select(index))
	else:
		view.modulate = Color(0.45, 0.45, 0.52)
	_hook_tooltip(view)
	_views[index] = view
	return view


func _incoming_slot() -> Control:
	var data := CardDB.card_from_spec(incoming_spec)
	var view := CardView.preview(data)
	view.mergeable = true
	_incoming_view = view
	_hook_tooltip(view)
	var tag := UIKit.small_label(tr("PICKER_NEW_CARD"), UIKit.COLOR_GOLD)
	tag.position = Vector2(0, 22)
	tag.size = Vector2(CardView.CARD_SIZE.x, 8)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	tag.add_theme_constant_override("outline_size", 2)
	view.add_child(tag)
	return view


func _hook_tooltip(view: CardView) -> void:
	view.hover_changed.connect(func(v: CardView, on: bool) -> void:
		if on:
			var at := v.global_position + Vector2(v.size.x + 4, 0)
			if at.x > 470:
				at.x = v.global_position.x - 170
			_tooltip.show_text(v.get_tooltip_bbcode(), at)
		else:
			_tooltip.hide_tip())


func _select(index: int) -> void:
	AudioManager.play_sfx("card", 0.05)
	if _selected >= 0 and _views.has(_selected):
		(_views[_selected] as CardView).mergeable = false
	_selected = index
	(_views[index] as CardView).mergeable = true
	_confirm.disabled = false
	if tabuh_family != "" and _incoming_view != null:
		var data := CardDB.card_from_spec(Blessings.tabuh_spec_for(tabuh_family, deck[index]))
		_incoming_view.card = CardInstance.new(data)
		_incoming_view.moxie_gain = data.moxie_gain
		_incoming_view.refresh()


func _finish(index: int) -> void:
	_tooltip.hide_tip()
	picked.emit(index)
	queue_free()
