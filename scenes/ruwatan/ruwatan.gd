extends Control
## Layar Ruwatan. Tanpa Ruwatan yang berjalan: pilih Tingkat Pagebluk lalu
## mulai. Saat berjalan: jalur delapan langkah, Nyawa dan berkah Eyang
## Palang, serta langkah berikutnya (battle, kejadian, atau Buto Hitam).
## Berkah setelah menang dan hasil akhir Ruwatan juga ditampilkan di sini.

const BG := preload("res://assets/backgrounds/battle_candi.png")
const HERO := preload("res://assets/sprites/hero/eyang_palang_idle.png")
const HEART := preload("res://assets/ui/mini_heart.png")
const DECK := preload("res://assets/ui/mini_deck.png")
const STAR := preload("res://assets/ui/mini_star.png")
const PADLOCK := preload("res://assets/ui/padlock.png")
const PATH_Y := 100.0
const PATH_X0 := 64.0
const PATH_DX := 73.0
const HERO_SCALE := 0.3
## Eyang Palang berdiri di atas medali langkah yang sedang dijalani.
const HERO_OFFSET := Vector2(0, -18)

var _ui: Control
var _overlay: Control
var _tooltip: GameTooltip
var _world: Node2D
var _hero: Sprite2D
var _selected_level: int = 1
var _detail_col: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.position = Vector2(0, -150)
	bg.modulate = Color(0.6, 0.52, 0.78)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_world = Node2D.new()
	add_child(_world)
	_world.add_child(Ambient.fireflies(Vector2(320, 200), Vector2(320, 150), 16))
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_tooltip = GameTooltip.new()
	add_child(_tooltip)
	_selected_level = GameState.ruwatan_max_level()
	_build()
	AudioManager.play_music("map")
	_resume.call_deferred()


# Lanjutan dari battle: hasil akhir, atau berkah yang menunggu dipilih.
func _resume() -> void:
	var run := GameState.ruwatan
	if run == null:
		return
	if run.is_over():
		_show_result()
	elif run.pending_blessing:
		_offer_blessing()


func _build() -> void:
	_tooltip.hide_tip()
	for child: Node in _ui.get_children():
		child.queue_free()
	if _hero != null:
		_hero.queue_free()
		_hero = null
	_build_bar()
	if GameState.ruwatan == null:
		_build_picker()
	else:
		_build_run()


func _build_bar() -> void:
	var run := GameState.ruwatan
	var bar := PanelContainer.new()
	bar.size = Vector2(640, 22)
	bar.custom_minimum_size = Vector2(640, 22)
	_ui.add_child(bar)
	var row := UIKit.hbox(6)
	bar.add_child(row)
	row.add_child(UIKit.label(tr("RUWATAN_TITLE"), &"HeaderLabel"))
	if run != null:
		var lvl := UIKit.label(tr("RUWATAN_LEVEL") % run.level, &"", UIKit.COLOR_PURPLE)
		lvl.mouse_filter = Control.MOUSE_FILTER_STOP
		lvl.mouse_entered.connect(func() -> void: _tooltip.show_text(_rules_text(run.level), lvl.global_position + Vector2(0, 18)))
		lvl.mouse_exited.connect(_tooltip.hide_tip)
		row.add_child(lvl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	if run != null and not run.is_over():
		row.add_child(UIKit.icon(HEART))
		row.add_child(UIKit.label(tr("RUWATAN_HP") % [run.hp, run.max_hp], &"", UIKit.COLOR_TEXT))
		var deck := _bar_button(tr("MAP_DECK"), _open_deck)
		deck.icon = DECK
		row.add_child(deck)
	row.add_child(_bar_button(tr("BTN_MAIN_MENU"), func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU)))


func _bar_button(text: String, action: Callable) -> Button:
	var b := UIKit.button(text)
	b.custom_minimum_size = Vector2(0, 16)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		action.call())
	return b


func _panel(at: Vector2, panel_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.position = at
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	_ui.add_child(panel)
	var col := UIKit.vbox(4)
	panel.add_child(col)
	return col


func _wrapped(text: String, width: float, color: Color = UIKit.COLOR_TEXT, variation: StringName = &"") -> Label:
	var l := UIKit.label(text, variation, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func _filler() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


#region Pilih Tingkat Pagebluk

func _build_picker() -> void:
	var left := _panel(Vector2(12, 30), Vector2(296, 320))
	left.add_child(_wrapped(tr("RUWATAN_INTRO"), 280, UIKit.COLOR_TEXT, &"BigLabel"))
	left.add_child(_filler())
	left.add_child(UIKit.label(tr("RUWATAN_LEVEL_PICK"), &"HeaderLabel"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var group := ButtonGroup.new()
	var top := GameState.ruwatan_max_level()
	for n: int in range(1, RuwatanRun.MAX_LEVEL + 1):
		var b := UIKit.button(str(n), 50, true)
		b.custom_minimum_size = Vector2(50, 30)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		if n > top:
			b.disabled = true
			b.text = ""
			b.icon = PADLOCK
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.tooltip_text = tr("RUWATAN_LOCKED_LEVEL")
		elif GameState.ruwatan_best_of(n) >= RuwatanRun.STEPS.size():
			b.icon = STAR
		b.button_pressed = n == _selected_level
		b.pressed.connect(func() -> void:
			AudioManager.play_sfx("click")
			_selected_level = n
			_fill_level_detail())
		grid.add_child(b)
	left.add_child(_filler())

	_detail_col = _panel(Vector2(316, 30), Vector2(312, 320))
	_fill_level_detail()


func _fill_level_detail() -> void:
	for child: Node in _detail_col.get_children():
		child.queue_free()
	var n := _selected_level
	_detail_col.add_child(UIKit.label(tr("RUWATAN_LEVEL") % n, &"HeaderLabel", UIKit.COLOR_GOLD))
	var best := GameState.ruwatan_best_of(n)
	var best_text := tr("RUWATAN_BEST_NONE")
	var best_color := UIKit.COLOR_DIM
	if best >= RuwatanRun.STEPS.size():
		best_text = tr("RUWATAN_BEST_WON")
		best_color = UIKit.COLOR_GREEN
	elif best >= 0:
		best_text = tr("RUWATAN_BEST_STEP") % best
		best_color = UIKit.COLOR_TEXT
	_detail_col.add_child(UIKit.label(best_text, &"BigLabel", best_color))
	_detail_col.add_child(UIKit.label(tr("RUWATAN_RULES"), &"BigLabel", UIKit.COLOR_GOLD))
	var keys := RuwatanRun.rule_keys(n)
	if keys.is_empty():
		_detail_col.add_child(_wrapped(tr("RUWATAN_RULES_NONE"), 296, UIKit.COLOR_TEXT, &"BigLabel"))
	var rules := UIKit.vbox(0)
	for key: String in keys:
		rules.add_child(_wrapped("- " + tr(key), 296, UIKit.COLOR_TEXT, &"BigLabel"))
	_detail_col.add_child(rules)
	_detail_col.add_child(_filler())
	var bonus := GameState.ruwatan_blessing_unlocked()
	_detail_col.add_child(_wrapped(tr("RUWATAN_BONUS_ON" if bonus else "RUWATAN_BONUS_OFF"), 296,
		UIKit.COLOR_GOLD if bonus else UIKit.COLOR_DIM))
	var start := UIKit.button(tr("RUWATAN_START"), 150, true)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_start_run)
	_detail_col.add_child(start)


func _rules_text(level: int) -> String:
	var lines: Array[String] = ["[b][color=#ffd36e]%s[/color][/b]" % (tr("RUWATAN_LEVEL") % level)]
	var keys := RuwatanRun.rule_keys(level)
	if keys.is_empty():
		lines.append(tr("RUWATAN_RULES_NONE"))
	for key: String in keys:
		lines.append("- " + tr(key))
	return "\n".join(lines)


func _start_run() -> void:
	if SceneRouter.is_busy():
		return
	AudioManager.play_sfx("gong")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var run := GameState.start_ruwatan(_selected_level, rng)
	_build()
	if run.start_blessing != "":
		var kind := Blessings.from_name(run.start_blessing)
		_message(tr("RUWATAN_TITLE"), tr("RUWATAN_START_BLESSING") % tr(Blessings.text_key(kind)))

#endregion


#region Jalur Ruwatan

func _build_run() -> void:
	var run := GameState.ruwatan
	# Garis jalur di belakang medali.
	var line := Control.new()
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func() -> void:
		for i: int in RuwatanRun.STEPS.size() - 1:
			var a := _step_point(i)
			var b := _step_point(i + 1)
			var done := i < run.steps_cleared()
			line.draw_line(a, b, Color(0, 0, 0, 0.5), 5.0)
			line.draw_line(a, b, StageNode.COLOR_CLEARED if done else Color(0.5, 0.48, 0.6), 2.0))
	_ui.add_child(line)

	for i: int in RuwatanRun.STEPS.size():
		var stage := run.build_stage(i)
		stage.stage_number = i + 1
		stage.map_position = _step_point(i)
		var state := StageNode.State.UPCOMING
		if i < run.steps_cleared():
			state = StageNode.State.CLEARED
		elif i == run.step and not run.is_over():
			state = StageNode.State.OPEN
		var node := StageNode.new()
		node.show_stars = false
		node.mystery = not run.is_battle_step(i)
		node.setup(stage, state)
		node.selected = i == run.step and not run.is_over()
		node.hover_changed.connect(func(n: StageNode, on: bool) -> void:
			if on:
				_tooltip.show_text(_step_tip(i), n.position + Vector2(n.size.x * 0.5 - 60, n.size.y + 16))
			else:
				_tooltip.hide_tip())
		node.pressed.connect(func(_n: StageNode) -> void:
			if i == run.step:
				_go())
		_ui.add_child(node)
	var label_y := PATH_Y + 26.0
	for i: int in RuwatanRun.STEPS.size():
		var kind := RuwatanRun.STEPS[i]
		var short := UIKit.small_label(tr(_short_key(kind)), UIKit.COLOR_GOLD if i == run.step else UIKit.COLOR_DIM)
		short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		short.position = Vector2(_step_point(i).x - 36, label_y)
		short.size = Vector2(72, 10)
		_ui.add_child(short)

	if not run.is_over():
		_hero = Ambient.breathing_sprite(HERO, _step_point(run.step) + HERO_OFFSET, false, HERO_SCALE)
		_world.add_child(_hero)

	_build_status(run)
	_build_next_step(run)


func _step_point(i: int) -> Vector2:
	return Vector2(PATH_X0 + PATH_DX * i, PATH_Y)


func _short_key(kind: RuwatanRun.Step) -> String:
	match kind:
		RuwatanRun.Step.EVENT:
			return "RUWATAN_SHORT_EVENT"
		RuwatanRun.Step.BOSS:
			return "RUWATAN_SHORT_BOSS"
		RuwatanRun.Step.MURKA, RuwatanRun.Step.TWIN_MURKA:
			return "RUWATAN_SHORT_MURKA"
	return "RUWATAN_SHORT_BATTLE"


func _step_tip(i: int) -> String:
	var run := GameState.ruwatan
	var lines: Array[String] = ["[b][color=#ffd36e]%s[/color][/b]" % (tr("RUWATAN_STEP") % [i + 1, RuwatanRun.STEPS.size()])]
	lines.append(tr(RuwatanRun.step_title_key(RuwatanRun.STEPS[i])))
	for spec: EnemySpec in run.enemy_specs(i):
		lines.append("- %s  (HP %d)" % [_buto_name(spec), run.display_hp(spec)])
	return "\n".join(lines)


func _buto_name(spec: EnemySpec) -> String:
	var base := tr("BUTO_" + StageNode.get_buto_key(spec).to_upper())
	return tr("BUTO_MURKA_FMT") % base if spec.murka else base


# Kiri bawah: Nyawa, Tingkat Pagebluk, dan berkah.
func _build_status(run: RuwatanRun) -> void:
	var col := _panel(Vector2(12, 150), Vector2(296, 200))
	col.add_child(UIKit.label(tr("SPEAKER_EYANG"), &"HeaderLabel"))
	var hp_row := UIKit.hbox(4)
	hp_row.add_child(UIKit.icon(HEART))
	hp_row.add_child(UIKit.label(tr("RUWATAN_HP") % [run.hp, run.max_hp], &"BigLabel", UIKit.COLOR_TEXT))
	col.add_child(hp_row)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(280, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var ratio := clampf(float(run.hp) / maxf(1.0, run.max_hp), 0.0, 1.0)
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(0.1, 0.08, 0.12))
		bar.draw_rect(Rect2(Vector2(1, 1), Vector2((bar.size.x - 2) * ratio, bar.size.y - 2)), UIKit.COLOR_RED.lerp(UIKit.COLOR_GREEN, ratio)))
	col.add_child(bar)
	col.add_child(_wrapped(tr("RUWATAN_HEAL_NOTE") % roundi(run.heal_ratio() * 100.0), 280, UIKit.COLOR_DIM))
	# Aturan Tingkat Pagebluk yang berlaku, ringkas dalam satu paragraf.
	var rules: Array[String] = []
	for key: String in RuwatanRun.rule_keys(run.level):
		rules.append(tr(key))
	var summary := tr("RUWATAN_ACTIVE_RULES") % (", ".join(rules) if not rules.is_empty() else tr("RUWATAN_RULES_NONE"))
	col.add_child(_wrapped(summary, 280, UIKit.COLOR_PURPLE.lightened(0.2)))
	col.add_child(_filler())
	var row := DeckOverview.blessing_row(run.blessings, _tooltip)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(row)
	var deck := UIKit.button(tr("MAP_DECK"), 120)
	deck.icon = DECK
	deck.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	deck.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_open_deck())
	col.add_child(deck)


# Kanan bawah: langkah berikutnya dan tombolnya.
func _build_next_step(run: RuwatanRun) -> void:
	var col := _panel(Vector2(316, 150), Vector2(312, 200))
	if run.is_over():
		return
	var kind := run.current_step()
	col.add_child(UIKit.small_label(tr("RUWATAN_STEP") % [run.step + 1, RuwatanRun.STEPS.size()], UIKit.COLOR_GOLD))
	col.add_child(UIKit.label(tr(RuwatanRun.step_title_key(kind)), &"HeaderLabel",
		StageNode.COLOR_BOSS if kind == RuwatanRun.Step.BOSS else UIKit.COLOR_TEXT))
	if kind == RuwatanRun.Step.EVENT:
		col.add_child(_wrapped(tr("RUWATAN_EVENT_TEXT"), 296, UIKit.COLOR_TEXT, &"BigLabel"))
	else:
		for spec: EnemySpec in run.enemy_specs():
			var line := UIKit.hbox(4)
			var mask := UIKit.icon(load("res://assets/ui/mask_%s.png" % StageNode.get_buto_key(spec)) as Texture2D)
			mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mask.custom_minimum_size = Vector2(16, 16)
			line.add_child(mask)
			var info := UIKit.vbox(0)
			info.add_child(UIKit.label(_buto_name(spec), &"",
				StageNode.COLOR_MURKA.lightened(0.45) if spec.murka else UIKit.COLOR_TEXT))
			var key := StageNode.get_buto_key(spec)
			info.add_child(UIKit.small_label("HP %d  -  %s" % [run.display_hp(spec), tr("SKILL_" + key.to_upper())], UIKit.COLOR_DIM))
			line.add_child(info)
			col.add_child(line)
	col.add_child(_filler())
	var buttons := UIKit.hbox(8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := UIKit.button(tr("RUWATAN_GO_EVENT" if kind == RuwatanRun.Step.EVENT else "BTN_FIGHT"), 120, true)
	go.pressed.connect(_go)
	var abandon := UIKit.button(tr("RUWATAN_ABANDON"), 110)
	abandon.custom_minimum_size = Vector2(110, 22)
	abandon.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_confirm(tr("RUWATAN_CONFIRM_ABANDON"), func() -> void:
			GameState.abandon_ruwatan()
			_build()))
	buttons.add_child(go)
	buttons.add_child(abandon)
	col.add_child(buttons)


## Menjalankan langkah sekarang: battle atau kejadian.
func _go() -> void:
	var run := GameState.ruwatan
	if run == null or run.is_over() or _overlay.get_child_count() > 0 or SceneRouter.is_busy():
		return
	if run.current_step() == RuwatanRun.Step.EVENT:
		AudioManager.play_sfx("click")
		var panel := EventPanel.new()
		panel.event_id = run.current_event()
		panel.profile = run
		_overlay.add_child(panel)
		await panel.done
		run.finish_event()
		_build()
		return
	GameState.play_mode = GameState.PlayMode.RUWATAN
	AudioManager.play_sfx("bedug")
	SceneRouter.go_to(SceneRouter.BATTLE)

#endregion


#region Berkah, hasil, dan panel kecil

func _offer_blessing() -> void:
	var run := GameState.ruwatan
	var reward := RewardPanel.new()
	reward.profile = run
	_overlay.add_child(reward)
	await reward.done
	run.finish_blessing()
	_build()


func _show_result() -> void:
	var run := GameState.ruwatan
	var won := run.state == RuwatanRun.State.WON
	var root := _overlay_root()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(8)
	panel.add_child(col)
	var title := UIKit.label(tr("RUWATAN_WON_TITLE" if won else "RUWATAN_LOST_TITLE"), &"TitleLabel",
		UIKit.COLOR_GOLD if won else UIKit.COLOR_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var text := tr("RUWATAN_WON_TEXT") % run.level if won else tr("RUWATAN_LOST_TEXT") % [run.step + 1, run.level]
	var body := _wrapped(text, 300, UIKit.COLOR_TEXT, &"BigLabel")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)
	if won:
		var next := tr("RUWATAN_TOP_CLEARED") if run.level >= RuwatanRun.MAX_LEVEL else tr("RUWATAN_UNLOCKED") % (run.level + 1)
		var unlock := UIKit.label(next, &"", UIKit.COLOR_GOLD)
		unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(unlock)
		AudioManager.play_music("victory")
	var done := UIKit.button(tr("RUWATAN_DONE"), 120, true)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_selected_level = mini(run.level + (1 if won else 0), GameState.ruwatan_max_level())
		GameState.abandon_ruwatan()
		root.queue_free()
		_build()
		AudioManager.play_music("map"))
	col.add_child(done)


func _message(title_text: String, text: String) -> void:
	var root := _overlay_root()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(8)
	panel.add_child(col)
	var title := UIKit.label(title_text, &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var body := _wrapped(text, 260, UIKit.COLOR_TEXT, &"BigLabel")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(body)
	var ok := UIKit.button(tr("BTN_CONTINUE"), 120, true)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		root.queue_free())
	col.add_child(ok)


func _confirm(message: String, on_yes: Callable) -> void:
	var root := _overlay_root()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(10)
	panel.add_child(col)
	var text := _wrapped(message, 240, UIKit.COLOR_TEXT, &"BigLabel")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UIKit.button(tr("BTN_YES"), 80, true)
	var no := UIKit.button(tr("BTN_NO"), 80, true)
	row.add_child(yes)
	row.add_child(no)
	col.add_child(row)
	yes.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		root.queue_free()
		on_yes.call())
	no.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		root.queue_free())


func _open_deck() -> void:
	var run := GameState.ruwatan
	if run == null:
		return
	var view := DeckOverview.new()
	view.deck = run.deck
	view.blessings = run.blessings
	view.tooltip = _tooltip
	_overlay.add_child(view)


func _overlay_root() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(UIKit.dimmer(0.7))
	_overlay.add_child(root)
	return root


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.get_child_count() > 0:
		var top := _overlay.get_child(-1)
		# Esc menutup jendela kecil, tapi tidak melewati berkah, kejadian, atau hasil.
		if event.is_action_pressed("pause") and (top is DeckOverview):
			_tooltip.hide_tip()
			top.queue_free()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		SceneRouter.go_to(SceneRouter.MAIN_MENU)
	elif event.is_action_pressed("ui_accept"):
		if GameState.ruwatan == null:
			_start_run()
		else:
			_go()
	else:
		return
	get_viewport().set_input_as_handled()

#endregion
