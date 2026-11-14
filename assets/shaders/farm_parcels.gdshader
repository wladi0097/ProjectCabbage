shader_type canvas_item;
// The country sheet's land that is not the company's yet (FarmRegister, `Page/Sheet/Layers/Parcels`):
// a TextureRect with the sheet's own art, drawn again over it in fallow grey wherever the art is
// cabbage green, except on the parcels owned. So the cabbage pattern the art already has shows only
// on company land, and spreads from a farm's token when its radius grows.
// A parcel is the land nearer to its site than to any other (so two farms share a straight fence),
// out to its radius; the edge wobbles a little, like a surveyed field.

// Every site: its place on the art (px) and how far its parcel reaches right now (px; 0: not owned).
uniform vec3 sites[9];
uniform vec2 art_size = vec2(3200.0, 1800.0);
uniform vec3 fallow : source_color = vec3(0.76, 0.78, 0.74);
// The edge of a parcel is this soft (px).
uniform float soft = 10.0;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 p = UV * art_size;
	float nearest = 1e9;
	float reach = 0.0;
	vec2 from = vec2(0.0);
	for (int i = 0; i < 9; i++) {
		float d = distance(p, sites[i].xy);
		if (d < nearest) {
			nearest = d;
			reach = sites[i].z;
			from = p - sites[i].xy;
		}
	}
	float edge = reach * (1.0 + 0.06 * sin(atan(from.y, from.x) * 7.0 + (p.x - from.x) * 0.01));
	float ours = reach > 0.0 ? smoothstep(edge, edge - soft, nearest) : 0.0;
	float green = smoothstep(0.03, 0.12, art.g - max(art.r, art.b));
	float light = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(fallow * light / 0.72, green * (1.0 - ours));
}
