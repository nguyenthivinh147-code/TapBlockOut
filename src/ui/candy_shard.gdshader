shader_type canvas_item;
// Mảnh kẹo vỡ: đúng chất liệu của khối (`candy_body.gdshaderinc`), thêm mặt gãy có bề dày.
// Màu đỉnh: r 0 ở rìa mảnh, 1 ở tâm mảnh; g loé khi mảnh xoay; b vết nứt loé trắng lúc vừa vỡ; a độ đậm.

#include "res://src/ui/candy_body.gdshaderinc"

const float GLOSS_AT = 0.14;   // vạch bóng ở mép trên, cách mép như trên khối
const float GLOSS_A = 0.7;
const float EDGE_LIGHT = 0.85;
const float EDGE_DARK = 0.32;
const float GLINT_A = 0.55;

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float edge = COLOR.r;
	// lúc vừa nứt các mảnh còn khít nhau nên không làm mờ rìa, vết nứt phải sáng chứ không hở nền
	float rim_a = mix(smoothstep(0.0, fwidth(edge) * 1.5 + 0.001, edge), 1.0, smoothstep(0.0, 0.2, COLOR.b));
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0) * rim_a;
	vec3 col = candy_color(c, d);

	// vạch bóng của khối còn nằm trên mảnh
	float up = (d - dist(c - vec2(0.0, CORNER_E))) / CORNER_E;
	float gloss = (1.0 - smoothstep(0.012, 0.04, abs(d - GLOSS_AT))) * smoothstep(0.6, 0.95, up);
	col = mix(col, vec3(1.0), gloss * GLOSS_A);

	// mặt gãy: rìa sáng, ngay trong rìa tối nhẹ, nhìn như miếng kẹo trong có bề dày
	float light = 1.0 - smoothstep(0.0, 0.26, edge);
	float dark = smoothstep(0.1, 0.28, edge) * (1.0 - smoothstep(0.28, 0.6, edge));
	col = mix(col, deep.rgb, dark * EDGE_DARK);
	col = mix(col, mix(stripe.rgb, vec3(1.0), 0.55), light * EDGE_LIGHT);

	col = mix(col, vec3(1.0), COLOR.g * GLINT_A);
	col = mix(col, vec3(1.0), smoothstep(0.0, 0.35, COLOR.b) * (0.12 + 0.88 * (1.0 - smoothstep(0.0, 0.16, edge))));
	COLOR = vec4(col, a * COLOR.a);
}
