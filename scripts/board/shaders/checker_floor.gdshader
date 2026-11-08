shader_type spatial;
render_mode unshaded;
// Circus void floor: black-and-white checker seen in perspective, tinted
// by the board theme.

uniform vec3 col_a : source_color = vec3(0.95, 0.95, 0.97);
uniform vec3 col_b : source_color = vec3(0.08, 0.06, 0.16);
uniform float checker_size : hint_range(1.0, 40.0) = 8.0;

void fragment() {
	vec2 uv = UV * checker_size;
	float c = mod(floor(uv.x) + floor(uv.y), 2.0);
	ALBEDO = mix(col_a, col_b, c);
}
