shader_type canvas_item;
// The country sheet's land that is not the company's yet (FarmRegister, `Page/Sheet/Layers/Parcels`):
// a TextureRect with the sheet's own art, drawn again over it in fallow grey wherever the art is
// cabbage green, except on the parcels owned. So the cabbage pattern the art already has shows only
// on company land, and spreads from a farm's token over its parcel when its progress grows.
// The parcels are baked once (tools/bake_parcels.gd, assets/textures/map_parcels/<country>.png):
// R is the place a pixel belongs to (its site's index; the head office last), G how far the spread
// has to come from that place to reach it (0 at the token .. 1 at the parcel's far end).

uniform sampler2D parcels : filter_linear;
// How far each place's spread has come (0: not owned .. 1: all of its parcel).
uniform float progress[9];
uniform vec3 fallow : source_color = vec3(0.76, 0.78, 0.74);
// The edge of the spread is this soft (in G).
uniform float soft = 0.015;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	ivec2 size = textureSize(parcels, 0);
	int place = int(texelFetch(parcels, clamp(ivec2(UV * vec2(size)), ivec2(0), size - 1), 0).r * 255.0 + 0.5);
	float far = texture(parcels, UV).g;
	float front = progress[min(place, 8)] * (1.0 + soft);
	float ours = 1.0 - smoothstep(front - soft, front, far);
	float green = smoothstep(0.03, 0.12, art.g - max(art.r, art.b));
	float light = dot(art.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(fallow * light / 0.72, green * (1.0 - ours));
}
