class_name EventPanel
extends Control
## Panel kejadian di perjalanan: cerita singkat, dua pilihan, lalu hasilnya.
## Dipakai di peta (mode cerita) dan di layar Ruwatan.

signal done

## Kejadian yang ditampilkan (lihat JourneyEvents). Diisi sebelum masuk tree.
var event_id: String = ""
## GameState (cerita) atau RuwatanRun. Kosong berarti GameState.
var profile: Object

var _col: VBoxContainer
var _buttons: Array[Button] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if profile == null:
		profile = GameState
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(UIKit.center(panel))
	_col = UIKit.vbox(6)
	panel.add_child(_col)

	var id := event_id.to_upper()
	var header := UIKit.small_label(tr("EVENT_HEADER"), UIKit.COLOR_DIM)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(header)
	var title := UIKit.label(tr("EV_%s_TITLE" % id), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)

	var row := UIKit.hbox(10)
	var tex := load(str(JourneyEvents.get_event(event_id).get("icon", ""))) as Texture2D
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(64, 64)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	var text := UIKit.label(tr("EV_%s_TEXT" % id), &"BigLabel", UIKit.COLOR_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(290, 0)
	row.add_child(text)
	_col.add_child(row)

	for choice: String in ["a", "b"]:
		var b := UIKit.button(tr("EV_%s_%s" % [id, choice.to_upper()]), 360, true)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(_choose.bind(choice))
		_col.add_child(b)
		_buttons.append(b)
	AudioManager.play_sfx("kentongan", 0.05)


func _choose(choice: String) -> void:
	AudioManager.play_sfx("click")
	for b: Button in _buttons:
		b.queue_free()
	_buttons.clear()
	var lines: Array[String] = []
	for effect: String in JourneyEvents.effects_of(event_id, choice):
		var line := ""
		if JourneyEvents.needs_picker(effect):
			line = await _run_picker(effect)
		else:
			line = JourneyEvents.apply(effect, profile, _rng)
		if line != "":
			lines.append(line)

	var story := UIKit.label(tr("EV_%s_%s_RESULT" % [event_id.to_upper(), choice.to_upper()]), &"BigLabel", UIKit.COLOR_TEXT)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(360, 0)
	_col.add_child(story)
	if not lines.is_empty():
		var summary := UIKit.label("\n".join(lines), &"", UIKit.COLOR_GOLD)
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(360, 0)
		_col.add_child(summary)
	var cont := UIKit.button(tr("BTN_CONTINUE"), 120, true)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		done.emit()
		queue_free())
	_col.add_child(cont)


# Kartu Tabuh baru atau tempa kartu pilihan. Mengembalikan kalimat hasilnya.
func _run_picker(effect: String) -> String:
	var picker := DeckPicker.new()
	var deck: Array[String] = profile.call("get_deck")
	picker.deck = deck.duplicate()
	if effect.begins_with("tabuh:"):
		var family := effect.get_slice(":", 1)
		picker.mode = DeckPicker.Mode.REPLACE
		picker.incoming_spec = "%s:1" % family
		picker.tabuh_family = family
	else:
		picker.mode = DeckPicker.Mode.UPGRADE
	get_parent().add_child(picker)
	var index: int = await picker.picked
	if index < 0:
		return tr("REWARD_SKIPPED")
	if effect.begins_with("tabuh:"):
		var swap: Array[String] = profile.call("place_tabuh", index, effect.get_slice(":", 1))
		if swap.is_empty():
			return ""
		return tr("REWARD_REPLACED") % [JourneyEvents.card_label(swap[1]), JourneyEvents.card_label(swap[0])]
	var old := deck[index]
	var result: String = profile.call("upgrade_card", index)
	if result == "":
		return ""
	return tr("EV_RESULT_UPGRADE") % [JourneyEvents.card_label(old), JourneyEvents.card_label(result)]
