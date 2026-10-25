extends Control
## Peta perjalanan Eyang Palang: sepuluh babak dari Desa Mejayan sampai
## Candi Pagebluk, dibagi tiga bagian cerita. Klik titik untuk melihat lawannya, lalu Bertarung.
## Prolog diputar sekali saat peta pertama kali dibuka.

const BG := preload("res://assets/backgrounds/map_mejayan.png")
const HERO := preload("res://assets/sprites/hero/eyang_palang_idle.png")
const HEART := preload("res://assets/ui/mini_heart.png")
const DECK := preload("res://assets/ui/mini_deck.png")
const HERO_SCALE := 0.3
const HERO_OFFSET := Vector2(-24, 10)

var _catalog: StageCatalog
var _nodes: Array[StageNode] = []
var _selected: StageNode
var _hero: Sprite2D
var _node_layer: Control
var _ui: Control
var _overlay: Control
var _tooltip: GameTooltip
var _info_col: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catalog = StageCatalog.load_default()

	var bg := TextureRect.new()
	bg.texture = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var world := Node2D.new()
	add_child(world)
	world.add_child(Ambient.fireflies(Vector2(320, 230), Vector2(320, 120), 16))

	_node_layer = Control.new()
	_node_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_node_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_node_layer)
	_hero = Ambient.breathing_sprite(HERO, Vector2.ZERO, false, HERO_SCALE)
	world.add_child(_hero)

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

	_build_nodes()
	_build_ui()
	var start := _nodes[_default_stage() - 1]
	_hero.position = start.stage.map_position + HERO_OFFSET
	_select(start, false)
	AudioManager.play_music("map")
	if not GameState.prologue_seen:
		_play_prologue.call_deferred()


func _default_stage() -> int:
	for n: int in range(1, GameState.STAGE_COUNT + 1):
		if GameState.is_stage_unlocked(n) and not GameState.is_stage_cleared(n):
			return n
	return clampi(GameState.current_stage, 1, GameState.STAGE_COUNT)


func _build_nodes() -> void:
	for n: int in range(1, GameState.STAGE_COUNT + 1):
		var stage := _catalog.get_stage(n)
		if stage == null:
			continue
		var state := StageNode.State.LOCKED
		if GameState.is_stage_cleared(n):
			state = StageNode.State.CLEARED
		elif GameState.is_stage_unlocked(n):
			state = StageNode.State.OPEN
		var node := StageNode.new()
		node.setup(stage, state)
		node.pressed.connect(_on_node_pressed)
		node.hover_changed.connect(_on_node_hover)
		_node_layer.add_child(node)
		_nodes.append(node)


#region UI

func _build_ui() -> void:
	for child: Node in _ui.get_children():
		child.queue_free()

	var bar := PanelContainer.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(640, 22)
	bar.custom_minimum_size = Vector2(640, 22)
	_ui.add_child(bar)
	var row := UIKit.hbox(6)
	bar.add_child(row)
	row.add_child(UIKit.label(tr("MAP_TITLE"), &"HeaderLabel"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	row.add_child(UIKit.icon(HEART))
	row.add_child(UIKit.label(tr("MAP_HP") % GameState.max_hp, &"", UIKit.COLOR_TEXT))
	if GameState.game_completed:
		row.add_child(_bar_button(tr("MAP_ENDING"), func() -> void: SceneRouter.go_to(SceneRouter.ENDING)))
	var deck := _bar_button(tr("MAP_DECK"), _open_deck)
	deck.icon = DECK
	row.add_child(deck)
	row.add_child(_bar_button(tr("MENU_PUSTAKA"), func() -> void: SceneRouter.go_to(SceneRouter.PUSTAKA)))
	row.add_child(_bar_button(tr("MAP_MENU"), _open_menu))

	var hint_text := tr("MAP_ALL_CLEAR") if GameState.game_completed else tr("MAP_HINT")
	var hint := UIKit.small_label(hint_text, UIKit.COLOR_DIM)
	hint.position = Vector2(8, 32)
	_ui.add_child(hint)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.position = Vector2(430, 196)
	panel.custom_minimum_size = Vector2(202, 156)
	panel.size = Vector2(202, 156)
	_ui.add_child(panel)
	_info_col = UIKit.vbox(3)
	panel.add_child(_info_col)
	if _selected != null:
		_fill_info(_selected)


func _bar_button(text: String, action: Callable) -> Button:
	var b := UIKit.button(text)
	b.custom_minimum_size = Vector2(0, 16)
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		action.call())
	return b


func _fill_info(node: StageNode) -> void:
	for child: Node in _info_col.get_children():
		child.queue_free()
	var stage := node.stage
	var head := UIKit.hbox(6)
	head.add_child(UIKit.small_label(tr("MAP_STAGE") % stage.stage_number, UIKit.COLOR_GOLD))
	if stage.is_boss:
		head.add_child(UIKit.small_label(tr("MAP_BOSS"), StageNode.COLOR_BOSS))
	if node.state == StageNode.State.CLEARED:
		head.add_child(UIKit.small_label(tr("MAP_CLEARED"), StageNode.COLOR_CLEARED))
	_info_col.add_child(head)
	_info_col.add_child(UIKit.small_label(tr("CHAPTER_%d" % stage.chapter),
		StageNode.COLOR_MURKA.lightened(0.35) if stage.chapter >= 2 else UIKit.COLOR_DIM))
	_info_col.add_child(UIKit.label(tr(stage.title_key), &"HeaderLabel"))

	if node.state == StageNode.State.LOCKED:
		_info_col.add_child(UIKit.label(tr("MAP_LOCKED"), &"", StageNode.COLOR_LOCKED))
		var why := UIKit.label(tr("MAP_LOCKED_HINT"), &"", UIKit.COLOR_DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(186, 0)
		_info_col.add_child(why)
		return

	# Lebih dari dua lawan (babak 9) tidak muat satu per baris, jadi dibuat
	# dua kolom ringkas tanpa nama ilmu.
	var compact := stage.enemies.size() > 2
	var list: Container
	if compact:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 2)
		list = grid
	else:
		_info_col.add_child(UIKit.small_label(tr("MAP_ENEMIES"), UIKit.COLOR_DIM))
		list = UIKit.vbox(3)
	_info_col.add_child(list)
	for spec: EnemySpec in stage.enemies:
		var key := StageNode.get_buto_key(spec)
		var line := UIKit.hbox(4)
		var mask := UIKit.icon(load("res://assets/ui/mask_%s.png" % key) as Texture2D)
		mask.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mask.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mask.custom_minimum_size = Vector2(16, 16)
		line.add_child(mask)
		var info := UIKit.vbox(0)
		var buto_name := tr("BUTO_" + key.to_upper())
		if compact:
			buto_name = buto_name.trim_prefix("Buto ")
		if spec.murka:
			buto_name = tr("BUTO_MURKA_FMT") % buto_name
		var name_color := StageNode.COLOR_MURKA.lightened(0.45) if spec.murka else UIKit.COLOR_TEXT
		info.add_child(UIKit.label(buto_name, &"", name_color))
		var detail := "HP %d" % spec.max_hp
		if not compact:
			detail += "  -  " + tr("SKILL_" + key.to_upper())
		info.add_child(UIKit.small_label(detail, UIKit.COLOR_DIM))
		line.add_child(info)
		list.add_child(line)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_col.add_child(filler)
	if node.state == StageNode.State.CLEARED:
		_info_col.add_child(UIKit.small_label(tr("MAP_REPLAY"), UIKit.COLOR_DIM))
	var fight := UIKit.button(tr("BTN_FIGHT"), 120, true)
	fight.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fight.pressed.connect(_start_battle)
	_info_col.add_child(fight)

#endregion


#region Pilih stage

func _on_node_pressed(node: StageNode) -> void:
	if node == _selected and node.state != StageNode.State.LOCKED:
		_start_battle()
		return
	_select(node, true)


func _on_node_hover(node: StageNode, hovering: bool) -> void:
	if hovering:
		_tooltip.show_text("[b]%s[/b]\n%s" % [tr("MAP_STAGE") % node.stage.stage_number, tr(node.stage.title_key)],
			node.position + Vector2(node.size.x + 4, 0))
	else:
		_tooltip.hide_tip()


func _select(node: StageNode, with_sound: bool) -> void:
	if _selected != null:
		_selected.selected = false
	_selected = node
	node.selected = true
	if with_sound:
		AudioManager.play_sfx("kentongan" if node.state != StageNode.State.LOCKED else "error")
	if node.state != StageNode.State.LOCKED:
		GameState.current_stage = node.stage.stage_number
		var target := node.stage.map_position + HERO_OFFSET
		var t := create_tween()
		t.tween_property(_hero, "position", target, 0.35).set_trans(Tween.TRANS_SINE)
	if _info_col != null:
		_fill_info(node)


func _start_battle() -> void:
	if _selected == null or _selected.state == StageNode.State.LOCKED or SceneRouter.is_busy():
		return
	GameState.current_stage = _selected.stage.stage_number
	AudioManager.play_sfx("bedug")
	SceneRouter.go_to(SceneRouter.BATTLE)


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.get_child_count() > 0:
		# Esc menutup overlay paling atas (kecuali dialog cerita).
		var top := _overlay.get_child(-1)
		if event.is_action_pressed("pause") and not (top is DialogBox):
			_tooltip.hide_tip()
			top.queue_free()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_open_menu()
	elif event.is_action_pressed("ui_accept"):
		_start_battle()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		var step := 1 if event.is_action_pressed("ui_right") else -1
		var idx := clampi(_nodes.find(_selected) + step, 0, _nodes.size() - 1)
		_select(_nodes[idx], true)
	else:
		return
	get_viewport().set_input_as_handled()

#endregion


#region Overlay: prolog, deck, menu

func _play_prologue() -> void:
	var box := DialogBox.new()
	_overlay.add_child(box)
	await box.play(_catalog.prologue_dialog)
	GameState.prologue_seen = true
	GameState.save_game()


func _open_deck() -> void:
	var root := _overlay_root()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
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
	var specs := GameState.deck.duplicate()
	specs.sort_custom(DeckPicker.compare_specs)
	for spec: String in specs:
		var data := CardDB.card_from_spec(spec)
		if data == null:
			continue
		grid.add_child(_card_with_tooltip(data))

	col.add_child(_blessing_row())

	var close := UIKit.button(tr("BTN_CLOSE"), 120, true)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		_tooltip.hide_tip()
		root.queue_free())
	col.add_child(close)


## Berkah yang dimiliki: ikon dengan keterangan saat disorot.
func _blessing_row() -> Control:
	var row := UIKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UIKit.label(tr("BLESS_OWNED"), &"", UIKit.COLOR_GOLD))
	if GameState.blessings.is_empty():
		row.add_child(UIKit.label(tr("BLESS_NONE"), &"", UIKit.COLOR_DIM))
		return row
	var counts := {}
	for entry: String in GameState.blessings:
		counts[entry] = int(counts.get(entry, 0)) + 1
	for entry: String in counts:
		var kind := Blessings.from_name(entry)
		if kind < 0:
			continue
		var tex: Texture2D = RewardPanel.BLESS_ICONS[kind]
		var ic := UIKit.icon(tex)
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		var text := "[b][color=#ffd36e]%s[/color][/b]\n%s" % [tr(Blessings.text_key(kind)), tr(Blessings.text_key(kind) + "_DESC")]
		if int(counts[entry]) > 1:
			text = "[b][color=#ffd36e]%s x%d[/color][/b]\n%s" % [tr(Blessings.text_key(kind)), int(counts[entry]), tr(Blessings.text_key(kind) + "_DESC")]
		ic.mouse_entered.connect(func() -> void: _tooltip.show_text(text, ic.global_position + Vector2(0, -40)))
		ic.mouse_exited.connect(_tooltip.hide_tip)
		row.add_child(ic)
		if int(counts[entry]) > 1:
			row.add_child(UIKit.small_label("x%d" % int(counts[entry]), UIKit.COLOR_TEXT))
	return row


## Kartu ukuran asli (skala pecahan merusak piksel) dengan tooltip saat disorot.
func _card_with_tooltip(data: CardData) -> Control:
	var view := CardView.preview(data)
	view.hover_changed.connect(func(v: CardView, on: bool) -> void:
		if on:
			_tooltip.show_text(v.get_tooltip_bbcode(), v.global_position + Vector2(v.size.x + 4, 0))
		else:
			_tooltip.hide_tip())
	return view


func _open_menu() -> void:
	var root := _overlay_root()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(6)
	panel.add_child(col)
	var title := UIKit.label(tr("MAP_MENU"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var resume := UIKit.button(tr("BTN_CLOSE"), 160, true)
	var settings := UIKit.button(tr("MENU_SETTINGS"), 160, true)
	var to_menu := UIKit.button(tr("BTN_MAIN_MENU"), 160, true)
	for b: Button in [resume, settings, to_menu]:
		col.add_child(b)
	resume.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		root.queue_free())
	settings.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		var s := SettingsPanel.new()
		root.add_child(s)
		s.closed.connect(func() -> void:
			_build_ui()
			root.queue_free()))
	to_menu.pressed.connect(func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU))


func _overlay_root() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(UIKit.dimmer(0.7))
	_overlay.add_child(root)
	return root

#endregion
