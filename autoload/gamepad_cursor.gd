extends Node
## Gamepad: stik kiri atau D-pad menggerakkan kursor mouse, tombol A menjadi
## klik kiri (tahan untuk menggeser kartu), dan stik kanan menjadi roda mouse.
## Karena semua bagian game bisa dimainkan dengan mouse, cara ini langsung
## berlaku di semua layar.
##
## Tombol lain dipasang langsung ke aksi lewat KeyBindings.JOYPAD: B dan Start
## untuk jeda/kembali, X akhiri giliran, Y Sapu Jagad, RB ganti sasaran, LB
## kecepatan 1x/2x.

## Kecepatan kursor (piksel layar game per detik) saat stik didorong penuh.
const SPEED := 240.0
## Setelah kursor bergerak sebentar, kecepatannya naik sampai dua kali lipat.
const BOOST_AFTER := 0.5
const BOOST_MAX := 2.0
const DEADZONE := 0.2
## D-pad bergerak lebih pelan supaya bisa membidik dengan tepat.
const DPAD_SPEED := 120.0
## Selama stik kanan didorong, roda mouse diputar satu langkah setiap sekian detik.
const SCROLL_EVERY := 0.08

var _moving_for: float = 0.0
var _held: bool = false
var _scroll_wait: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Aksi ui_* bawaan Godot juga membaca gamepad (A = ui_accept, D-pad dan
	# stik = ui_left dan kawan-kawannya). Di game ini gamepad sudah menjadi
	# mouse, jadi semuanya dilepas supaya satu tekanan tidak terhitung dua
	# kali: A di irama Sapu Jagad, atau D-pad yang ikut menggeser slider.
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			continue
		for ev: InputEvent in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)


## Gerak kursor (piksel per detik) dari stik dan D-pad. Statis supaya bisa dites.
static func cursor_velocity(stick: Vector2, dpad: Vector2, moving_for: float) -> Vector2:
	var length := stick.length()
	var push := Vector2.ZERO
	if length > DEADZONE:
		push = stick / length * minf((length - DEADZONE) / (1.0 - DEADZONE), 1.0)
	var boost := 1.0 + clampf((moving_for - BOOST_AFTER) / BOOST_AFTER, 0.0, 1.0) * (BOOST_MAX - 1.0)
	return push * SPEED * boost + dpad.limit_length(1.0) * DPAD_SPEED


func _process(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var device: int = pads[0]
	_scroll(device, delta)
	var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	var dpad := Vector2(
		float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)),
		float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)))
	var velocity := cursor_velocity(stick, dpad, _moving_for)
	if velocity == Vector2.ZERO:
		_moving_for = 0.0
		return
	_moving_for += delta
	var viewport := get_viewport()
	var limit := viewport.get_visible_rect().size - Vector2.ONE
	var target := (viewport.get_mouse_position() + velocity * delta).clamp(Vector2.ZERO, limit)
	viewport.warp_mouse(target)
	# Gerak buatan juga dikirim, supaya kartu yang sedang digeser ikut bergerak
	# walau sistem operasi tidak mengirim gerak dari warp_mouse.
	var motion := InputEventMouseMotion.new()
	motion.position = viewport.get_final_transform() * target
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	Input.parse_input_event(motion)


## Stik kanan menggulir seperti roda mouse, misalnya di Pustaka.
func _scroll(device: int, delta: float) -> void:
	var push := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	if absf(push) <= DEADZONE:
		_scroll_wait = 0.0
		return
	_scroll_wait -= delta
	if _scroll_wait > 0.0:
		return
	_scroll_wait = SCROLL_EVERY
	var viewport := get_viewport()
	for pressed: bool in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if push > 0.0 else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = pressed
		wheel.factor = 1.0
		wheel.position = viewport.get_final_transform() * viewport.get_mouse_position()
		wheel.global_position = wheel.position
		Input.parse_input_event(wheel)


func _input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button == null or button.button_index != JOY_BUTTON_A or button.pressed == _held:
		return
	_held = button.pressed
	var viewport := get_viewport()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = button.pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if button.pressed else 0
	click.position = viewport.get_final_transform() * viewport.get_mouse_position()
	click.global_position = click.position
	Input.parse_input_event(click)
	viewport.set_input_as_handled()
