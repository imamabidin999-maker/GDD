class_name RhythmGebrakan
extends Control
## Permainan irama singkat saat Sapu Jagad dipakai.
##
## Iringan gamelan dimulai dengan empat hitungan kentongan ("tok tok tok
## tok"), lalu enam ketukan "dung" (bedug, bulat) dan "krek" (korek, kotak)
## berjalan dari kanan ke lingkaran sasaran mengikuti irama. Tekan klik kiri,
## Spasi, Enter, atau Q tepat saat ketukan masuk lingkaran:
##   tepat  (selisih <= PERFECT_MS) bernilai 1
##   cukup  (selisih <= GOOD_MS)    bernilai 0,5
##   meleset                         bernilai 0
## Bonus damage Gebrakan = rata-rata nilai x MAX_BONUS. Meleset semua tidak
## mengurangi damage.
##
## Temponya pelan dan ketukannya selalu jatuh di ketukan bulat, seperti tabuhan
## dung-krek yang berselang-seling. Angka waktunya sama dengan iringan di
## tools/build_audio.py. Waktu diambil dari jam sungguhan, jadi kecepatan
## battle 2x tidak mempercepat iramanya.

## Selesai. score 0..1; bonus damage = 1 + score * MAX_BONUS.
signal finished(score: float)

enum Note { DUNG, KREK }

const PERFECT_MS := 90
const GOOD_MS := 180
const MAX_BONUS := 0.3
const BEAT_MS := 700
## Jeda sebelum hitungan kentongan pertama.
const PRE_ROLL_MS := 500
## Hitungan kentongan sebelum ketukan pertama.
const COUNT_IN := 4
const SPEED := 0.15 # piksel per milidetik
const HIT_X := 70.0
const TRACK_SIZE := Vector2(440, 62)
const BACKING := "res://assets/audio/sfx/gebrakan_iringan.ogg"
## Pola ketukan: [ketukan ke-, jenis]. Jaraknya paling dekat satu ketukan.
const PATTERNS := [
	[[0, Note.DUNG], [1, Note.KREK], [2, Note.DUNG], [3, Note.KREK], [4, Note.DUNG], [5, Note.KREK]],
	[[0, Note.DUNG], [1, Note.DUNG], [2, Note.KREK], [4, Note.DUNG], [5, Note.DUNG], [6, Note.KREK]],
	[[0, Note.DUNG], [1, Note.KREK], [3, Note.DUNG], [4, Note.KREK], [5, Note.DUNG], [6, Note.KREK]],
]

## Waktu tiap ketukan (ms sejak mulai) dan jenisnya.
var note_times: Array[int] = []
var note_kinds: Array[int] = []
## Nilai tiap ketukan: -1 belum dinilai, 0 meleset, 0.5 cukup, 1 tepat.
var judgements: Array[float] = []
## Untuk tes: kalau >= 0 dipakai sebagai "sekarang" (ms), bukan jam sungguhan.
var manual_time_ms: int = -1
## Tampilkan cara bermain dulu, lalu mulai setelah tombol Mulai ditekan.
var show_intro: bool = false

var _start_usec: int = 0
var _started: bool = false
var _done: bool = false
var _col: VBoxContainer
var _intro: VBoxContainer
var _hint: Label
var _track: Control
var _result_label: Label
var _feedback: Label
var _audio: AudioStreamPlayer


## Waktu ketukan pertama (ms), setelah jeda dan hitungan kentongan.
static func first_note_ms() -> int:
	return PRE_ROLL_MS + COUNT_IN * BEAT_MS


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
		note_times.append(first_note_ms() + int(entry[0]) * BEAT_MS)
		note_kinds.append(int(entry[1]))
		judgements.append(-1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dimmer(0.45))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	add_child(UIKit.center(panel))
	_col = UIKit.vbox(4)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_col)
	var title := UIKit.label(tr("RHYTHM_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(title)
	_hint = UIKit.small_label(tr("RHYTHM_HINT"), UIKit.COLOR_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_hint)
	_track = Control.new()
	_track.custom_minimum_size = TRACK_SIZE
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	_col.add_child(_track)
	_feedback = UIKit.label("", &"BigLabel", UIKit.COLOR_GOLD)
	_feedback.position = Vector2(HIT_X - 50, -2)
	_feedback.size = Vector2(100, 16)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_feedback.add_theme_constant_override("outline_size", 3)
	_track.add_child(_feedback)
	_result_label = UIKit.label("", &"HeaderLabel", UIKit.COLOR_GOLD)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_result_label)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "SFX"
	if manual_time_ms < 0 and ResourceLoader.exists(BACKING):
		_audio.stream = load(BACKING)
	add_child(_audio)
	if show_intro:
		_build_intro()
	else:
		_begin()


# Cara bermain, tampil sebelum permainan pertama dan di latihan.
func _build_intro() -> void:
	_track.visible = false
	_hint.visible = false
	_intro = UIKit.vbox(4)
	_col.add_child(_intro)
	_col.move_child(_intro, 1)
	_intro.add_child(UIKit.label(tr("RHYTHM_INTRO_TITLE"), &"BigLabel", UIKit.COLOR_GOLD))
	for key: String in ["RHYTHM_INTRO_1", "RHYTHM_INTRO_2", "RHYTHM_INTRO_3"]:
		var line := UIKit.label(_fill_keys(tr(key)), &"BigLabel", UIKit.COLOR_TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(TRACK_SIZE.x, 0)
		_intro.add_child(line)
	var legend := Control.new()
	legend.custom_minimum_size = Vector2(TRACK_SIZE.x, 26)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.draw.connect(func() -> void:
		draw_note(legend, Vector2(150, 13), Note.DUNG, 1.0)
		legend.draw_string(UIKit.FONT_MAIN, Vector2(166, 18), tr("RHYTHM_DUNG"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COLOR_TEXT)
		draw_note(legend, Vector2(260, 13), Note.KREK, 1.0)
		legend.draw_string(UIKit.FONT_MAIN, Vector2(276, 18), tr("RHYTHM_KREK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COLOR_TEXT))
	_intro.add_child(legend)
	var start := UIKit.button(tr("RHYTHM_INTRO_START"), 120, true)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_begin)
	_intro.add_child(start)


func _begin() -> void:
	if _started:
		return
	if _intro != null:
		_intro.queue_free()
		_intro = null
		_track.visible = true
		_hint.visible = true
	_started = true
	if _audio.stream != null:
		_audio.play()
	# Jam dimulai bersamaan dengan iringan, digeser jeda keluaran audio supaya
	# ketukan yang terlihat sama dengan yang terdengar.
	_start_usec = Time.get_ticks_usec() + int(AudioServer.get_output_latency() * 1000000.0)


func now_ms() -> int:
	if manual_time_ms >= 0:
		return manual_time_ms
	return int((Time.get_ticks_usec() - _start_usec) / 1000)


func _process(_delta: float) -> void:
	if not _started or _done:
		return
	_mark_misses(now_ms())
	_track.queue_redraw()
	if now_ms() > note_times[-1] + BEAT_MS + 300:
		_finish()


## Menilai satu tekanan di waktu `at_ms`. Mengembalikan nilainya, atau -1
## kalau tidak ada ketukan yang cukup dekat (tekanan diabaikan, tapi pemain
## diberi tahu kalau terlalu cepat).
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
		if is_inside_tree() and _next_note_after(at_ms) >= 0:
			_show_text(tr("RHYTHM_EARLY"), UIKit.COLOR_DIM)
		return -1.0
	var value := judge(best_delta)
	judgements[best] = value
	if is_inside_tree():
		_sfx("bedug" if note_kinds[best] == Note.DUNG else "korek", 0.03)
		_show_feedback(value)
	return value


# Ketukan berikutnya yang belum dinilai dan masih kurang dari satu ketukan lagi.
func _next_note_after(at_ms: int) -> int:
	for i: int in note_times.size():
		if judgements[i] < 0.0 and note_times[i] > at_ms and note_times[i] - at_ms < BEAT_MS:
			return i
	return -1


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


# Nama tombol pilihan pemain di teks ({ultimate} -> "Q"), lewat node seperti _sfx.
func _fill_keys(text: String) -> String:
	var gs := get_node_or_null("/root/GameState")
	return str(gs.call("fill_keys", text)) if gs != null else text


# Lewat node, bukan nama autoload, supaya kelas ini bisa dipakai tes yang
# dikompilasi sebelum autoload terdaftar.
func _sfx(key: String, jitter: float, volume_db: float = 0.0) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", key, jitter, volume_db)


func _show_feedback(value: float) -> void:
	if value >= 1.0:
		_show_text(tr("RHYTHM_PERFECT"), UIKit.COLOR_GOLD)
	elif value > 0.0:
		_show_text(tr("RHYTHM_GOOD"), UIKit.COLOR_TEXT)
	else:
		_show_text(tr("RHYTHM_MISS"), UIKit.COLOR_RED)


func _show_text(text: String, color: Color) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)
	_feedback.modulate.a = 1.0
	var t := _feedback.create_tween()
	t.tween_interval(0.35)
	t.tween_property(_feedback, "modulate:a", 0.0, 0.25)


func _finish() -> void:
	if _done:
		return
	_done = true
	var final := score()
	_result_label.text = tr("RHYTHM_RESULT") % roundi((bonus_for(final) - 1.0) * 100.0)
	var t := create_tween()
	t.tween_property(_audio, "volume_db", -30.0, 0.7)
	t.parallel().tween_interval(0.7)
	t.tween_callback(func() -> void:
		finished.emit(final)
		queue_free())


func _input(event: InputEvent) -> void:
	if _done:
		return
	if not _started:
		# Di layar cara bermain, Spasi/Enter sama dengan tombol Mulai.
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ultimate"):
			_begin()
			get_viewport().set_input_as_handled()
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
	var now := now_ms()
	_track.draw_rect(Rect2(Vector2(8, mid - 1), Vector2(TRACK_SIZE.x - 16, 2)), Color(0.35, 0.3, 0.25))
	# Garis ketukan: setiap ketukan iringan punya tanda kecil di lintasan.
	for b: int in range(COUNT_IN + 8):
		var beat_time := PRE_ROLL_MS + b * BEAT_MS
		var x := HIT_X + (beat_time - now) * SPEED
		if x > HIT_X + 4.0 and x < TRACK_SIZE.x - 8.0:
			_track.draw_line(Vector2(x, mid - 5), Vector2(x, mid + 5), Color(0.5, 0.45, 0.38, 0.6), 1.0)
	# Lingkaran sasaran berdenyut di setiap ketukan.
	var pulse := 0.0
	if now >= PRE_ROLL_MS:
		var phase := float((now - PRE_ROLL_MS) % BEAT_MS) / BEAT_MS
		pulse = clampf(1.0 - phase * 4.0, 0.0, 1.0)
	_track.draw_circle(Vector2(HIT_X, mid), 17.0, Color(UIKit.COLOR_GOLD, 0.1 + 0.15 * pulse))
	_track.draw_arc(Vector2(HIT_X, mid), 17.0 + 3.0 * pulse, 0.0, TAU, 32, UIKit.COLOR_GOLD, 2.0)
	_track.draw_arc(Vector2(HIT_X, mid), 12.0, 0.0, TAU, 32, Color(UIKit.COLOR_GOLD, 0.35), 1.0)
	# Hitungan kentongan: 4, 3, 2, 1 di dalam lingkaran.
	if now >= PRE_ROLL_MS and now < first_note_ms():
		var count := COUNT_IN - int((now - PRE_ROLL_MS) / BEAT_MS)
		var text := str(count)
		var w := UIKit.FONT_MAIN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_track.draw_string(UIKit.FONT_MAIN, Vector2(HIT_X - w * 0.5, mid + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COLOR_GOLD)
	elif now < PRE_ROLL_MS:
		var ready := tr("RHYTHM_READY")
		_track.draw_string(UIKit.FONT_MAIN, Vector2(HIT_X + 24, mid + 6), ready, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COLOR_DIM)
	for i: int in note_times.size():
		var x := HIT_X + (note_times[i] - now) * SPEED
		if x < -12.0 or x > TRACK_SIZE.x + 12.0:
			continue
		var alpha := 0.25 if judgements[i] >= 0.0 else 1.0
		draw_note(_track, Vector2(x, mid), note_kinds[i], alpha)


## Satu ketukan: dung bulat (bedug), krek kotak (korek). Dipakai juga arak-arakan.
static func draw_note(canvas: CanvasItem, c: Vector2, kind: int, alpha: float) -> void:
	if kind == Note.DUNG:
		canvas.draw_circle(c, 11.0, Color(0.38, 0.22, 0.12, alpha))
		canvas.draw_circle(c, 8.0, Color(0.91, 0.84, 0.66, alpha))
		canvas.draw_circle(c, 3.0, Color(0.6, 0.45, 0.3, alpha))
	else:
		canvas.draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(0.38, 0.22, 0.12, alpha))
		canvas.draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), Color(0.75, 0.55, 0.32, alpha))
		for k: int in 3:
			canvas.draw_line(c + Vector2(-4 + k * 4, -6), c + Vector2(-4 + k * 4, 6), Color(0.3, 0.18, 0.1, alpha), 1.0)
