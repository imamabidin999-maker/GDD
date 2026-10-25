class_name DeckOverview
extends Control
## Panel "Jurus Eyang Palang": seluruh kartu deck dan berkah yang dimiliki,
## dengan keterangan saat disorot. Dipakai di peta cerita dan layar Ruwatan.

## Isi deck sebagai spec "tipe:rank". Diisi sebelum masuk tree.
var deck: Array[String] = []
var blessings: Array[String] = []
## Tooltip milik scene pemakai.
var tooltip: GameTooltip


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	var col := UIKit.vbox(4)
	panel.add_child(col)
	var title := UIKit.label(tr("DECK_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UIKit.small_label(tr("DECK_HINT"), UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	var specs := deck.duplicate()
	specs.sort_custom(DeckPicker.compare_specs)
	for spec: String in specs:
		var data := CardDB.card_from_spec(spec)
		if data != null:
			grid.add_child(_card_with_tooltip(data))

	col.add_child(blessing_row(blessings, tooltip))

	var close := UIKit.button(tr("BTN_CLOSE"), 120, true)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		if tooltip != null:
			tooltip.hide_tip()
		queue_free())
	col.add_child(close)


## Baris ikon berkah yang dimiliki, dengan keterangan saat disorot.
static func blessing_row(owned: Array[String], tip: GameTooltip) -> Control:
	var row := UIKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UIKit.label(TranslationServer.translate("BLESS_OWNED"), &"", UIKit.COLOR_GOLD))
	if owned.is_empty():
		row.add_child(UIKit.label(TranslationServer.translate("BLESS_NONE"), &"", UIKit.COLOR_DIM))
		return row
	var counts := {}
	for entry: String in owned:
		counts[entry] = int(counts.get(entry, 0)) + 1
	for entry: String in counts:
		var kind := Blessings.from_name(entry)
		if kind < 0:
			continue
		var name := TranslationServer.translate(Blessings.text_key(kind))
		if int(counts[entry]) > 1:
			name += " x%d" % int(counts[entry])
		var text := "[b][color=#ffd36e]%s[/color][/b]\n%s" % [name, TranslationServer.translate(Blessings.text_key(kind) + "_DESC")]
		# Ikon berkah berbeda ukuran (12, 15, 40 piksel): yang besar diperkecil
		# setengah, yang kecil tetap ukuran asli supaya pikselnya tidak pecah.
		var tex: Texture2D = RewardPanel.BLESS_ICONS[kind]
		var ic := TextureRect.new()
		ic.texture = tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(20, 20)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if tex.get_width() > 20 else TextureRect.STRETCH_KEEP_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		if tip != null:
			ic.mouse_entered.connect(func() -> void: tip.show_text(text, ic.global_position + Vector2(0, -40)))
			ic.mouse_exited.connect(tip.hide_tip)
		row.add_child(ic)
		if int(counts[entry]) > 1:
			row.add_child(UIKit.small_label("x%d" % int(counts[entry]), UIKit.COLOR_TEXT))
	return row


## Kartu ukuran asli (skala pecahan merusak piksel) dengan tooltip saat disorot.
func _card_with_tooltip(data: CardData) -> Control:
	var view := CardView.preview(data)
	view.hover_changed.connect(func(v: CardView, on: bool) -> void:
		if tooltip == null:
			return
		if on:
			tooltip.show_text(v.get_tooltip_bbcode(), v.global_position + Vector2(v.size.x + 4, 0))
		else:
			tooltip.hide_tip())
	return view
