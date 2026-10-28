class_name CrossroadsPanel
extends Control
## Persimpangan jalan: dua jalan, masing-masing menuju kejadian yang berbeda.
## Setiap jalan diberi nama tempat dan petunjuk (bunyi, bau, atau suara) dari
## kejadian di ujungnya. Kejadian di jalan yang tidak dipilih belum dialami,
## jadi masih bisa muncul di persimpangan berikutnya.
##
## Pemakaian:
##   var panel := CrossroadsPanel.new()
##   panel.options = ["pande", "sesajen"]
##   add_child(panel)
##   var id: String = await panel.chosen

signal chosen(event_id: String)

const SIGNPOST := preload("res://assets/ui/crossroads.png")

## Dua kejadian (lihat JourneyEvents). Diisi sebelum masuk tree.
var options: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	var col := UIKit.vbox(6)
	panel.add_child(col)

	var header := UIKit.small_label(tr("CROSSROADS_HEADER"), UIKit.COLOR_DIM)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(header)
	var title_row := UIKit.hbox(6)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_child(UIKit.icon(SIGNPOST))
	var title := UIKit.label(tr("CROSSROADS_TITLE"), &"HeaderLabel")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title)
	col.add_child(title_row)

	var paths := UIKit.hbox(10)
	paths.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(paths)
	for id: String in options:
		paths.add_child(_path_button(id))

	var note := UIKit.small_label(tr("CROSSROADS_NOTE"), UIKit.COLOR_DIM)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	AudioManager.play_sfx("kentongan", 0.05)


func _path_button(id: String) -> Button:
	var large := UIKit.large_text()
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 160) if large else Vector2(196, 116)
	b.focus_mode = Control.FOCUS_NONE
	var inner := UIKit.vbox(4)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6
	inner.offset_right = -6
	inner.offset_top = 6
	inner.offset_bottom = -6
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	var pic := TextureRect.new()
	pic.texture = load(str(JourneyEvents.get_event(id).get("icon", ""))) as Texture2D
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(0, 40)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(pic)
	var name_label := UIKit.label(tr("EV_%s_PATH" % id.to_upper()), &"BigLabel", UIKit.COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_label)
	var hint := UIKit.label(tr("EV_%s_HINT" % id.to_upper()), UIKit.small_text_variation(), UIKit.COLOR_TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(218 if large else 184, 0)
	inner.add_child(hint)
	b.add_child(inner)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		chosen.emit(id)
		queue_free())
	return b
