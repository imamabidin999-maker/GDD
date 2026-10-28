class_name ArakArakan
extends Control
## Penutup cerita: arak-arakan keliling desa setelah Buto Hitam kalah, seperti
## asal-usul Dongkrek yang diarak untuk mengusir pagebluk.
##
## Iringannya dimulai dengan empat hitungan kentongan, lalu empat putaran
## delapan ketukan. Di awal setiap putaran satu rombongan ikut: pembawa bedug,
## penabuh korek bersama Roro Ayu dan Roro Perot, pembawa gong dan obor, lalu
## para penari bertopeng Buto. Pemain menabuh dung dan krek seperti di irama
## Sapu Jagad (klik, Spasi, Enter, atau tombol Sapu Jagad). Tidak ada kalah:
## ketukan yang meleset hanya mengurangi semaraknya, dan rombongan tetap ikut.
##
## Setelah selesai, barisannya tetap di layar sebagai gambar penutup.
## Angka waktunya sama dengan iringan di tools/build_audio.py.

## Selesai. score 0..1, atau -1 kalau dilewati atau dimainkan otomatis.
signal finished(score: float)

const Note := RhythmGebrakan.Note
const BEAT_MS := 600
const PRE_ROLL_MS := 500
const COUNT_IN := 4
const ROUND_BEATS := 8
const ROUNDS := 4
const OUTRO_BEATS := 6
const SPEED := 0.12 # piksel per milidetik
const HIT_X := 60.0
const TRACK_SIZE := Vector2(420, 40)
const BACKING := "res://assets/audio/bgm/arak_arakan.ogg"
## Ketukan pemain tiap putaran: [ketukan ke- (0..7), jenis]. Makin ramai di
## putaran akhir, tapi jaraknya tetap paling dekat satu ketukan.
const CHART := [
	[[0, Note.DUNG], [2, Note.DUNG], [4, Note.DUNG], [6, Note.DUNG]],
	[[0, Note.DUNG], [1, Note.KREK], [2, Note.DUNG], [3, Note.KREK], [4, Note.DUNG], [5, Note.KREK], [6, Note.DUNG], [7, Note.KREK]],
	[[0, Note.DUNG], [1, Note.KREK], [2, Note.DUNG], [3, Note.DUNG], [4, Note.KREK], [6, Note.DUNG], [7, Note.KREK]],
	[[0, Note.DUNG], [1, Note.DUNG], [2, Note.KREK], [4, Note.DUNG], [5, Note.DUNG], [6, Note.KREK], [7, Note.KREK]],
]
## Pengumuman saat tiap rombongan ikut.
const JOIN_KEYS: Array[String] = ["ARAK_JOIN_BEDUG", "ARAK_JOIN_KOREK", "ARAK_JOIN_GONG", "ARAK_JOIN_TOPENG"]
const EYANG := preload("res://assets/sprites/hero/eyang_palang_idle.png")
const RORO_AYU := preload("res://assets/sprites/roro/roro_ayu_idle.png")
const RORO_PEROT := preload("res://assets/sprites/roro/roro_perot_idle.png")
const BUTO_KEYS: Array[String] = ["kuning", "hijau", "merah", "putih", "hitam"]
## Kaki barisan depan (tokoh) dan barisan belakang (siluet warga).
const FRONT_Y := 334.0
const BACK_Y := 270.0

var note_times: Array[int] = []
var note_kinds: Array[int] = []
## Nilai tiap ketukan: -1 belum dinilai, 0 meleset, 0.5 cukup, 1 tepat.
var judgements: Array[float] = []
## Untuk tes: kalau >= 0 dipakai sebagai "sekarang" (ms), bukan jam sungguhan.
var manual_time_ms: int = -1
## Tanpa permainan irama (irama dimatikan di Pengaturan): barisan berjalan sendiri.
var auto_play: bool = false

var _start_usec: int = 0
var _started: bool = false
var _done: bool = false
var _joined: int = 0
var _beat_seen: int = -1
var _audio: AudioStreamPlayer
var _panel: PanelContainer
var _track: Control
var _banner: Label
var _feedback: Label
var _skip: Button
var _line: Node2D
var _groups: Array = []
var _dancers: Array[Sprite2D] = []
## Pose para penari: [diam, serang] per penari.
var _dance_frames: Array = []


## Waktu ketukan ke-`beat` sejak mulai (ms).
static func beat_ms(beat: int) -> int:
	return PRE_ROLL_MS + beat * BEAT_MS


## Ketukan pertama putaran `round_index` (0..ROUNDS-1).
static func round_start_beat(round_index: int) -> int:
	return COUNT_IN + round_index * ROUND_BEATS


static func end_ms() -> int:
	return beat_ms(COUNT_IN + ROUNDS * ROUND_BEATS + OUTRO_BEATS)


func _init() -> void:
	for r: int in CHART.size():
		for entry: Array in CHART[r]:
			note_times.append(beat_ms(round_start_beat(r) + int(entry[0])))
			note_kinds.append(int(entry[1]))
			judgements.append(-1.0)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_line = Node2D.new()
	add_child(_line)
	_build_procession()
	_build_track()
	_skip = UIKit.button(tr("BTN_SKIP"), 60)
	_skip.position = Vector2(570, 8)
	_skip.size = Vector2(60, 18)
	_skip.pressed.connect(skip)
	add_child(_skip)
	_audio = AudioStreamPlayer.new()
	_audio.bus = "Music"
	if manual_time_ms < 0 and ResourceLoader.exists(BACKING):
		_audio.stream = load(BACKING)
	add_child(_audio)
	_begin()


func _begin() -> void:
	_started = true
	if _audio.stream != null:
		_audio.play()
	_start_usec = Time.get_ticks_usec() + int(AudioServer.get_output_latency() * 1000000.0)
	# Barisan maju pelan sepanjang arak-arakan.
	var walk := create_tween()
	walk.tween_property(_line, "position:x", 70.0, end_ms() / 1000.0)


func now_ms() -> int:
	if manual_time_ms >= 0:
		return manual_time_ms
	return int((Time.get_ticks_usec() - _start_usec) / 1000)


func _process(_delta: float) -> void:
	if not _started or _done:
		return
	var now := now_ms()
	_update_beat(now)
	if not auto_play:
		_mark_misses(now)
		_track.queue_redraw()
	if now >= end_ms():
		_finish(score() if not auto_play else -1.0)


#region Barisan

func _build_procession() -> void:
	# Barisan belakang: siluet warga, dari kanan (depan) ke kiri (belakang).
	var back := [
		[["bedug", 452.0]],
		[["korek", 372.0], ["korek", 340.0]],
		[["gong", 262.0], ["kentongan", 214.0], ["obor", 520.0], ["obor", 186.0]],
		[["obor", 120.0]],
	]
	var front := [
		[],
		[[RORO_AYU, 394.0, 0.52], [RORO_PEROT, 346.0, 0.52]],
		[],
		[],
	]
	# Eyang Palang memimpin dari awal.
	_add_figure(EYANG, Vector2(470, FRONT_Y), 0.55, true)
	for r: int in ROUNDS:
		var group: Array = []
		for entry: Array in back[r]:
			var tex := load("res://assets/sprites/arak/warga_%s.png" % entry[0]) as Texture2D
			group.append(_add_silhouette(tex, Vector2(entry[1], BACK_Y)))
		for entry: Array in front[r]:
			group.append(_add_figure(entry[0], Vector2(entry[1], FRONT_Y), entry[2], false))
		if r == ROUNDS - 1:
			# Para penari bertopeng Buto, berjajar di belakang Roro Perot.
			for i: int in BUTO_KEYS.size():
				var idle := load("res://assets/sprites/buto/buto_%s_idle.png" % BUTO_KEYS[i]) as Texture2D
				var attack := load("res://assets/sprites/buto/buto_%s_attack.png" % BUTO_KEYS[i]) as Texture2D
				var dancer := _add_figure(idle, Vector2(288.0 - i * 52.0, FRONT_Y), 0.36, false)
				# Kedua pose Buto menghadap kiri; di arak-arakan semua menghadap kanan.
				dancer.flip_h = true
				_dancers.append(dancer)
				_dance_frames.append([idle, attack])
				group.append(dancer)
		_groups.append(group)


func _add_figure(texture: Texture2D, feet: Vector2, scale_value: float, visible_now: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = Vector2(-texture.get_width() * 0.5, -150.0)
	s.scale = Vector2.ONE * scale_value
	s.position = feet
	s.visible = visible_now
	_line.add_child(s)
	if visible_now:
		_bob(s)
	return s


func _add_silhouette(texture: Texture2D, feet: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	s.position = feet
	s.visible = false
	_line.add_child(s)
	return s


# Langkah: naik turun sedikit setiap dua ketukan.
func _bob(s: Sprite2D) -> void:
	var base := s.position.y
	var t := s.create_tween().set_loops()
	t.tween_property(s, "position:y", base - 2.0, BEAT_MS / 1000.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(s, "position:y", base, BEAT_MS / 1000.0).set_trans(Tween.TRANS_SINE)


## Rombongan ke-`index` ikut: masuk dari kiri sambil muncul perlahan.
func join(index: int, instant: bool = false) -> void:
	if index < _joined or index >= _groups.size():
		return
	_joined = index + 1
	for node: Variant in _groups[index]:
		var s := node as Sprite2D
		s.visible = true
		if instant:
			_bob(s)
			continue
		var target := s.position
		s.position.x -= 120.0
		s.modulate.a = 0.0
		var t := s.create_tween().set_parallel()
		t.tween_property(s, "position:x", target.x, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", 1.0, 0.6)
		t.chain().tween_callback(_bob.bind(s))
	if is_inside_tree() and not instant:
		_banner.text = tr(JOIN_KEYS[index])
		_banner.modulate.a = 1.0
		var fade := _banner.create_tween()
		fade.tween_interval(2.4)
		fade.tween_property(_banner, "modulate:a", 0.0, 0.5)


func joined_count() -> int:
	return _joined


# Setiap ketukan: rombongan berikutnya mulai masuk dua ketukan sebelum
# putarannya, dan para penari topeng berganti pose.
func _update_beat(now: int) -> void:
	var beat := int(floor(float(now - PRE_ROLL_MS) / BEAT_MS))
	if beat == _beat_seen:
		return
	_beat_seen = beat
	for r: int in ROUNDS:
		if beat >= round_start_beat(r) - 2 and _joined <= r:
			join(r)
	# Penari topeng bergantian pose di setiap ketukan, berselang-seling.
	for i: int in _dancers.size():
		_dancers[i].texture = _dance_frames[i][1 if (beat + i) % 2 == 0 else 0]

#endregion


#region Irama

func _build_track() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"GoldPanel"
	_panel.position = Vector2(100, 8)
	_panel.custom_minimum_size = Vector2(440, 0)
	add_child(_panel)
	var col := UIKit.vbox(2)
	_panel.add_child(col)
	var title := UIKit.label(tr("ARAK_TITLE"), &"HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var hint := UIKit.small_label(GameState.fill_keys(tr("ARAK_HINT" if not auto_play else "ARAK_HINT_AUTO")), UIKit.COLOR_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)
	_track = Control.new()
	_track.custom_minimum_size = TRACK_SIZE
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	_track.visible = not auto_play
	col.add_child(_track)
	_feedback = UIKit.label("", &"BigLabel", UIKit.COLOR_GOLD)
	_feedback.position = Vector2(HIT_X - 50, -6)
	_feedback.size = Vector2(100, 16)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_feedback.add_theme_constant_override("outline_size", 3)
	_track.add_child(_feedback)
	_banner = UIKit.label("", &"BigLabel", UIKit.COLOR_GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_banner.add_theme_constant_override("outline_size", 3)
	_banner.position = Vector2(0, 150)
	_banner.size = Vector2(640, 20)
	add_child(_banner)


## Menilai satu tekanan di waktu `at_ms` (lihat RhythmGebrakan.press).
func press(at_ms: int) -> float:
	var best := -1
	var best_delta := 1 << 30
	for i: int in note_times.size():
		if judgements[i] >= 0.0:
			continue
		var delta := at_ms - note_times[i]
		if absi(delta) <= RhythmGebrakan.GOOD_MS and absi(delta) < absi(best_delta):
			best = i
			best_delta = delta
	if best < 0:
		return -1.0
	var value := RhythmGebrakan.judge(best_delta)
	judgements[best] = value
	if is_inside_tree():
		AudioManager.play_sfx("bedug" if note_kinds[best] == Note.DUNG else "korek", 0.03)
		_show_feedback(value)
	return value


func _mark_misses(at_ms: int) -> void:
	for i: int in note_times.size():
		if judgements[i] < 0.0 and at_ms - note_times[i] > RhythmGebrakan.GOOD_MS:
			judgements[i] = 0.0
			if is_inside_tree():
				_show_feedback(0.0)


func score() -> float:
	var total := 0.0
	for value: float in judgements:
		total += maxf(value, 0.0)
	return total / maxf(1.0, float(judgements.size()))


func _show_feedback(value: float) -> void:
	var text := tr("RHYTHM_PERFECT") if value >= 1.0 else (tr("RHYTHM_GOOD") if value > 0.0 else tr("RHYTHM_MISS"))
	var color := UIKit.COLOR_GOLD if value >= 1.0 else (UIKit.COLOR_TEXT if value > 0.0 else UIKit.COLOR_RED)
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)
	_feedback.modulate.a = 1.0
	var t := _feedback.create_tween()
	t.tween_interval(0.3)
	t.tween_property(_feedback, "modulate:a", 0.0, 0.2)


func _draw_track() -> void:
	var mid := TRACK_SIZE.y * 0.5
	var now := now_ms()
	_track.draw_rect(Rect2(Vector2(8, mid - 1), Vector2(TRACK_SIZE.x - 16, 2)), Color(0.35, 0.3, 0.25))
	var pulse := 0.0
	if now >= PRE_ROLL_MS:
		pulse = clampf(1.0 - float((now - PRE_ROLL_MS) % BEAT_MS) / BEAT_MS * 4.0, 0.0, 1.0)
	_track.draw_circle(Vector2(HIT_X, mid), 15.0, Color(UIKit.COLOR_GOLD, 0.1 + 0.15 * pulse))
	_track.draw_arc(Vector2(HIT_X, mid), 15.0 + 3.0 * pulse, 0.0, TAU, 32, UIKit.COLOR_GOLD, 2.0)
	if now >= PRE_ROLL_MS and now < beat_ms(COUNT_IN):
		var text := str(COUNT_IN - int((now - PRE_ROLL_MS) / BEAT_MS))
		var w := UIKit.FONT_MAIN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_track.draw_string(UIKit.FONT_MAIN, Vector2(HIT_X - w * 0.5, mid + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.COLOR_GOLD)
	for i: int in note_times.size():
		var x := HIT_X + (note_times[i] - now) * SPEED
		if x < -12.0 or x > TRACK_SIZE.x + 12.0:
			continue
		RhythmGebrakan.draw_note(_track, Vector2(x, mid), note_kinds[i], 0.25 if judgements[i] >= 0.0 else 1.0)

#endregion


## Melewati arak-arakan: semua rombongan langsung ikut.
func skip() -> void:
	if _done:
		return
	AudioManager.play_sfx("click")
	for r: int in ROUNDS:
		join(r, true)
	if _audio.playing:
		var t := create_tween()
		t.tween_property(_audio, "volume_db", -40.0, 0.6)
		t.tween_callback(_audio.stop)
	_finish(-1.0)


func _finish(final: float) -> void:
	if _done:
		return
	_done = true
	for r: int in ROUNDS:
		join(r, true)
	_skip.visible = false
	_panel.visible = false
	if final >= 0.0:
		_banner.text = "%s\n%s" % [tr("ARAK_RESULT") % roundi(final * 100.0), tr(rating_key(final))]
		_banner.size.y = 40
		_banner.modulate.a = 1.0
	else:
		_banner.text = ""
	finished.emit(final)


static func rating_key(final: float) -> String:
	if final >= 0.85:
		return "ARAK_RATING_3"
	if final >= 0.6:
		return "ARAK_RATING_2"
	if final >= 0.3:
		return "ARAK_RATING_1"
	return "ARAK_RATING_0"


func _input(event: InputEvent) -> void:
	if not _started or _done or auto_play:
		return
	var hit := false
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if _skip.get_global_rect().has_point(mb.position):
			return
		hit = true
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ultimate"):
		hit = true
	if hit:
		press(now_ms())
		get_viewport().set_input_as_handled()
