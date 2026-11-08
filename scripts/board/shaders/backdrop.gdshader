shader_type spatial;
render_mode unshaded, cull_disabled;
// Psychedelic moving backdrop (Balatro / Mother-battle vibes), driven by
// per-board BoardDef colors so each theme paints its own void.

uniform vec3 color_a : source_color = vec3(0.23, 0.12, 0.43);
uniform vec3 color_b : source_color = vec3(1.0, 0.44, 0.71);
uniform vec3 color_c : source_color = vec3(0.30, 0.93, 0.92);
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform float pattern_scale : hint_range(0.5, 10.0) = 3.0;


// Wind indicator (user request, 2026-11-08): chevron arrows flowing with the
// wind. wind_arrow is the fade intensity (0 off), wind_dir the flow (+1 flows
// toward local +x of the wall; on the back wall that is world +X, the side a
// wind_direction of +1 pushes the marble toward).
uniform float wind_arrow : hint_range(0.0, 1.0) = 0.0;
uniform float wind_dir : hint_range(-1.0, 1.0) = 1.0;

float _seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float _wind_chevrons(vec2 uv, float t) {
	vec2 q = vec2(fract(uv.x * 9.0 - t * 0.4 * wind_dir),
			fract(uv.y * 4.0));
	float d = min(
			_seg_dist(q, vec2(0.32, 0.30), vec2(0.68, 0.50)),
			_seg_dist(q, vec2(0.68, 0.50), vec2(0.32, 0.70)));
	return smoothstep(0.07, 0.02, d);
}

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
	float arrows = _wind_chevrons(UV, TIME) * wind_arrow;
	ALBEDO = mix(col, color_c, arrows * 0.4);
	EMISSION = col * 0.55 + color_c * arrows * 0.9;
}
