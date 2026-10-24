shader_type canvas_item;
// Efek sprite karakter:
// - garis tepi tipis (supaya Buto berbulu gelap tetap terbaca di latar malam)
// - kilat putih saat terkena pukulan
// - warna tepi berubah saat Buto sedang jadi target

uniform vec4 outline_color : source_color = vec4(0.78, 0.82, 1.0, 0.45);
uniform float outline_width = 1.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
	float around = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
		+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float edge = step(0.5, around) * (1.0 - step(0.5, base.a));
	vec4 outline = vec4(outline_color.rgb, outline_color.a * edge);
	base.rgb = mix(base.rgb, flash_color.rgb, flash * step(0.01, base.a));
	vec4 result = mix(outline, base, step(0.01, base.a));
	result.a *= fade;
	COLOR = result * COLOR;
}
