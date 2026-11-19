// The war maquettes' shared surface: architect's card, board and balsa. One shader, one compile;
// each maquette_*.tres only sets the uniforms. UV is in metres (Blender box projection, or along a
// stick's length for balsa), so fibre and grain keep their size on every piece.
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.86, 0.84, 0.78);
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.25;
uniform float fibre : hint_range(0.0, 0.3) = 0.035; // paper fibre speckle and short streaks
uniform float fibre_scale = 700.0; // per metre
uniform float mottle : hint_range(0.0, 0.3) = 0.025; // soft cloudiness of pressed board
uniform float grain : hint_range(0.0, 0.6) = 0.0; // balsa streaks running along UV.x
uniform float grain_scale = 220.0; // streaks per metre across the grain
uniform float end_grain : hint_range(0.0, 0.6) = 0.0; // how much darker a stick's sawn end is (|UV.y| > 50)
uniform float side_lift : hint_range(0.0, 2.0) = 0.0; // self-light on walls (not tops), so dark board sides in the lamp's shade keep their colour

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV;
	float shade = 0.0;
	// fine detail fades out once a fibre gets smaller than a pixel (the map camera), so it never sparkles
	float near = 1.0 - clamp(length(fwidth(p * fibre_scale)) - 0.6, 0.0, 1.0);
	float near_grain = 1.0 - clamp(fwidth(p.y * grain_scale) - 0.6, 0.0, 1.0);
	// fibre: fine speckle plus short streaks in two crossing directions
	float speck = noise(p * fibre_scale) - 0.5;
	vec2 q = p * fibre_scale * 0.35;
	float streak = max(noise(vec2(q.x * 0.25, q.y * 2.0)), noise(vec2(q.y * 0.25 + 17.0, q.x * 2.0)));
	shade += fibre * near * (speck * 1.5 - smoothstep(0.7, 0.92, streak));
	shade += mottle * (noise(p * 18.0) - 0.5) * 2.0;
	// balsa: long soft streaks across V, a few darker growth lines
	float g = noise(vec2(p.x * grain_scale * 0.03, p.y * grain_scale)) * 0.65 + noise(vec2(p.x * grain_scale * 0.06 + 5.0, p.y * grain_scale * 2.3)) * 0.35;
	if (abs(UV.y) > 50.0) { // the sawn end of a balsa stick: a clean, slightly darker tone
		shade = -end_grain;
	} else {
		shade += grain * near_grain * ((g - 0.5) * 1.6 - smoothstep(0.74, 0.9, g) * 0.9);
	}
	ALBEDO = albedo * clamp(1.0 + shade, 0.0, 1.5);
	float side = 1.0 - abs((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	EMISSION = ALBEDO * side_lift * side;
	ROUGHNESS = clamp(roughness + shade * 0.5, 0.0, 1.0);
	METALLIC = metallic;
	SPECULAR = specular;
}
