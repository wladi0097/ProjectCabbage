shader_type canvas_item;
// A country's cabbage-pattern overlay on the world sheet (WorldRegister, `Page/Sheet/Layers/<id>`):
// shown out to `reach` px from the country's holding point, so the pattern spreads from the token
// when the country is taken (the country sheet's parcels do the same, farm_parcels.gdshader). The
// edge wobbles a little, like a surveyed field. An owned country's reach covers the whole sheet.
// `patchy`: only some of its farms are ours (WorldRegister.Share.SOME), so only scattered patches of
// the pattern show, mottled like land bought up piecemeal. The same patches whatever the share.

// The holding point on the art (px) and how far the pattern reaches from it right now (px).
uniform vec2 from = vec2(0.0);
uniform float reach = 0.0;
uniform vec2 art_size = vec2(3200.0, 1800.0);
// The spreading edge is this soft (px).
uniform float soft = 24.0;
uniform bool patchy = false;
// The patches: their size (px), how much of the land they cover (0..1) and how strongly they print.
uniform float patch_size = 46.0;
uniform float patch_cover = 0.42;
uniform float patch_ink = 0.85;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 px = UV * art_size;
	vec2 away = px - from;
	float edge = reach * (1.0 + 0.06 * sin(atan(away.y, away.x) * 7.0));
	float shown = smoothstep(edge, edge - soft, length(away));
	if (patchy) {
		vec2 p = px / patch_size;
		float n = 0.65 * noise(p) + 0.35 * noise(p * 2.7 + 17.0);
		shown *= patch_ink * smoothstep(1.0 - patch_cover - 0.03, 1.0 - patch_cover + 0.03, n);
	}
	COLOR = vec4(art.rgb, art.a * shown);
}
