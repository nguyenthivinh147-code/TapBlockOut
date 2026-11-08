shader_type canvas_item;
// Thanh viền khung: capsule tô theo mặt cắt đo từ art/concepts/concept_candy_board_v5_stripe.png,
// có mũi tên trắng bo góc. Cổng nhịp đóng thì thân ngả về màu đậm của cổng, phủ sọc kẹo gậy trắng chéo và mũi tên
// đổi thành ổ khoá trắng. Đơn vị là px.

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
// cổng nhịp đóng
const float CLOSED_DEEP = 0.5;      // thân ngả chừng này về màu đậm của cổng
const float CLOSED_DEEP_VAL = 0.86; // màu đậm đó tối thêm chừng này
const float STRIPE_PERIOD = 0.9;    // chu kỳ sọc theo bề dày thanh; sọc chéo 45° theo hướng "/"
const float STRIPE_DUTY = 0.42;     // phần sọc trắng trong một chu kỳ
const float STRIPE_MIX = 0.8;       // sọc trắng pha chừng này với thân (giữ chút khối của thân)
const float STRIPE_RIM = 0.24;      // sọc nhạt dần sát mép thanh, theo bán kính: chừa viền màu cổng
const float STRIPE_SHADE = 0.16;    // mép dưới của sọc tối đi chừng này cho sọc nổi lên
const vec3 STRIPE_COL = vec3(1.0, 0.988, 0.965);
// ổ khoá, theo ô; gốc ở tâm cả ổ, y hướng xuống
const float LOCK_W = 0.3;           // thân
const float LOCK_H = 0.21;
const float LOCK_ROUND = 0.055;
const float LOCK_BODY_Y = 0.0625;   // tâm thân
const float LOCK_ARC_Y = -0.0675;   // tâm cung quai
const float LOCK_ARC_R = 0.075;     // bán kính tới đường giữa quai
const float LOCK_ARC_W = 0.052;     // bề dày quai
const float LOCK_HOLE_R = 0.034;    // lỗ khoá
const float LOCK_HOLE_Y = 0.048;
const float LOCK_SLOT = 0.055;      // khe dưới lỗ khoá
const float LOCK_SLOT_W = 0.026;
const float BADGE_R = 0.33;         // huy hiệu tròn màu đậm của cổng dưới ổ khoá, theo ô; to hơn bề dày thanh chút
const float BADGE_RIM = 0.045;      // viền sáng của huy hiệu
const float BADGE_LOCK_Y = 0.008;   // ổ khoá lệch xuống trong huy hiệu cho cân mắt
const float BADGE_TOP = 1.15;       // huy hiệu: màu đậm của cổng sáng lên ở trên, tối đi ở dưới
const float BADGE_BOTTOM = 0.72;
const float BADGE_SHADOW_ON_BAR = 0.72;  // bóng huy hiệu đổ lên thân thanh tối còn chừng này
const vec2 SHADOW_OFF = vec2(0.0, 0.03);  // bóng mũi tên, ổ khoá lệch xuống, theo ô
const vec2 EDGE_OFF = vec2(0.0, 0.035);   // mép dưới ám hồng của mũi tên, ổ khoá, theo ô
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

// Hộp bo góc tâm ở gốc, nửa cỡ h, bán kính bo rr. Âm là bên trong.
float round_box(vec2 p, vec2 h, float rr) {
	vec2 e = abs(p) - (h - vec2(rr));
	return length(max(e, vec2(0.0))) + min(max(e.x, e.y), 0.0) - rr;
}

// Mũi tên tâm ở gốc (q đã trừ tâm và chia cỡ), âm là bên trong; ô chứa mũi tên giữ đúng arrow_size sau khi bo góc.
float arrow_shape(vec2 q) {
	vec2 lp = vec2(dot(q, vec2(-arrow_dir.y, arrow_dir.x)), -dot(q, arrow_dir));
	float rr = ARROW_ROUND * cell_px;
	vec2 t = vec2(arrow_size.x * 0.5 - rr, arrow_size.y - 2.0 * rr);
	return triangle(lp + vec2(0.0, t.y * 0.5), t) - rr;
}

// Ổ khoá đứng thẳng trên màn: thân hộp bo góc, quai nửa vòng cắm hai chân xuống thân. Âm là bên trong.
float lock_shape(vec2 q) {
	float u = cell_px;
	float body = round_box(q - vec2(0.0, LOCK_BODY_Y * u), vec2(LOCK_W, LOCK_H) * 0.5 * u, LOCK_ROUND * u);
	vec2 a = q - vec2(0.0, LOCK_ARC_Y * u);
	float rc = LOCK_ARC_R * u;
	float legs = (LOCK_BODY_Y - LOCK_ARC_Y) * u;
	float arc = a.y < 0.0 ? abs(length(a) - rc) : length(vec2(abs(a.x) - rc, max(a.y - legs, 0.0)));
	return min(body, arc - LOCK_ARC_W * 0.5 * u);
}

// Lỗ khoá trên thân ổ: chấm tròn và khe hẹp bên dưới. Âm là bên trong.
float lock_hole(vec2 q) {
	float u = cell_px;
	vec2 c = q - vec2(0.0, LOCK_HOLE_Y * u);
	float dot_d = length(c) - LOCK_HOLE_R * u;
	vec2 sp = c - vec2(0.0, clamp(c.y, 0.0, LOCK_SLOT * u));
	return min(dot_d, length(sp) - LOCK_SLOT_W * 0.5 * u);
}

// Tâm mũi tên (cũng là chỗ ổ khoá) thứ i. Nhiều cổng: dời dọc thanh tới arrows_along.
vec2 glyph_at(int i) {
	if (seg_count < 2) {
		return arrow_at;
	}
	return vertical ? vec2(arrow_at.x, arrows_along[i]) : vec2(arrows_along[i], arrow_at.y);
}

// Chỉ số mũi tên gần `p` nhất (0 khi thanh một cổng).
int nearest_glyph(vec2 p) {
	int best = 0;
	float bd = 1e9;
	for (int i = 0; i < 3; i++) {
		if (i >= max(seg_count, 1)) {
			break;
		}
		float dd = length(p - glyph_at(i));
		if (dd < bd) {
			bd = dd;
			best = i;
		}
	}
	return best;
}

// Mũi tên (kind 0), ổ khoá (1) hoặc lỗ khoá (2) gần nhất, phóng theo `s` và phồng theo `pop`. Âm là bên trong.
float glyph(vec2 p, int kind, float s) {
	float k = max(s * (1.0 + pop), 0.001);
	float d = 1e6;
	for (int i = 0; i < 3; i++) {
		if (i >= max(seg_count, 1)) {
			break;
		}
		vec2 q = (p - glyph_at(i)) / k;
		vec2 ql = q - vec2(0.0, BADGE_LOCK_Y * cell_px);  // ổ khoá trong huy hiệu
		d = min(d, kind == 0 ? arrow_shape(q) : (kind == 1 ? lock_shape(ql) : lock_hole(ql)));
	}
	return d * k;
}

// Mũi tên và ổ khoá nảy nhẹ khi hiện ra: 0 → 1, vượt quá khoảng 2,5% rồi về.
float pop_in(float x) {
	return x + 0.45 * sin(PI * x) * x;
}

// Cổng đóng: thân ngả về màu đậm của cổng, phủ sọc kẹo gậy trắng chéo 45°; sọc dày dần theo `closed`.
// surf: toạ độ ngang thanh trên mặt thanh (thân thanh: across); rim: 0 sát mép, 1 vào trong.
vec3 closed_look(vec3 base, vec3 deep, float along, float surf, float thick, float rim, float closed) {
	if (closed <= 0.001) {
		return base;
	}
	vec3 c = mix(base, deep * CLOSED_DEEP_VAL, CLOSED_DEEP * closed);
	float period = thick * STRIPE_PERIOD;
	float t = along + surf;
	float ph = mod(t, period) - period * 0.5;  // tâm sọc ở ph = 0
	float hw = period * STRIPE_DUTY * 0.5 * closed;
	float m = (1.0 - smoothstep(hw - 0.9, hw + 0.9, abs(ph))) * smoothstep(0.0, 0.25, closed) * rim;
	// mép sau của sọc (phía dưới phải) tối dần như bóng của dải nổi
	float sh = smoothstep(hw + 0.9, hw + thick * 0.12, ph) * (1.0 - smoothstep(hw + thick * 0.12, hw + thick * 0.2, ph));
	c *= 1.0 - STRIPE_SHADE * sh * closed * rim;
	vec3 sc = mix(base, STRIPE_COL, STRIPE_MIX);
	return mix(c, sc, m);
}

// Đoạn bị va: lăng trụ lục giác quay quanh trục thanh, nhìn thẳng từ trên xuống; spin = 0 thì một mặt hướng lên
// người nhìn. Mỗi mặt tô một màu của mặt cắt tại hướng pháp tuyến của nó nên vẫn khớp ánh sáng với thân thanh.
// Trả về màu và độ phủ.
vec4 segment(float along, float across, float r, float half_len, float closed) {
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
		col = ramp_of(gate_at(seg_at), u);
		if (closed > 0.001) {
			// sọc vẽ trên từng mặt nên lăn theo mặt; mặt nào quay ra trước cũng khớp sọc của thân thanh
			float s = clamp((x - x0) / (x1 - x0), 0.0, 1.0);
			col = closed_look(col, end_of(gate_at(seg_at)), along, k * (0.5 - s), 2.0 * r, 1.0, closed);
		}
		col *= mix(SEG_SHADE, 1.0, facing);
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
	vec4 sg = seg > 0.001 ? segment(along, across, r, half_len, closed) : vec4(0.0);
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

		body = closed_look(body, gate_end, along, across, thick, smoothstep(0.0, r * STRIPE_RIM, d), closed);

		// sóng sáng chạy dọc thanh từ điểm bị va
		if (hit_t < 1.0) {
			float eased = 1.0 - (1.0 - hit_t) * (1.0 - hit_t);
			float h = (abs(along - hit_at) - eased * HIT_REACH * cell_px) / (HIT_W * cell_px);
			body = mix(body, vec3(1.0), HIT_A * (1.0 - hit_t) * exp(-h * h));
		}

		// mũi tên: viền mờ màu đậm của thanh, lệch nhẹ xuống; thân trắng, mép dưới ám hồng. Cổng đóng thì thu lại
		// nhường chỗ cho ổ khoá.
		if (open > 0.001) {
			float gs = pop_in(open);
			float ad = glyph(p, 0, gs);
			float as = 1.0 - smoothstep(0.0, 0.075 * cell_px, glyph(p - SHADOW_OFF * cell_px, 0, gs));
			body = mix(body, gate_end * 0.92, as * 0.85 * open);
			float edge = smoothstep(-0.035 * cell_px, 0.0, glyph(p + EDGE_OFF * cell_px, 0, gs));
			vec3 ac = mix(ARROW_COL, ARROW_EDGE, edge * 0.45);
			body = mix(body, ac, clamp(0.5 - ad, 0.0, 1.0) * smoothstep(0.0, 0.35, open));
		}

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
		vec3 sc = mix(sg.rgb, vec3(1.0), flash * 0.55);
		col = a > 0.0 ? mix(col, sc, sa) : sc;
		a = max(a, sa);
	}

	// cổng đóng: huy hiệu tròn màu đậm của cổng nổi trên thanh (lấn ra ngoài thanh), ổ khoá trắng ở giữa;
	// nảy ra chỗ mũi tên khi cổng đóng, thu lại khi mở
	if (closed > 0.001) {
		float gs = pop_in(closed);
		float k = max(gs * (1.0 + pop), 0.001);
		float bw = smoothstep(0.0, 0.35, closed);
		vec2 bc = glyph_at(nearest_glyph(p));
		vec3 deep = end_of(gate_at(vertical ? bc.y : bc.x));
		float R = BADGE_R * cell_px;
		vec2 q = (p - bc) / k;
		float bd = (length(q) - R) * k;
		float ba = clamp(0.5 - bd, 0.0, 1.0) * bw;
		// bóng đổ: trên thanh thì tối thân thanh, ngoài thanh thì nhập vào bóng của thanh
		float bsd = (length(q - vec2(0.0, SHADOW_DY * cell_px) / k) - R) * k;
		float bsh = smoothstep(-SHADOW_BLUR * cell_px, 0.02 * cell_px, -bsd) * bw;
		col = mix(col, col * BADGE_SHADOW_ON_BAR, bsh * a * (1.0 - ba));
		shadow = max(shadow, bsh * SHADOW_A);
		if (ba > 0.0) {
			float yy = clamp(q.y / R, -1.0, 1.0);
			vec3 bcol = mix(min(deep * BADGE_TOP, vec3(1.0)), deep * BADGE_BOTTOM, smoothstep(-0.9, 0.9, yy));
			// viền sáng, phía trên sáng hơn phía dưới
			float rim_w = BADGE_RIM * cell_px;
			float rim = smoothstep(-rim_w - 0.8, -rim_w + 0.8, length(q) - R);
			bcol = mix(bcol, mix(deep, vec3(1.0), mix(0.6, 0.25, smoothstep(-1.0, 1.0, yy))), rim);
			// ổ khoá: bóng lệch xuống màu đậm, thân trắng mép dưới ám hồng, lỗ khoá màu đậm
			float ld = glyph(p, 1, gs);
			float lsd = 1.0 - smoothstep(0.0, 0.06 * cell_px, glyph(p - SHADOW_OFF * cell_px, 1, gs));
			bcol = mix(bcol, deep * 0.5, lsd * 0.55 * (1.0 - rim));
			float edge = smoothstep(-0.035 * cell_px, 0.0, glyph(p + EDGE_OFF * cell_px, 1, gs));
			vec3 lc = mix(ARROW_COL, ARROW_EDGE, edge * 0.45);
			lc = mix(lc, deep * 0.75, clamp(0.5 - glyph(p, 2, gs), 0.0, 1.0));
			bcol = mix(bcol, lc, clamp(0.5 - ld, 0.0, 1.0));
			bcol = mix(bcol, vec3(1.0), flash * 0.55);
			col = a > 0.0 ? mix(col, bcol, ba) : bcol;
			a = max(a, ba);
		}
	}

	float alpha = a + shadow * (1.0 - a);
	COLOR = vec4((col * a + SHADOW_COL * shadow * (1.0 - a)) / max(alpha, 0.0001), alpha);
}
