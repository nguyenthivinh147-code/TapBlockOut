shader_type canvas_item;
// Thanh viền khung: capsule tô theo mặt cắt đo từ art/concepts/concept_candy_board_v5_stripe.png,
// có mũi tên trắng bo góc. Cổng nhịp đóng thì thanh tối đi, mũi tên mờ và hiện thanh chắn. Đơn vị là px.

uniform sampler2D ramp : filter_linear, repeat_disable;  // mặt cắt ngang thanh, tính từ mép trên hoặc mép trái
uniform vec4 end_col : source_color = vec4(1.0);  // vành hai đầu thanh
uniform vec2 quad_px = vec2(1.0);  // cỡ vùng vẽ, thanh nằm giữa
uniform vec2 bar_px = vec2(1.0);
uniform bool vertical = false;
uniform vec2 arrow_dir = vec2(0.0, -1.0);
uniform vec2 arrow_at = vec2(0.0);    // tâm mũi tên, tính từ tâm thanh
uniform vec2 arrow_size = vec2(1.0);  // x: ngang thân, y: dọc theo hướng mũi tên
uniform float cell_px = 64.0;
uniform float open = 1.0;   // 0: đóng, 1: mở
uniform float flash = 0.0;

const float END_RIM = 0.3;          // vành ở hai đầu, theo bán kính đầu thanh
const float CAP_GLOSS_AT = 0.32;    // vòng sáng ở đầu trên thanh dọc, theo bán kính
const float CAP_GLOSS_W = 0.17;
const float CAP_GLOSS_A = 0.82;
const float CAP_BAND_FROM = 0.58;   // đầu dưới thanh dọc đậm dần từ đây tới mép, theo bán kính
const float CAP_BAND_TO = 0.3;
const float ARROW_ROUND = 0.055;    // bo góc mũi tên, theo ô
const float CLOSED_DIM = 0.55;
const float SHADOW_DY = 0.11;       // bóng đổ, theo ô
const float SHADOW_BLUR = 0.14;
const float SHADOW_A = 0.32;
const vec3 SHADOW_COL = vec3(0.14, 0.03, 0.16);
const vec3 ARROW_COL = vec3(0.992, 0.984, 0.98);
const vec3 ARROW_EDGE = vec3(0.945, 0.76, 0.83);

// Khoảng cách tới mép capsule, dương là bên trong.
float capsule(vec2 p) {
	float r = min(bar_px.x, bar_px.y) * 0.5;
	vec2 q = abs(p) - (bar_px * 0.5 - vec2(r));
	return r - length(max(q, vec2(0.0))) - min(max(q.x, q.y), 0.0);
}

// Tam giác cân, đỉnh ở gốc, đáy ở y = q.y, nửa rộng q.x. Âm là bên trong.
float triangle(vec2 p, vec2 q) {
	p.x = abs(p.x);
	vec2 a = p - q * clamp(dot(p, q) / dot(q, q), 0.0, 1.0);
	vec2 b = p - q * vec2(clamp(p.x / q.x, 0.0, 1.0), 1.0);
	vec2 d = min(vec2(dot(a, a), -(p.x * q.y - p.y * q.x)), vec2(dot(b, b), -(p.y - q.y)));
	return -sqrt(d.x) * sign(d.y);
}

// Khoảng cách tới mép mũi tên, âm là bên trong; ô chứa mũi tên giữ đúng arrow_size sau khi bo góc.
float arrow(vec2 p) {
	vec2 rel = p - arrow_at;
	vec2 lp = vec2(dot(rel, vec2(-arrow_dir.y, arrow_dir.x)), -dot(rel, arrow_dir));
	float rr = ARROW_ROUND * cell_px;
	vec2 q = vec2(arrow_size.x * 0.5 - rr, arrow_size.y - 2.0 * rr);
	return triangle(lp + vec2(0.0, q.y * 0.5), q) - rr;
}

void fragment() {
	vec2 p = UV * quad_px - quad_px * 0.5;
	float d = capsule(p);
	float a = clamp(d + 0.5, 0.0, 1.0);
	float closed = 1.0 - open;

	float ds = capsule(p - vec2(0.0, SHADOW_DY * cell_px));
	float shadow = smoothstep(-SHADOW_BLUR * cell_px, 0.02 * cell_px, ds) * SHADOW_A;
	vec3 col = SHADOW_COL;

	if (a > 0.0) {
		float r = min(bar_px.x, bar_px.y) * 0.5;
		float across = vertical ? p.x : p.y;
		float along = vertical ? p.y : p.x;
		float half_len = (vertical ? bar_px.y : bar_px.x) * 0.5;
		float thick = r * 2.0;
		vec3 body = texture(ramp, vec2((across + r) / thick, 0.5)).rgb;

		// hai đầu thanh: vành đậm ôm theo đầu tròn
		float in_cap = smoothstep(0.0, r * 0.6, abs(along) - (half_len - r));
		body = mix(body, mix(end_col.rgb, body, smoothstep(0.0, r * END_RIM, d)), in_cap);
		if (vertical) {
			// đầu trên có vòng sáng, đầu dưới đậm dần
			float top = smoothstep(0.0, r * 0.45, -along - (half_len - r));
			float g = (d - r * CAP_GLOSS_AT) / (r * CAP_GLOSS_W);
			body = mix(body, vec3(1.0), CAP_GLOSS_A * top * exp(-g * g));
			body = mix(body, end_col.rgb, 1.0 - smoothstep(r * CAP_BAND_TO, r * CAP_BAND_FROM, half_len - along));
		}

		body = mix(body, body * (1.0 - CLOSED_DIM), closed);

		// thanh chắn khi đóng: các vạch ngang thanh
		if (closed > 0.01) {
			float period = thick * 0.95;
			float tick = abs(mod(along + period * 0.5, period) - period * 0.5);
			float mark = (1.0 - smoothstep(thick * 0.07, thick * 0.07 + 1.0, tick));
			mark *= 1.0 - smoothstep(r * 0.72 * closed, r * 0.72 * closed + 1.0, abs(across));
			body = mix(body, vec3(1.0), mark * 0.6 * closed);
		}

		// mũi tên: viền mờ màu đậm của thanh, lệch nhẹ xuống; thân trắng, mép dưới ám hồng
		float ad = arrow(p);
		float as = 1.0 - smoothstep(0.0, 0.075 * cell_px, arrow(p - vec2(0.0, 0.03 * cell_px)));
		body = mix(body, end_col.rgb * 0.92, as * 0.85 * open);
		float edge = smoothstep(-0.035 * cell_px, 0.0, arrow(p + vec2(0.0, 0.035 * cell_px)));
		vec3 ac = mix(ARROW_COL, ARROW_EDGE, edge * 0.45);
		body = mix(body, ac, clamp(0.5 - ad, 0.0, 1.0) * mix(0.25, 1.0, open));

		col = mix(body, vec3(1.0), flash * 0.55);
	}

	float alpha = a + shadow * (1.0 - a);
	COLOR = vec4((col * a + SHADOW_COL * shadow * (1.0 - a)) / max(alpha, 0.0001), alpha);
}
