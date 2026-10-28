class_name PadBindings
extends RefCounted
## Tombol gamepad untuk aksi battle yang bisa diubah pemain di panel Tombol
## Gamepad. Setiap aksi punya satu tombol, dan Jeda selalu juga bisa lewat
## Start. A, D-pad, dan kedua stik dipakai GamepadCursor (klik, kursor, dan
## gulir), jadi tidak bisa dipasang ke aksi.
##
## Pilihan pemain disimpan GameState sebagai {aksi: tombol} (NONE = kosong).
## Aksi yang belum pernah diubah memakai DEFAULTS. Semua fungsi di sini statis
## dan tidak menyentuh GameState, supaya bisa dites.

const ACTIONS: Array[String] = ["ultimate", "end_turn", "target_next", "toggle_speed", "pause"]
const DEFAULTS := {
	"ultimate": JOY_BUTTON_Y,
	"end_turn": JOY_BUTTON_X,
	"target_next": JOY_BUTTON_RIGHT_SHOULDER,
	"toggle_speed": JOY_BUTTON_LEFT_SHOULDER,
	"pause": JOY_BUTTON_B,
}
## Start selalu untuk jeda dan kembali, di samping tombol pilihan pemain.
const PAUSE_FIXED := JOY_BUTTON_START
const NONE := -1
## Nama tombol mengikuti gamepad Xbox (tata letak yang dipakai Godot).
const NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS",
	JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad",
	JOY_BUTTON_DPAD_DOWN: "D-pad",
	JOY_BUTTON_DPAD_LEFT: "D-pad",
	JOY_BUTTON_DPAD_RIGHT: "D-pad",
	JOY_BUTTON_MISC1: "Share",
	JOY_BUTTON_PADDLE1: "P1",
	JOY_BUTTON_PADDLE2: "P2",
	JOY_BUTTON_PADDLE3: "P3",
	JOY_BUTTON_PADDLE4: "P4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}


## Tombol yang tidak bisa dipasang ke aksi: A (klik), D-pad (kursor), Start
## (selalu jeda), dan Guide (biasanya dipakai sistem operasi).
static func is_reserved(button: int) -> bool:
	return button in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_GUIDE,
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]


## Tombol pilihan untuk aksi ini (NONE kalau kosong).
static func button(bindings: Dictionary, action: String) -> int:
	return int(bindings.get(action, DEFAULTS.get(action, NONE)))


## Semua tombol yang menjalankan aksi ini, termasuk Start untuk Jeda.
static func buttons(bindings: Dictionary, action: String) -> Array[int]:
	var out: Array[int] = []
	if action == "pause":
		out.append(PAUSE_FIXED)
	var chosen := button(bindings, action)
	if chosen != NONE and not out.has(chosen):
		out.append(chosen)
	return out


## Memasang `pad_button` ke `action`. Tombol yang sama di aksi lain dilepas
## supaya satu tombol hanya punya satu arti. Mengembalikan aksi yang kehilangan
## tombolnya ("" kalau tidak ada), atau "!" kalau ditolak.
static func assign(bindings: Dictionary, action: String, pad_button: int) -> String:
	if not ACTIONS.has(action) or pad_button < 0 or is_reserved(pad_button):
		return "!"
	var displaced := ""
	for other: String in ACTIONS:
		if other != action and button(bindings, other) == pad_button:
			bindings[other] = NONE
			displaced = other
	bindings[action] = pad_button
	return displaced


static func clear(bindings: Dictionary, action: String) -> void:
	if ACTIONS.has(action):
		bindings[action] = NONE


## Dari simpanan: hanya aksi yang dikenal, tombol yang boleh dipakai, dan
## tidak ada tombol yang dipakai dua aksi.
static func sanitize(data: Variant) -> Dictionary:
	var out := {}
	if not (data is Dictionary):
		return out
	for action: String in ACTIONS:
		if not (data as Dictionary).has(action):
			continue
		var value := int((data as Dictionary)[action])
		if value == NONE or (value >= 0 and value < JOY_BUTTON_MAX and not is_reserved(value)):
			out[action] = value
	# Pilihan pemain didahulukan dari tombol bawaan kalau keduanya bentrok.
	var used := {}
	for explicit: bool in [true, false]:
		for action: String in ACTIONS:
			if out.has(action) != explicit:
				continue
			var b := button(out, action)
			if b == NONE:
				continue
			if used.has(b):
				out[action] = NONE
			else:
				used[b] = true
	return out


static func button_name(pad_button: int) -> String:
	if pad_button == NONE:
		return "-"
	return str(NAMES.get(pad_button, "#%d" % pad_button))
