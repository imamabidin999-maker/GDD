class_name RewardPanel
extends Control
## Pilihan "Berkah Roro Ayu" setelah kemenangan pertama di sebuah babak:
## pemain memilih satu dari tiga berkah. Kalau babaknya sudah pernah memberi
## berkah, panel hanya memberi tahu hal itu.

signal done

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
}

## Babak asal berkah. Diisi sebelum panel masuk ke tree.
var stage_number: int = 0
## true kalau babak ini sudah pernah memberi berkah.
var already_received: bool = false

var _col: VBoxContainer
var _choices: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	_col = UIKit.vbox(8)
	panel.add_child(_col)
	var title := UIKit.label(tr("REWARD_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	if already_received:
		_add_message(tr("REWARD_ALREADY"))
		_add_continue()
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var options := GameState.roll_blessings(rng)
	if options.is_empty():
		_add_message(tr("REWARD_EMPTY"))
		_add_continue()
		return
	var hint := UIKit.label(tr("REWARD_HINT"), &"", UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(hint)
	_choices = UIKit.hbox(8)
	_col.add_child(_choices)
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


func _choose(blessing: Blessings.Kind) -> void:
	AudioManager.play_sfx("gong")
	var upgraded := GameState.apply_blessing(blessing, stage_number)
	for child: Node in _choices.get_children():
		child.queue_free()
	var msg := tr("REWARD_DONE")
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
		msg += "\n" + tr("MAP_HP") % GameState.max_hp
	var result := UIKit.label(msg, &"", UIKit.COLOR_TEXT)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(result)
	_add_continue()
