shader_type canvas_item;
// Mảnh kẹo: đúng chất liệu của khối (`candy_body.gdshaderinc`, kẹo sọc hoặc crystal), thêm mặt gãy có bề dày.
// Mặt trên, màu đỉnh: r 0 ở rìa mảnh, 1 ở tâm mảnh; g loé khi mảnh xoay; b bề rộng viền mặt gãy (1 là mảnh thường); a độ đậm.
// Mặt bên (UV.x lệch SIDE_FLAG): r 0 ở mép giáp mặt trên, 1 ở mép đáy; g độ tối theo hướng mặt; a như trên.

#include "res://src/ui/candy_body.gdshaderinc"

const float GLOSS_AT = 0.14;   // vạch bóng ở mép trên, cách mép như trên khối
const float GLOSS_A = 0.7;
const float EDGE_LIGHT = 0.85;
const float EDGE_DARK = 0.32;
const float GLINT_A = 0.55;
const float SIDE_FLAG = 4.0;   // khớp SIDE_UV trong candy_shards.gd
const float SIDE_LIP = 0.55;   // vạch sáng ở mép mặt bên giáp mặt trên
const float SIDE_FLOOR = 0.78; // mép đáy mặt bên tối còn chừng này
const float CRYSTAL_GLINT_A = 0.95;  // mảnh crystal loé gần trắng hẳn khi xoay
const float CRYSTAL_SIDE_LIGHT = 0.35;  // mặt bên mảnh crystal trong, sáng hơn kẹo

vec3 side_color(float k, float shade, vec2 c) {
	// thân kẹo nhìn ngang: tông hai bên ngả về tông đáy ở mặt quay khỏi ánh sáng, sọc mờ xuyên qua
	vec2 p = c - vec2(pad);
	float band = 1.0 - smoothstep(0.2, 0.3, abs(fract(p.x + p.y + 0.25) - 0.5));
	vec3 col = mix(side.rgb, deep.rgb, shade);
	col = mix(col, stripe.rgb, crystal > 0.5 ? CRYSTAL_SIDE_LIGHT : band * STRIPE_IN_BEVEL);
	col *= mix(1.0, SIDE_FLOOR, k);
	return mix(col, mix(stripe.rgb, vec3(1.0), 0.5), (1.0 - smoothstep(0.0, 0.3, k)) * SIDE_LIP);
}

void fragment() {
	bool is_side = UV.x > SIDE_FLAG * 0.5;
	vec2 c = (is_side ? UV - vec2(SIDE_FLAG, 0.0) : UV) * dims;
	float d = dist(c);
	vec3 col;
	float a;
	if (is_side) {
		// theo góc bo của khối, nhưng mép thẳng (d ~ 0) vẫn đặc
		a = clamp(d * cell_px + 1.5, 0.0, 1.0);
		col = side_color(COLOR.r, COLOR.g, c);
	} else {
		float edge = COLOR.r;
		float rim_a = smoothstep(0.0, fwidth(edge) * 1.5 + 0.001, edge);
		a = clamp(d * cell_px + 0.5, 0.0, 1.0) * rim_a;
		col = body_color(c, d);

		// vạch bóng của khối còn nằm trên mảnh (crystal có vệt bóng riêng trong crystal_color)
		float up = (d - dist(c - vec2(0.0, CORNER_E))) / CORNER_E;
		float gloss = (1.0 - smoothstep(0.012, 0.04, abs(d - GLOSS_AT))) * smoothstep(0.6, 0.95, up) * (1.0 - crystal);
		col = mix(col, vec3(1.0), gloss * GLOSS_A);

		// mặt gãy: rìa sáng, ngay trong rìa tối nhẹ, nối với mặt bên bên dưới
		float rim = edge / max(COLOR.b, 0.05);
		float light = 1.0 - smoothstep(0.0, 0.26, rim);
		float dark = smoothstep(0.1, 0.28, rim) * (1.0 - smoothstep(0.28, 0.6, rim));
		col = mix(col, deep.rgb, dark * EDGE_DARK);
		col = mix(col, mix(stripe.rgb, vec3(1.0), 0.55), light * EDGE_LIGHT);

		col = mix(col, vec3(1.0), COLOR.g * (crystal > 0.5 ? CRYSTAL_GLINT_A : GLINT_A));
	}
	COLOR = vec4(col, a * COLOR.a);
}
