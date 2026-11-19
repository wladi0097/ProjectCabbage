shader_type spatial;
// The chapter 5 ending's MATERIAL conversion: drawn over a converted object's meshes (material_overlay),
// fresh cabbage leaf with pale veins spreads from the hit point (`origin`, world space) out to `radius`,
// a bright rim on its front edge. Outside the radius the object's own material shows.
render_mode cull_back;

uniform vec3 origin = vec3(0.0);
uniform float radius = 0.0;
uniform float rim = 0.12;
uniform vec3 leaf : source_color = vec3(0.36, 0.66, 0.2);
uniform vec3 shade : source_color = vec3(0.2, 0.42, 0.12);
uniform vec3 vein : source_color = vec3(0.78, 0.9, 0.55);
// Veins per metre.
uniform float scale = 2.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A leaf vein pattern: a midrib per cell and side veins slanting off it.
float veins(vec2 p) {
	p *= scale;
	p += vec2(noise(p * 1.7), noise(p * 1.7 + 9.0)) * 0.35;
	vec2 cell = fract(p) - 0.5;
	float mid = smoothstep(0.035, 0.0, abs(cell.x));
	float side = smoothstep(0.06, 0.0, abs(fract(cell.y * 3.0 - abs(cell.x) * 2.2) - 0.5)) * smoothstep(0.5, 0.1, abs(cell.x));
	return max(mid, side * 0.55);
}

void fragment() {
	float d = distance(world_pos, origin);
	if (d > radius) {
		discard;
	}
	vec3 n = abs(world_normal);
	vec2 uv = n.y > max(n.x, n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float mottle = noise(uv * 6.0);
	vec3 base = mix(shade, leaf, 0.55 + 0.45 * mottle);
	ALBEDO = mix(base, vein, veins(uv) * 0.7);
	ROUGHNESS = 0.55;
	SPECULAR = 0.25;
	float edge = smoothstep(rim, 0.0, radius - d);
	EMISSION = vein * edge * 1.4;
}
