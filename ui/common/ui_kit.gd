class_name UIKit
extends RefCounted
## Fungsi kecil untuk membuat elemen UI dari kode dengan gaya yang seragam.

const COLOR_TEXT := Color(0.925, 0.902, 0.835)
const COLOR_GOLD := Color(1.0, 0.862, 0.502)
const COLOR_DIM := Color(0.6, 0.6, 0.68)
const COLOR_RED := Color(0.94, 0.36, 0.33)
const COLOR_BLUE := Color(0.45, 0.72, 1.0)
const COLOR_GREEN := Color(0.5, 0.86, 0.5)
const COLOR_PURPLE := Color(0.8, 0.5, 0.95)

const FONT_SMALL := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/PixelifySans-Bold.ttf")


static func label(text: String, variation: StringName = &"", color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func small_label(text: String, color: Color = COLOR_TEXT) -> Label:
	return label(text, &"SmallLabel", color)


static func button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_width > 0.0:
		b.custom_minimum_size.x = min_width
	return b


static func icon(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func hbox(separation: int = 2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(separation: int = 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Panel yang menutupi seluruh layar dengan warna gelap transparan.
static func dimmer(alpha: float = 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.05, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


## Membuat anak Control berada tepat di tengah induknya.
static func center(control: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(control)
	return c
