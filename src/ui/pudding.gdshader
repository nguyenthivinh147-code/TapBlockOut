shader_type canvas_item;
// Thân khối kẹo: chất liệu chung từ `candy_body.gdshaderinc` (kẹo sọc hoặc crystal), thêm lớp phủ (pudding hoặc băng,
// 1 hay 2 lớp), hộp giấy, ruy băng, lớp sương mù, nháy sáng và bóng đổ.

#include "res://src/ui/candy_body.gdshaderinc"

uniform vec4 overlay = vec4(0.0);  // lớp phủ màu trong hình khối
uniform float flash = 0.0;         // nháy sáng trong hình khối (gợi ý, nảy)
uniform float body_a = 1.0;        // 0: chỉ vẽ bóng đổ
uniform float shadow_a = 0.0;      // độ đậm bóng đổ
uniform float candy_a = 1.0;       // 0: bỏ thân kẹo, chỉ còn lớp pudding (lớp pudding vỡ bay ra)
uniform float jelly = 0.0;         // lớp phủ gần trong suốt phủ trọn khối (pudding hoặc băng), 0..1
uniform float jelly_thick = 0.0;   // 1: lớp phủ dày (khối 2 lớp): tràn xa hơn, đục hơn, có viền trong
uniform float ice_mat = 0.0;       // 1: lớp phủ là băng thay cho pudding
uniform float paper = 0.0;         // hộp giấy thay cho thân kẹo (khối hai lớp)
uniform vec2 tape = vec2(-9.0);    // tâm băng dán của hộp, toạ độ ô của khối; âm là không có
uniform float fog = 0.0;           // lớp sương phủ trên cùng (khối còn trong sương mù), 0..1
uniform vec2 fog_origin = vec2(0.0);  // ô gốc của khối trên bàn: các khối sương cạnh nhau chung một đám sương
uniform float ribbons = 0.0;       // số ruy băng còn lại (0..4): dải satin cùng màu khối quấn chéo

const float SHADOW_DY = 0.09;
const float SHADOW_BLUR = 0.13;
const vec3 SHADOW_COL = vec3(0.09, 0.08, 0.26);

const float JELLY_OUT = 0.1;     // pudding phủ ra ngoài mép khối chừng này (ô)
const float JELLY_OUT2 = 0.16;   // lớp dày (2 lớp) phủ ra xa hơn
const vec3 JELLY_COL = vec3(1.0, 0.86, 0.92);
const vec3 JELLY_COL2 = vec3(0.99, 0.74, 0.85);  // lòng pudding 2 lớp hồng đậm hơn
const vec3 JELLY_DEEP = vec3(0.93, 0.47, 0.66);
const float JELLY_BODY_A = 0.24;   // độ đục trong lòng pudding
const float JELLY_BODY_A2 = 0.44;  // lòng pudding 2 lớp đục hơn
const float JELLY_RIM_A = 0.82;   // độ đục ở viền pudding
const float JELLY_RIM_W = 0.2;
const float JELLY_INNER_W = 0.03; // viền trong của lớp thứ hai, nằm ở mép lớp 1 (nửa bề rộng, ô)
const float SWEEP_PERIOD = 3.2;   // giây giữa hai vệt sáng quét chéo qua pudding

// Băng: trong, trắng xanh, viền đóng sương trắng loang, vết nứt trắng mảnh, vệt sáng lạnh quét chéo, hạt sương lấp lánh.
const vec3 ICE_COL = vec3(0.76, 0.91, 1.0);
const vec3 ICE_DEEP = vec3(0.45, 0.7, 0.95);
const vec3 ICE_FROST = vec3(0.94, 0.98, 1.0);  // sương giá ở viền, trắng ánh xanh
const float ICE_BODY_A = 0.34;
const float ICE_BODY_A2 = 0.56;   // băng 2 lớp đục hơn
const float ICE_RIM_A = 0.88;
const float ICE_RIM_W = 0.16;
const float ICE_FROST_W = 0.12;   // dải sương giá trắng ở viền (ô), dày hơn ở băng 2 lớp
const float ICE_CRACKS = 1.2;     // mảnh băng mỗi ô (vết nứt là ranh mảnh); băng 2 lớp nhiều hơn
const float ICE_SWEEP_PERIOD = 2.6;

// Hộp giấy: nắp giấy bìa nhuộm màu khối (mờ, không bóng, vân sợi và đốm kraft), thành hộp lộ ra quanh nắp (dày ở đáy,
// mỏng ở trên như kẹo) với cạnh gấp sắc, viền tối bao quanh, băng dán chữ thập có bóng đè qua cạnh xuống thành hộp.
const vec3 KRAFT = vec3(0.79, 0.6, 0.39);
const vec3 KRAFT_FLECK = vec3(0.36, 0.24, 0.13);  // đốm xơ giấy tái chế
const float PAPER_KRAFT = 0.26;   // màu giấy pha kraft chừng này, phần còn lại là màu khối
const float PAPER_FIBERS = 6.0;   // sợi giấy ngắn mỗi ô, mỗi chiều
const float BOX_WALL = 0.11;      // thành hộp lộ ra hai bên nắp (ô)
const float BOX_SHIFT = 0.075;    // lệch dọc: thành đáy dày thêm, thành trên mỏng đi chừng này
const float BOX_LINE = 0.03;      // viền tối quanh hộp (ô)
const float TAPE_W = 0.1;         // nửa bề rộng băng dán (ô)
const vec3 TAPE_COL = vec3(1.0, 0.95, 0.83);

// Ruy băng (concept `art/concepts/ribbon_concept_v2.png`): `ribbons` dải satin cùng màu khối quấn chéo (theo x + y), rải
// đều trong khung khối, phủ gần kín khối; số khe tối giữa các dải cho biết số lớp. Hai dải ngoài kéo tới góc khung.
const float RIB_MARGIN = 0.3;     // khoảng x + y bỏ trống ở hai góc xa khi chia dải
const float RIB_FILL = 0.86;      // phần mỗi khoảng do dải phủ, còn lại là khe
const float RIB_GAP_DIM = 0.72;   // kẹo lộ ở khe nằm trong bóng ruy băng

// Sương mù: lớp mờ loang phủ chồng lên khối, trôi chậm, viền mờ dần và lấn ra ngoài mép (BoardView vẽ khối sương sau
// các khối khác nên phần lấn phủ lên mép khối bên cạnh). Phần lấn phải nằm trong lề texture SDF (Pudding.PAD, 0,31 ô).
const float FOG_SPILL = 0.24;     // sương lấn ra ngoài mép khối chừng này (ô) rồi tắt hẳn (cộng nửa FOG_WISP < 0,30)
const float FOG_FULL = 0.1;       // vào trong mép chừng này (ô) thì sương đủ dày
const float FOG_WISP = 0.12;      // mép sương xô lệch theo nhiễu chừng này (ô), viền không thẳng
const float FOG_THIN = 0.34;      // độ đục chỗ sương mỏng
const float FOG_THICK = 0.74;     // độ đục chỗ sương dày
const float FOG_SCALE = 0.8;      // cụm sương mỗi ô
const vec2 FOG_DRIFT = vec2(0.07, 0.03);  // sương trôi (ô/giây)
const vec3 FOG_LIGHT = vec3(0.97, 0.97, 1.0);
const vec3 FOG_SHADE = vec3(0.76, 0.78, 0.9);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Pháp tuyến ngoài của mép tại c (đơn vị ô), từ đạo hàm SDF.
vec2 outward(vec2 c) {
	const float EPS = 0.04;
	vec2 g = vec2(dist(c + vec2(EPS, 0.0)) - dist(c - vec2(EPS, 0.0)), dist(c + vec2(0.0, EPS)) - dist(c - vec2(0.0, EPS)));
	return -normalize(g + vec2(1e-5));
}

// Một dải băng dán: t là khoảng cách tới đường giữa dải (ô). Băng hơi trong nên ám màu giấy dưới nó, mép đậm, vệt bóng
// lệch về một bên, bóng mảnh in xuống giấy ngay ngoài mép.
vec3 tape_strip(vec3 under, vec3 paper_tone, float t, float grain, float shade, float aa) {
	float drop = (1.0 - smoothstep(TAPE_W, TAPE_W + 0.04, t)) * 0.18;
	under *= 1.0 - drop;
	float band = 1.0 - smoothstep(TAPE_W - aa, TAPE_W + aa, t);
	vec3 tcol = mix(TAPE_COL, paper_tone, 0.1) * (0.97 + 0.05 * grain);
	tcol *= 1.0 - 0.16 * smoothstep(TAPE_W * 0.6, TAPE_W, t);
	tcol = mix(tcol, vec3(1.0), (1.0 - smoothstep(0.0, TAPE_W * 0.22, abs(t - TAPE_W * 0.3))) * 0.4);
	return mix(under, tcol * shade, band);
}

// Sợi giấy: mỗi ô lưới (`PAPER_FIBERS` mỗi ô khối) một sợi ngắn, hướng và chỗ ngẫu nhiên. x là độ phủ, y là dấu
// (sợi sáng hay sợi sẫm).
vec2 paper_fiber(vec2 p) {
	vec2 q = p * PAPER_FIBERS;
	vec2 i = floor(q);
	vec2 v = fract(q) - 0.5 - (vec2(crystal_hash(i + 1.7), crystal_hash(i + 8.9)) - 0.5) * 0.3;
	float ang = crystal_hash(i + 3.3) * 3.1416;
	vec2 dir = vec2(cos(ang), sin(ang));
	float w = PAPER_FIBERS / cell_px;  // một px theo đơn vị lưới
	float along = 1.0 - smoothstep(0.24, 0.34, abs(dot(v, dir)));
	float across = 1.0 - smoothstep(w * 0.4, w * 1.1, abs(dot(v, vec2(-dir.y, dir.x))));
	float on = step(crystal_hash(i + 6.1), 0.7);
	return vec2(along * across * on, crystal_hash(i + 4.4) < 0.5 ? -1.0 : 1.0);
}

vec3 paper_color(vec2 c, float d) {
	vec2 p = c - vec2(pad);
	float aa = 1.0 / cell_px;
	vec3 card = mix(face.rgb, KRAFT, PAPER_KRAFT);
	vec3 ink = mix(deep.rgb, KRAFT_FLECK, 0.4) * 0.55;  // viền và đường gấp: tông đáy của màu khối, ngả nâu
	vec2 n = outward(c);
	float lit = clamp(dot(n, vec2(-0.45, -0.9)), 0.0, 1.0);
	float e_x = (d - dist(c + vec2(CORNER_E, 0.0))) / CORNER_E;  // mép quay sang phải
	// vân giấy: loang mờ, vệt xơ dài theo chiều ngang, sợi ngắn sáng sẫm, đốm xơ kraft thưa
	float mottle = crystal_noise(p * 2.6 + 1.3) * 0.6 + crystal_noise(p * 6.5 + 5.1) * 0.4;
	float grain = crystal_noise(p * vec2(1.6, 11.0) + 2.2);
	float near_top = clamp(-dist(c - vec2(0.0, 0.5)) / 0.5, 0.0, 1.0);
	vec3 lid = card * (0.93 + 0.1 * mottle + 0.06 * (grain - 0.5) + 0.06 * near_top);
	vec2 fb = paper_fiber(p);
	vec2 fb2 = paper_fiber(p * 1.37 + 0.53);
	lid *= 1.0 + 0.08 * (fb.x * fb.y + fb2.x * fb2.y);
	vec2 fleck = crystal_grain(p + 0.21, 7.0, 0.1);
	lid = mix(lid, mix(card, KRAFT_FLECK, 0.45), fleck.x * 0.35);
	// thành hộp: SDF lệch dọc nên dày ở đáy, vừa hai bên, mỏng ở trên; ngả về tông đáy của màu khối, mép phải tối hơn
	float lid_d = dist(c + vec2(0.0, BOX_SHIFT)) - BOX_WALL;  // dương là trên nắp
	float on_lid = smoothstep(-aa, aa, lid_d);
	float near_bottom = clamp(-dist(c + vec2(0.0, 0.3)) / 0.3, 0.0, 1.0);
	float right = 1.0 - 0.1 * smoothstep(0.4, 0.8, e_x);
	float wall_shade = mix(0.84, 0.68, near_bottom) * right;
	vec3 wall = mix(card * 0.86, mix(deep.rgb, KRAFT * 0.7, PAPER_KRAFT) * 0.92, near_bottom) * right;
	wall *= 0.97 + 0.06 * grain;
	vec3 col = mix(wall, lid, on_lid);
	// cạnh gấp của nắp: vệt sáng ngay trong mép nắp ở phía đón sáng, đường gấp sẫm ngay ngoài mép nắp
	float lip = (1.0 - smoothstep(0.0, 0.04, lid_d)) * on_lid;
	col = mix(col, mix(lid, vec3(1.0), 0.5), lip * (0.25 + 0.6 * lit));
	float crease = (1.0 - smoothstep(0.0, 0.022, -lid_d)) * (1.0 - on_lid);
	col = mix(col, ink, crease * 0.5);
	// băng dán chữ thập qua tâm hộp, đè qua cạnh xuống thành hộp; dải ngang nằm trên dải dọc
	if (tape.x > -5.0) {
		float shade = mix(wall_shade, 1.0, on_lid);
		col = tape_strip(col, card, abs(p.x - tape.x), grain, shade, aa);
		col = tape_strip(col, card, abs(p.y - tape.y), grain, shade, aa);
	}
	// viền sẫm bao quanh hộp
	float line = 1.0 - smoothstep(BOX_LINE - aa, BOX_LINE + aa, d);
	return mix(col, ink, line * 0.92);
}

// Lớp pudding tại c: rgb và độ đục, dj = khoảng cách tới mép pudding (dương là bên trong).
vec4 jelly_layer(vec2 c, float dj) {
	vec2 p = c - vec2(pad);
	vec2 n = outward(c);
	float rim = 1.0 - smoothstep(0.0, JELLY_RIM_W, dj);
	float light = clamp(dot(n, normalize(vec2(-0.55, -1.0))), 0.0, 1.0);
	float dark = clamp(dot(n, normalize(vec2(0.5, 1.0))), 0.0, 1.0);
	vec3 col = mix(mix(JELLY_COL, JELLY_COL2, jelly_thick), JELLY_DEEP, rim * (0.35 + 0.5 * dark));
	float a = mix(mix(JELLY_BODY_A, JELLY_BODY_A2, jelly_thick), JELLY_RIM_A, rim);
	// lớp thứ hai: viền trong đậm ngay chỗ mép của lớp 1, sáng ở trên trái như mép thạch
	float inner = jelly_thick * (1.0 - smoothstep(0.0, JELLY_INNER_W, abs(dj - (JELLY_OUT2 - JELLY_OUT))));
	col = mix(col, mix(JELLY_DEEP, vec3(1.0), light * 0.6), inner * 0.7);
	a = max(a, inner * 0.75);
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

// Lớp băng tại c: rgb và độ đục, dj như jelly_layer. Hoa văn theo toạ độ ô của khối nên đi theo khối.
vec4 ice_layer(vec2 c, float dj) {
	vec2 p = c - vec2(pad);
	vec2 n = outward(c);
	float rim = 1.0 - smoothstep(0.0, ICE_RIM_W, dj);
	float light = clamp(dot(n, normalize(vec2(-0.55, -1.0))), 0.0, 1.0);
	float dark = clamp(dot(n, normalize(vec2(0.5, 1.0))), 0.0, 1.0);
	vec3 col = mix(ICE_COL, ICE_DEEP, rim * (0.3 + 0.55 * dark));
	float a = mix(mix(ICE_BODY_A, ICE_BODY_A2, jelly_thick), ICE_RIM_A, rim);
	// mảnh băng: mỗi mảnh xanh lệch một chút, ranh mảnh là vết nứt trắng (băng 2 lớp nứt dày hơn)
	vec2 fc = crystal_facet(p + 1.9, ICE_CRACKS * (1.0 + 0.6 * jelly_thick));
	col = mix(col, ICE_DEEP, (fc.x - 0.5) * 0.25);
	float crack = (1.0 - smoothstep(0.006, 0.022, fc.y)) * smoothstep(0.3, 0.6, crystal_noise(p * 1.7 + 4.2));
	crack *= mix(0.6, 1.0, jelly_thick) * smoothstep(0.06, 0.16, dj);
	// sương giá trắng loang ở viền, mép trong xô lệch theo nhiễu
	float fn = crystal_noise(p * 7.0 + 2.3) * 0.6 + crystal_noise(p * 15.0 + 9.1) * 0.4;
	float frost_w = ICE_FROST_W * (1.0 + 0.6 * jelly_thick);
	float frost = 1.0 - smoothstep(frost_w * 0.35, frost_w, dj + (fn - 0.5) * 0.07);
	// vệt bóng sát mép trên trái, vệt sáng lạnh quét chéo, hạt sương lấp lánh
	float spec = (1.0 - smoothstep(0.0, 0.045, abs(dj - 0.06))) * smoothstep(0.35, 0.95, light);
	float sweep_pos = fract(TIME / ICE_SWEEP_PERIOD) * 6.0 - 1.5;
	float sweep = (1.0 - smoothstep(0.0, 0.16, abs(p.x + p.y * 0.6 - sweep_pos))) * 0.4;
	float twinkle = crystal_twinkle(p * 1.3 + 0.7) * smoothstep(0.1, 0.2, dj);
	col = mix(col, ICE_FROST, clamp(frost * 0.8, 0.0, 1.0));
	col = mix(col, vec3(1.0), clamp(crack * 0.85 + spec * 0.9 + sweep + twinkle, 0.0, 1.0));
	a = clamp(max(a, frost * 0.85) + crack * 0.6 + spec * 0.6 + sweep * 0.4 + twinkle * 0.6, 0.0, 1.0);
	return vec4(col, a);
}

// Lớp sương tại c: rgb và độ đục; d = dist(c). Nhiễu theo toạ độ ô trên bàn nên sương liền qua các khối sương kề nhau.
vec4 fog_layer(vec2 c, float d) {
	vec2 q = (c - vec2(pad) + fog_origin) * FOG_SCALE + TIME * FOG_DRIFT;
	float n = crystal_noise(q) * 0.55 + crystal_noise(q * 2.3 + 7.1) * 0.3 + crystal_noise(q * 5.1 + 2.9) * 0.15;
	float edge = smoothstep(-FOG_SPILL, FOG_FULL, d + (n - 0.5) * FOG_WISP);
	vec3 col = mix(FOG_SHADE, FOG_LIGHT, smoothstep(0.25, 0.8, n));
	return vec4(col, edge * mix(FOG_THIN, FOG_THICK, n));
}

// Ruy băng tại c: rgb và độ phủ (1 trên dải, 0 ở khe).
vec4 ribbon_layer(vec2 c, float d) {
	vec2 p = c - vec2(pad);
	vec2 box = dims - vec2(2.0 * pad);
	float s = p.x + p.y;
	float slot = (box.x + box.y - 2.0 * RIB_MARGIN) / ribbons;
	float k = clamp(floor((s - RIB_MARGIN) / slot), 0.0, ribbons - 1.0);
	float centre = RIB_MARGIN + (k + 0.5) * slot;
	float half_w = 0.5 * slot * RIB_FILL;
	float v = (s - centre) / half_w;  // -1..1 ngang dải
	float edge_px = 1.27 / (cell_px * half_w);
	float inside = 1.0 - smoothstep(1.0 - edge_px, 1.0 + edge_px, abs(v));
	if ((k < 0.5 && v < 0.0) || (k > ribbons - 1.5 && v > 0.0)) {
		inside = 1.0;
	}
	float av = clamp(abs(v), 0.0, 1.0);
	vec3 col = mix(face.rgb, side.rgb, smoothstep(0.55, 1.0, av) * 0.75);  // mép dải gập tối
	col = mix(col, vec3(1.0), exp(-pow((v + 0.25) / 0.32, 2.0)) * 0.42);    // vệt bóng satin lệch tâm
	col += vec3(0.04) * sin((p.x - p.y) * 6.0 + v * 2.0);                   // gợn vải
	col *= mix(0.8, 1.0, smoothstep(0.0, 0.12, d));                          // quấn qua mép khối
	return vec4(col, inside);
}

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float a = max(clamp(d * cell_px + 0.5, 0.0, 1.0), crystal_fuzz(c, d)) * body_a * candy_a;

	// bóng đổ mềm lệch xuống dưới, ám chàm
	float jelly_out = mix(JELLY_OUT, JELLY_OUT2, jelly_thick);
	float ds = dist(c - vec2(0.0, SHADOW_DY)) + jelly_out * jelly;
	float shadow = smoothstep(-SHADOW_BLUR, 0.02, ds) * shadow_a;

	vec3 col = vec3(0.0);
	if (a > 0.0) {
		col = paper > 0.5 ? paper_color(c, d) : body_color(c, d);
	}
	// Ruy băng phủ trên thân kẹo; candy_a 0 (ruy băng bay đi) thì chỉ còn các dải.
	if (ribbons > 0.5 && body_a > 0.0) {
		vec4 rl = ribbon_layer(c, d);
		col = mix(col * RIB_GAP_DIM, rl.rgb, rl.a);
		a = max(a, rl.a * clamp(d * cell_px + 0.5, 0.0, 1.0) * body_a);
	}
	if (a > 0.0) {
		col = mix(col, overlay.rgb, overlay.a);
		col = mix(col, vec3(1.0), flash * 0.28);
	}
	// cộng dồn có nhân alpha: thân kẹo, lớp phủ bên trên, bóng đổ phía sau
	vec3 pm = col * a;
	float pa = a;
	if (jelly > 0.0 && body_a > 0.0) {
		float dj = d + jelly_out;
		float cover = clamp(dj * cell_px + 0.5, 0.0, 1.0);
		if (cover > 0.0) {
			vec4 jl = ice_mat > 0.5 ? ice_layer(c, dj) : jelly_layer(c, dj);
			jl.rgb = mix(jl.rgb, vec3(1.0), flash * 0.4);
			float ja = jl.a * cover * jelly * body_a;
			pm = jl.rgb * ja + pm * (1.0 - ja);
			pa = ja + pa * (1.0 - ja);
		}
	}
	// sương trên cùng, cả trên lớp pudding; lấn ra ngoài mép khối nên không nhân độ phủ của thân
	if (fog > 0.0 && body_a > 0.0) {
		vec4 fl = fog_layer(c, d);
		fl.rgb = mix(fl.rgb, vec3(1.0), flash * 0.3);
		float fa = fl.a * fog;
		pm = fl.rgb * fa + pm * (1.0 - fa);
		pa = fa + pa * (1.0 - fa);
	}
	pm += SHADOW_COL * shadow * (1.0 - pa);
	pa += shadow * (1.0 - pa);
	COLOR = vec4(pm / max(pa, 0.0001), pa);
}
