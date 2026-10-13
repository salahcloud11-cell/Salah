shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;
uniform float dither_strength : hint_range(0.0, 0.2) = 0.06;
uniform float color_levels : hint_range(2.0, 64.0) = 10.0;
uniform float pixel_scale : hint_range(1.0, 8.0) = 2.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.05;
uniform float contrast : hint_range(0.0, 2.0) = 1.05;
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec2 screen_size = vec2(textureSize(screen_tex, 0));
	vec2 texel = 1.0 / screen_size;

	vec3 original = texture(screen_tex, SCREEN_UV).rgb;

	float px = max(pixel_scale, 1.0);
	vec2 block = texel * px;
	vec2 block_uv = (floor(SCREEN_UV / block) + 0.5) * block;
	block_uv = clamp(block_uv, block * 0.5, 1.0 - block * 0.5);

	vec3 col = texture(screen_tex, block_uv).rgb;

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = (col - 0.5) * contrast + 0.5 + brightness;

	vec2 fp = mod(FRAGCOORD.xy, 4.0);
	int idx = int(fp.y) * 4 + int(fp.x);
	float bayer = (BAYER[idx] / 15.0) * 2.0 - 1.0;
	col += bayer * dither_strength;

	float levels = max(color_levels, 2.0);
	col = floor(col * (levels - 1.0) + 0.5) / (levels - 1.0);

	col = mix(original, col, effect_strength);

	vec2 v = SCREEN_UV - 0.5;
	col *= clamp(1.0 - dot(v, v) * (2.4 * vignette_strength), 0.0, 1.0);

	COLOR = vec4(col, opacity);
}
