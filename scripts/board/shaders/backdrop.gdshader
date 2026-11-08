shader_type spatial;
render_mode unshaded, cull_disabled;
// Psychedelic moving backdrop (Balatro / Mother-battle vibes), driven by
// per-board BoardDef colors so each theme paints its own void.

uniform vec3 color_a : source_color = vec3(0.23, 0.12, 0.43);
uniform vec3 color_b : source_color = vec3(1.0, 0.44, 0.71);
uniform vec3 color_c : source_color = vec3(0.30, 0.93, 0.92);
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform float pattern_scale : hint_range(0.5, 10.0) = 3.0;

void fragment() {
	vec2 uv = UV * pattern_scale;
	float t = TIME * speed;
	vec2 p = uv + vec2(
		sin(t * 0.7 + uv.y * 2.0) * 0.35,
		cos(t * 0.5 + uv.x * 2.0) * 0.35);
	float waves = sin(p.x * 3.0 + t) * sin(p.y * 3.0 - t * 0.8);
	float band = fract(waves + t * 0.15);
	vec3 col = mix(color_a, color_b, smoothstep(0.25, 0.75, band));
	col = mix(col, color_c, 0.25 + 0.25 * sin(t + p.x + p.y));
	ALBEDO = col;
	EMISSION = col * 0.55;
}
