shader_type spatial;
// A 1960s-70s fourteen-segment readout behind dark smoked glass (DigitalReadout): pale cold phosphor
// figures with a soft glow, every unlit segment faintly ghosted behind them, fine scanlines and a
// dim reflection across the top of the glass. The window fills with as many figure cells as fit
// (at least min_cells, shrinking the figures to fit); the figures sit right-aligned, the cells to
// their left stay ghosted. masks[0] is the rightmost cell: bits 0-13 the segments (SEGS), 14 the dot,
// 15 the pilcrow and 16 a B (drawn whole: in segments they read as a 9 and an 8).
render_mode unshaded, cull_back;

uniform int masks[16];
uniform vec3 ink : source_color = vec3(0.62, 0.86, 0.68);
uniform int min_cells = 1;
// How bright a lit segment's core burns (above 1 the room's glow picks it up).
uniform float burn = 1.15;

// Figure width, cell pitch and the figures' height, in figure heights / window heights.
const float W = 0.58;
const float PITCH = 0.94;
const float HEIGHT = 0.72;
const float T = 0.072;
const float G = 0.04;
const float SLANT = 0.1;
const vec3 GLASS = vec3(0.018, 0.03, 0.026);
const float M = W * 0.5;
// a b c d e f g1 g2 h i j k l m: top, upper right, lower right, bottom, lower left, upper left,
// middle left/right, upper-left diagonal, upper stem, upper-right diagonal, lower-left diagonal,
// lower stem, lower-right diagonal.
const vec4 SEGS[14] = vec4[](
	vec4(G, 1.0, W - G, 1.0), vec4(W, 0.5 + G, W, 1.0 - G), vec4(W, G, W, 0.5 - G),
	vec4(G, 0.0, W - G, 0.0), vec4(0.0, G, 0.0, 0.5 - G), vec4(0.0, 0.5 + G, 0.0, 1.0 - G),
	vec4(G, 0.5, M - G * 0.5, 0.5), vec4(M + G * 0.5, 0.5, W - G, 0.5),
	vec4(G * 2.4, 1.0 - G * 2.6, M - G * 1.3, 0.5 + G * 2.2), vec4(M, 0.5 + G * 1.7, M, 1.0 - G * 1.7),
	vec4(W - G * 2.4, 1.0 - G * 2.6, M + G * 1.3, 0.5 + G * 2.2),
	vec4(G * 2.4, G * 2.6, M - G * 1.3, 0.5 - G * 2.2), vec4(M, G * 1.7, M, 0.5 - G * 1.7),
	vec4(W - G * 2.4, G * 2.6, M + G * 1.3, 0.5 - G * 2.2));

varying float aspect;

void vertex() {
	aspect = length(MODEL_MATRIX[0].xyz) / max(length(MODEL_MATRIX[1].xyz), 1e-5);
}

float segment(vec2 p, vec4 s) {
	vec2 pa = p - s.xy;
	vec2 ba = s.zw - s.xy;
	float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * t);
}

void fragment() {
	vec2 q = vec2(UV.x * aspect, 1.0 - UV.y);
	float h = min(HEIGHT, aspect / (float(min_cells) * PITCH + 0.5));
	float pitch = h * PITCH;
	int cells = clamp(int(floor((aspect - 0.5 * h) / pitch + 0.01)), 1, 16);
	float x0 = (aspect - float(cells) * pitch) * 0.5;
	float col = floor((q.x - x0) / pitch);
	vec2 p = vec2(q.x - x0 - col * pitch - h * 0.04, q.y - (1.0 - h) * 0.5) / h;
	p.x -= (p.y - 0.5) * SLANT;
	int k = cells - 1 - int(col);
	int mask = (col >= 0.0 && k >= 0) ? masks[k] : 0;
	bool inside = col >= 0.0 && k >= 0;
	float lit = 1e3;
	float every = 1e3;
	if (inside) {
		for (int s = 0; s < 14; s++) {
			float d = segment(p, SEGS[s]) - T;
			every = min(every, d);
			if (((mask >> s) & 1) == 1) {
				lit = min(lit, d);
			}
		}
		float dot_d = length(p - vec2(W + 0.17, 0.03)) - T * 2.3;
		every = min(every, dot_d);
		if (((mask >> 14) & 1) == 1) {
			lit = min(lit, dot_d);
		}
		// The pilcrow (bit 15) has its own shape: a solid bowl at the top left, two stems, a bar.
		if (((mask >> 15) & 1) == 1) {
			float bowl = max(length(p - vec2(M, 0.74)) - 0.26, p.x - M);
			float stems = min(segment(p, vec4(M, 0.0, M, 1.0)), segment(p, vec4(W, 0.0, W, 1.0))) - T;
			lit = min(lit, min(bowl, min(stems, segment(p, vec4(M, 1.0, W, 1.0)) - T)));
		}
		// B (bit 16) too: a full left stem and two round bowls, or it reads as an 8 or a 3.
		if (((mask >> 16) & 1) == 1) {
			float bars = min(segment(p, vec4(0.0, 1.0, W * 0.5, 1.0)), segment(p, vec4(0.0, 0.0, W * 0.52, 0.0)));
			bars = min(bars, min(segment(p, vec4(0.0, 0.5, W * 0.5, 0.5)), segment(p, vec4(0.0, 0.0, 0.0, 1.0))));
			float top = max(abs(length(p - vec2(W * 0.5, 0.75)) - 0.25), W * 0.5 - p.x);
			float low = max(abs(length(p - vec2(W * 0.52, 0.25)) - 0.25), W * 0.52 - p.x);
			lit = min(lit, min(bars, min(top, low)) - T);
		}
	}
	float aa = fwidth(p.y) * 1.2;
	float core = 1.0 - smoothstep(-aa, aa, lit);
	float ghost = 1.0 - smoothstep(-aa, aa, every);
	float halo = exp(-max(lit, 0.0) * 22.0) * 0.32 + exp(-max(lit, 0.0) * 7.0) * 0.1;
	float lines = q.y / h * 40.0;
	float scan = 1.0 - 0.12 * (0.5 + 0.5 * sin(lines * 6.2832)) * (1.0 - smoothstep(0.2, 0.45, fwidth(lines)));
	vec3 col_out = GLASS * (0.7 + 0.5 * UV.y);
	col_out += ink * ghost * 0.016;
	col_out += ink * (core * burn + halo * (1.0 - core)) * scan;
	// The glass: a dim reflection across its top, its edges in the bezel's shadow.
	col_out += vec3(0.75, 0.8, 0.78) * 0.035 * smoothstep(0.45, 0.0, UV.y) * (0.6 + 0.4 * sin(UV.x * 3.0 + 1.0));
	float edge = min(min(q.x, aspect - q.x), min(q.y, 1.0 - q.y));
	col_out *= mix(0.45, 1.0, smoothstep(0.0, 0.12, edge));
	ALBEDO = col_out;
}
