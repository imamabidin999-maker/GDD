class_name ChallengePanel
extends Control
## Panel "Hasil Tantangan" setelah menang: tiga bintang babak, mana yang
## tercapai di battle ini, mana yang baru, total Bintang Dongkrek, dan hadiah
## yang baru terbuka.

signal done

const STAR := preload("res://assets/ui/mini_star.png")
const STAR_EMPTY := preload("res://assets/ui/mini_star_empty.png")

## Kalimat tiga bintang (lihat Challenges.describe_stage). Diisi sebelum masuk tree.
var lines: Array[String] = []
## Tercapai di battle ini.
var results: Array[bool] = []
## Baru didapat kali ini.
var fresh: Array[bool] = []
## Sudah dimiliki sesudah battle ini (bitmask).
var owned_mask: int = 0
var total_before: int = 0
var total_after: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.custom_minimum_size = Vector2(320, 0)
	add_child(UIKit.center(panel))
	var col := UIKit.vbox(6)
	panel.add_child(col)
	var title := UIKit.label(tr("CHALLENGE_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	for i: int in lines.size():
		var row := UIKit.hbox(6)
		var owned := bool(owned_mask & (1 << i))
		var star := UIKit.icon(STAR if owned else STAR_EMPTY)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(24, 24)
		row.add_child(star)
		var achieved := i < results.size() and results[i]
		var text := UIKit.label(lines[i], &"BigLabel", UIKit.COLOR_TEXT if achieved else UIKit.COLOR_DIM)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(230, 0)
		row.add_child(text)
		if i < fresh.size() and fresh[i]:
			row.add_child(UIKit.label(tr("CHALLENGE_NEW"), &"BigLabel", UIKit.COLOR_GOLD))
			_pop(star, i)
		col.add_child(row)

	var total := UIKit.label(tr("CHALLENGE_TOTAL") % [total_after, GameState.STAGE_COUNT * Challenges.STARS_PER_STAGE], &"", UIKit.COLOR_GOLD)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(total)
	for reward: Array in Challenges.rewards():
		if total_before < int(reward[0]) and total_after >= int(reward[0]):
			var msg := UIKit.label(tr("CHALLENGE_UNLOCKED") % tr(str(reward[1])), &"", Color(0.75, 1.0, 0.55))
			msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			msg.custom_minimum_size = Vector2(300, 0)
			col.add_child(msg)

	var cont := UIKit.button(tr("BTN_CONTINUE"), 120, true)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cont.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		done.emit()
		queue_free())
	col.add_child(cont)


# Bintang yang baru didapat muncul bergantian dengan bunyi kentongan.
func _pop(star: Control, order: int) -> void:
	star.pivot_offset = Vector2(12, 12)
	star.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_interval(0.25 + 0.25 * order)
	t.tween_callback(func() -> void: AudioManager.play_sfx("kentongan", 0.05))
	t.tween_property(star, "scale", Vector2.ONE * 1.3, 0.15)
	t.tween_property(star, "scale", Vector2.ONE, 0.1)
