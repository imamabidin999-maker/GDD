class_name RewardPanel
extends Control
## Pilihan "Berkah Roro Ayu" setelah menang: pemain memilih satu dari tiga
## berkah (menaikkan bintang kartu atau HP maksimal).

signal done

const BLESS_KEYS := {
	GameState.Blessing.TEMPA_SERANG: "BLESS_TEMPA",
	GameState.Blessing.ILMU_FOKUS: "BLESS_FOKUS",
	GameState.Blessing.SIASAT_TAKTIK: "BLESS_TAKTIK",
	GameState.Blessing.JAMU: "BLESS_JAMU",
}
const BLESS_ICONS := {
	GameState.Blessing.TEMPA_SERANG: preload("res://assets/cards/icon_serang.png"),
	GameState.Blessing.ILMU_FOKUS: preload("res://assets/cards/icon_fokus.png"),
	GameState.Blessing.SIASAT_TAKTIK: preload("res://assets/cards/icon_taktik.png"),
	GameState.Blessing.JAMU: preload("res://assets/ui/mini_heart.png"),
}

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
	var hint := UIKit.label(tr("REWARD_HINT"), &"", UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(hint)
	_choices = UIKit.hbox(8)
	_col.add_child(_choices)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for blessing: GameState.Blessing in GameState.roll_blessings(rng):
		_choices.add_child(_make_choice(blessing))


func _make_choice(blessing: GameState.Blessing) -> Button:
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
	var ic := UIKit.icon(BLESS_ICONS[blessing])
	ic.custom_minimum_size = Vector2(0, 30)
	inner.add_child(ic)
	var name_label := UIKit.label(tr(BLESS_KEYS[blessing]), &"", UIKit.COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_label)
	var desc := UIKit.label(tr(BLESS_KEYS[blessing] + "_DESC"), &"", UIKit.COLOR_TEXT)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(138, 0)
	inner.add_child(desc)
	b.add_child(inner)
	b.pressed.connect(_choose.bind(blessing))
	return b


func _choose(blessing: GameState.Blessing) -> void:
	AudioManager.play_sfx("gong")
	var upgraded := GameState.apply_blessing(blessing)
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
	if blessing == GameState.Blessing.JAMU:
		msg += "\n" + tr("MAP_HP") % GameState.max_hp
	var result := UIKit.label(msg, &"", UIKit.COLOR_TEXT)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(result)
	var cont := UIKit.button(tr("BTN_CONTINUE"), 120)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func() -> void:
		done.emit()
		queue_free())
	_col.add_child(cont)
