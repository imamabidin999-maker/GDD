class_name Ambient
extends RefCounted
## Efek suasana yang dipakai di beberapa layar (battle, menu, peta, ending).


## Kunang-kunang yang melayang pelan di area persegi (center ± extents).
static func fireflies(center: Vector2, extents: Vector2, amount: int = 18) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.position = center
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.5, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.95, 0.5, 0.9))
	ramp.add_point(0.7, Color(0.8, 1.0, 0.5, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 1.0, 0.5, 0.0))
	p.color_ramp = ramp
	return p


## Sprite karakter yang "bernapas" pelan (skala naik-turun sedikit).
## Origin sprite ada di kaki supaya napasnya tidak menggeser pijakan.
static func breathing_sprite(texture: Texture2D, feet: Vector2, flip: bool = false, sprite_scale: float = 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = false
	s.offset = Vector2(-texture.get_width() * 0.5, -150.0)
	s.position = feet
	s.flip_h = flip
	s.scale = Vector2.ONE * sprite_scale
	var t := s.create_tween().set_loops()
	t.tween_property(s, "scale:y", sprite_scale * 1.02, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(s, "scale:y", sprite_scale, 1.1).set_trans(Tween.TRANS_SINE)
	return s
