// Chất liệu khối kẹo, dùng chung cho thân khối (`pudding.gdshader`) và mảnh vỡ (`candy_shard.gdshader`).
// Tô theo khoảng cách tới mép (texture R = signed distance, đơn vị ô, dương là bên trong).
// Số đo lấy từ art/concepts/concept_candy_board_v5_stripe.png: mép gối sáng từ trên xuống
// (mỏng ở trên, vừa ở hai bên, dày ở đáy), sọc 45 độ chu kỳ đúng 1 ô, vạch sáng ở đáy.

uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec4 deep : source_color = vec4(1.0);    // đáy gối
uniform vec4 side : source_color = vec4(1.0);    // hai bên
uniform vec4 face : source_color = vec4(1.0);    // mặt, phần sọc đậm
uniform vec4 stripe : source_color = vec4(1.0);  // mặt, phần sọc nhạt
uniform vec2 dims = vec2(1.0);  // cỡ vùng texture, đơn vị ô
uniform float pad = 0.0;        // lề của texture, đơn vị ô
uniform float cell_px = 64.0;
uniform float crystal = 0.0;    // 1: khối crystal (mảnh leaderboard) thay cho kẹo sọc

const float BEVEL = 0.2;          // bề dày mép hai bên
const float BEVEL_SHIFT = 0.08;   // lệch dọc: mép đáy dày thêm chừng này
const float TOP_THIN = 0.1;       // mép trên mỏng đi thêm chừng này
const float SOFT = 0.11;          // chuyển từ mép sang mặt
const float REACH_TOP = 0.6;      // tầm sáng từ mép trên xuống
const float REACH_BOTTOM = 0.35;  // tầm đổi màu về đáy
const float TOP_GLOW = 0.26;
const float STRIPE_A = 0.5;          // sọc nhạt pha bấy nhiêu tông stripe vào mặt
const float STRIPE_IN_BEVEL = 0.08;
const float RIGHT_DARK = 0.22;    // mép phải tối hơn mép trái, ánh sáng từ trên trái
const float RIM_AT = 0.05;        // vạch sáng đáy, cách mép
const float RIM_W = 0.022;
const float CORNER_E = 0.06;

// Crystal, theo art/concepts/concept_candy_board_v4_crystal_semi.png: kẹo đường kết tinh trong như thuỷ tinh, không sọc.
// Lòng khối đậm màu hơn kẹo thường, sáng tối loang như nhìn xuyên vào khối, các mảnh vỡ lệch sáng tối với vết nứt trắng
// sắc đứt quãng; ánh sáng vào từ trên trái nên lòng khối sáng lên sát mép dưới phải. Viền trong (mép mặt bàn) là vạch
// sáng, rõ nhất ở dưới phải; mép vát quanh sáng ở trên trái, đậm ở dưới phải. Đường cát phủ quanh mép, dày ở trên, hạt
// lồi ra khỏi mép; một vệt sáng quét qua theo chu kỳ; sao bốn cánh nhấp nháy. Vệt bóng lưỡi liềm ở góc lồi trên trái
// vẽ bằng `BoardFx.draw_crystal_gloss`. Mọi hoa văn theo toạ độ ô của khối nên đi theo khối khi trượt.
const float CRYSTAL_BODY_DEEP = 0.42;  // lòng khối ngả từ tông mặt về tông đáy chừng này
const float CRYSTAL_CLOUD = 1.5;       // vệt sáng tối loang trong lòng, mỗi ô
const float CRYSTAL_FACETS = 1.1;      // mảnh vỡ lớn mỗi ô, mỗi chiều
const float CRYSTAL_CRACKS = 2.6;      // vết nứt nhỏ mỗi ô, mỗi chiều
const float CRYSTAL_CREASE = 0.02;     // bề rộng vết nứt lớn (ô); vết nhỏ mảnh hơn
const float CRYSTAL_TABLE = 0.15;      // viền trong cách mép chừng này (ô); phần ngoài là mép vát
const float CRYSTAL_SUGAR = 0.11;      // dải đường cát ở mép trên (ô), mỏng dần còn một nửa ở mép dưới
const float CRYSTAL_GRAIN = 17.0;      // hạt đường mỗi ô, mỗi chiều
const float CRYSTAL_FUZZ = 0.025;      // hạt đường lồi ra khỏi mép chừng này (ô)
const float CRYSTAL_TWINKLE = 0.45;    // sao nhấp nháy mỗi giây, mỗi ô
const float CRYSTAL_SWEEP = 2.8;       // giây giữa hai lần vệt sáng quét qua mặt bàn

float dist(vec2 c) {
	return texture(sdf, c / dims).r;
}

// Màu kẹo tại điểm c (đơn vị ô), d = dist(c).
vec3 candy_color(vec2 c, float d) {
	// sọc: 45 độ, chu kỳ 1 ô theo toạ độ ô nên khối cạnh nhau liền pha
	vec2 p = c - vec2(pad);
	float u = abs(fract(p.x + p.y + 0.25) - 0.5);
	float aa = 1.0 / cell_px;
	float band = 1.0 - smoothstep(0.25 - aa, 0.25 + aa, u);

	// gần mép trên, gần mép đáy (đo bằng SDF lệch dọc nên không có nếp gấp ở góc)
	float near_top = clamp(-dist(c - vec2(0.0, REACH_TOP)) / REACH_TOP, 0.0, 1.0);
	float near_bottom = clamp(-dist(c + vec2(0.0, REACH_BOTTOM)) / REACH_BOTTOM, 0.0, 1.0);

	vec3 top_col = mix(face.rgb, stripe.rgb, band * STRIPE_A);
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
	return body;
}

float crystal_hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

// Nhiễu trơn 0..1 (value noise), một nút mỗi đơn vị của p.
float crystal_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = crystal_hash(i);
	float b = crystal_hash(i + vec2(1.0, 0.0));
	float c = crystal_hash(i + vec2(0.0, 1.0));
	float e = crystal_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

// Mảnh vỡ Voronoi tại p (toạ độ ô), `freq` mảnh mỗi ô: x là độ sáng riêng của mảnh (0..1), y là khoảng cách tới
// vết nứt gần nhất (ô).
vec2 crystal_facet(vec2 p, float freq) {
	vec2 q = p * freq;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float f1 = 8.0;
	float f2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(crystal_hash(i + g), crystal_hash(i + g + 17.3)) * 0.8 + 0.1;
			float dd = length(g + o - f);
			if (dd < f1) {
				f2 = f1;
				f1 = dd;
				id = crystal_hash(i + g + 5.1);
			} else if (dd < f2) {
				f2 = dd;
			}
		}
	}
	return vec2(id, (f2 - f1) * 0.5 / freq);
}

// Hạt đường: mỗi ô lưới (`n` mỗi ô khối) có hạt tròn ở chỗ ngẫu nhiên với xác suất `density`.
// x là độ phủ của hạt, y là độ sáng trong hạt (sáng ở trên trái, tối ở dưới phải).
vec2 crystal_grain(vec2 p, float n, float density) {
	vec2 q = p * n;
	vec2 i = floor(q);
	vec2 v = fract(q) - (vec2(crystal_hash(i + 13.1), crystal_hash(i + 29.3)) * 0.5 + 0.25);
	float r = 0.26 + 0.16 * crystal_hash(i + 7.7);
	float aa = n / cell_px;
	float cover = (1.0 - smoothstep(r - aa, r + aa, length(v))) * step(crystal_hash(i + 41.7), density);
	return vec2(cover, clamp(0.55 - (v.x + v.y) / r * 0.5, 0.0, 1.0));
}

// Hạt đường lồi ra ngoài mép khối crystal: độ phủ thêm ngay ngoài mép (0..1), 0 với kẹo thường.
float crystal_fuzz(vec2 c, float d) {
	if (crystal < 0.5 || d >= 0.0 || d < -CRYSTAL_FUZZ) {
		return 0.0;
	}
	return crystal_grain(c - vec2(pad), CRYSTAL_GRAIN, 0.55).x;  // tập con của hạt ở mép trong crystal_color
}

// Sao bốn cánh nhấp nháy, mỗi ô một sao ở chỗ ngẫu nhiên; 0..1.
float crystal_twinkle(vec2 p) {
	vec2 cell_id = floor(p);
	float h = crystal_hash(cell_id + 3.7);
	vec2 at = vec2(0.22, 0.22) + vec2(crystal_hash(cell_id + 9.2), h) * 0.56;
	vec2 v = fract(p) - at;
	float beat = fract(TIME * CRYSTAL_TWINKLE * (0.7 + 0.6 * h) + h * 7.0);
	float on = pow(max(0.0, sin(beat * 3.14159)), 18.0);
	float rays = exp(-abs(v.x) * 70.0) * exp(-abs(v.y) * 11.0) + exp(-abs(v.y) * 70.0) * exp(-abs(v.x) * 11.0);
	return clamp((rays + exp(-dot(v, v) * 900.0)) * on, 0.0, 1.0);
}

// Màu crystal tại điểm c (đơn vị ô), d = dist(c). Dùng chung bốn tông của màu khối nên vẫn đọc được hướng đi.
vec3 crystal_color(vec2 c, float d) {
	vec2 p = c - vec2(pad);
	vec3 white = vec3(1.0);
	vec3 glow = mix(stripe.rgb, white, 0.3);
	// pháp tuyến ngoài của mép gần nhất (đạo hàm SDF): mép trên trái đón sáng, mép dưới phải khuất
	vec2 n = vec2(d - dist(c + vec2(CORNER_E, 0.0)), d - dist(c + vec2(0.0, CORNER_E))) / CORNER_E;
	float lit = clamp(dot(n, vec2(-0.45, -0.9)), 0.0, 1.0);
	float shaded = clamp(dot(n, vec2(0.4, 0.92)), 0.0, 1.0);

	// lòng khối: đậm hơn kẹo thường, sáng tối loang
	float cloud = crystal_noise(p * CRYSTAL_CLOUD + 3.1) * 0.6 + crystal_noise(p * CRYSTAL_CLOUD * 2.4 + 8.7) * 0.4;
	vec3 body = mix(face.rgb, deep.rgb, CRYSTAL_BODY_DEEP);
	body = mix(body, glow, smoothstep(0.45, 0.9, cloud) * 0.5);
	body = mix(body, deep.rgb, smoothstep(0.4, 0.1, cloud) * 0.5);
	// mảnh vỡ lệch sáng tối (pha về tông đáy hoặc tông sáng nên vẫn tươi màu), vết nứt trắng đứt quãng: lớn rõ, nhỏ mờ
	vec2 fc = crystal_facet(p, CRYSTAL_FACETS);
	body = fc.x < 0.5 ? mix(body, deep.rgb, (0.5 - fc.x) * 0.8) : mix(body, glow, (fc.x - 0.5) * 0.7);
	vec2 fine = crystal_facet(p + 4.3, CRYSTAL_CRACKS);
	float crack = (1.0 - smoothstep(CRYSTAL_CREASE * 0.3, CRYSTAL_CREASE, fc.y)) * smoothstep(0.25, 0.55, crystal_noise(p * 2.2 + 1.7));
	crack += (1.0 - smoothstep(CRYSTAL_CREASE * 0.15, CRYSTAL_CREASE * 0.6, fine.y)) * smoothstep(0.55, 0.8, crystal_noise(p * 2.8 + 5.3)) * 0.45;
	body = mix(body, mix(stripe.rgb, white, 0.75), clamp(crack, 0.0, 1.0) * 0.8);
	// ánh sáng xuyên qua khối dồn ra sát mép dưới phải
	float exit = (1.0 - smoothstep(CRYSTAL_TABLE, CRYSTAL_TABLE + 0.3, d)) * smoothstep(0.2, 0.8, shaded);
	body = mix(body, glow, exit * 0.6);
	// vệt sáng quét chéo theo chu kỳ
	float diag = p.x + p.y * 0.7;
	float sweep = 1.0 - smoothstep(0.0, 0.3, abs(diag - (fract(TIME / CRYSTAL_SWEEP) * 9.0 - 2.0)));
	body = mix(body, white, sweep * 0.32);

	// mép vát quanh viền trong: thuỷ tinh tròn, sáng ở trên trái, đậm ở dưới phải, vạch sáng sát đáy
	vec3 bevel = mix(face.rgb, deep.rgb, 0.55);
	bevel = mix(bevel, mix(stripe.rgb, white, 0.5), lit * 0.85);
	bevel = mix(bevel, deep.rgb * 0.78, shaded * 0.75);
	float rim = 1.0 - smoothstep(RIM_W * 0.5, RIM_W * 1.5, abs(d - RIM_AT));
	bevel = mix(bevel, glow, rim * shaded * 0.75);
	vec3 col = mix(bevel, body, smoothstep(CRYSTAL_TABLE - 0.03, CRYSTAL_TABLE + 0.005, d));
	// viền trong: vạch sáng mảnh quanh khối, rõ nhất ở dưới phải (ánh sáng xuyên ra)
	float inner = 1.0 - smoothstep(0.008, 0.03, abs(d - CRYSTAL_TABLE));
	col = mix(col, mix(stripe.rgb, white, 0.6), inner * (0.3 + 0.5 * shaded + 0.2 * lit));

	// đường cát: dải hạt dày quanh mép (dày ở trên, mỏng ở dưới), phủ mờ như sương; hạt thưa khắp mặt
	float band_w = CRYSTAL_SUGAR * mix(0.5, 1.0, lit);
	float band = 1.0 - smoothstep(band_w * 0.45, band_w, d);
	col = mix(col, mix(stripe.rgb, white, 0.55), band * 0.3);
	float density = band * mix(0.6, 0.92, lit) + 0.02;
	vec2 g = crystal_grain(p, CRYSTAL_GRAIN, density);
	vec2 g2 = crystal_grain(p + 0.37, CRYSTAL_GRAIN * 2.1, band * 0.8 + 0.03);
	vec3 sugar_dark = mix(face.rgb, white, 0.35);
	col = mix(col, mix(sugar_dark, white, g.y), g.x * 0.95);
	col = mix(col, mix(sugar_dark, white, g2.y), g2.x * 0.8);
	return mix(col, white, crystal_twinkle(p) * smoothstep(CRYSTAL_TABLE, CRYSTAL_TABLE + 0.08, d));
}

// Màu thân khối theo chất liệu: crystal hoặc kẹo sọc.
vec3 body_color(vec2 c, float d) {
	return crystal > 0.5 ? crystal_color(c, d) : candy_color(c, d);
}
