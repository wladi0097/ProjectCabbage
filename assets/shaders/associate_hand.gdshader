shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;
// The junior associate's hand: the player's glove mesh, recoloured by its vertex colour parts
// (linear: suit sleeve ~0.003, glove ~0.07, shirt cuff ~0.5) into an intern's off-white cotton
// glove and grey office sleeve. A ghost: see-through in the middle, firmer at the silhouette, and
// (being transparent) it casts no shadow.

uniform vec3 glove : source_color = vec3(0.56, 0.57, 0.55);
uniform vec3 sleeve : source_color = vec3(0.36, 0.37, 0.38);
uniform vec3 shirt : source_color = vec3(0.74, 0.75, 0.74);
uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	float part = COLOR.r;
	ALBEDO = part < 0.02 ? sleeve : (part > 0.3 ? shirt : glove);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	RIM = 0.25;
	RIM_TINT = 0.3;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALPHA = mix(opacity, edge_opacity, edge);
}
