shader_type canvas_item;
// The chapter 5 colour flip over the 3D view: saturation goes up and everything tints toward cabbage
// green as `amount` goes 0 -> 1 (at 0 the screen is untouched).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float saturation = 1.2;
uniform vec3 green : source_color = vec3(0.45, 0.8, 0.28);
uniform float tint = 0.45;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sat = max(mix(vec3(l), c, 1.0 + saturation * amount), 0.0);
	vec3 g = green / dot(green, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(sat * mix(vec3(1.0), g, tint * amount), 1.0);
}
