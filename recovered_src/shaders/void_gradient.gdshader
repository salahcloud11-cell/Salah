shader_type canvas_item;
// Very dark "outside world" void backdrop. A faint radial center glow with a
// slowly drifting offset gives a weightless sense of motion without any world
// geometry. Fade it in via u_alpha.

uniform float u_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float u_drift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 1.12;
	p.x += u_drift * 0.03;
	p.y += u_drift * 0.012;
	float d = length(p);
	float glow = smoothstep(0.9, 0.0, d) * 0.05;
	COLOR = vec4(0.014, 0.02, 0.032 + glow, 1.0) * u_alpha;
}
