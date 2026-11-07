shader_type spatial;
// The farm TV's glass: shows a SubViewport (screen_tex) like an old CRT. Barrel-warped (WARP must
// match FarmTv.WARP so clicks land where they are seen), scanlines, a dark vignette, a faint
// flicker and a power-on/off collapse (power 0 dark glass, 1 fully on).
render_mode unshaded, cull_back;

uniform sampler2D screen_tex : source_color, filter_linear, repeat_disable;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float brightness = 1.0;
const float WARP = 0.06;
const vec3 GLASS = vec3(0.025, 0.03, 0.028);

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	vec2 w = c + c * (c.yx * c.yx) * WARP;
	vec2 uv = w * 0.5 + 0.5;
	vec3 col = texture(screen_tex, uv).rgb;
	float inside = step(abs(w.x), 1.0) * step(abs(w.y), 1.0);
	col *= 0.8 + 0.2 * sin(uv.y * 768.0 * 3.14159);              // scanlines
	col *= 1.0 - 0.55 * pow(length(c * vec2(0.9, 1.0)) * 0.72, 3.0); // vignette
	col *= 0.97 + 0.03 * sin(TIME * 47.0) + 0.015 * sin(TIME * 3.1);   // flicker
	// Power: a bright line widens across (0..0.5), then opens up (0.5..1).
	float across = clamp(power * 2.0, 0.0, 1.0);
	float up = clamp(power * 2.0 - 1.0, 0.006, 1.0);
	float lit = step(abs(c.x), across) * step(abs(c.y), up) * step(0.001, power);
	col = mix(col, vec3(0.8, 0.85, 0.83), (1.0 - up) * lit);
	float edge = 1.0 - smoothstep(0.9, 1.0, max(abs(w.x), abs(w.y)));
	ALBEDO = GLASS + col * inside * lit * brightness * mix(0.6, 1.0, edge);
}
