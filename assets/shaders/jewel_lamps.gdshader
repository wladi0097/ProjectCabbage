shader_type spatial;
// A bank of jewel lamp lenses on one mesh: each lens carries its index in UV.x ((index + 0.5) / lamps),
// and the first `lit` of them glow. One draw call for the whole bank; state is one instance uniform.

uniform float lamps = 24.0;
uniform vec3 dark : source_color = vec3(0.2, 0.045, 0.04);
uniform vec3 glow : source_color = vec3(0.45, 0.085, 0.07);
uniform float energy = 0.8;
instance uniform float lit = 0.0;

void fragment() {
	float on = step(floor(UV.x * lamps) + 0.5, lit);
	ALBEDO = mix(dark, glow * 0.5, on);
	EMISSION = glow * energy * on;
	ROUGHNESS = 0.4;
	SPECULAR = 0.3;
}
