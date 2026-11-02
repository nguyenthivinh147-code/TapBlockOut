shader_type canvas_item;
render_mode blend_add;
// Loé sáng tại điểm va chạm: quầng tròn, sao bốn cánh và vòng sóng toả ra. `t` chạy từ 0 tới 1.

uniform vec4 tint : source_color = vec4(1.0);
uniform float t = 0.0;
uniform float ring_a = 0.7;

float rays(vec2 p, float len) {
	return exp(-abs(p.x) * 46.0) * exp(-abs(p.y) * len) + exp(-abs(p.y) * 46.0) * exp(-abs(p.x) * len);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fade = 1.0 - t;
	float grow = 1.0 - fade * fade * fade;

	float glow = exp(-r * r * mix(16.0, 4.5, grow)) * fade * fade;
	float reach = mix(9.0, 3.4, grow);
	float q = 0.7071;
	float star = rays(p, reach) + 0.45 * rays(vec2(p.x + p.y, p.y - p.x) * q, reach * 1.5);
	star *= fade * fade * fade;
	float w = (r - grow * 0.88) / (0.025 + 0.06 * t);
	float ring = exp(-w * w) * fade * fade * ring_a;

	float i = glow + star + ring;
	vec3 col = mix(tint.rgb, vec3(1.0), clamp(glow * 1.3 + star * 1.2, 0.0, 1.0));
	COLOR = vec4(col, clamp(i, 0.0, 1.0));
}
