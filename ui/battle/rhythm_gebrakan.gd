class_name RhythmGebrakan
extends Control
## Permainan irama singkat saat Gebrakan Dongkrek dipakai.
##
## Enam ketukan "dung" (bedug) dan "krek" (korek) berjalan dari kanan ke
## lingkaran sasaran. Tekan klik kiri, Spasi, Enter, atau tombol Gebrakan
## tepat saat ketukan masuk lingkaran:
##   tepat  (selisih <= PERFECT_MS) bernilai 1
##   cukup  (selisih <= GOOD_MS)    bernilai 0,5
##   meleset                         bernilai 0
## Bonus damage Gebrakan = rata-rata nilai x MAX_BONUS. Meleset semua tidak
## mengurangi damage.
##
## Waktu diambil dari jam sungguhan (bukan delta yang ikut kecepatan battle),
## jadi kecepatan 2x tidak mempercepat iramanya.

## Selesai. score 0..1; bonus damage = 1 + score * MAX_BONUS.
signal finished(score: float)

enum Note { DUNG, KREK }

const PERFECT_MS := 70
const GOOD_MS := 140
const MAX_BONUS := 0.3
const BEAT_MS := 480
const LEAD_IN_MS := 1300
const SPEED := 0.24 # piksel per milidetik
const HIT_X := 64.0
const TRACK_SIZE := Vector2(420, 54)
## Pola ketukan: [ketukan ke-, jenis]. Paling dekat setengah ketukan.
const PATTERNS := [
	[[0.0, Note.DUNG], [1.0, Note.DUNG], [2.0, Note.KREK], [3.0, Note.DUNG], [3.5, Note.DUNG], [4.0, Note.KREK]],
	[[0.0, Note.DUNG], [1.0, Note.KREK], [2.0, Note.DUNG], [2.5, Note.KREK], [3.0, Note.DUNG], [4.0, Note.KREK]],
	[[0.0, Note.DUNG], [0.5, Note.DUNG], [1.5, Note.KREK], [2.5, Note.DUNG], [3.0, Note.DUNG], [4.0, Note.KREK]],
]

## Waktu tiap ketukan (ms sejak mulai) dan jenisnya.
var note_times: Array[int] = []
var note_kinds: Array[int] = []
## Nilai tiap ketukan: -1 belum dinilai, 0 meleset, 0.5 cukup, 1 tepat.
var judgements: Array[float] = []
## Untuk tes: kalau >= 0 dipakai sebagai "sekarang" (ms), bukan jam sungguhan.
var manual_time_ms: int = -1

var _start_usec: int = 0
var _track: Control
var _result_label: Label
var _feedback: Label
var _done: bool = false


## Nilai satu tekanan dari selisih waktunya (ms, boleh negatif).
static func judge(delta_ms: int) -> float:
	var d := absi(delta_ms)
	if d <= PERFECT_MS:
		return 1.0
	if d <= GOOD_MS:
		return 0.5
	return 0.0


static func bonus_for(score: float) -> float:
	return 1.0 + clampf(score, 0.0, 1.0) * MAX_BONUS


func _init() -> void:
	set_pattern(PATTERNS[randi() % PATTERNS.size()])


func set_pattern(pattern: Array) -> void:
	note_times.clear()
	note_kinds.clear()
	judgements.clear()
	for entry: Array in pattern:
		note_times.append(LEAD_IN_MS + roundi(float(entry[0]) * BEAT_MS))
		note_kinds.append(int(entry[1]))
		judgements.append(-1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := UIKit.dimmer(0.45)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	var col := UIKit.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var title := UIKit.label(tr("RHYTHM_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UIKit.small_label(tr("RHYTHM_HINT"), UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_track = Control.new()
	_track.custom_minimum_size = TRACK_SIZE
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	col.add_child(_track)
	_feedback = UIKit.label("", &"BigLabel", UIKit.COLOR_GOLD)
	_feedback.position = Vector2(HIT_X - 30, 0)
	_feedback.size = Vector2(60, 16)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_track.add_child(_feedback)
	_result_label = UIKit.label("", &"HeaderLabel", UIKit.COLOR_GOLD)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result_label)
	_start_usec = Time.get_ticks_usec()


func now_ms() -> int:
	if manual_time_ms >= 0:
		return manual_time_ms
	return int((Time.get_ticks_usec() - _start_usec) / 1000)


func _process(_delta: float) -> void:
	if _done:
		return
	_mark_misses(now_ms())
	_track.queue_redraw()
	if now_ms() > note_times[-1] + GOOD_MS + 250:
		_finish()


## Menilai satu tekanan di waktu `at_ms`. Mengembalikan nilainya, atau -1
## kalau tidak ada ketukan yang cukup dekat (tekanan diabaikan).
func press(at_ms: int) -> float:
	var best := -1
	var best_delta := 1 << 30
	for i: int in note_times.size():
		if judgements[i] >= 0.0:
			continue
		var delta := at_ms - note_times[i]
		if absi(delta) <= GOOD_MS and absi(delta) < absi(best_delta):
			best = i
			best_delta = delta
	if best < 0:
		return -1.0
	var value := judge(best_delta)
	judgements[best] = value
	if is_inside_tree():
		_sfx("bedug" if note_kinds[best] == Note.DUNG else "korek", 0.03)
		_show_feedback(value)
	return value


## Ketukan yang lewat tanpa ditekan dinilai meleset.
func _mark_misses(at_ms: int) -> void:
	for i: int in note_times.size():
		if judgements[i] < 0.0 and at_ms - note_times[i] > GOOD_MS:
			judgements[i] = 0.0
			if is_inside_tree():
				_show_feedback(0.0)


func score() -> float:
	var total := 0.0
	for value: float in judgements:
		total += maxf(value, 0.0)
	return total / maxf(1.0, float(judgements.size()))


# Lewat node, bukan nama autoload, supaya kelas ini bisa dipakai tes yang
# dikompilasi sebelum autoload terdaftar.
func _sfx(key: String, jitter: float, volume_db: float = 0.0) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", key, jitter, volume_db)


func _show_feedback(value: float) -> void:
	if value >= 1.0:
		_feedback.text = tr("RHYTHM_PERFECT")
		_feedback.add_theme_color_override("font_color", UIKit.COLOR_GOLD)
	elif value > 0.0:
		_feedback.text = tr("RHYTHM_GOOD")
		_feedback.add_theme_color_override("font_color", UIKit.COLOR_TEXT)
	else:
		_feedback.text = tr("RHYTHM_MISS")
		_feedback.add_theme_color_override("font_color", UIKit.COLOR_DIM)
	_feedback.modulate.a = 1.0
	var t := _feedback.create_tween()
	t.tween_interval(0.25)
	t.tween_property(_feedback, "modulate:a", 0.0, 0.25)


func _finish() -> void:
	if _done:
		return
	_done = true
	var final := score()
	_result_label.text = tr("RHYTHM_RESULT") % roundi((bonus_for(final) - 1.0) * 100.0)
	_sfx("gong", 0.0, -4.0)
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_callback(func() -> void:
		finished.emit(final)
		queue_free())


func _input(event: InputEvent) -> void:
	if _done:
		return
	var hit := false
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		hit = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ultimate"):
		hit = true
	if hit:
		press(now_ms())
		get_viewport().set_input_as_handled()


func _draw_track() -> void:
	var mid := TRACK_SIZE.y * 0.5 + 6.0
	_track.draw_rect(Rect2(Vector2(8, mid - 1), Vector2(TRACK_SIZE.x - 16, 2)), Color(0.35, 0.3, 0.25))
	_track.draw_arc(Vector2(HIT_X, mid), 15.0, 0.0, TAU, 32, UIKit.COLOR_GOLD, 2.0)
	_track.draw_arc(Vector2(HIT_X, mid), 11.0, 0.0, TAU, 32, Color(UIKit.COLOR_GOLD, 0.35), 1.0)
	var now := now_ms()
	for i: int in note_times.size():
		var x := HIT_X + (note_times[i] - now) * SPEED
		if x < -10.0 or x > TRACK_SIZE.x + 10.0:
			continue
		var judged := judgements[i] >= 0.0
		var alpha := 0.25 if judged else 1.0
		var c := Vector2(x, mid)
		if note_kinds[i] == Note.DUNG:
			_track.draw_circle(c, 10.0, Color(0.38, 0.22, 0.12, alpha))
			_track.draw_circle(c, 7.0, Color(0.91, 0.84, 0.66, alpha))
		else:
			_track.draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), Color(0.38, 0.22, 0.12, alpha))
			_track.draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color(0.75, 0.55, 0.32, alpha))
			for k: int in 3:
				_track.draw_line(c + Vector2(-4 + k * 4, -5), c + Vector2(-4 + k * 4, 5), Color(0.3, 0.18, 0.1, alpha), 1.0)
