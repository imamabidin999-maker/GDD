extends Control
## Akhir cerita: fajar di Mejayan setelah Buto Hitam kalah, dialog penutup,
## lalu judul "Pagebluk Sirna" dan kredit.

const BG := preload("res://assets/backgrounds/ending.png")
const HERO := preload("res://assets/sprites/hero/eyang_palang_idle.png")

var _overlay: Control
var _bg: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = TextureRect.new()
	_bg.texture = BG
	_bg.position = Vector2(-8, -8)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.modulate = Color(0.55, 0.55, 0.7)
	add_child(_bg)
	# Langit perlahan menghangat seperti fajar.
	var dawn := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.62, 0.36, 0.5))
	grad.set_color(1, Color(1.0, 0.62, 0.36, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 8
	tex.height = 64
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	dawn.texture = tex
	dawn.stretch_mode = TextureRect.STRETCH_SCALE
	dawn.size = Vector2(640, 220)
	dawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn.modulate.a = 0.0
	add_child(dawn)

	var world := Node2D.new()
	add_child(world)
	var motes := Ambient.fireflies(Vector2(320, 200), Vector2(320, 140), 26)
	world.add_child(motes)
	world.add_child(Ambient.breathing_sprite(HERO, Vector2(320, 228)))

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	var t := create_tween().set_parallel()
	t.tween_property(_bg, "modulate", Color.WHITE, 6.0)
	t.tween_property(dawn, "modulate:a", 0.35, 6.0)
	AudioManager.play_music("victory")
	_run.call_deferred()


func _run() -> void:
	var catalog := StageCatalog.load_default()
	var box := DialogBox.new()
	_overlay.add_child(box)
	await box.play(catalog.ending_dialog)
	AudioManager.play_music("menu")
	AudioManager.play_sfx("gong")
	_show_credits()


func _show_credits() -> void:
	var col := UIKit.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	panel.add_child(col)
	var center := UIKit.center(panel)
	center.modulate.a = 0.0
	_overlay.add_child(center)

	var title := UIKit.label(tr("ENDING_TITLE"), &"TitleLabel", UIKit.COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var credits_title := UIKit.label(tr("CREDITS_TITLE"), &"HeaderLabel")
	credits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(credits_title)
	var text := UIKit.label(tr("CREDITS_TEXT"), &"BigLabel", UIKit.COLOR_TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(500, 0)
	col.add_child(text)
	var end := UIKit.label(tr("ENDING_THANKS"), &"HeaderLabel", UIKit.COLOR_GOLD)
	end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(end)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var to_menu := UIKit.button(tr("BTN_MAIN_MENU"), 120, true)
	var to_map := UIKit.button(tr("BTN_TO_MAP"), 120, true)
	row.add_child(to_map)
	row.add_child(to_menu)
	col.add_child(row)
	to_menu.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		SceneRouter.go_to(SceneRouter.MAIN_MENU))
	to_map.pressed.connect(func() -> void:
		AudioManager.play_sfx("click")
		SceneRouter.go_to(SceneRouter.STAGE_MAP))
	var t := center.create_tween()
	t.tween_property(center, "modulate:a", 1.0, 1.2)
