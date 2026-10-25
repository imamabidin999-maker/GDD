// Aura Buto Murka: siluet sprite yang dikaburkan lalu diwarnai modulate.
// Dipakai di belakang sprite Buto, jadi yang terlihat hanya pinggirannya.
// Warna diambil dari modulate (bukan dari tekstur) karena tubuh Buto hampir
// hitam, dan warna hitam tidak menambah apa-apa pada blend tambahan.
shader_type canvas_item;
render_mode blend_add;

// Jari-jari kabur dalam piksel tekstur.
uniform float radius = 4.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 step_px = TEXTURE_PIXEL_SIZE * radius;
	float a = texture(TEXTURE, UV).a;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		vec2 dir = vec2(cos(ang), sin(ang));
		a += texture(TEXTURE, UV + dir * step_px).a;
		a += texture(TEXTURE, UV + dir * step_px * 2.0).a * 0.6;
	}
	COLOR = vec4(tint.rgb, tint.a * clamp(a / 10.0, 0.0, 1.0));
}
