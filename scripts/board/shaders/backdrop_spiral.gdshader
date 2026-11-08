shader_type spatial;
render_mode unshaded, cull_disabled;
// Hypnotic spiral backdrop variant (M2.5): slow rings winding out of the
// center of the room wall. Same uniforms and emission as backdrop.gdshader,
// so a BoardDef only picks the style and keeps its three colors.

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
	// Mirror the chevron with the flow sign: the shape must point the same
	// way it drifts, or a -1 wind shows arrows leaning the wrong way
	// (user report, 2026-11-08).
	q.x = wind_dir >= 0.0 ? q.x : 1.0 - q.x;
	float d = min(
			_seg_dist(q, vec2(0.32, 0.30), vec2(0.68, 0.50)),
			_seg_dist(q, vec2(0.68, 0.50), vec2(0.32, 0.70)));
	return smoothstep(0.07, 0.02, d);
}

void fragment() {
	// Centered coordinates so the rings wind out of the middle of the wall.
	vec2 p = (UV - vec2(0.5)) * pattern_scale * 2.0;
	float t = TIME * speed;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	// Tight spiral: the ring count grows with the radius, the phase with time.
	float spiral = sin(angle * 3.0 + radius * 6.0 - t * 1.4);
	float band = smoothstep(-0.2, 0.6, spiral);
	vec3 col = mix(color_a, color_b, band);
	col = mix(col, color_c, 0.3 + 0.3 * sin(t + radius * 1.5));
	float arrows = _wind_chevrons(UV, TIME) * wind_arrow;
	ALBEDO = mix(col, color_c, arrows * 0.4);
	EMISSION = col * 0.55 + color_c * arrows * 0.9;
}
