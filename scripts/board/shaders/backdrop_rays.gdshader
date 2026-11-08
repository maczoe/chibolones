shader_type spatial;
render_mode unshaded, cull_disabled;
// Rotating rays backdrop variant (M2.5): a fairground burst of light beams
// turning behind the cabinet. Same uniforms and emission as
// backdrop.gdshader, so a BoardDef only picks the style and keeps its
// three colors.

uniform vec3 color_a : source_color = vec3(0.23, 0.12, 0.43);
uniform vec3 color_b : source_color = vec3(1.0, 0.44, 0.71);
uniform vec3 color_c : source_color = vec3(0.30, 0.93, 0.92);
uniform float speed : hint_range(0.0, 3.0) = 0.6;
uniform float pattern_scale : hint_range(0.5, 10.0) = 3.0;

void fragment() {
	// Centered coordinates: the burst turns around the middle of the wall.
	vec2 p = (UV - vec2(0.5)) * pattern_scale;
	float t = TIME * speed;
	float radius = length(p);
	float angle = atan(p.y, p.x) + t * 0.25;
	// Rays: a fast angular wave, softened by the distance to the center so
	// the middle stays readable behind the board.
	float rays = sin(angle * 8.0) * 0.5 + 0.5;
	float falloff = clamp(radius * 1.4, 0.0, 1.0);
	vec3 col = mix(color_a, color_b, rays * falloff);
	col = mix(col, color_c, 0.2 + 0.25 * sin(t + radius * 2.0));
	ALBEDO = col;
	EMISSION = col * 0.55;
}
