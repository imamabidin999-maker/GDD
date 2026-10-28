class_name UnitView
extends Node2D
## Tampilan satu karakter di medan tempur: sprite, bar HP, Tameng, Racun,
## niat (khusus Buto), penanda target, dan animasi serang/kena pukul/mati.
##
## Titik asal node ini ada di kaki karakter. Sprite desain berukuran 160x160
## dengan kaki di sekitar baris 150.

signal clicked(view: UnitView)
signal hover_changed(view: UnitView, hovering: bool)
## Kursor masuk/keluar dari ikon status. `icon`: "intent", "amuk",
## "bala_shield", "block", "poison", "ajian", "prayitna", atau "giris". `at` adalah
## titik tengah atas ikon itu (koordinat layar), tempat tooltip ditaruh.
signal icon_hovered(view: UnitView, icon: String, hovering: bool, at: Vector2)

const MURKA_AURA := preload("res://assets/shaders/murka_aura.gdshader")
const SHADER := preload("res://assets/shaders/sprite_fx.gdshader")
const FEET_Y := 150.0
const AMUK_FULL := preload("res://assets/ui/amuk_dot.png")
const AMUK_EMPTY := preload("res://assets/ui/amuk_dot_empty.png")
const BAR_WIDTH := 58
const OUTLINE_NORMAL := Color(0.78, 0.82, 1.0, 0.45)
const OUTLINE_TARGET := Color(1.0, 0.82, 0.35, 0.95)

const INTENT_ICONS := {
	EnemyIntent.Kind.ATTACK: preload("res://assets/ui/mini_attack.png"),
	EnemyIntent.Kind.DRAIN: preload("res://assets/ui/mini_drain.png"),
	EnemyIntent.Kind.LOCK: preload("res://assets/ui/mini_lock.png"),
	EnemyIntent.Kind.POISON: preload("res://assets/ui/mini_poison.png"),
	EnemyIntent.Kind.CHARGE: preload("res://assets/ui/mini_charge.png"),
	EnemyIntent.Kind.HEAVY: preload("res://assets/ui/mini_heavy.png"),
	EnemyIntent.Kind.PLAGUE_STRIKE: preload("res://assets/ui/mini_plague.png"),
	EnemyIntent.Kind.AJIAN_CHARGE: preload("res://assets/ui/mini_ajian.png"),
	EnemyIntent.Kind.AJIAN: preload("res://assets/ui/mini_ajian.png"),
	EnemyIntent.Kind.SUMMON: preload("res://assets/ui/mini_summon.png"),
	EnemyIntent.Kind.STAGGER: preload("res://assets/ui/mini_stagger.png"),
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
var _intent_icon2: TextureRect
var _intent_label2: Label
var _ngamuk_badge: Label
var _amuk_row: HBoxContainer
var _amuk_dots: Array[TextureRect] = []
var _amuk_pulse: Tween
var _prayitna_icon: TextureRect
var _giris_box: HBoxContainer
var _giris_label: Label
var _ajian_bar: ProgressBar
var _ajian_label: Label
var _bala_shield: TextureRect
var _bala_tween: Tween
var _marker: Polygon2D
var _click_area: Control
var _home := Vector2.ZERO
var _bar_width: float = BAR_WIDTH
var _aura: Sprite2D
var _aura_tween: Tween
var _embers: CPUParticles2D
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

	# Bar nyawa ikut menyempit kalau Buto diperkecil (tata letak 4 Buto).
	_bar_width = roundf(BAR_WIDTH * clampf(unit_scale, 0.85, 1.0))
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
	_bar.size = Vector2(_bar_width, 8)
	_bar.position = Vector2(-_bar_width * 0.5, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_enemy:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.36, 0.78, 0.42)
		fill.border_width_bottom = 1
		fill.border_color = Color(0.18, 0.45, 0.22)
		_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)
	_bar_label = UIKit.small_label("")
	_bar_label.size = Vector2(_bar_width, 8)
	_bar_label.position = Vector2(-_bar_width * 0.5, 2)
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_bar_label.add_theme_constant_override("outline_size", 2)
	add_child(_bar_label)

	# Tameng & Racun di kiri bar HP.
	_status_row = UIKit.hbox(1)
	_status_row.position = Vector2(-_bar_width * 0.5 - 36, 1)
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
	# Prayitna (hanya Eyang Palang): ikon mata waspada.
	_prayitna_icon = UIKit.icon(preload("res://assets/ui/mini_prayitna.png"))
	_prayitna_icon.visible = false
	_status_row.add_child(_prayitna_icon)
	# Giris (hanya Buto): serangan berikutnya melemah karena Gong Beri.
	_giris_box = UIKit.hbox(0)
	_giris_box.add_child(UIKit.icon(preload("res://assets/ui/mini_giris.png")))
	_giris_label = UIKit.small_label("", UIKit.COLOR_PURPLE)
	_giris_box.add_child(_giris_label)
	_giris_box.visible = false
	_status_row.add_child(_giris_box)
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
	# Aksi kedua, hanya tampil saat Buto ini akan Ngamuk.
	_intent_icon2 = UIKit.icon(null)
	_intent_box.add_child(_intent_icon2)
	_intent_label2 = UIKit.label("", &"", UIKit.COLOR_TEXT)
	_intent_label2.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_intent_label2.add_theme_constant_override("outline_size", 3)
	_intent_box.add_child(_intent_label2)
	_intent_box.visible = false
	add_child(_intent_box)

	# Titik Amuk: tiga api kecil di bawah niat, dan "x2" saat siap Ngamuk.
	_amuk_row = UIKit.hbox(2)
	_amuk_row.position = Vector2(-20, top - 4)
	_amuk_row.size = Vector2(40, 9)
	_amuk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i: int in EnemyUnit.AMUK_MAX:
		var dot := UIKit.icon(AMUK_EMPTY)
		_amuk_row.add_child(dot)
		_amuk_dots.append(dot)
	_ngamuk_badge = UIKit.small_label("x2", UIKit.COLOR_RED)
	_ngamuk_badge.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_ngamuk_badge.add_theme_constant_override("outline_size", 2)
	_ngamuk_badge.visible = false
	_amuk_row.add_child(_ngamuk_badge)
	_amuk_row.visible = false
	add_child(_amuk_row)

	# Bar Buyarkan (Buto Hitam saat menyiapkan Ajian), tepat di atas bar nyawa.
	# Di bawahnya sudah ada kartu di tangan.
	_ajian_bar = ProgressBar.new()
	_ajian_bar.show_percentage = false
	_ajian_bar.size = Vector2(_bar_width, 8)
	_ajian_bar.position = Vector2(-_bar_width * 0.5, -7)
	_ajian_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ajian_bg := StyleBoxFlat.new()
	ajian_bg.bg_color = Color(0.12, 0.06, 0.14)
	ajian_bg.set_border_width_all(1)
	ajian_bg.border_color = Color(0.84, 0.19, 0.38)
	_ajian_bar.add_theme_stylebox_override("background", ajian_bg)
	var ajian_fill := StyleBoxFlat.new()
	ajian_fill.bg_color = Color(0.72, 0.5, 0.16)
	_ajian_bar.add_theme_stylebox_override("fill", ajian_fill)
	_ajian_bar.visible = false
	add_child(_ajian_bar)
	_ajian_label = UIKit.small_label("", Color(1.0, 0.9, 0.7))
	_ajian_label.size = Vector2(_bar_width + 40, 8)
	_ajian_label.position = Vector2(-_bar_width * 0.5 - 20, -8)
	_ajian_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ajian_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.06))
	_ajian_label.add_theme_constant_override("outline_size", 2)
	_ajian_label.visible = false
	add_child(_ajian_label)

	# Perisai Bala di samping niat: Buto ini hanya menerima separuh damage.
	_bala_shield = UIKit.icon(preload("res://assets/ui/mini_bala_shield.png"))
	_bala_shield.position = Vector2(-36, top - 17)
	_bala_shield.visible = false
	add_child(_bala_shield)

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
	# Area badan di bawah ikon-ikon, supaya ikon di atas kepala bisa disorot sendiri.
	move_child(_click_area, _sprite.get_index() + 1)
	_hoverable(_intent_box, "intent")
	_hoverable(_amuk_row, "amuk")
	_hoverable(_bala_shield, "bala_shield")
	_hoverable(_block_box, "block")
	_hoverable(_poison_box, "poison")
	_hoverable(_ajian_label, "ajian")
	_hoverable(_prayitna_icon, "prayitna")
	_hoverable(_giris_box, "giris")

	_home = position
	_start_bob()


# Ikon status yang menampilkan keterangan saat disorot.
func _hoverable(control: Control, icon: String) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_HELP
	control.mouse_entered.connect(func() -> void:
		var rect := control.get_global_rect()
		icon_hovered.emit(self, icon, true, Vector2(rect.get_center().x, rect.position.y)))
	control.mouse_exited.connect(func() -> void: icon_hovered.emit(self, icon, false, Vector2.ZERO))


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


## Titik Amuk hanya tampil untuk Buto yang bisa Ngamuk.
func show_amuk(enabled: bool) -> void:
	_amuk_row.visible = enabled and not _dead


func set_amuk(value: int) -> void:
	var filled := clampi(value, 0, _amuk_dots.size())
	for i: int in _amuk_dots.size():
		_amuk_dots[i].texture = AMUK_FULL if i < filled else AMUK_EMPTY
	if _amuk_pulse != null:
		_amuk_pulse.kill()
		_amuk_row.modulate = Color.WHITE
	_ngamuk_badge.visible = filled >= _amuk_dots.size()
	if filled >= _amuk_dots.size():
		# Amuk penuh: berdenyut supaya pemain sadar giliran depan ia Ngamuk.
		_amuk_pulse = _amuk_row.create_tween().set_loops()
		_amuk_pulse.tween_property(_amuk_row, "modulate", Color(1.6, 1.2, 1.2), 0.35)
		_amuk_pulse.tween_property(_amuk_row, "modulate", Color.WHITE, 0.35)


## Lencana "x2" mengikuti jumlah aksi sebenarnya. Buto Hitam bisa menunda
## Ngamuk walau Amuk-nya penuh.
func set_ngamuk_badge(on: bool) -> void:
	if _dead or not _amuk_row.visible:
		return
	_ngamuk_badge.visible = on


## Bar Buyarkan. progress < 0 menyembunyikannya.
func set_ajian_progress(progress: int, threshold: int) -> void:
	var on := progress >= 0 and not _dead
	_ajian_bar.visible = on
	_ajian_label.visible = on
	if not on:
		return
	_ajian_bar.max_value = threshold
	var t := create_tween()
	t.tween_property(_ajian_bar, "value", float(mini(progress, threshold)), 0.2)
	_ajian_label.text = tr("AJIAN_BREAK_BAR") % [mini(progress, threshold), threshold]


func set_bala_shield(on: bool) -> void:
	on = on and not _dead
	_bala_shield.visible = on
	if _bala_tween != null:
		_bala_tween.kill()
		_bala_tween = null
	if on:
		_bala_tween = _bala_shield.create_tween().set_loops()
		_bala_tween.tween_property(_bala_shield, "modulate", Color(1.5, 1.3, 1.7), 0.5)
		_bala_tween.tween_property(_bala_shield, "modulate", Color.WHITE, 0.5)


## Wujud Bala: gelap keunguan dan tembus pandang.
func set_shadow(on: bool) -> void:
	if not on:
		return
	_sprite.modulate = Color(0.42, 0.32, 0.6, 0.8)
	_material.set_shader_parameter("outline_color", Color(0.6, 0.4, 0.9, 0.55))


## Muncul perlahan dari kepulan asap (Bala yang baru dipanggil).
func play_spawn() -> void:
	var target := _sprite.modulate
	_sprite.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_sprite, "modulate:a", target.a, 0.6)
	var smoke := CPUParticles2D.new()
	smoke.amount = 16
	smoke.lifetime = 0.8
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(36, 40) * unit_scale
	smoke.position = Vector2(0, -60) * unit_scale
	smoke.direction = Vector2(0, -1)
	smoke.spread = 60.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 20.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 5.0
	smoke.color = Color(0.45, 0.3, 0.6, 0.55)
	add_child(smoke)
	smoke.emitting = true
	get_tree().create_timer(1.2).timeout.connect(smoke.queue_free)


## Ikon Prayitna di samping bar nyawa Eyang Palang.
func set_prayitna(on: bool) -> void:
	_prayitna_icon.visible = on and not _dead


## Ikon Giris di samping bar nyawa Buto, dengan persen serangan yang hilang.
func set_giris(value: float) -> void:
	_giris_box.visible = value > 0.0 and not _dead
	_giris_label.text = "-%d%%" % roundi(value * 100.0)


func set_intent(intent: EnemyIntent) -> void:
	var list: Array[EnemyIntent] = [intent]
	set_intents(list)


## Satu niat, atau dua kalau Buto ini akan Ngamuk (keduanya tampil berdampingan).
func set_intents(intents: Array[EnemyIntent]) -> void:
	if intents.is_empty() or intents[0] == null or _dead:
		_intent_box.visible = false
		return
	_intent_box.visible = true
	_show_intent(intents[0], _intent_icon, _intent_label)
	var second := intents.size() >= 2 and intents[1] != null
	_intent_icon2.visible = second
	_intent_label2.visible = second
	if second:
		_show_intent(intents[1], _intent_icon2, _intent_label2)


func _show_intent(intent: EnemyIntent, icon: TextureRect, label: Label) -> void:
	icon.texture = INTENT_ICONS.get(intent.kind)
	match intent.kind:
		EnemyIntent.Kind.LOCK:
			label.text = "x%d" % intent.extra if intent.extra > 1 else ""
		EnemyIntent.Kind.CHARGE:
			label.text = "!"
		EnemyIntent.Kind.AJIAN_CHARGE:
			label.text = "%d!" % intent.extra
		EnemyIntent.Kind.SUMMON:
			label.text = "x%d" % intent.extra
		_:
			label.text = str(intent.damage) if intent.damage > 0 else ""
	var heavy := intent.kind in [EnemyIntent.Kind.HEAVY, EnemyIntent.Kind.AJIAN, EnemyIntent.Kind.AJIAN_CHARGE]
	label.add_theme_color_override("font_color", UIKit.COLOR_RED if heavy else UIKit.COLOR_TEXT)


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
	if _amuk_pulse != null:
		_amuk_pulse.kill()
	_amuk_row.visible = false
	_ajian_bar.visible = false
	_ajian_label.visible = false
	_giris_box.visible = false
	set_bala_shield(false)
	if _aura_tween != null:
		_aura_tween.kill()
	if _aura != null:
		_aura.visible = false
	if _embers != null:
		_embers.emitting = false
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
	if _aura != null:
		_aura.texture = _sprite.texture


## Aura Buto Murka: cahaya merah keunguan yang berdenyut di belakang tubuh
## dan bara kecil yang naik.
func set_murka(on: bool) -> void:
	if not on or _aura != null:
		return
	_make_aura(Color(0.95, 0.15, 0.5, 0.55), 0.45, 0.9)
	_embers = CPUParticles2D.new()
	_embers.amount = 10
	_embers.lifetime = 1.4
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(40, 30) * unit_scale
	_embers.position = Vector2(0, -60) * unit_scale
	_embers.direction = Vector2(0, -1)
	_embers.spread = 25.0
	_embers.gravity = Vector2.ZERO
	_embers.initial_velocity_min = 12.0
	_embers.initial_velocity_max = 24.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.45, 0.3, 0.9))
	ramp.set_color(1, Color(0.7, 0.2, 0.8, 0.0))
	_embers.color_ramp = ramp
	add_child(_embers)


## Aura emas Eyang Palang (hadiah 30 Bintang Dongkrek).
func set_golden_aura(on: bool) -> void:
	if on and _aura == null:
		_make_aura(Color(1.0, 0.78, 0.3, 0.4), 0.3, 0.6)


# Siluet bercahaya di belakang sprite yang berdenyut antara dua tingkat alpha.
func _make_aura(color: Color, alpha_low: float, alpha_high: float) -> void:
	_aura = Sprite2D.new()
	_aura.texture = _sprite.texture
	_aura.centered = false
	_aura.offset = _sprite.offset
	_aura.flip_h = _sprite.flip_h
	_aura.scale = _sprite.scale * 1.06
	_aura.position = Vector2(0, 2)
	var mat := ShaderMaterial.new()
	mat.shader = MURKA_AURA
	_aura.material = mat
	_aura.modulate = color
	add_child(_aura)
	move_child(_aura, _sprite.get_index())
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(_aura, "modulate:a", alpha_high, 0.7).set_trans(Tween.TRANS_SINE)
	_aura_tween.tween_property(_aura, "modulate:a", alpha_low, 0.7).set_trans(Tween.TRANS_SINE)


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
