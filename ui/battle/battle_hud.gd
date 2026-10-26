class_name BattleHUD
extends Control
## HUD battle: bar atas (nama stage, turn, dek/buangan, jeda), panel bawah kiri
## (AP, Moxie, Evolutionary Chain), tombol Ultimate & Akhiri Turn di kanan,
## dan spanduk "Giliranmu" / "Giliran Buto".

signal end_turn_pressed
signal ultimate_pressed
signal pause_pressed
## Tombol kecepatan battle (1x/2x) ditekan.
signal speed_pressed
## Elemen HUD disorot: tampilkan tooltip dengan teks ini di posisi layar itu.
signal tooltip_requested(text: String, at: Vector2)
signal tooltip_hidden

const PANEL_TOP := 252.0
const AP_FULL := preload("res://assets/ui/mini_ap.png")
const AP_EMPTY := preload("res://assets/ui/mini_ap_empty.png")
const ICON_DECK := preload("res://assets/ui/mini_deck.png")
const ICON_DISCARD := preload("res://assets/ui/mini_discard.png")
const ICON_CHAIN := preload("res://assets/ui/mini_chain.png")
const ICON_ULTIMATE := preload("res://assets/ui/icon_ultimate.png")

var battle: BattleManager
var _turn_label: Label
var _stage_label: Label
var _deck_label: Label
var _discard_label: Label
var _ap_row: HBoxContainer
var _moxie_base: ProgressBar
var _moxie_over: ProgressBar
var _moxie_label: Label
var _chain_label: Label
var _chain_dots: Array[ColorRect] = []
var _ultimate_button: Button
var _end_turn_button: Button
var _banner: Label
var _ap_box: Control
var _ultimate_glow: Tween
var _speed_button: Button


func setup(battle_manager: BattleManager, stage_title: String) -> void:
	battle = battle_manager
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar(stage_title)
	_build_bottom_panel()
	_build_banner()

	var player := battle.player
	player.ap_changed.connect(func(_c: int, _m: int) -> void: _refresh_ap())
	player.moxie_changed.connect(func(_v: float) -> void: _refresh_moxie())
	player.evolutionary_chain_triggered.connect(func(_s: int, _m: float) -> void: _refresh_chain())
	battle.deck.piles_changed.connect(func(_d: int, _x: int) -> void: _refresh_piles())
	battle.turn_started.connect(func(t: int) -> void:
		_turn_label.text = tr("BATTLE_TURN") % t
		_refresh_chain())
	battle.state_changed.connect(func(_a: BattleManager.State, _b: BattleManager.State) -> void: refresh_buttons())
	battle.player_input_ready.connect(refresh_buttons)
	battle.hand.hand_changed.connect(_refresh_chain)
	_refresh_ap()
	_refresh_moxie()
	_refresh_piles()
	_refresh_chain()
	refresh_buttons()


func refresh_speed() -> void:
	_speed_button.text = "%dx" % roundi(GameState.battle_speed)


## Menulis ulang teks yang dirakit dari beberapa bagian (dipanggil saat bahasa diganti).
func refresh_texts(stage_title: String) -> void:
	_stage_label.text = stage_title
	if battle.turn_number > 0:
		_turn_label.text = tr("BATTLE_TURN") % battle.turn_number


#region Bangun

func _build_top_bar(stage_title: String) -> void:
	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(640, 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	_stage_label = UIKit.label(stage_title, &"", UIKit.COLOR_GOLD)
	_stage_label.position = Vector2(6, 1)
	add_child(_stage_label)

	_turn_label = UIKit.label("", &"", UIKit.COLOR_TEXT)
	_turn_label.position = Vector2(270, 1)
	_turn_label.size = Vector2(100, 16)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_turn_label)

	var piles := UIKit.hbox(3)
	piles.position = Vector2(500, 2)
	piles.size = Vector2(110, 14)
	piles.alignment = BoxContainer.ALIGNMENT_END
	piles.mouse_filter = Control.MOUSE_FILTER_PASS
	var deck_box := UIKit.hbox(1)
	deck_box.add_child(UIKit.icon(ICON_DECK))
	_deck_label = UIKit.label("0")
	deck_box.add_child(_deck_label)
	piles.add_child(deck_box)
	var disc_box := UIKit.hbox(1)
	disc_box.add_child(UIKit.icon(ICON_DISCARD))
	_discard_label = UIKit.label("0")
	disc_box.add_child(_discard_label)
	piles.add_child(disc_box)
	add_child(piles)
	_hover_tip(deck_box, func() -> String: return tr("BATTLE_DECK_TIP") % battle.deck.get_draw_count())
	_hover_tip(disc_box, func() -> String: return tr("BATTLE_DISCARD_TIP") % battle.deck.get_discard_count())

	_speed_button = UIKit.button("")
	_speed_button.position = Vector2(470, 0)
	_speed_button.size = Vector2(26, 17)
	_speed_button.add_theme_constant_override("content_margin_left", 2)
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	add_child(_speed_button)
	_hover_tip(_speed_button, func() -> String: return tr("BATTLE_SPEED_TIP"))
	refresh_speed()

	var pause := UIKit.button("II")
	pause.position = Vector2(616, 0)
	pause.size = Vector2(22, 17)
	pause.add_theme_constant_override("content_margin_left", 2)
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause)


func _build_bottom_panel() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.035, 0.035, 0.07, 0.88)
	panel.position = Vector2(0, PANEL_TOP)
	panel.size = Vector2(640, 360 - PANEL_TOP)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var line := ColorRect.new()
	line.color = Color(0.91, 0.71, 0.28, 0.7)
	line.position = Vector2(0, PANEL_TOP)
	line.size = Vector2(640, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)

	# --- kiri: AP, Moxie, Chain
	var left := UIKit.vbox(3)
	left.position = Vector2(6, PANEL_TOP + 6)
	left.size = Vector2(80, 96)
	add_child(left)

	var ap_title := UIKit.small_label("HUD_AP", UIKit.COLOR_GOLD)
	left.add_child(ap_title)
	_ap_row = UIKit.hbox(1)
	left.add_child(_ap_row)
	_ap_box = _ap_row
	_hover_tip(_ap_row, func() -> String: return tr("BATTLE_AP_TIP"))
	_ap_row.mouse_filter = Control.MOUSE_FILTER_PASS

	left.add_child(UIKit.small_label("HUD_MOXIE", UIKit.COLOR_BLUE))
	var moxie_holder := Control.new()
	moxie_holder.custom_minimum_size = Vector2(76, 10)
	moxie_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	_moxie_base = _make_bar(Color(0.32, 0.6, 0.98), 100.0)
	_moxie_over = _make_bar(Color(0.78, 0.42, 0.98), 100.0)
	_moxie_over.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	moxie_holder.add_child(_moxie_base)
	moxie_holder.add_child(_moxie_over)
	_moxie_label = UIKit.small_label("0%", Color(1, 1, 1))
	_moxie_label.size = Vector2(76, 10)
	_moxie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moxie_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_moxie_label.add_theme_constant_override("outline_size", 2)
	moxie_holder.add_child(_moxie_label)
	left.add_child(moxie_holder)
	_hover_tip(moxie_holder, func() -> String: return tr("BATTLE_MOXIE_TIP") % roundi(battle.player.moxie))

	var chain_row := UIKit.hbox(2)
	chain_row.mouse_filter = Control.MOUSE_FILTER_PASS
	chain_row.add_child(UIKit.icon(ICON_CHAIN))
	for i: int in PlayerState.CHAIN_LENGTH:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(5, 5)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chain_row.add_child(dot)
		_chain_dots.append(dot)
	_chain_label = UIKit.small_label("x1.00", UIKit.COLOR_GOLD)
	chain_row.add_child(_chain_label)
	left.add_child(chain_row)
	_hover_tip(chain_row, func() -> String:
		return tr("BATTLE_CHAIN_TIP") % [battle.player.get_chain_progress(), battle.player.ultimate_damage_multiplier])

	# --- kanan: Ultimate & Akhiri Turn
	_ultimate_button = Button.new()
	_ultimate_button.icon = ICON_ULTIMATE
	_ultimate_button.focus_mode = Control.FOCUS_NONE
	_ultimate_button.position = Vector2(562, PANEL_TOP + 6)
	_ultimate_button.size = Vector2(72, 54)
	_ultimate_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ultimate_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_ultimate_button.expand_icon = false
	_ultimate_button.text = ""
	_ultimate_button.pressed.connect(func() -> void: ultimate_pressed.emit())
	add_child(_ultimate_button)
	# Teks berupa kunci terjemahan supaya ikut berganti saat bahasa diubah.
	var ult_label := UIKit.small_label("BATTLE_ULTIMATE_SHORT", UIKit.COLOR_GOLD)
	ult_label.position = Vector2(562, PANEL_TOP + 47)
	ult_label.size = Vector2(72, 10)
	ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# "GELAP NGAMPAR" lebih panjang dari lebar tombol kalau memakai huruf kecil
	# biasa, jadi dipakai Tiny5 ukuran asli (8) yang lebih ramping.
	ult_label.add_theme_font_override("font", UIKit.FONT_MAIN)
	ult_label.add_theme_font_size_override("font_size", 8)
	ult_label.clip_text = true
	add_child(ult_label)
	_hover_tip(_ultimate_button, func() -> String:
		var preview := roundi(battle.ultimate_base_damage * battle.player.ultimate_damage_multiplier * maxf(battle.player.moxie, 100.0) / 100.0)
		return tr("BATTLE_ULTIMATE_TIP") % preview)

	_end_turn_button = UIKit.button("BATTLE_END_TURN")
	_end_turn_button.position = Vector2(562, PANEL_TOP + 66)
	_end_turn_button.size = Vector2(72, 30)
	_end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	add_child(_end_turn_button)


func _build_banner() -> void:
	_banner = UIKit.label("", &"TitleLabel")
	_banner.position = Vector2(0, 120)
	_banner.size = Vector2(640, 32)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	add_child(_banner)


func _make_bar(color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = max_value
	bar.size = Vector2(76, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.border_width_bottom = 2
	fill.border_color = color.darkened(0.4)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _hover_tip(control: Control, text_func: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.mouse_entered.connect(func() -> void:
		tooltip_requested.emit(text_func.call() as String, control.global_position))
	control.mouse_exited.connect(func() -> void: tooltip_hidden.emit())

#endregion


#region Pembaruan

func _refresh_ap() -> void:
	for child: Node in _ap_row.get_children():
		child.queue_free()
	var player := battle.player
	var shown := maxi(player.max_ap, player.current_ap)
	for i: int in shown:
		_ap_row.add_child(UIKit.icon(AP_FULL if i < player.current_ap else AP_EMPTY))


func _refresh_moxie() -> void:
	var m := battle.player.moxie
	var t := create_tween().set_parallel(true)
	t.tween_property(_moxie_base, "value", minf(m, 100.0), 0.25)
	t.tween_property(_moxie_over, "value", maxf(m - 100.0, 0.0), 0.25)
	_moxie_label.text = "%d%%" % roundi(m)
	refresh_buttons()


func _refresh_piles() -> void:
	_deck_label.text = str(battle.deck.get_draw_count())
	_discard_label.text = str(battle.deck.get_discard_count())


func _refresh_chain() -> void:
	var progress := battle.player.get_chain_progress()
	for i: int in _chain_dots.size():
		_chain_dots[i].color = Color(1.0, 0.84, 0.35) if i < progress else Color(0.25, 0.25, 0.32)
	_chain_label.text = "x%.2f" % battle.player.ultimate_damage_multiplier


func refresh_buttons() -> void:
	if battle == null:
		return
	var input_ok := battle.is_accepting_input()
	_end_turn_button.disabled = not input_ok
	var ready := input_ok and battle.player.is_ultimate_ready()
	_ultimate_button.disabled = not ready
	if ready and _ultimate_glow == null:
		_ultimate_glow = create_tween().set_loops()
		_ultimate_glow.tween_property(_ultimate_button, "modulate", Color(1.35, 1.2, 0.8), 0.45)
		_ultimate_glow.tween_property(_ultimate_button, "modulate", Color.WHITE, 0.45)
	elif not ready and _ultimate_glow != null:
		_ultimate_glow.kill()
		_ultimate_glow = null
		_ultimate_button.modulate = Color.WHITE


## Spanduk besar di tengah layar, hilang sendiri.
func show_banner(text: String, color: Color = UIKit.COLOR_GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	var t := create_tween()
	_banner.modulate.a = 0.0
	_banner.position.y = 128
	t.tween_property(_banner, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(_banner, "position:y", 120.0, 0.15)
	t.tween_interval(0.7)
	t.tween_property(_banner, "modulate:a", 0.0, 0.3)


## Getar kecil di AP saat AP tidak cukup.
func shake_ap() -> void:
	var base := _ap_box.position
	var t := create_tween()
	for i: int in 4:
		t.tween_property(_ap_box, "position:x", base.x + (3.0 if i % 2 == 0 else -3.0), 0.035)
	t.tween_property(_ap_box, "position:x", base.x, 0.035)


func get_ap_point() -> Vector2:
	return _ap_box.global_position + Vector2(24, 0)


func get_moxie_point() -> Vector2:
	return _moxie_base.global_position + Vector2(38, 0)

#endregion
