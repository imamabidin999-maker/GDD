extends Control
## Pustaka: ensiklopedia kecil tentang kesenian Dongkrek, Eyang Palang, para
## Buto (terbuka setelah pernah dilawan), cara bermain, daftar kartu, istilah
## Jawa, dan tanda mana yang asli dari kisah Dongkrek dan mana yang rekaan.

const BG := preload("res://assets/backgrounds/menu.png")
const HERO := preload("res://assets/sprites/hero/eyang_palang_idle.png")
const RORO_AYU := preload("res://assets/sprites/roro/roro_ayu_idle.png")
const RORO_PEROT := preload("res://assets/sprites/roro/roro_perot_idle.png")
const BUTO_KEYS: Array[String] = ["kuning", "hijau", "merah", "putih", "hitam"]
## Istilah yang menjadi pokok halaman itu sendiri, jadi tidak ditandai lagi di sana.
const PAGE_TERMS := {
	"dongkrek": ["GLOSS_DONGKREK"],
	"eyang": ["GLOSS_EYANG", "GLOSS_PALANG"],
	"roro_ayu": ["GLOSS_RORO_AYU"],
	"roro_perot": ["GLOSS_RORO_PEROT"],
}
## Warna tanda asal-usul: kisah Dongkrek, budaya Jawa, rekaan game.
const ORIGIN_COLORS := {"asli": UIKit.COLOR_GOLD, "budaya": UIKit.COLOR_BLUE, "rekaan": UIKit.COLOR_PURPLE}

var _content: VBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _tooltip: GameTooltip
var _group := ButtonGroup.new()
var _first_specs := {}
var _current: String = "dongkrek"
# Istilah Jawa yang sudah ditandai di halaman ini (lihat GlossaryText).
var _glossary_used := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.position = Vector2(-8, -8)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(UIKit.dimmer(0.55))
	_collect_specs()
	_build()
	_tooltip = GameTooltip.new()
	add_child(_tooltip)
	AudioManager.play_music("menu")


## Statistik Buto diambil dari stage pertama tempat ia muncul.
func _collect_specs() -> void:
	var catalog := StageCatalog.load_default()
	for n: int in range(1, GameState.STAGE_COUNT + 1):
		var stage := catalog.get_stage(n)
		if stage == null:
			continue
		for spec: EnemySpec in stage.enemies:
			var key := StageNode.get_buto_key(spec)
			if not _first_specs.has(key):
				_first_specs[key] = spec


func _build() -> void:
	var bar := PanelContainer.new()
	bar.size = Vector2(640, 22)
	bar.custom_minimum_size = Vector2(640, 22)
	add_child(bar)
	var row := UIKit.hbox(6)
	bar.add_child(row)
	row.add_child(UIKit.label(tr("PUSTAKA_TITLE"), &"HeaderLabel"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var back := UIKit.button(tr("BTN_BACK"), 80)
	back.custom_minimum_size.y = 16
	back.pressed.connect(_go_back)
	row.add_child(back)

	var list_panel := PanelContainer.new()
	list_panel.position = Vector2(8, 30)
	list_panel.size = Vector2(142, 322)
	add_child(list_panel)
	_list = UIKit.vbox(3)
	list_panel.add_child(_list)
	_add_entry("dongkrek", tr("PUSTAKA_DONGKREK"))
	_add_entry("eyang", tr("PUSTAKA_EYANG"))
	_add_entry("roro_ayu", tr("PUSTAKA_RORO_AYU"))
	_add_entry("roro_perot", tr("PUSTAKA_RORO_PEROT") if _met_perot() else "? ? ?")
	for key: String in BUTO_KEYS:
		var seen := GameState.seen_buto.has(key)
		_add_entry(key, tr("BUTO_" + key.to_upper()) if seen else "? ? ?")
	_add_entry("murka", tr("PUSTAKA_MURKA") if GameState.seen_buto.has("murka") else "? ? ?")
	_add_entry("bala", tr("PUSTAKA_BALA") if GameState.seen_buto.has("bala") else "? ? ?")
	_add_entry("howto", tr("PUSTAKA_HOWTO"))
	_add_entry("cards", tr("PUSTAKA_CARDS"))
	_add_entry("istilah", tr("PUSTAKA_GLOSSARY"))
	_add_entry("asli", tr("PUSTAKA_ORIGINS"))

	var content_panel := PanelContainer.new()
	content_panel.theme_type_variation = &"GoldPanel"
	content_panel.position = Vector2(158, 30)
	content_panel.size = Vector2(474, 322)
	add_child(content_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_panel.add_child(_scroll)
	_content = UIKit.vbox(6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_show(_current)


func _add_entry(key: String, text: String) -> void:
	var b := UIKit.button(text)
	b.toggle_mode = true
	b.button_group = _group
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.button_pressed = key == _current
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_show(key))
	_list.add_child(b)


func _show(key: String) -> void:
	_current = key
	_tooltip_hide()
	_glossary_used.clear()
	for term: String in PAGE_TERMS.get(key, []):
		_glossary_used[term] = true
	for child: Node in _content.get_children():
		child.queue_free()
	_scroll.scroll_vertical = 0
	match key:
		"dongkrek":
			_heading(tr("PUSTAKA_DONGKREK"))
			var masks := UIKit.hbox(10)
			masks.alignment = BoxContainer.ALIGNMENT_CENTER
			for buto: String in BUTO_KEYS:
				masks.add_child(UIKit.icon(load("res://assets/ui/mask_%s.png" % buto) as Texture2D))
			_content.add_child(masks)
			_content.add_child(_origin_tag(["asli"], tr("ORIGIN_TAG_DONGKREK")))
			_paragraph(tr("PUSTAKA_DONGKREK_TEXT"))
		"eyang":
			_figure(HERO, tr("PUSTAKA_EYANG"), [], tr("PUSTAKA_EYANG_TEXT"), false,
				_origin_tag(["asli"], tr("ORIGIN_TAG_EYANG")))
		"roro_ayu":
			_figure(RORO_AYU, tr("PUSTAKA_RORO_AYU"), [], tr("PUSTAKA_RORO_AYU_TEXT"), false,
				_origin_tag(["asli", "rekaan"], tr("ORIGIN_TAG_RORO")))
		"roro_perot":
			if _met_perot():
				_figure(RORO_PEROT, tr("PUSTAKA_RORO_PEROT"), [], tr("PUSTAKA_RORO_PEROT_TEXT"), false,
					_origin_tag(["asli", "rekaan"], tr("ORIGIN_TAG_RORO")))
			else:
				_figure(RORO_PEROT, "? ? ?", [], tr("PUSTAKA_PEROT_LOCKED"), true)
		"howto":
			_heading(tr("PUSTAKA_HOWTO"))
			_paragraph(tr("PUSTAKA_HOWTO_TEXT"))
		"cards":
			_show_cards()
		"istilah":
			_show_glossary()
		"asli":
			_show_origins()
		"murka":
			_show_murka()
		"bala":
			_show_bala()
		_:
			_show_buto(key)


## Roro Perot baru terbuka setelah ditemui di salah satu kejadiannya, atau
## setelah tamat (ia ikut arak-arakan penutup).
func _met_perot() -> bool:
	if GameState.game_completed:
		return true
	for id: String in JourneyEvents.PEROT_EVENTS:
		if GameState.seen_events.has(id):
			return true
	return false


func _show_buto(key: String) -> void:
	var sprite := load("res://assets/sprites/buto/buto_%s_idle.png" % key) as Texture2D
	if not GameState.seen_buto.has(key):
		_figure(sprite, "? ? ?", [], tr("PUSTAKA_LOCKED"), true)
		return
	var facts: Array[String] = []
	var spec := _first_specs.get(key) as EnemySpec
	if spec != null:
		facts.append(tr("PUSTAKA_STATS") % [spec.max_hp, spec.attack_power])
	facts.append(tr("PUSTAKA_SKILL") % tr("SKILL_" + key.to_upper()))
	_figure(sprite, tr("BUTO_" + key.to_upper()), facts, tr("PUSTAKA_BUTO_%s_TEXT" % key.to_upper()), false,
		_origin_tag(["asli", "rekaan"], tr("ORIGIN_TAG_BUTO")))


func _show_murka() -> void:
	var sprite := load("res://assets/sprites/buto/buto_merah_idle.png") as Texture2D
	if not GameState.seen_buto.has("murka"):
		_figure(sprite, "? ? ?", [], tr("PUSTAKA_LOCKED"), true)
		return
	_figure(sprite, tr("PUSTAKA_MURKA"), [], tr("PUSTAKA_MURKA_TEXT"), false, _origin_tag(["rekaan"], tr("ORIGIN_TAG_REKAAN")))
	# Aura yang sama dengan di medan tempur, di belakang gambar Buto.
	var pic := (_content.get_child(-1) as Control).get_child(0) as TextureRect
	var aura := TextureRect.new()
	aura.texture = sprite
	aura.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aura.show_behind_parent = true
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = UnitView.MURKA_AURA
	aura.material = mat
	aura.modulate = Color(0.95, 0.15, 0.5, 0.55)
	pic.add_child(aura)
	var t := aura.create_tween().set_loops()
	t.tween_property(aura, "modulate:a", 0.9, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(aura, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)


func _show_bala() -> void:
	var sprite := load("res://assets/sprites/buto/buto_hijau_idle.png") as Texture2D
	if not GameState.seen_buto.has("bala"):
		_figure(sprite, "? ? ?", [], tr("PUSTAKA_LOCKED"), true)
		return
	# Angka Bala diambil dari nilai bawaan Buto Hitam supaya selalu sama dengan battle.
	var hitam := EnemyButo.new()
	var stats: Array[String] = [tr("PUSTAKA_STATS") % [hitam.bala_hp, hitam.bala_attack]]
	hitam.free()
	_figure(sprite, tr("PUSTAKA_BALA"), stats, tr("PUSTAKA_BALA_TEXT"), false, _origin_tag(["rekaan"], tr("ORIGIN_TAG_REKAAN")))
	# Wujud bayangan yang sama dengan di medan tempur.
	var pic := (_content.get_child(-1) as Control).get_child(0) as TextureRect
	pic.modulate = Color(0.42, 0.32, 0.6, 0.8)


func _show_cards() -> void:
	_heading(tr("PUSTAKA_CARDS"))
	_content.add_child(UIKit.small_label(tr("PUSTAKA_CARDS_HINT"), UIKit.COLOR_DIM))
	# Satu baris per tipe: tiga kartu (bintang 1-3) lalu keterangannya.
	for family: String in ["serang", "fokus", "taktik"]:
		_content.add_child(_family_row(family))

	_heading(tr("PUSTAKA_TABUH"))
	_content.add_child(UIKit.small_label(tr("PUSTAKA_TABUH_HINT"), UIKit.COLOR_DIM))
	for family: String in Blessings.TABUH_FAMILIES:
		_content.add_child(_family_row(family))

	_heading(tr("PUSTAKA_RECIPES"))
	for recipe: MergeRecipe in CardDB.get_recipes():
		var a := _base_card(recipe.type_a)
		var b := _base_card(recipe.type_b)
		var result := recipe.get_result_for_rank(1)
		if a == null or b == null or result == null:
			continue
		var line := UIKit.hbox(6)
		line.add_child(_card_with_tooltip(a, []))
		line.add_child(_symbol("+"))
		line.add_child(_card_with_tooltip(b, []))
		line.add_child(_symbol("="))
		line.add_child(_card_with_tooltip(result, [a, b]))
		var text := UIKit.label(tr(result.display_name + "_DESC"), &"", UIKit.COLOR_DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(110, 0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(text)
		_content.add_child(line)


## Kamus istilah Jawa, dikelompokkan; tombol di atas melompat ke kelompoknya.
func _show_glossary() -> void:
	_heading(tr("PUSTAKA_GLOSSARY"))
	_content.add_child(_note(tr("PUSTAKA_GLOSSARY_INTRO")))
	var jumps := HFlowContainer.new()
	jumps.add_theme_constant_override("h_separation", 4)
	jumps.add_theme_constant_override("v_separation", 4)
	_content.add_child(jumps)
	var gold := UIKit.COLOR_GOLD.to_html(false)
	for cat: String in GlossaryData.CATEGORIES:
		var heading := UIKit.label(tr("GLOSS_CAT_" + cat.to_upper()), &"HeaderLabel")
		var jump := UIKit.button(tr("GLOSS_CAT_" + cat.to_upper()))
		jump.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			_scroll.scroll_vertical = int(heading.position.y))
		jumps.add_child(jump)
		_content.add_child(heading)
		var lines: Array[String] = []
		for entry: Dictionary in GlossaryData.TERMS:
			if entry["cat"] == cat:
				lines.append("[color=#%s]%s[/color]   %s" % [gold, entry["term"], tr(entry["key"])])
		# Halaman ini sendiri kamusnya, jadi istilahnya tidak ditandai lagi.
		_paragraph("\n\n".join(lines), false)


## Unsur-unsur game dan asalnya: kisah Dongkrek, budaya Jawa, atau rekaan.
func _show_origins() -> void:
	_heading(tr("PUSTAKA_ORIGINS"))
	_content.add_child(_note(tr("PUSTAKA_ORIGINS_INTRO")))
	for kind: String in GlossaryData.ORIGIN_KINDS:
		var head := _origin_tag([kind], tr("ORIGIN_KIND_" + kind.to_upper()))
		var label := head.get_child(-1) as Label
		label.theme_type_variation = &"HeaderLabel"
		label.add_theme_color_override("font_color", ORIGIN_COLORS[kind])
		_content.add_child(head)
		var color := (ORIGIN_COLORS[kind] as Color).to_html(false)
		var lines: Array[String] = []
		for entry: Dictionary in GlossaryData.ORIGINS:
			if entry["kind"] == kind:
				lines.append("[color=#%s]%s[/color]\n%s" % [color, tr(entry["key"] + "_TITLE"), tr(entry["key"] + "_TEXT")])
		_paragraph("\n\n".join(lines))


## Tanda asal-usul: kotak warna (satu per jenis) lalu keterangannya.
func _origin_tag(kinds: Array[String], text: String) -> HBoxContainer:
	var row := UIKit.hbox(3)
	for kind: String in kinds:
		var chip := ColorRect.new()
		chip.color = ORIGIN_COLORS[kind]
		chip.custom_minimum_size = Vector2(6, 6)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	var label := UIKit.label(text, &"", UIKit.COLOR_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 120
	row.add_child(label)
	return row


func _note(text: String) -> Label:
	var l := UIKit.label(text, &"", UIKit.COLOR_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	return l


# Satu baris: kartu bintang 1-3 lalu nama dan keterangannya.
func _family_row(family: String) -> Control:
	var row := UIKit.hbox(4)
	for rank: int in range(1, 4):
		var data := CardDB.get_card(family, rank)
		if data != null:
			row.add_child(_card_with_tooltip(data, []))
	var first := CardDB.get_card(family, 1)
	if first != null:
		var text := UIKit.label("%s\n%s" % [tr(first.display_name), tr(first.display_name + "_DESC")], &"BigLabel", UIKit.COLOR_TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(200, 0)
		text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(text)
	return row


func _symbol(text: String) -> Label:
	var l := UIKit.label(text, &"TitleLabel", UIKit.COLOR_GOLD)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _base_card(card_type: CardData.CardType) -> CardData:
	for data: CardData in CardDB.get_all_cards():
		if data.card_type == card_type and data.rank == 1 and data.is_base_type():
			return data
	return null


#region Potongan isi

func _heading(text: String) -> void:
	_content.add_child(UIKit.label(text, &"HeaderLabel"))


func _paragraph(text: String, glossary: bool = true) -> void:
	var r := UIKit.rich_text(GlossaryText.mark(text, _glossary_used) if glossary else text, 440)
	if glossary:
		GlossaryText.attach(r)
	_content.add_child(r)


## Gambar tokoh di kiri, nama/fakta/cerita di kanan.
func _figure(texture: Texture2D, title: String, facts: Array[String], text: String, silhouette: bool, tag: Control = null) -> void:
	var row := UIKit.hbox(10)
	var pic := TextureRect.new()
	pic.texture = texture
	pic.custom_minimum_size = Vector2(140, 150)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if silhouette:
		pic.modulate = Color(0, 0, 0, 0.85)
	row.add_child(pic)
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(title, &"HeaderLabel"))
	if tag != null:
		col.add_child(tag)
	for fact: String in facts:
		col.add_child(UIKit.label(fact, &"", UIKit.COLOR_GOLD))
	var r := UIKit.rich_text(text if silhouette else GlossaryText.mark(text, _glossary_used), 270,
		UIKit.COLOR_DIM if silhouette else UIKit.COLOR_TEXT)
	GlossaryText.attach(r)
	col.add_child(r)
	row.add_child(col)
	_content.add_child(row)


## Kartu ukuran asli (skala pecahan merusak piksel) dengan tooltip saat disorot.
func _card_with_tooltip(data: CardData, components: Array[CardData]) -> CardView:
	var view := CardView.preview(data, components)
	view.hover_changed.connect(func(v: CardView, on: bool) -> void:
		if on:
			_tooltip.show_text(v.get_tooltip_bbcode(), v.global_position + Vector2(v.size.x + 4, 0))
		else:
			_tooltip_hide())
	return view

#endregion


func _tooltip_hide() -> void:
	if _tooltip != null:
		_tooltip.hide_tip()


func _go_back() -> void:
	AudioManager.play_sfx("click")
	SceneRouter.go_back(SceneRouter.MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_go_back()
		get_viewport().set_input_as_handled()
