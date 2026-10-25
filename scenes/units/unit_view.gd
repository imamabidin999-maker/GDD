class_name UnitView
extends Node2D
## Tampilan satu karakter di medan tempur: sprite, bar HP, Tameng, Racun,
## niat (khusus Buto), penanda target, dan animasi serang/kena pukul/mati.
##
## Titik asal node ini ada di kaki karakter. Sprite desain berukuran 160x160
## dengan kaki di sekitar baris 150.

signal clicked(view: UnitView)
signal hover_changed(view: UnitView, hovering: bool)

const SHADER := preload("res://assets/shaders/sprite_fx.gdshader")
const FEET_Y := 150.0
const BAR_WIDTH := 58
const OUTLINE_NORMAL := Color(0.78, 0.82, 1.0, 0.45)
const OUTLINE_TARGET := Color(1.0, 0.82, 0.35, 0.95)

const INTENT_ICONS := {
	EnemyIntent.Kind.ATTACK: preload("res://assets/ui/mini_attack.png"),
	EnemyIntent.Kind.DRAIN: preload("res://assets/ui/mini_drain.png"),
	EnemyIntent.Kind.LOCK: preload("res://assets/ui/mini_lock.png"),
	EnemyIntent.Kind.SHUFFLE: preload("res://assets/ui/mini_shuffle.png"),
	EnemyIntent.Kind.POISON: preload("res://assets/ui/mini_poison.png"),
	EnemyIntent.Kind.CHARGE: preload("res://assets/ui/mini_charge.png"),
	EnemyIntent.Kind.HEAVY: preload("res://assets/ui/mini_heavy.png"),
}

var health: HealthComponent
var unit_scale: float = 1.0
## 1 = menghadap kanan (Eyang Palang), -1 = menghadap kiri (Buto).
var facing: int = 1
var is_enemy: bool = false

var _idle_texture: Texture2D
var _attack_textures: Array[Texture2D] = []
var _sprite: Sprite2D
var _material: ShaderMaterial
var _bar: ProgressBar
var _bar_label: Label
var _status_row: HBoxContainer
var _block_box: HBoxContainer
var _block_label: Label
var _poison_box: HBoxContainer
var _poison_label: Label
var _intent_box: HBoxContainer
var _intent_icon: TextureRect
var _intent_label: Label
var _marker: Polygon2D
var _click_area: Control
var _home := Vector2.ZERO
var _bob_tween: Tween
var _dead: bool = false


func setup(idle: Texture2D, attacks: Array[Texture2D], unit_health: HealthComponent, enemy: bool, scale_factor: float = 1.0) -> void:
	_idle_texture = idle
	_attack_textures = attacks
	health = unit_health
	is_enemy = enemy
	facing = -1 if enemy else 1
	unit_scale = scale_factor
	_build()
	health.hp_changed.connect(_on_hp_changed)
	health.block_changed.connect(_on_block_changed)
	health.died.connect(play_death)
	_on_hp_changed(health.current_hp, health.max_hp)
	_on_block_changed(health.block)


func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("outline_color", OUTLINE_NORMAL)

	_sprite = Sprite2D.new()
	_sprite.texture = _idle_texture
	_sprite.centered = false
	_sprite.offset = Vector2(-80, -FEET_Y)
	_sprite.scale = Vector2(unit_scale, unit_scale)
	_sprite.material = _material
	add_child(_sprite)

	var top := -FEET_Y * unit_scale + 10.0

	# Bar HP di bawah kaki, angkanya ditulis di atas bar.
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.size = Vector2(BAR_WIDTH, 8)
	_bar.position = Vector2(-BAR_WIDTH * 0.5, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_enemy:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.36, 0.78, 0.42)
		fill.border_width_bottom = 1
		fill.border_color = Color(0.18, 0.45, 0.22)
		_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)
	_bar_label = UIKit.small_label("")
	_bar_label.size = Vector2(BAR_WIDTH, 8)
	_bar_label.position = Vector2(-BAR_WIDTH * 0.5, 2)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_bar_label.add_theme_constant_override("outline_size", 2)
	add_child(_bar_label)

	# Tameng & Racun di kiri bar HP.
	_status_row = UIKit.hbox(1)
	_status_row.position = Vector2(-BAR_WIDTH * 0.5 - 36, 1)
	_status_row.size = Vector2(34, 12)
	_status_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(_status_row)
	_block_box = UIKit.hbox(0)
	_block_box.add_child(UIKit.icon(preload("res://assets/ui/mini_block.png")))
	_block_label = UIKit.small_label("0", UIKit.COLOR_GREEN)
	_block_box.add_child(_block_label)
	_status_row.add_child(_block_box)
	_poison_box = UIKit.hbox(0)
	_poison_box.add_child(UIKit.icon(preload("res://assets/ui/mini_poison.png")))
	_poison_label = UIKit.small_label("0", UIKit.COLOR_GREEN)
	_poison_box.add_child(_poison_label)
	_status_row.add_child(_poison_box)
	_block_box.visible = false
	_poison_box.visible = false

	# Niat Buto di atas kepala.
	_intent_box = UIKit.hbox(1)
	_intent_box.position = Vector2(-20, top - 18)
	_intent_box.size = Vector2(40, 14)
	_intent_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_intent_icon = UIKit.icon(null)
	_intent_box.add_child(_intent_icon)
	_intent_label = UIKit.label("", &"", UIKit.COLOR_TEXT)
	_intent_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_intent_label.add_theme_constant_override("outline_size", 3)
	_intent_box.add_child(_intent_label)
	_intent_box.visible = false
	add_child(_intent_box)

	# Penanda target: segitiga emas yang naik-turun.
	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, 6)])
	_marker.color = Color(1.0, 0.82, 0.35)
	_marker.position = Vector2(0, top - 28)
	_marker.visible = false
	add_child(_marker)
	var marker_tween := create_tween().set_loops()
	marker_tween.tween_property(_marker, "position:y", top - 31, 0.4).set_trans(Tween.TRANS_SINE)
	marker_tween.tween_property(_marker, "position:y", top - 28, 0.4).set_trans(Tween.TRANS_SINE)

	# Area klik seukuran badan.
	_click_area = Control.new()
	_click_area.position = Vector2(-48, -138) * unit_scale
	_click_area.size = Vector2(96, 138) * unit_scale
	_click_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_enemy else Control.CURSOR_ARROW
	_click_area.gui_input.connect(_on_area_input)
	_click_area.mouse_entered.connect(func() -> void: hover_changed.emit(self, true))
	_click_area.mouse_exited.connect(func() -> void: hover_changed.emit(self, false))
	add_child(_click_area)

	_home = position
	_start_bob()


## Posisi awal (dipakai untuk kembali setelah menyerang).
func set_home(pos: Vector2) -> void:
	position = pos
	_home = pos


## Titik di depan badan, arah lawan menyerang.
func get_hit_point() -> Vector2:
	return global_position + Vector2(0, -70 * unit_scale)


func get_top_point() -> Vector2:
	return global_position + Vector2(0, (-FEET_Y + 4) * unit_scale)


func is_dead() -> bool:
	return _dead


func contains_point(global_point: Vector2) -> bool:
	return not _dead and _click_area.get_global_rect().has_point(global_point)


#region Status

func set_targeted(on: bool) -> void:
	_marker.visible = on and not _dead
	_material.set_shader_parameter("outline_color", OUTLINE_TARGET if on and not _dead else OUTLINE_NORMAL)


func set_intent(intent: EnemyIntent) -> void:
	if intent == null or _dead:
		_intent_box.visible = false
		return
	_intent_box.visible = true
	_intent_icon.texture = INTENT_ICONS.get(intent.kind)
	match intent.kind:
		EnemyIntent.Kind.LOCK:
			_intent_label.text = "x%d" % intent.extra if intent.extra > 1 else ""
		EnemyIntent.Kind.CHARGE:
			_intent_label.text = "!"
		_:
			_intent_label.text = str(intent.damage) if intent.damage > 0 else ""
	var heavy := intent.kind == EnemyIntent.Kind.HEAVY
	_intent_label.add_theme_color_override("font_color", UIKit.COLOR_RED if heavy else UIKit.COLOR_TEXT)


func hide_intent() -> void:
	_intent_box.visible = false


func set_poison(stacks: int) -> void:
	_poison_box.visible = stacks > 0
	_poison_label.text = str(stacks)


func _on_hp_changed(current: int, maximum: int) -> void:
	_bar.max_value = maximum
	var t := create_tween()
	t.tween_property(_bar, "value", float(current), 0.25)
	_bar_label.text = "%d/%d" % [current, maximum]


func _on_block_changed(block: int) -> void:
	_block_box.visible = block > 0
	_block_label.text = str(block)

#endregion


#region Animasi

func _start_bob() -> void:
	if _bob_tween != null:
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	var period := randf_range(1.4, 1.9)
	_bob_tween.tween_property(_sprite, "position:y", -1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
	_bob_tween.tween_property(_sprite, "position:y", 0.0, period * 0.5).set_trans(Tween.TRANS_SINE)


## Animasi menyerang: maju ke arah lawan, ganti pose serang, lalu mundur.
## Selesai sekitar 0.45 detik.
func play_attack(heavy: bool = false) -> void:
	if _dead:
		return
	var reach := (46.0 if heavy else 30.0) * facing
	var t := create_tween()
	t.tween_callback(_set_pose.bind(0))
	t.tween_property(self, "position", _home + Vector2(reach * 0.4, 0), 0.08)
	t.tween_callback(_set_pose.bind(1))
	t.tween_property(self, "position", _home + Vector2(reach, 0), 0.07)
	t.tween_interval(0.12)
	t.tween_property(self, "position", _home, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(_set_pose.bind(-1))


## Animasi ancang-ancang (Buto Merah): mundur sedikit sambil berkedip merah.
func play_charge() -> void:
	if _dead:
		return
	var t := create_tween()
	t.tween_property(self, "position", _home + Vector2(-10 * facing, 0), 0.15)
	t.parallel().tween_method(_set_flash.bind(Color(1, 0.35, 0.2)), 0.0, 0.6, 0.15)
	t.tween_interval(0.15)
	t.tween_property(self, "position", _home, 0.15)
	t.parallel().tween_method(_set_flash.bind(Color(1, 0.35, 0.2)), 0.6, 0.0, 0.15)


## Kilat & getar saat terkena pukulan.
func play_hit(color: Color = Color.WHITE) -> void:
	if _dead:
		return
	var t := create_tween()
	t.tween_method(_set_flash.bind(color), 1.0, 0.0, 0.3)
	var s := create_tween()
	for i: int in 4:
		s.tween_property(_sprite, "position:x", 3.0 if i % 2 == 0 else -3.0, 0.03)
	s.tween_property(_sprite, "position:x", 0.0, 0.03)


## Kilat warna lembut, misalnya saat mendapat Tameng atau Moxie.
func play_glow(color: Color) -> void:
	if _dead:
		return
	var t := create_tween()
	t.tween_method(_set_flash.bind(color), 0.0, 0.45, 0.12)
	t.tween_method(_set_flash.bind(color), 0.45, 0.0, 0.25)


func play_death() -> void:
	if _dead:
		return
	_dead = true
	set_targeted(false)
	hide_intent()
	_click_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _bob_tween != null:
		_bob_tween.kill()
	var t := create_tween()
	t.tween_method(_set_flash.bind(Color(0.9, 0.3, 0.3)), 1.0, 0.0, 0.25)
	t.tween_property(_sprite, "position:y", 10.0, 0.7)
	t.parallel().tween_method(_set_fade, 1.0, 0.0, 0.7)
	t.parallel().tween_property(_bar, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property(_bar_label, "modulate:a", 0.0, 0.4)
	t.parallel().tween_property(_status_row, "modulate:a", 0.0, 0.4)


func _set_pose(index: int) -> void:
	if index < 0 or _attack_textures.is_empty():
		_sprite.texture = _idle_texture
	else:
		_sprite.texture = _attack_textures[mini(index, _attack_textures.size() - 1)]


func _set_flash(value: float, color: Color) -> void:
	_material.set_shader_parameter("flash_color", color)
	_material.set_shader_parameter("flash", value)


func _set_fade(value: float) -> void:
	_material.set_shader_parameter("fade", value)

#endregion


func _on_area_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
