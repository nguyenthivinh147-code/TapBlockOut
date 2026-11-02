shader_type canvas_item;
// Khối kẹo: tô theo khoảng cách tới mép (texture R = signed distance, đơn vị ô, dương là bên trong).
// Số đo lấy từ art/concepts/concept_candy_board_v5_stripe.png: mép gối sáng từ trên xuống
// (mỏng ở trên, vừa ở hai bên, dày ở đáy), sọc 45 độ chu kỳ đúng 1 ô, vạch sáng ở đáy, bóng đổ xuống dưới.

uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec4 deep : source_color = vec4(1.0);    // đáy gối
uniform vec4 side : source_color = vec4(1.0);    // hai bên
uniform vec4 face : source_color = vec4(1.0);    // mặt, phần sọc đậm
uniform vec4 stripe : source_color = vec4(1.0);  // mặt, phần sọc nhạt
uniform vec4 overlay = vec4(0.0);                // lớp phủ trong hình khối (băng)
uniform float flash = 0.0;                       // nháy sáng trong hình khối (gợi ý, nảy)
uniform float body_a = 1.0;                      // 0: chỉ vẽ bóng đổ
uniform float shadow_a = 0.0;                    // độ đậm bóng đổ
uniform vec2 dims = vec2(1.0);  // cỡ vùng texture, đơn vị ô
uniform float pad = 0.0;        // lề của texture, đơn vị ô
uniform float cell_px = 64.0;

const float BEVEL = 0.2;          // bề dày mép hai bên
const float BEVEL_SHIFT = 0.08;   // lệch dọc: mép đáy dày thêm chừng này
const float TOP_THIN = 0.1;       // mép trên mỏng đi thêm chừng này
const float SOFT = 0.11;          // chuyển từ mép sang mặt
const float REACH_TOP = 0.6;      // tầm sáng từ mép trên xuống
const float REACH_BOTTOM = 0.35;  // tầm đổi màu về đáy
const float TOP_GLOW = 0.26;
const float STRIPE_IN_BEVEL = 0.15;
const float RIGHT_DARK = 0.22;    // mép phải tối hơn mép trái, ánh sáng từ trên trái
const float RIM_AT = 0.05;        // vạch sáng đáy, cách mép
const float RIM_W = 0.022;
const float CORNER_E = 0.06;
const float SHADOW_DY = 0.09;
const float SHADOW_BLUR = 0.13;
const vec3 SHADOW_COL = vec3(0.09, 0.08, 0.26);

float dist(vec2 c) {
	return texture(sdf, c / dims).r;
}

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0) * body_a;

	// bóng đổ mềm lệch xuống dưới, ám chàm
	float ds = dist(c - vec2(0.0, SHADOW_DY));
	float shadow = smoothstep(-SHADOW_BLUR, 0.02, ds) * shadow_a;
	vec3 col = SHADOW_COL;

	if (a > 0.0) {
		// sọc: 45 độ, chu kỳ 1 ô theo toạ độ ô nên khối cạnh nhau liền pha
		vec2 p = c - vec2(pad);
		float u = abs(fract(p.x + p.y + 0.25) - 0.5);
		float aa = 1.0 / cell_px;
		float band = 1.0 - smoothstep(0.25 - aa, 0.25 + aa, u);

		// gần mép trên, gần mép đáy (đo bằng SDF lệch dọc nên không có nếp gấp ở góc)
		float near_top = clamp(-dist(c - vec2(0.0, REACH_TOP)) / REACH_TOP, 0.0, 1.0);
		float near_bottom = clamp(-dist(c + vec2(0.0, REACH_BOTTOM)) / REACH_BOTTOM, 0.0, 1.0);

		vec3 top_col = mix(face.rgb, stripe.rgb, band);
		top_col = mix(top_col, vec3(1.0), TOP_GLOW * near_top);

		// mép gối: một mẫu SDF lệch lên cho cả ba bề dày, nên viền góc liền một nét
		vec3 bevel = mix(side.rgb, deep.rgb, smoothstep(0.1, 0.55, near_bottom));
		bevel = mix(bevel, stripe.rgb, band * STRIPE_IN_BEVEL);
		float e_x = (d - dist(c + vec2(CORNER_E, 0.0))) / CORNER_E;
		float e_y = (d - dist(c + vec2(0.0, CORNER_E))) / CORNER_E;
		bevel = mix(bevel, deep.rgb, RIGHT_DARK * smoothstep(0.4, 0.8, e_x));
		float inner = dist(c + vec2(0.0, BEVEL_SHIFT)) - BEVEL + TOP_THIN * smoothstep(0.5, 0.9, near_top);
		vec3 body = mix(bevel, top_col, smoothstep(-SOFT, 0.0, inner));

		// vạch sáng sát đáy, đậm hơn ở góc dưới phải
		float rim = 1.0 - smoothstep(RIM_W * 0.5, RIM_W * 1.5, abs(d - RIM_AT));
		body = mix(body, side.rgb, rim * smoothstep(0.45, 0.8, e_y) * 0.75);
		body = mix(body, top_col, rim * smoothstep(0.3, 0.6, min(e_x, e_y)) * 0.8);

		body = mix(body, overlay.rgb, overlay.a);
		body = mix(body, vec3(1.0), flash * 0.28);
		col = body;
	}

	float alpha = a + shadow * (1.0 - a);
	COLOR = vec4((col * a + SHADOW_COL * shadow * (1.0 - a)) / max(alpha, 0.0001), alpha);
}
