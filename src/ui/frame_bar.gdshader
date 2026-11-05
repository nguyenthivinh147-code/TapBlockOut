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
uniform float hit_at = 0.0;  // điểm bị va, tính từ tâm thanh dọc theo thanh
uniform float hit_t = 1.0;   // 0: vừa va, 1: sóng đã tan
uniform float pop = 0.0;     // mũi tên phồng lên khi bị va
uniform float seg = 0.0;       // đoạn bị va: 0 nằm trong thanh, 1 nổi hẳn lên thành lăng trụ
uniform float seg_at = 0.0;    // tâm đoạn, tính từ tâm thanh dọc theo thanh
uniform float seg_half = 0.0;  // nửa chiều dài đoạn
uniform float spin = 0.0;      // góc quay của đoạn quanh trục thanh, radian; mỗi mặt lục giác 60°
// Level nhiều cổng (Road Trip): thanh chia seg_count cổng (1..3) tại cut_a, cut_b (along, px từ tâm thanh); cổng 2, 3
// tô theo ramp_b, ramp_c và end_col_b, end_col_c; mỗi cổng một mũi tên ở arrows_along (along). seg_count 1: như cũ.
uniform int seg_count = 1;
uniform float cut_a = 0.0;
uniform float cut_b = 0.0;
uniform sampler2D ramp_b : filter_linear, repeat_disable;
uniform sampler2D ramp_c : filter_linear, repeat_disable;
uniform vec4 end_col_b : source_color = vec4(1.0);
uniform vec4 end_col_c : source_color = vec4(1.0);
uniform vec3 arrows_along = vec3(0.0);

const float END_RIM = 0.3;          // vành ở hai đầu, theo bán kính đầu thanh
const float CAP_GLOSS_AT = 0.32;    // vòng sáng ở đầu trên thanh dọc, theo bán kính
const float CAP_GLOSS_W = 0.17;
const float CAP_GLOSS_A = 0.82;
const float CAP_BAND_FROM = 0.58;   // đầu dưới thanh dọc đậm dần từ đây tới mép, theo bán kính
const float CAP_BAND_TO = 0.3;
const float ARROW_ROUND = 0.055;    // bo góc mũi tên, theo ô
const float HIT_REACH = 7.0;        // sóng sáng chạy được chừng này ô mỗi phía
const float HIT_W = 0.55;           // bề rộng sóng, theo ô
const float HIT_A = 0.9;
const float SEG_GROW = 1.12;        // bề ngang đỉnh-tới-đỉnh của lăng trụ so với bề dày thanh
const float SEG_SHADE = 0.72;       // mặt nghiêng hẳn tối còn chừng này
const float SEG_EDGE_A = 0.4;       // vệt sáng ở cạnh giữa hai mặt
const float SEG_SEAM = 0.08;        // khe tối ở hai đầu đoạn, theo ô
const float PIN_LEN = 0.09;         // chốt trục ló ra hai đầu đoạn, theo ô
const float PIN_W = 0.32;           // nửa bề rộng chốt, theo bán kính thanh
const float CLOSED_DIM = 0.55;
const float SHADOW_DY = 0.11;       // bóng đổ, theo ô
const float SHADOW_BLUR = 0.14;
const float SHADOW_A = 0.32;
const vec3 SHADOW_COL = vec3(0.14, 0.03, 0.16);
const vec3 ARROW_COL = vec3(0.992, 0.984, 0.98);
const vec3 ARROW_EDGE = vec3(0.945, 0.76, 0.83);
const float GATE_SEAM = 0.07;       // khe giữa hai cổng, theo ô
const float GATE_SEAM_A = 0.85;

// Cổng chứa điểm `along` (0, 1, 2).
int gate_at(float along) {
	if (seg_count < 2 || along < cut_a) {
		return 0;
	}
	return (seg_count < 3 || along < cut_b) ? 1 : 2;
}

vec3 ramp_of(int g, float u) {
	if (g == 1) {
		return texture(ramp_b, vec2(u, 0.5)).rgb;
	}
	if (g == 2) {
		return texture(ramp_c, vec2(u, 0.5)).rgb;
	}
	return texture(ramp, vec2(u, 0.5)).rgb;
}

vec3 end_of(int g) {
	return g == 1 ? end_col_b.rgb : (g == 2 ? end_col_c.rgb : end_col.rgb);
}

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

// Khoảng cách tới mép một mũi tên có tâm `at`, âm là bên trong; ô chứa mũi tên giữ đúng arrow_size sau khi bo góc.
float arrow_one(vec2 p, vec2 at) {
	vec2 rel = (p - at) / (1.0 + pop);
	vec2 lp = vec2(dot(rel, vec2(-arrow_dir.y, arrow_dir.x)), -dot(rel, arrow_dir));
	float rr = ARROW_ROUND * cell_px;
	vec2 q = vec2(arrow_size.x * 0.5 - rr, arrow_size.y - 2.0 * rr);
	return triangle(lp + vec2(0.0, q.y * 0.5), q) - rr;
}

// Mũi tên gần nhất. Nhiều cổng: mỗi cổng một mũi tên, dời dọc thanh tới arrows_along.
float arrow(vec2 p) {
	if (seg_count < 2) {
		return arrow_one(p, arrow_at);
	}
	float d = 1e6;
	for (int i = 0; i < 3; i++) {
		if (i >= seg_count) {
			break;
		}
		vec2 at = vertical ? vec2(arrow_at.x, arrows_along[i]) : vec2(arrows_along[i], arrow_at.y);
		d = min(d, arrow_one(p, at));
	}
	return d;
}

// Đoạn bị va: lăng trụ lục giác quay quanh trục thanh, nhìn thẳng từ trên xuống; spin = 0 thì một mặt hướng lên
// người nhìn. Mỗi mặt tô một màu của mặt cắt tại hướng pháp tuyến của nó nên vẫn khớp ánh sáng với thân thanh.
// Trả về màu và độ phủ.
vec4 segment(float along, float across, float r, float half_len) {
	float lo = max(seg_at - seg_half, -half_len + r);
	float hi = min(seg_at + seg_half, half_len - r);
	float to_end = min(along - lo, hi - along);
	if (hi <= lo || to_end < -0.5) {
		return vec4(0.0);
	}
	float k = r * mix(1.0, SEG_GROW, seg);  // tâm tới đỉnh
	// đỉnh nằm ở spin + i * 60°; đỉnh gần phương ngang thanh nhất quyết định bề ngang bóng
	float off = mod(spin + PI / 6.0, PI / 3.0) - PI / 6.0;
	float w = k * cos(off);  // nửa bề ngang bóng lăng trụ
	float cover = clamp(to_end + 0.5, 0.0, 1.0) * clamp(w - abs(across) + 0.5, 0.0, 1.0);
	if (cover <= 0.0) {
		return vec4(0.0);
	}
	float x = clamp(across, -w, w);
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float phi = spin + PI * 0.5 + PI / 3.0 * float(i);  // pháp tuyến: cos là phương ngang thanh, sin hướng về người nhìn
		float facing = sin(phi);
		if (facing <= 0.0) {
			continue;
		}
		float x0 = k * cos(phi - PI / 6.0);
		float x1 = k * cos(phi + PI / 6.0);
		if (x < min(x0, x1) - 0.01 || x > max(x0, x1) + 0.01) {
			continue;
		}
		float u = mix((cos(phi) + 1.0) * 0.5, clamp((across + r) / (2.0 * r), 0.0, 1.0), 0.3);
		col = ramp_of(gate_at(seg_at), u) * mix(SEG_SHADE, 1.0, facing);
		// cạnh giữa hai mặt cùng thấy được thì sáng lên, mép bóng thì không
		float inner = min(abs(x0) < w - 0.5 ? abs(x - x0) : 1e4, abs(x1) < w - 0.5 ? abs(x - x1) : 1e4);
		col = mix(col, vec3(1.0), SEG_EDGE_A * (1.0 - smoothstep(0.5, 2.0, inner)));
		break;
	}
	col *= mix(0.78, 1.0, smoothstep(0.0, SEG_SEAM * cell_px, to_end));
	return vec4(col, cover);
}

void fragment() {
	vec2 p = UV * quad_px - quad_px * 0.5;
	float d = capsule(p);
	float a = clamp(d + 0.5, 0.0, 1.0);
	float closed = 1.0 - open;

	float ds = capsule(p - vec2(0.0, SHADOW_DY * cell_px));
	float shadow = smoothstep(-SHADOW_BLUR * cell_px, 0.02 * cell_px, ds) * SHADOW_A;
	vec3 col = SHADOW_COL;

	float r = min(bar_px.x, bar_px.y) * 0.5;
	float across = vertical ? p.x : p.y;
	float along = vertical ? p.y : p.x;
	float half_len = (vertical ? bar_px.y : bar_px.x) * 0.5;
	vec4 sg = seg > 0.001 ? segment(along, across, r, half_len) : vec4(0.0);
	float sa = sg.a * smoothstep(0.0, 0.3, seg);

	if (a > 0.0) {
		float thick = r * 2.0;
		int gi = gate_at(along);
		vec3 gate_end = end_of(gi);
		vec3 body = ramp_of(gi, (across + r) / thick);

		// hai đầu thanh: vành đậm ôm theo đầu tròn
		float in_cap = smoothstep(0.0, r * 0.6, abs(along) - (half_len - r));
		body = mix(body, mix(gate_end, body, smoothstep(0.0, r * END_RIM, d)), in_cap);
		if (vertical) {
			// đầu trên có vòng sáng, đầu dưới đậm dần
			float top = smoothstep(0.0, r * 0.45, -along - (half_len - r));
			float g = (d - r * CAP_GLOSS_AT) / (r * CAP_GLOSS_W);
			body = mix(body, vec3(1.0), CAP_GLOSS_A * top * exp(-g * g));
			body = mix(body, gate_end, 1.0 - smoothstep(r * CAP_BAND_TO, r * CAP_BAND_FROM, half_len - along));
		}

		// khe giữa hai cổng: vạch đậm ngang thanh, màu đậm của cổng bên này
		if (seg_count > 1) {
			float to_cut = abs(along - cut_a);
			if (seg_count > 2) {
				to_cut = min(to_cut, abs(along - cut_b));
			}
			float hw = GATE_SEAM * cell_px * 0.5;
			body = mix(body, gate_end * 0.7, GATE_SEAM_A * (1.0 - smoothstep(hw, hw + 1.0, to_cut)));
		}

		body = mix(body, body * (1.0 - CLOSED_DIM), closed);

		// sóng sáng chạy dọc thanh từ điểm bị va
		if (hit_t < 1.0) {
			float eased = 1.0 - (1.0 - hit_t) * (1.0 - hit_t);
			float h = (abs(along - hit_at) - eased * HIT_REACH * cell_px) / (HIT_W * cell_px);
			body = mix(body, vec3(1.0), HIT_A * (1.0 - hit_t) * exp(-h * h));
		}

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
		body = mix(body, gate_end * 0.92, as * 0.85 * open);
		float edge = smoothstep(-0.035 * cell_px, 0.0, arrow(p + vec2(0.0, 0.035 * cell_px)));
		vec3 ac = mix(ARROW_COL, ARROW_EDGE, edge * 0.45);
		body = mix(body, ac, clamp(0.5 - ad, 0.0, 1.0) * mix(0.25, 1.0, open));

		// chốt trục ló ra hai đầu đoạn đang quay
		if (seg > 0.001) {
			float lo = max(seg_at - seg_half, -half_len + r);
			float hi = min(seg_at + seg_half, half_len - r);
			float out_end = max(lo - along, along - hi);
			float pin = clamp(PIN_LEN * cell_px - out_end + 0.5, 0.0, 1.0) * step(0.0, out_end);
			pin *= clamp(r * PIN_W - abs(across) + 0.5, 0.0, 1.0) * smoothstep(0.0, 0.3, seg);
			body = mix(body, end_of(gate_at(seg_at)) * 0.8, pin);
		}

		col = mix(body, vec3(1.0), flash * 0.55);
	}

	// đoạn bị va đè lên thân thanh, phần lăng trụ to hơn thanh vẽ ra ngoài
	if (sa > 0.0) {
		vec3 sc = mix(sg.rgb, sg.rgb * (1.0 - CLOSED_DIM), closed);
		sc = mix(sc, vec3(1.0), flash * 0.55);
		col = a > 0.0 ? mix(col, sc, sa) : sc;
		a = max(a, sa);
	}

	float alpha = a + shadow * (1.0 - a);
	COLOR = vec4((col * a + SHADOW_COL * shadow * (1.0 - a)) / max(alpha, 0.0001), alpha);
}
