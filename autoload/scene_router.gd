extends CanvasLayer
## Pindah scene dengan transisi fade hitam.
##
## Pemakaian: SceneRouter.go_to(SceneRouter.BATTLE)

signal scene_changed(path: String)

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const STAGE_MAP := "res://scenes/stage_map/stage_map.tscn"
const BATTLE := "res://scenes/battle/battle_scene.tscn"
const PUSTAKA := "res://scenes/pustaka/pustaka.tscn"
const ENDING := "res://scenes/ending/ending.tscn"

const FADE_TIME := 0.25

## Scene sebelum perpindahan terakhir (dipakai tombol Kembali di Pustaka).
var previous_path: String = ""

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.03, 0.06, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


## Kembali ke scene sebelumnya, atau ke `fallback` kalau tidak ada.
func go_back(fallback: String = MAIN_MENU) -> void:
	go_to(previous_path if previous_path != "" else fallback)


func is_busy() -> bool:
	return _busy


func go_to(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await out.finished
	get_tree().paused = false
	var current := get_tree().current_scene
	if current != null and current.scene_file_path != path:
		previous_path = current.scene_file_path
	get_tree().change_scene_to_file(path)
	# Tunggu satu frame supaya scene baru sempat _ready sebelum layar dibuka.
	await get_tree().process_frame
	scene_changed.emit(path)
	var back := create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
