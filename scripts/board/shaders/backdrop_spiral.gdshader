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
	ALBEDO = col;
	EMISSION = col * 0.55;
}
