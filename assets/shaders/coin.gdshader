// The loose coins (CoinPile's MultiMesh): the coin texture is an atlas of three faces ($1, $5,
// $10); INSTANCE_CUSTOM.x picks the column, the instance colour tints the metal.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;

varying flat float face;

void vertex() {
	face = INSTANCE_CUSTOM.x;
}

void fragment() {
	vec2 uv = vec2((clamp(UV.x, 0.01, 0.99) + face) / 3.0, UV.y);
	ALBEDO = texture(albedo_tex, uv).rgb * COLOR.rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	AO = orm.r;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
}
