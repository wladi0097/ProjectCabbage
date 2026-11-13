// The high Findings tokens (¶500, ¶1K, ¶5K, ¶10K): findings_token_high atlas, 4 faces side by
// side, each drawn into the middle 96% of its tile; `column` picks one (one material per denomination).
// No lights: a cold cyan rim lights the chit's side wall (world normal near horizontal, brightest
// edge-on), stronger the higher the value (`rim_level`). Opaque, one pass.
shader_type spatial;

const float COLUMNS = 4.0;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float column = 0.0;
uniform float rim_level = 1.0;
uniform vec3 rim_colour : source_color = vec3(0.35, 0.8, 0.88);
uniform float rim_energy = 1.6;
uniform float rim_power = 2.0;

void fragment() {
	vec2 uv = vec2((UV.x * 0.96 + 0.02 + column) / COLUMNS, UV.y * 0.96 + 0.02);
	ALBEDO = texture(albedo_tex, uv).rgb;
	// Like the low tokens' ORMMaterial3D (ao off, metallic 0): only the roughness channel is used.
	ROUGHNESS = texture(orm_tex, uv).g;
	float side = 1.0 - abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_colour * (side * side * (0.35 + 0.65 * fresnel) * rim_level * rim_energy);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
}
