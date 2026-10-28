class_name KeyBindings
extends RefCounted
## Tombol keyboard yang bisa diubah pemain di Pengaturan.
##
## Setiap aksi punya dua slot tombol. Yang disimpan kode fisik tombol
## (physical_keycode), jadi letaknya sama di keyboard QWERTY maupun AZERTY;
## namanya ditampilkan mengikuti tata letak keyboard pemain.
##
## Pilihan pemain disimpan GameState sebagai {aksi: [kode, kode]} (0 = slot
## kosong). Aksi yang belum pernah diubah memakai DEFAULTS. Semua fungsi di
## sini statis dan tidak menyentuh GameState, supaya bisa dites.

const SLOTS := 2
const CARD_KEYS := 9
const ACTIONS: Array[String] = [
	"ultimate", "end_turn", "target_next", "toggle_speed", "pause",
	"card_1", "card_2", "card_3", "card_4", "card_5", "card_6", "card_7", "card_8", "card_9",
]
const DEFAULTS := {
	"ultimate": [KEY_Q, 0],
	"end_turn": [KEY_E, KEY_SPACE],
	"target_next": [KEY_TAB, 0],
	"toggle_speed": [KEY_F, 0],
	"pause": [KEY_ESCAPE, 0],
	"card_1": [KEY_1, 0],
	"card_2": [KEY_2, 0],
	"card_3": [KEY_3, 0],
	"card_4": [KEY_4, 0],
	"card_5": [KEY_5, 0],
	"card_6": [KEY_6, 0],
	"card_7": [KEY_7, 0],
	"card_8": [KEY_8, 0],
	"card_9": [KEY_9, 0],
}
## Esc selalu untuk jeda, kembali, dan membatalkan. Slot pertama Jeda tidak
## bisa diubah, dan Esc tidak bisa dipasang ke aksi lain.
const RESERVED := KEY_ESCAPE
## Tombol gamepad untuk aksi battle (tetap, tidak bisa diubah). Kursor dan
## klik gamepad diurus autoload GamepadCursor.
const JOYPAD := {
	"ultimate": [JOY_BUTTON_Y],
	"end_turn": [JOY_BUTTON_X],
	"target_next": [JOY_BUTTON_RIGHT_SHOULDER],
	"toggle_speed": [JOY_BUTTON_LEFT_SHOULDER],
	"pause": [JOY_BUTTON_START, JOY_BUTTON_B],
}


static func is_locked(action: String, slot: int) -> bool:
	return action == "pause" and slot == 0


## Kode tombol aksi ini (selalu SLOTS buah, 0 = kosong).
static func codes(bindings: Dictionary, action: String) -> Array[int]:
	var raw: Variant = bindings.get(action, DEFAULTS.get(action, []))
	var out: Array[int] = []
	for i: int in SLOTS:
		out.append(int(raw[i]) if raw is Array and i < (raw as Array).size() else 0)
	if action == "pause":
		out[0] = RESERVED
	return out


## Memasang semua tombol (dan tombol gamepad) ke InputMap. Aksi yang belum ada dibuat dulu.
static func apply(bindings: Dictionary) -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code: int in codes(bindings, action):
			if code != 0:
				var ev := InputEventKey.new()
				ev.physical_keycode = code as Key
				InputMap.action_add_event(action, ev)
		for button: int in JOYPAD.get(action, []):
			var pad := InputEventJoypadButton.new()
			pad.button_index = button as JoyButton
			pad.device = -1
			InputMap.action_add_event(action, pad)


## Memasang `code` ke slot `slot` aksi `action`. Tombol yang sama di aksi
## lain dilepas supaya satu tombol hanya punya satu arti. Mengembalikan aksi
## yang kehilangan tombolnya ("" kalau tidak ada), atau "!" kalau ditolak.
static func assign(bindings: Dictionary, action: String, slot: int, code: int) -> String:
	if not ACTIONS.has(action) or slot < 0 or slot >= SLOTS or is_locked(action, slot) or code == RESERVED or code == 0:
		return "!"
	var displaced := ""
	for other: String in ACTIONS:
		var list := codes(bindings, other)
		var changed := false
		for i: int in SLOTS:
			if list[i] == code and not (other == action and i == slot) and not is_locked(other, i):
				list[i] = 0
				changed = true
		if changed:
			bindings[other] = list
			if other != action:
				displaced = other
	var mine := codes(bindings, action)
	mine[slot] = code
	bindings[action] = mine
	return displaced


static func clear(bindings: Dictionary, action: String, slot: int) -> void:
	if not ACTIONS.has(action) or is_locked(action, slot):
		return
	var mine := codes(bindings, action)
	mine[slot] = 0
	bindings[action] = mine


## Nama satu tombol, misalnya "Q", "Spasi", "Tab".
static func key_name(code: int) -> String:
	if code == 0:
		return "-"
	var logical := code
	if DisplayServer.get_name() != "headless":
		var mapped := DisplayServer.keyboard_get_keycode_from_physical(code as Key)
		if mapped != KEY_NONE:
			logical = mapped
	var name := OS.get_keycode_string(logical as Key)
	match name:
		"Space":
			return TranslationServer.translate("KEYNAME_SPACE")
		"Escape":
			return "Esc"
	return name


## Nama semua tombol aksi ini, misalnya "E / Spasi". "-" kalau kosong.
static func names(bindings: Dictionary, action: String) -> String:
	var parts: Array[String] = []
	for code: int in codes(bindings, action):
		if code != 0:
			parts.append(key_name(code))
	return " / ".join(parts) if not parts.is_empty() else "-"


## Mengganti {aksi} di teks dengan nama tombolnya, misalnya "tekan {ultimate}".
static func fill(text: String, bindings: Dictionary) -> String:
	if not text.contains("{"):
		return text
	for action: String in ACTIONS:
		text = text.replace("{%s}" % action, names(bindings, action))
	return text


## Pilihan tersimpan yang valid saja (dari simpanan yang mungkin rusak).
static func sanitize(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for key: Variant in raw:
		var action := str(key)
		var value: Variant = (raw as Dictionary)[key]
		if not ACTIONS.has(action) or not (value is Array):
			continue
		var list: Array[int] = []
		for i: int in SLOTS:
			var code := int((value as Array)[i]) if i < (value as Array).size() else 0
			list.append(0 if code == RESERVED and not is_locked(action, i) else code)
		out[action] = list
	return out
