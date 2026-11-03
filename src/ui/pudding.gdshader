shader_type canvas_item;
// Thân khối kẹo: chất liệu chung từ `candy_body.gdshaderinc`, thêm lớp pudding, hộp giấy, nháy sáng và bóng đổ.

#include "res://src/ui/candy_body.gdshaderinc"

uniform vec4 overlay = vec4(0.0);  // lớp phủ màu trong hình khối
uniform float flash = 0.0;         // nháy sáng trong hình khối (gợi ý, nảy)
uniform float body_a = 1.0;        // 0: chỉ vẽ bóng đổ
uniform float shadow_a = 0.0;      // độ đậm bóng đổ
uniform float candy_a = 1.0;       // 0: bỏ thân kẹo, chỉ còn lớp pudding (lớp pudding vỡ bay ra)
uniform float jelly = 0.0;         // lớp pudding gần trong suốt phủ trọn khối (vật cản 2 lần chạm)
uniform float paper = 0.0;         // hộp giấy thay cho thân kẹo (khối hai lớp)
uniform vec2 tape = vec2(-9.0);    // tâm băng dán của hộp, toạ độ ô của khối; âm là không có

const float SHADOW_DY = 0.09;
const float SHADOW_BLUR = 0.13;
const vec3 SHADOW_COL = vec3(0.09, 0.08, 0.26);

const float JELLY_OUT = 0.1;     // pudding phủ ra ngoài mép khối chừng này (ô)
const vec3 JELLY_COL = vec3(1.0, 0.86, 0.92);
const vec3 JELLY_DEEP = vec3(0.93, 0.47, 0.66);
const float JELLY_BODY_A = 0.24;   // độ đục trong lòng pudding
const float JELLY_RIM_A = 0.82;   // độ đục ở viền pudding
const float JELLY_RIM_W = 0.2;
const float SWEEP_PERIOD = 3.2;   // giây giữa hai vệt sáng quét chéo qua pudding

const vec3 KRAFT = vec3(0.79, 0.6, 0.39);
const float PAPER_TINT = 0.55;    // giấy nhuộm màu khối chừng này, phần còn lại là màu giấy kraft
const float PAPER_EDGE = 0.1;     // mép gấp của hộp (ô)
const float TAPE_W = 0.11;        // nửa bề rộng băng dán (ô)
const vec3 TAPE_COL = vec3(1.0, 0.95, 0.84);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Pháp tuyến ngoài của mép tại c (đơn vị ô), từ đạo hàm SDF.
vec2 outward(vec2 c) {
	const float EPS = 0.04;
	vec2 g = vec2(dist(c + vec2(EPS, 0.0)) - dist(c - vec2(EPS, 0.0)), dist(c + vec2(0.0, EPS)) - dist(c - vec2(0.0, EPS)));
	return -normalize(g + vec2(1e-5));
}

vec3 paper_color(vec2 c, float d) {
	vec2 p = c - vec2(pad);
	vec3 base = mix(KRAFT, face.rgb, PAPER_TINT);
	// sợi giấy: nhiễu mịn theo hàng và cột
	float fiber = hash(floor(p * 22.0)) * 0.5 + hash(floor(p * vec2(6.0, 40.0))) * 0.5;
	base *= 0.95 + 0.07 * fiber;
	// nắp hộp: dải trên sáng hơn, đường gấp tối ngay dưới nắp
	float near_top = clamp(-dist(c - vec2(0.0, 0.3)) / 0.3, 0.0, 1.0);
	base = mix(base, base * 1.12 + 0.04, smoothstep(0.35, 0.6, near_top));
	float lid_line = smoothstep(0.08, 0.0, abs(near_top - 0.32)) * 0.22;
	base *= 1.0 - lid_line;
	// mép gấp: tối dần ra ngoài, mép phải và đáy tối hơn
	vec2 n = outward(c);
	float edge = 1.0 - smoothstep(0.0, PAPER_EDGE, d);
	float shade = mix(0.92, 0.7, clamp(dot(n, vec2(0.45, 0.9)) * 0.5 + 0.5, 0.0, 1.0));
	base = mix(base, base * shade, edge);
	base = mix(base, vec3(1.0), (1.0 - smoothstep(0.0, 0.035, abs(d - 0.03))) * clamp(dot(n, vec2(-0.5, -0.86)), 0.0, 1.0) * 0.45);
	// băng dán chữ thập qua tâm hộp
	if (tape.x > -5.0) {
		float tx = abs(p.x - tape.x);
		float ty = abs(p.y - tape.y);
		float band = max(1.0 - smoothstep(TAPE_W - 0.012, TAPE_W + 0.012, tx), 1.0 - smoothstep(TAPE_W - 0.012, TAPE_W + 0.012, ty));
		vec3 tcol = TAPE_COL * (0.93 + 0.07 * fiber);
		float t_edge = max(smoothstep(TAPE_W - 0.04, TAPE_W, tx) * step(tx, TAPE_W), smoothstep(TAPE_W - 0.04, TAPE_W, ty) * step(ty, TAPE_W));
		tcol *= 1.0 - 0.12 * t_edge;
		base = mix(base, tcol, band * smoothstep(0.0, 0.05, d));
	}
	return base;
}

// Lớp pudding tại c: rgb và độ đục, dj = khoảng cách tới mép pudding (dương là bên trong).
vec4 jelly_layer(vec2 c, float dj) {
	vec2 p = c - vec2(pad);
	vec2 n = outward(c);
	float rim = 1.0 - smoothstep(0.0, JELLY_RIM_W, dj);
	float light = clamp(dot(n, normalize(vec2(-0.55, -1.0))), 0.0, 1.0);
	float dark = clamp(dot(n, normalize(vec2(0.5, 1.0))), 0.0, 1.0);
	vec3 col = mix(JELLY_COL, JELLY_DEEP, rim * (0.35 + 0.5 * dark));
	float a = mix(JELLY_BODY_A, JELLY_RIM_A, rim);
	// vệt bóng lớn sát mép trên trái
	float spec = (1.0 - smoothstep(0.0, 0.05, abs(dj - 0.07))) * smoothstep(0.35, 0.95, light);
	// vệt sáng chéo quét qua theo chu kỳ
	float sweep_pos = fract(TIME / SWEEP_PERIOD) * 6.0 - 1.5;
	float sweep = (1.0 - smoothstep(0.0, 0.22, abs(p.x + p.y * 0.6 - sweep_pos))) * 0.35;
	// bọt khí nhỏ, mỗi ô một bọt ở chỗ ngẫu nhiên
	vec2 cell_id = floor(p);
	vec2 bp = vec2(0.25, 0.25) + vec2(hash(cell_id), hash(cell_id + 7.0)) * 0.5;
	float br = 0.045 + 0.03 * hash(cell_id + 3.0);
	float bd = length(fract(p) - bp);
	float bubble = (1.0 - smoothstep(br - 0.012, br, bd)) * 0.35 + (1.0 - smoothstep(0.0, 0.016, abs(bd - br))) * 0.45;
	bubble *= smoothstep(0.1, 0.2, dj);
	col = mix(col, vec3(1.0), clamp(spec * 0.9 + sweep + bubble, 0.0, 1.0));
	a = clamp(a + spec * 0.6 + sweep * 0.5 + bubble * 0.4, 0.0, 1.0);
	return vec4(col, a);
}

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0) * body_a * candy_a;

	// bóng đổ mềm lệch xuống dưới, ám chàm
	float ds = dist(c - vec2(0.0, SHADOW_DY)) + JELLY_OUT * jelly;
	float shadow = smoothstep(-SHADOW_BLUR, 0.02, ds) * shadow_a;

	vec3 col = vec3(0.0);
	if (a > 0.0) {
		col = paper > 0.5 ? paper_color(c, d) : candy_color(c, d);
		col = mix(col, overlay.rgb, overlay.a);
		col = mix(col, vec3(1.0), flash * 0.28);
	}
	// cộng dồn có nhân alpha: thân kẹo, lớp pudding bên trên, bóng đổ phía sau
	vec3 pm = col * a;
	float pa = a;
	if (jelly > 0.0 && body_a > 0.0) {
		float dj = d + JELLY_OUT;
		float cover = clamp(dj * cell_px + 0.5, 0.0, 1.0);
		if (cover > 0.0) {
			vec4 jl = jelly_layer(c, dj);
			jl.rgb = mix(jl.rgb, vec3(1.0), flash * 0.4);
			float ja = jl.a * cover * jelly * body_a;
			pm = jl.rgb * ja + pm * (1.0 - ja);
			pa = ja + pa * (1.0 - ja);
		}
	}
	pm += SHADOW_COL * shadow * (1.0 - pa);
	pa += shadow * (1.0 - pa);
	COLOR = vec4(pm / max(pa, 0.0001), pa);
}
