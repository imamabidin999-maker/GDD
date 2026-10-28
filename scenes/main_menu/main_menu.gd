extends Control
## Menu utama: judul, Eyang Palang berhadapan dengan Buto Hitam di depan candi,
## dan tombol Lanjutkan / Petualangan Baru / Ruwatan / Pustaka / Pengaturan /
## Keluar. Ruwatan terkunci sampai cerita tamat sekali.

const BG := preload("res://assets/backgrounds/menu.png")
const HERO := preload("res://assets/sprites/hero/eyang_palang_idle.png")
const BOSS := preload("res://assets/sprites/buto/buto_hitam_idle.png")
const VERSION := "v1.0"

var _ui: Control
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_scenery()
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_build_ui()
	AudioManager.play_music("menu")


func _build_scenery() -> void:
	var bg := TextureRect.new()
	bg.texture = BG
	bg.position = Vector2(-8, -8)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Sisi kiri digelapkan supaya judul dan tombol mudah dibaca.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.06, 0.88))
	grad.set_color(1, Color(0.02, 0.02, 0.06, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 8
	tex.fill_from = Vector2(0.25, 0)
	tex.fill_to = Vector2(1.0, 0)
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2.ZERO
	shade.size = Vector2(420, 360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var world := Node2D.new()
	add_child(world)
	world.add_child(Ambient.fireflies(Vector2(420, 220), Vector2(240, 120), 22))
	var boss := Ambient.breathing_sprite(BOSS, Vector2(556, 330), false, 1.15)
	boss.modulate = Color(0.85, 0.85, 0.95)
	world.add_child(boss)
	world.add_child(Ambient.breathing_sprite(HERO, Vector2(410, 332)))


func _build_ui() -> void:
	for child: Node in _ui.get_children():
		child.queue_free()

	var col := UIKit.vbox(4)
	col.position = Vector2(36, 34)
	col.size = Vector2(240, 0)
	_ui.add_child(col)

	var title := UIKit.label(tr("GAME_TITLE"), &"TitleLabel", UIKit.COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)
	var subtitle := UIKit.label(tr("GAME_SUBTITLE"), &"HeaderLabel", UIKit.COLOR_TEXT)
	col.add_child(subtitle)
	# Hadiah 30 Bintang Dongkrek: gelar Juru Dongkrek.
	if GameState.master_unlocked():
		var master := UIKit.hbox(3)
		master.add_child(UIKit.icon(preload("res://assets/ui/mini_star.png")))
		master.add_child(UIKit.label(tr("MENU_MASTER_TITLE"), &"", UIKit.COLOR_GOLD))
		master.add_child(UIKit.icon(preload("res://assets/ui/mini_star.png")))
		col.add_child(master)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	col.add_child(spacer)

	var buttons := UIKit.vbox(6)
	col.add_child(buttons)
	if GameState.has_save():
		_add_menu_button(buttons, tr("MENU_CONTINUE"), _on_continue)
	_add_menu_button(buttons, tr("MENU_NEW"), _on_new_game)
	var ruwatan := _add_menu_button(buttons, tr("MENU_RUWATAN"), func() -> void: SceneRouter.go_to(SceneRouter.RUWATAN))
	if not GameState.ruwatan_unlocked:
		ruwatan.disabled = true
		ruwatan.icon = preload("res://assets/ui/padlock.png")
		ruwatan.tooltip_text = tr("MENU_RUWATAN_LOCKED")
		ruwatan.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_menu_button(buttons, tr("MENU_PUSTAKA"), func() -> void: SceneRouter.go_to(SceneRouter.PUSTAKA))
	_add_menu_button(buttons, tr("MENU_SETTINGS"), _open_settings)
	if OS.get_name() != "Web":
		_add_menu_button(buttons, tr("MENU_QUIT"), func() -> void: get_tree().quit())

	var credit := UIKit.small_label(tr("MENU_CREDIT_LINE"), UIKit.COLOR_DIM)
	credit.position = Vector2(12, 342)
	_ui.add_child(credit)
	var version := UIKit.small_label(VERSION, UIKit.COLOR_DIM)
	version.position = Vector2(606, 342)
	_ui.add_child(version)


func _add_menu_button(parent: Control, text: String, action: Callable) -> Button:
	var b := UIKit.button(text, 170, true)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		action.call())
	parent.add_child(b)
	return b


func _on_continue() -> void:
	SceneRouter.go_to(SceneRouter.STAGE_MAP)


func _on_new_game() -> void:
	if not GameState.has_save():
		_start_new_game()
		return
	_confirm(tr("MENU_CONFIRM_NEW"), _start_new_game)


func _start_new_game() -> void:
	GameState.new_game()
	AudioManager.play_sfx("bedug")
	SceneRouter.go_to(SceneRouter.STAGE_MAP)


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	_overlay.add_child(panel)
	panel.closed.connect(_build_ui)


func _confirm(message: String, on_yes: Callable) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(UIKit.dimmer(0.7))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	root.add_child(UIKit.center(panel))
	var col := UIKit.vbox(10)
	panel.add_child(col)
	var text := UIKit.label(message, &"BigLabel", UIKit.COLOR_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(300, 0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UIKit.button(tr("BTN_YES"), 80, true)
	var no := UIKit.button(tr("BTN_NO"), 80, true)
	row.add_child(yes)
	row.add_child(no)
	col.add_child(row)
	_overlay.add_child(root)
	yes.pressed.connect(func() -> void:
		root.queue_free()
		on_yes.call())
	no.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		root.queue_free())
