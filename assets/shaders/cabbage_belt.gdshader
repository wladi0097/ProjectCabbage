shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The condensed cabbage's paper belt (entities/cabbage/, mesh assets/meshes/Props/cabbage_belt.res,
// built round its Y axis at radius BASE). Every vertex moves out to just past the cabbage's own leaves
// in its direction, read from `reach` (how far each cabbage mesh reaches, baked by the skill's
// examples/cabbage_reach_bake.gd), so the paper hugs whatever side of the cabbage is turned into it and
// no leaf can poke through. The belt keeps its offset from BASE (the paper's thickness, the overlap).
// Per belt (Cabbage._process): the rows of the turn from belt to mesh space, the mesh's scale (w of
// to_mesh_x), which mesh (w of to_mesh_y) and the printed count (w of to_mesh_z, a row of the atlas).

uniform sampler2D print_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D reach : filter_linear, repeat_disable;

instance uniform vec4 to_mesh_x = vec4(1.0, 0.0, 0.0, 1.5);
instance uniform vec4 to_mesh_y = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform vec4 to_mesh_z = vec4(0.0, 0.0, 1.0, 0.0);

const float BASE = 0.15;
// The reach texture's full scale (m, mesh space), as in the bake.
const float REACH = 0.11;
// Each mesh's table: LAT rows of latitude (from +Y down), the three meshes stacked.
const float LAT = 64.0;
const float SHAPES = 3.0;
// Air between the outermost leaf and the paper (m).
const float CLEAR = 0.002;
// Half the belt's width plus a little: leaves within this of its middle line hold it out; leaves
// FADE higher or lower pass over or under it (between the two they let go of it gradually).
const float HALF = 0.038;
const float FADE = 0.01;
// Samples round the belt, SPAN each way STEP apart: a leaf tip holds the paper out a little either
// side of it too, falling off as cos(BEND * angle), so the paper bends over it instead of stepping.
// Kept narrow: a wide window (it was ±39°) stood the band's ends a centimetre or more off the
// cabbage's outline, so it read as a flat label sticking out both sides.
const int SPAN = 1;
const float STEP = 0.07;
const float BEND = 1.0;
// Samples up and down the belt's width, ELEVS each way ELEV apart.
const int ELEVS = 6;
const float ELEV = 0.07;
const float ROWS = 33.0;
// The mesh's arc either side of the front (degrees) and its print tiles per turn (as in
// examples/cabbage_belt_geo.py): toward the cut ends the paper shades off as it turns away round the sides.
const float ARC = 60.0;
const float TILES = 3.0;

// How far the mesh reaches in belt-space direction d. Read smoothly (the bake dilated every leaf
// over its neighbouring texels, so blending them never undercuts a leaf), so the paper never steps.
float reach_at(vec3 d) {
	vec3 m = vec3(dot(to_mesh_x.xyz, d), dot(to_mesh_y.xyz, d), dot(to_mesh_z.xyz, d));
	float lat = clamp(acos(clamp(m.y, -1.0, 1.0)) / PI * LAT, 0.5, LAT - 0.5);
	vec2 at = vec2(atan(m.z, m.x) / TAU + 0.5, (lat + floor(to_mesh_y.w + 0.5) * LAT) / (LAT * SHAPES));
	return textureLod(reach, at, 0.0).r * REACH * to_mesh_x.w;
}

void vertex() {
	vec2 across = VERTEX.xz;
	float r = length(across);
	vec2 dir = across / r;
	float hug = 0.0;
	for (int j = -SPAN; j <= SPAN; j++) {
		float a = float(j) * STEP;
		vec2 turned = vec2(dir.x * cos(a) - dir.y * sin(a), dir.x * sin(a) + dir.y * cos(a));
		for (int k = -ELEVS; k <= ELEVS; k++) {
			float e = float(k) * ELEV;
			float far = reach_at(vec3(turned.x * cos(e), sin(e), turned.y * cos(e)));
			float let_go = 1.0 - 0.25 * smoothstep(HALF, HALF + FADE, abs(far * sin(e)));
			hug = max(hug, far * cos(e) * cos(BEND * a) * let_go);
		}
	}
	VERTEX.xz = dir * (hug + CLEAR + r - BASE);
}

void fragment() {
	bool back = UV.y > 1.5;
	float v = clamp(back ? UV.y - 2.0 : UV.y, 0.01, 0.99);
	float row = back ? 0.0 : to_mesh_z.w;
	// A soft shade along the paper's edges, where it lifts off the leaves.
	float edge = smoothstep(0.0, 0.07, v) * smoothstep(1.0, 0.93, v);
	float round_side = smoothstep(ARC, ARC * 0.35, abs(UV.x - 0.5) * 360.0 / TILES);
	ALBEDO = texture(print_atlas, vec2(UV.x, (row + v) / ROWS)).rgb * mix(0.72, 1.0, edge) * mix(0.55, 1.0, round_side);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	// A little of its own light, so the side turned from the lamp stays paper, not a black stripe.
	EMISSION = ALBEDO * 0.08;
}
