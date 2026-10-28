class_name GlossaryText
extends RefCounted
## Istilah Jawa di teks cerita diberi warna. Arahkan kursor ke istilah itu
## untuk membaca artinya, sama dengan isi halaman Istilah Jawa di Pustaka.
## Daftar istilah dan bentuk katanya ada di GlossaryData.
##
## Pemakaian:
##   GlossaryText.attach(label)            # sekali, untuk RichTextLabel-nya
##   label.text = GlossaryText.mark(teks)  # setiap kali teksnya diganti

const COLOR := "f4bf5c"
const META_PREFIX := "gloss:"

static var _term_regex: RegEx
static var _tag_regex: RegEx
static var _names := {}
static var _tip: GameTooltip


## Menandai kemunculan pertama setiap istilah di `text` (BBCode boleh).
## `used` mencatat istilah yang sudah ditandai sebelumnya, jadi satu
## percakapan tidak penuh tanda yang sama berulang-ulang.
static func mark(text: String, used: Dictionary = {}) -> String:
	if not GameState.glossary_marks or text == "":
		return text
	_prepare()
	var out := ""
	var pos := 0
	var in_url := 0
	for tag: RegExMatch in _tag_regex.search_all(text):
		var plain := text.substr(pos, tag.get_start() - pos)
		out += plain if in_url > 0 else _mark_plain(plain, used)
		var t := tag.get_string()
		if t.begins_with("[url"):
			in_url += 1
		elif t == "[/url]":
			in_url = maxi(in_url - 1, 0)
		out += t
		pos = tag.get_end()
	var rest := text.substr(pos)
	out += rest if in_url > 0 else _mark_plain(rest, used)
	return out


## Menyiapkan RichTextLabel supaya istilah yang ditandai menampilkan artinya
## saat disorot. Klik tetap diteruskan ke induknya (misalnya kotak dialog).
static func attach(label: RichTextLabel) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.meta_hover_started.connect(func(meta: Variant) -> void: _show(label, str(meta)))
	label.meta_hover_ended.connect(func(_meta: Variant) -> void: hide_tip())
	label.visibility_changed.connect(hide_tip)
	label.tree_exiting.connect(hide_tip)


## Isi keterangan untuk satu tanda: nama istilah lalu artinya.
static func tooltip_text(meta: String) -> String:
	if not meta.begins_with(META_PREFIX):
		return ""
	_prepare()
	var blocks: Array[String] = []
	for key: String in meta.substr(META_PREFIX.length()).split("|", false):
		blocks.append("[color=#%s]%s[/color]\n%s" % [UIKit.COLOR_GOLD.to_html(false), _names.get(key, ""), TranslationServer.translate(key)])
	return "\n\n".join(blocks)


static func hide_tip() -> void:
	if _tip != null and is_instance_valid(_tip):
		_tip.hide_tip()


static func _mark_plain(plain: String, used: Dictionary) -> String:
	if plain == "":
		return plain
	var out := ""
	var pos := 0
	for m: RegExMatch in _term_regex.search_all(plain):
		var keys: Array = GlossaryData.FORMS.get(m.get_string().to_lower(), [])
		var fresh := false
		for key: String in keys:
			if not used.has(key):
				fresh = true
		if not fresh:
			continue
		for key: String in keys:
			used[key] = true
		out += plain.substr(pos, m.get_start() - pos)
		out += "[color=#%s][url=%s%s]%s[/url][/color]" % [COLOR, META_PREFIX, "|".join(keys), m.get_string()]
		pos = m.get_end()
	return out + plain.substr(pos)


static func _prepare() -> void:
	if _term_regex != null:
		return
	var forms: Array = GlossaryData.FORMS.keys()
	# Bentuk terpanjang dicoba dulu: "tangkis balik" sebelum "tangkis".
	forms.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	_term_regex = RegEx.create_from_string("(?i)(?<![A-Za-z0-9])(?:%s)(?![A-Za-z0-9])" % "|".join(forms))
	_tag_regex = RegEx.create_from_string("\\[[^\\[\\]]*\\]")
	for entry: Dictionary in GlossaryData.TERMS:
		_names[entry["key"]] = entry["term"]


static func _show(label: RichTextLabel, meta: String) -> void:
	var text := tooltip_text(meta)
	if text == "" or not label.is_visible_in_tree():
		return
	if _tip == null or not is_instance_valid(_tip):
		# Lapisan sendiri di atas semua layar, supaya keterangan tidak tertutup
		# kotak dialog atau HUD battle.
		var layer := CanvasLayer.new()
		layer.layer = 90
		label.get_tree().root.add_child(layer)
		_tip = GameTooltip.new()
		layer.add_child(_tip)
	_tip.show_text(text, label.get_viewport().get_mouse_position())
