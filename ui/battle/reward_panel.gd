class_name RewardPanel
extends Control
## Pilihan "Berkah Roro Ayu" setelah kemenangan pertama di sebuah babak
## (atau setiap kemenangan di Ruwatan): pemain memilih satu dari beberapa
## berkah. Kalau babaknya sudah pernah memberi berkah, panel hanya memberi
## tahu hal itu.

signal done

const RORO_AYU := preload("res://assets/sprites/roro/roro_ayu_idle.png")

const BLESS_ICONS := {
	Blessings.Kind.TEMPA_SABET: preload("res://assets/cards/icon_serang.png"),
	Blessings.Kind.OLAH_SEMEDI: preload("res://assets/cards/icon_fokus.png"),
	Blessings.Kind.LAKU_TANGKIS: preload("res://assets/cards/icon_taktik.png"),
	Blessings.Kind.JAMU_KUNYIT_ASAM: preload("res://assets/ui/mini_heart.png"),
	Blessings.Kind.KENDANG_PEMBUKA: preload("res://assets/ui/bless_kendang.png"),
	Blessings.Kind.GREGET_LELUHUR: preload("res://assets/ui/bless_leluhur.png"),
	Blessings.Kind.TAMENG_PUSAKA: preload("res://assets/ui/bless_pusaka.png"),
	Blessings.Kind.JIMAT_PENOLAK_SIREP: preload("res://assets/ui/bless_jimat.png"),
	Blessings.Kind.JAMU_BERAS_KENCUR: preload("res://assets/ui/bless_kencur.png"),
	Blessings.Kind.TABUH_BEDUG: preload("res://assets/cards/icon_bedug.png"),
	Blessings.Kind.TABUH_KENTONGAN: preload("res://assets/cards/icon_kentongan.png"),
	Blessings.Kind.TABUH_KOREK: preload("res://assets/cards/icon_korek.png"),
	Blessings.Kind.TABUH_GONG: preload("res://assets/cards/icon_gong.png"),
	Blessings.Kind.TABUH_KENONG: preload("res://assets/cards/icon_kenong.png"),
	Blessings.Kind.LARAS_GAMELAN: preload("res://assets/cards/icon_kenong.png"),
	Blessings.Kind.TABUH_BERI: preload("res://assets/cards/icon_beri.png"),
}

## Babak asal berkah. Diisi sebelum panel masuk ke tree.
var stage_number: int = 0
## true kalau babak ini sudah pernah memberi berkah.
var already_received: bool = false
## GameState (cerita) atau RuwatanRun. Kosong berarti GameState.
var profile: Object

var _col: VBoxContainer
var _choices: HBoxContainer
var _reroll: Button


func _ready() -> void:
	if profile == null:
		profile = GameState
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	var row := UIKit.hbox(10)
	panel.add_child(row)
	row.add_child(_roro_ayu())
	_col = UIKit.vbox(8)
	row.add_child(_col)
	var title := UIKit.label(tr("REWARD_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	if already_received:
		_add_message(tr("REWARD_ALREADY"))
		_add_continue()
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var options: Array[Blessings.Kind] = profile.call("roll_blessings", rng)
	if options.is_empty():
		_add_message(tr("REWARD_EMPTY"))
		_add_continue()
		return
	var hint := UIKit.label(tr("REWARD_HINT"), &"", UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(hint)
	_choices = UIKit.hbox(8)
	_col.add_child(_choices)
	_fill_choices(options)
	# Hadiah 16 Bintang Dongkrek: sekali undi ulang di setiap panel berkah.
	if GameState.reroll_unlocked():
		_reroll = UIKit.button(tr("REWARD_REROLL"), 120)
		_reroll.tooltip_text = tr("REWARD_REROLL_TIP")
		_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_reroll.pressed.connect(func() -> void:
			AudioManager.play_sfx("kentongan")
			_reroll.queue_free()
			_reroll = null
			var again: Array[Blessings.Kind] = profile.call("roll_blessings", rng)
			if not again.is_empty():
				_fill_choices(again))
		_col.add_child(_reroll)


# Roro Ayu berdiri di kiri panel dan bernapas pelan.
func _roro_ayu() -> Control:
	var tex := UIKit.trimmed(RORO_AYU)
	var holder := Control.new()
	holder.custom_minimum_size = tex.get_size()
	holder.size_flags_vertical = Control.SIZE_SHRINK_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var figure := UIKit.icon(tex)
	holder.add_child(figure)
	var t := figure.create_tween().set_loops()
	t.tween_property(figure, "position:y", -2.0, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(figure, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	return holder


func _fill_choices(options: Array[Blessings.Kind]) -> void:
	for child: Node in _choices.get_children():
		child.queue_free()
	for blessing: Blessings.Kind in options:
		_choices.add_child(_make_choice(blessing))


func _add_message(text: String) -> void:
	var msg := UIKit.label(text, &"BigLabel", UIKit.COLOR_TEXT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(300, 0)
	_col.add_child(msg)


func _add_continue() -> void:
	var cont := UIKit.button(tr("BTN_CONTINUE"), 120, true)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func() -> void:
		done.emit()
		queue_free())
	_col.add_child(cont)


func _make_choice(blessing: Blessings.Kind) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(150, 112)
	b.focus_mode = Control.FOCUS_NONE
	var inner := UIKit.vbox(3)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6
	inner.offset_right = -6
	inner.offset_top = 6
	inner.offset_bottom = -6
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	var tex: Texture2D = BLESS_ICONS[blessing]
	var ic := UIKit.icon(tex)
	ic.custom_minimum_size = Vector2(0, 30)
	if tex.get_width() < 20:
		# Ikon kecil (hati 12px) diperbesar 2x supaya sejajar dengan ikon kartu.
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(tex.get_width() * 2, 30)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(ic)
	var name_label := UIKit.label(tr(Blessings.text_key(blessing)), &"BigLabel", UIKit.COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_label)
	var desc := UIKit.label(tr(Blessings.text_key(blessing) + "_DESC"), &"", UIKit.COLOR_TEXT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(138, 0)
	inner.add_child(desc)
	b.add_child(inner)
	b.pressed.connect(_choose.bind(blessing))
	return b


# Berkah kartu Tabuh: pemain memilih kartu yang diganti. Mengembalikan teks hasilnya.
func _place_tabuh(family: String) -> String:
	var picker := DeckPicker.new()
	picker.mode = DeckPicker.Mode.REPLACE
	var deck: Array[String] = profile.call("get_deck")
	picker.deck = deck.duplicate()
	picker.incoming_spec = "%s:1" % family
	picker.tabuh_family = family
	get_parent().add_child(picker)
	var index: int = await picker.picked
	if index < 0:
		return tr("REWARD_SKIPPED")
	var swap: Array[String] = profile.call("place_tabuh", index, family)
	if swap.is_empty():
		return tr("REWARD_SKIPPED")
	return tr("REWARD_REPLACED") % [_card_name(swap[1]), _card_name(swap[0])]


func _card_name(spec: String) -> String:
	var card := CardDB.card_from_spec(spec)
	if card == null:
		return spec
	return "%s (%s)" % [tr(card.display_name), tr("CARD_RANK") % card.rank]


func _choose(blessing: Blessings.Kind) -> void:
	AudioManager.play_sfx("gong")
	var upgraded: Array[String] = profile.call("apply_blessing", blessing, stage_number)
	for child: Node in _choices.get_children():
		child.queue_free()
	if _reroll != null:
		_reroll.queue_free()
		_reroll = null
	var msg := tr("REWARD_DONE")
	if Blessings.TABUH_FAMILY.has(blessing):
		msg += "\n" + await _place_tabuh(Blessings.TABUH_FAMILY[blessing])
	# Kartu kembar ditulis sekali dengan jumlahnya, misal "Fokus  Bintang 2  x2".
	var counts := {}
	for spec: String in upgraded:
		counts[spec] = int(counts.get(spec, 0)) + 1
	for spec: String in counts:
		var card := CardDB.card_from_spec(spec)
		if card == null:
			continue
		msg += "\n%s  %s" % [tr(card.display_name), tr("CARD_RANK") % card.rank]
		if int(counts[spec]) > 1:
			msg += "  x%d" % int(counts[spec])
	if blessing == Blessings.Kind.JAMU_KUNYIT_ASAM:
		msg += "\n" + tr("MAP_HP") % int(profile.call("get_max_hp"))
	var result := UIKit.label(msg, &"", UIKit.COLOR_TEXT)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(result)
	_add_continue()
