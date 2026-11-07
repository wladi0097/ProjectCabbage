shader_type canvas_item;
// The farm TV's NO SIGNAL snow: grey cells re-rolled 20 times a second, a slow rolling band.

void fragment() {
	vec2 cell = floor(UV * vec2(256.0, 192.0));
	float n = fract(sin(dot(cell + floor(TIME * 20.0) * 7.13, vec2(12.9898, 78.233))) * 43758.5453);
	float roll = 0.8 + 0.2 * sin(UV.y * 30.0 + TIME * 5.0);
	COLOR = vec4(vec3(0.82, 0.86, 0.84) * mix(0.14, 0.6, n) * roll, 1.0);
}
