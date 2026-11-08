shader_type canvas_item;
// Ống góc của khung: một phần tư vành tròn hồng phấn nối hai thanh, phần thẳng chui dưới đầu thanh.
// Số đo lấy từ art/concepts/concept_candy_board_v5_stripe.png; màu theo nền (xem RAMP_* bên dưới). Đơn vị là px, trừ `s` và `peak` tính theo nửa bề rộng ống.

uniform vec2 quad_px = vec2(1.0);
uniform vec2 center_px = vec2(0.0);  // tâm cung, tính từ góc trên trái vùng vẽ
uniform vec2 quadrant = vec2(-1.0);  // hướng ra ngoài của góc này
uniform float tube_r = 1.0;          // bán kính tới đường giữa ống
uniform float tube_hw = 1.0;         // nửa bề rộng ống
uniform float peak = 0.0;            // chỗ sáng nhất trên mặt cắt: -1 mép trong, 1 mép ngoài
uniform float gloss = 0.0;           // độ đậm vệt trắng
uniform float gloss_w = 0.2;         // nửa bề rộng vệt trắng
uniform float gloss_at = 0.8;        // tâm vệt trắng theo góc, radian từ phương ngang
uniform float gloss_arc = 0.4;       // độ dài vệt trắng theo góc
uniform float spread = 1.0;          // mặt cắt tối dần chậm hay nhanh quanh chỗ sáng nhất
uniform float cell_px = 64.0;

// Hồng phấn cùng sắc với nền và tấm bàn (ThemeKit.BOARD_BG E9CDD2), đậm hơn nền một chút để ống còn nổi khối.
const vec3 RAMP_0 = vec3(0.976, 0.863, 0.89);   // F9DCE3, tại chỗ sáng nhất
const vec3 RAMP_1 = vec3(0.949, 0.784, 0.824);  // F2C8D2
const vec3 RAMP_2 = vec3(0.91, 0.702, 0.753);   // E8B3C0
const vec3 RAMP_3 = vec3(0.855, 0.624, 0.682);  // DA9FAE
const vec3 RAMP_4 = vec3(0.769, 0.533, 0.604);  // C4889A
const vec3 RIM = vec3(0.71, 0.49, 0.557);       // B57D8E
const float SHADOW_DY = 0.11;
const float SHADOW_BLUR = 0.14;
const float SHADOW_A = 0.32;
const vec3 SHADOW_COL = vec3(0.14, 0.03, 0.16);

float tube(vec2 q) {
	return tube_hw - abs(length(max(q, vec2(0.0))) - tube_r);
}

void fragment() {
	vec2 pos = UV * quad_px - center_px;
	vec2 q = pos * quadrant;
	float d = tube(q);
	float a = clamp(d + 0.5, 0.0, 1.0);

	float ds = tube((pos - vec2(0.0, SHADOW_DY * cell_px)) * quadrant);
	float shadow = smoothstep(-SHADOW_BLUR * cell_px, 0.02 * cell_px, ds) * SHADOW_A;
	vec3 col = SHADOW_COL;

	if (a > 0.0) {
		float s = (length(max(q, vec2(0.0))) - tube_r) / tube_hw;
		float dq = abs(s - peak) / spread;
		vec3 body = mix(RAMP_0, RAMP_1, smoothstep(0.0, 0.3, dq));
		body = mix(body, RAMP_2, smoothstep(0.3, 0.6, dq));
		body = mix(body, RAMP_3, smoothstep(0.6, 0.9, dq));
		body = mix(body, RAMP_4, smoothstep(0.9, 1.3, dq));
		// vệt trắng chạy theo cung
		float angle = (atan(max(q.y, 0.0), max(q.x, 0.0)) - gloss_at) / gloss_arc;
		float g = (s - peak) / gloss_w;
		body = mix(body, vec3(1.0), gloss * exp(-angle * angle - g * g));
		body = mix(body, RIM, smoothstep(0.7, 1.05, abs(s)));
		col = body;
	}

	float alpha = a + shadow * (1.0 - a);
	COLOR = vec4((col * a + SHADOW_COL * shadow * (1.0 - a)) / max(alpha, 0.0001), alpha);
}
