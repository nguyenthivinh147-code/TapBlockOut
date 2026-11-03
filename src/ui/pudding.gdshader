shader_type canvas_item;
// Khối kẹo cứng: tô theo khoảng cách tới mép (texture R = signed distance, đơn vị ô, dương là bên trong).
// Cấu trúc theo ảnh tham chiếu kẹo cứng: viền đậm màu mỏng, bevel bóng (sáng ở trên trái, tối ở dưới phải),
// vạch phản chiếu sáng nằm lùi vào trong mép, các vệt chéo sáng song song chạy khắp mặt kẹo.
// (Tên file giữ là pudding để không đổi đường dẫn; chất liệu hiện là kẹo cứng.)

uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec2 dims = vec2(1.0);  // cỡ vùng texture, đơn vị ô
uniform float cell_px = 64.0;

const float OUTLINE = 0.05;    // bề dày viền đậm màu sát mép
const float BEVEL = 0.20;      // bề rộng vùng bevel tính từ mép vào
const float SHADOW_DY = 0.04;
const float STRIPE_FREQ = 1.55;   // số vệt trên mỗi ô, đo theo đường chéo (x + y)
const vec2 LIGHT_DIR = vec2(-0.70710678, -0.70710678);  // hướng tới nguồn sáng: trên trái

float dist(vec2 c) {
	return texture(sdf, c / dims).r;
}

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0);

	// bóng đổ mềm lệch xuống dưới
	float ds = dist(c - vec2(0.0, SHADOW_DY));
	float shadow = smoothstep(-0.035, 0.03, ds) * 0.32;

	// pháp tuyến 2D hướng ra ngoài, suy từ gradient của SDF (SDF dương ở trong nên đảo dấu)
	const float EPS = 0.02;
	vec2 g = vec2(dist(c + vec2(EPS, 0.0)) - dist(c - vec2(EPS, 0.0)),
			dist(c + vec2(0.0, EPS)) - dist(c - vec2(0.0, EPS)));
	vec2 n = -g / max(length(g), 0.0001);
	float lit = dot(n, LIGHT_DIR);  // 1 = mép quay về nguồn sáng, -1 = quay ngược

	// kẹo trong hơn một chút: tâm khối sáng và ngả vàng-trắng, mép đậm hơn
	vec3 col = mix(base_color.rgb, vec3(1.0), 0.07);  // kẹo sáng hơn màu gốc một chút
	vec3 deep = col * vec3(0.86, 0.82, 0.92);
	vec3 glow = mix(col, vec3(1.0), 0.10);
	float core = smoothstep(0.02, 0.14, d);
	vec3 body = mix(deep, glow, core);

	// vệt chéo song song (kẹo sọc): chạy theo hướng "/" , mờ dần khi tới mép
	float s = fract((c.x + c.y) * STRIPE_FREQ + 0.18);
	float stripe = smoothstep(0.0, 0.10, s) * (1.0 - smoothstep(0.34, 0.46, s));
	float stripe_dark = smoothstep(0.52, 0.62, s) * (1.0 - smoothstep(0.80, 0.92, s));
	float inner = smoothstep(0.05, 0.20, d);
	body = mix(body, mix(col, vec3(1.0), 0.55), stripe * 0.62 * inner);
	body = mix(body, deep, stripe_dark * 0.10 * inner);

	// bevel: vùng sát mép sáng lên phía nguồn sáng, tối đi phía ngược lại
	float bevel = 1.0 - smoothstep(OUTLINE, BEVEL, d);
	body = mix(body, mix(col, vec3(1.0), 0.62), bevel * max(lit, 0.0) * 0.85);
	body = mix(body, col * vec3(0.66, 0.60, 0.74), bevel * max(-lit, 0.0) * 0.45);

	// vạch phản chiếu sáng, lùi vào khỏi mép, chỉ ở phía quay về nguồn sáng
	float ridge_c = OUTLINE + 0.055;
	float ridge = smoothstep(ridge_c - 0.028, ridge_c, d) * (1.0 - smoothstep(ridge_c, ridge_c + 0.032, d));
	body = mix(body, vec3(1.0), ridge * clamp(lit * 1.3 - 0.1, 0.0, 1.0) * 0.80);
	// phản xạ nhẹ ở đáy phải (ánh sáng xuyên qua kẹo)
	body = mix(body, mix(col, vec3(1.0), 0.45), ridge * clamp(-lit - 0.3, 0.0, 1.0) * 0.30);

	// viền đậm màu sát mép, giữ nét khối khi nằm cạnh khối khác
	vec3 edge_col = col * vec3(0.68, 0.58, 0.74);
	body = mix(edge_col, body, smoothstep(OUTLINE * 0.55, OUTLINE * 1.35, d));

	float alpha = a + shadow * (1.0 - a);
	vec3 rgb = (body * a + vec3(0.05, 0.04, 0.10) * shadow * (1.0 - a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
