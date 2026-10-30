shader_type canvas_item;
// Darkens the screen edges, like the moody desk reference.

uniform float strength : hint_range(0.0, 1.0) = 0.65;
uniform float inner : hint_range(0.0, 1.0) = 0.35;
uniform float outer : hint_range(0.0, 1.5) = 0.95;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(inner, outer, length(d) * 1.4);
	COLOR = vec4(0.0, 0.0, 0.0, v * strength);
}
