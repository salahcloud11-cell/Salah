shader_type canvas_item;

uniform float pixelation : hint_range(0.001, 0.1) = 0.002;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 viewport_size = vec2(1.0 / SCREEN_PIXEL_SIZE.x, 1.0 / SCREEN_PIXEL_SIZE.y);
	float aspect = viewport_size.x / viewport_size.y;
	vec2 pixel_size = vec2(pixelation / aspect, pixelation);

	vec2 coord = SCREEN_UV;
	coord = (floor(coord / pixel_size) + 0.5) * pixel_size;
	float edge_tolerance = 0.001;
	coord = clamp(coord, pixel_size * 0.5 + edge_tolerance, 1.0 - pixel_size * 0.5 - edge_tolerance);

	vec4 color = textureLod(SCREEN_TEXTURE, coord, 0.0);

	vec2 uv_delta = fwidth(SCREEN_UV);
	vec2 edge_dist = smoothstep(vec2(0.0), uv_delta * 2.0, SCREEN_UV) *
					 smoothstep(vec2(0.0), uv_delta * 2.0, vec2(1.0) - SCREEN_UV);
	float edge_factor = edge_dist.x * edge_dist.y;

	vec2 v = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(v, v) * (2.4 * vignette_strength);
	color.rgb *= vignette;

	color.a = opacity * edge_factor;
	COLOR = color;
}
