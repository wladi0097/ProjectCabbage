shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// Thin glass for round parts (the mini tube's pipe): nearly clear face-on, opaque-ish pale at the
// grazing edges, so a cylinder reads as a cylinder from above.

uniform vec3 tint : source_color = vec3(0.6, 0.67, 0.67);
uniform float face_alpha = 0.06;
uniform float edge_alpha = 0.7;
uniform float edge_power = 3.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_power);
	ALBEDO = tint;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	ALPHA = mix(face_alpha, edge_alpha, fresnel);
}
