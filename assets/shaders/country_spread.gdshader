shader_type canvas_item;
// A country's cabbage-pattern overlay on the world sheet (WorldRegister, `Page/Sheet/Layers/<id>`):
// shown out to `reach` px from the country's holding point, so the pattern spreads from the token
// when the country is taken (the country sheet's parcels do the same, farm_parcels.gdshader). The
// edge wobbles a little, like a surveyed field. An owned country's reach covers the whole sheet.

// The holding point on the art (px) and how far the pattern reaches from it right now (px).
uniform vec2 from = vec2(0.0);
uniform float reach = 0.0;
uniform vec2 art_size = vec2(3200.0, 1800.0);
// The spreading edge is this soft (px).
uniform float soft = 24.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 away = UV * art_size - from;
	float edge = reach * (1.0 + 0.06 * sin(atan(away.y, away.x) * 7.0));
	COLOR = vec4(art.rgb, art.a * smoothstep(edge, edge - soft, length(away)));
}
