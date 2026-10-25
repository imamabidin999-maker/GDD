class_name StageNode
extends Control
## Satu titik stage di peta: medali bundar berisi topeng Buto penjaganya.
## Terkunci = gelap dengan gembok, terbuka = cincin emas berdenyut,
## selesai = cincin hijau dengan tanda centang, menunggu = cincin redup tanpa
## gembok (langkah Ruwatan yang belum dicapai). Babak Buto Murka diberi
## lingkaran aura merah keunguan.

signal pressed(node: StageNode)
signal hover_changed(node: StageNode, hovering: bool)

enum State { LOCKED, OPEN, CLEARED, UPCOMING }

const RADIUS := 15.0
const PADLOCK := preload("res://assets/ui/padlock.png")
const COLOR_FILL := Color(0.07, 0.07, 0.13)
const COLOR_LOCKED := Color(0.36, 0.36, 0.44)
const COLOR_CLEARED := Color(0.55, 0.86, 0.5)
const COLOR_BOSS := Color(0.86, 0.3, 0.42)
const COLOR_MURKA := Color(0.95, 0.2, 0.6)

var stage: StageData
var state: State = State.LOCKED
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _mask: Texture2D
var _phase: float = 0.0
var _murka: bool = false
## Bintang Dongkrek babak ini (bitmask 3 bintang).
var stars: int = 0
## Tiga bintang di bawah medali (tidak dipakai di Ruwatan).
var show_stars: bool = true
## Tanda tanya di tengah medali (langkah kejadian Ruwatan).
var mystery: bool = false


func setup(stage_data: StageData, node_state: State) -> void:
	stage = stage_data
	state = node_state
	size = Vector2.ONE * (RADIUS * 2.0 + 10.0)
	position = stage.map_position - size * 0.5
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not stage.enemies.is_empty():
		_mask = load("res://assets/ui/mask_%s.png" % get_buto_key(stage.enemies[0]))
	_murka = has_murka(stage)
	mouse_entered.connect(func() -> void:
		_scale_to(1.12)
		hover_changed.emit(self, true))
	mouse_exited.connect(func() -> void:
		_scale_to(1.0)
		hover_changed.emit(self, false))


static func get_buto_key(spec: EnemySpec) -> String:
	return String(EnemyButo.ButoType.find_key(spec.buto_type)).to_lower()


static func has_murka(stage_data: StageData) -> bool:
	for spec: EnemySpec in stage_data.enemies:
		if spec.murka:
			return true
	return false


func _scale_to(value: float) -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * value, 0.1)


func _process(delta: float) -> void:
	if state == State.OPEN or selected or (_murka and state != State.LOCKED):
		_phase += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		pressed.emit(self)
		accept_event()


func _draw() -> void:
	var c := size * 0.5
	draw_set_transform(c + Vector2(0, RADIUS - 1), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, RADIUS + 2.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var ring := COLOR_LOCKED
	match state:
		State.OPEN:
			ring = UIKit.COLOR_GOLD.lerp(Color.WHITE, 0.25 + 0.25 * sin(_phase * 4.0))
		State.CLEARED:
			ring = COLOR_CLEARED
		State.UPCOMING:
			ring = COLOR_LOCKED.lightened(0.3)

	if _murka and state != State.LOCKED:
		var aura := COLOR_MURKA
		aura.a = 0.3 + 0.15 * sin(_phase * 3.0)
		draw_circle(c, RADIUS + 4.0, aura)
		draw_arc(c, RADIUS + 3.5, 0.0, TAU, 32, Color(COLOR_MURKA, 0.75), 1.0)
	if selected:
		var glow := UIKit.COLOR_GOLD
		glow.a = 0.35 + 0.2 * sin(_phase * 5.0)
		draw_circle(c, RADIUS + 5.0, glow)
	if stage.is_boss:
		# Duri merah di sekeliling medali bos.
		for i: int in 10:
			var a := TAU * i / 10.0 + PI * 0.5
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x) * 3.0
			var base := c + dir * (RADIUS + 1.0)
			draw_colored_polygon(PackedVector2Array([base + side, base - side, c + dir * (RADIUS + 6.0)]),
				COLOR_BOSS if state != State.LOCKED else COLOR_LOCKED.darkened(0.3))
	draw_circle(c, RADIUS + 1.0, ring.darkened(0.45))
	draw_circle(c, RADIUS, ring)
	draw_circle(c, RADIUS - 2.0, COLOR_FILL)

	if _mask != null:
		var mask_size := Vector2(24, 24)
		var tint := Color.WHITE
		if state == State.LOCKED:
			tint = Color(0.22, 0.22, 0.28)
		elif state == State.UPCOMING:
			tint = Color(0.72, 0.72, 0.8)
		draw_texture_rect(_mask, Rect2(c - mask_size * 0.5, mask_size), false, tint)
	elif mystery:
		var q_size := UIKit.FONT_MAIN.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(UIKit.FONT_MAIN, c + Vector2(-q_size.x * 0.5, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			UIKit.COLOR_GOLD if state == State.OPEN else ring)
	if state == State.LOCKED:
		draw_texture(PADLOCK, c - PADLOCK.get_size() * 0.5 + Vector2(0, 1))
	elif state == State.CLEARED:
		var b := c + Vector2(RADIUS - 3.0, RADIUS - 3.0)
		draw_circle(b, 5.0, Color(0.1, 0.25, 0.12))
		draw_circle(b, 4.0, COLOR_CLEARED)
		draw_polyline(PackedVector2Array([b + Vector2(-2, 0), b + Vector2(-0.5, 1.5), b + Vector2(2, -1.5)]),
			Color(0.06, 0.16, 0.08), 1.5)

	# Tiga Bintang Dongkrek di bawah medali.
	if show_stars and (state != State.LOCKED or stars != 0):
		for i: int in Challenges.STARS_PER_STAGE:
			var sc := c + Vector2((i - 1) * 8.0, RADIUS + 5.0)
			var lit := bool(stars & (1 << i))
			_draw_star(sc, 3.6, Color(0.05, 0.05, 0.1))
			_draw_star(sc, 2.8, UIKit.COLOR_GOLD if lit else Color(0.25, 0.25, 0.32))

	# Nomor stage di kiri atas. Angka dua digit diberi lencana lonjong.
	var n := c + Vector2(-RADIUS + 2.0, -RADIUS + 2.0)
	var font := UIKit.FONT_SMALL
	var text := str(stage.stage_number)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var stretch := maxf(0.0, w - 6.0) * 0.5
	for layer: int in 2:
		var r := 5.5 - layer
		var col := ring.darkened(0.45) if layer == 0 else COLOR_FILL
		draw_circle(n + Vector2(-stretch, 0), r, col)
		draw_circle(n + Vector2(stretch, 0), r, col)
		if stretch > 0.0:
			draw_rect(Rect2(n + Vector2(-stretch, -r), Vector2(stretch * 2.0, r * 2.0)), col)
	draw_string(font, n + Vector2(-w * 0.5 + 0.5, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ring)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, color)
