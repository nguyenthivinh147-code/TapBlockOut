shader_type canvas_item;
// Khối pudding: tô theo khoảng cách tới mép (texture R = signed distance, đơn vị ô, dương là bên trong).
// Cấu trúc theo concept art/concepts/concept_candy_board_v1.png: viền gel sáng mỏng ở trên và hai bên,
// dải đáy dày nhạt dần về mép kèm vạch sáng sát mép, lòng khối đậm màu có bóng tối ở đáy lòng.

uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec2 dims = vec2(1.0);  // cỡ vùng texture, đơn vị ô
uniform float cell_px = 64.0;

const float RIM = 0.042;     // bề dày viền sáng ở trên và hai bên
const float BAND = 0.17;     // phần dày thêm của dải đáy
const float SHADOW_DY = 0.04;

float dist(vec2 c) {
	return texture(sdf, c / dims).r;
}

float well_raw(vec2 c) {
	return min(dist(c), dist(c + vec2(0.0, BAND))) - RIM;
}

float well(vec2 c) {
	return smoothstep(0.0, 0.09, well_raw(c));
}

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0);

	// bóng đổ mềm lệch xuống dưới
	float ds = dist(c - vec2(0.0, SHADOW_DY));
	float shadow = smoothstep(-0.035, 0.03, ds) * 0.30;

	vec3 col = base_color.rgb;
	float w = well(c);

	// lòng khối: đậm màu, tối dần ở mép dưới của lòng, sáng hơn ở mép trên và hai bên
	float w_bottom = w * (1.0 - well(c + vec2(0.0, 0.07)));
	float w_top = w * (1.0 - well(c - vec2(0.0, 0.10)));
	float w_side = w * (1.0 - max(well(c - vec2(0.09, 0.0)), well(c + vec2(0.09, 0.0))));
	vec3 well_col = col;
	well_col = mix(well_col, mix(col, vec3(1.0), 0.28), w_top * 0.65);
	well_col = mix(well_col, mix(col, vec3(1.0), 0.20), w_side * 0.45);
	float w_bottom_wide = w * (1.0 - well(c + vec2(0.0, 0.16)));
	well_col *= 1.0 - 0.07 * w_bottom - 0.08 * w_bottom_wide;

	// viền gel và dải đáy: càng gần mép càng sáng, có vạch sáng sát mép
	float depth = 1.0 - smoothstep(0.0, RIM + BAND, d);
	vec3 gel = mix(col, vec3(1.0), 0.12 + 0.30 * depth * depth);
	float facing_bottom = smoothstep(0.0, 0.02, d - dist(c + vec2(0.0, 0.02)));
	float facing_top = smoothstep(0.0, 0.02, d - dist(c - vec2(0.0, 0.02)));
	// vạch sáng nằm sát mép (trên và hai bên) hoặc lùi vào một chút (đáy, nơi có thành nâu bên ngoài)
	float lip_in = mix(0.0, 0.016, facing_bottom);
	float edge = smoothstep(lip_in, lip_in + 0.012, d) * (1.0 - smoothstep(lip_in + 0.014, lip_in + 0.05, d));
	gel = mix(gel, vec3(1.0), edge * (0.32 + 0.30 * facing_bottom + 0.30 * facing_top));
	// thành đáy: vạch nâu ấm sát mép dưới
	float wall = facing_bottom * (1.0 - smoothstep(0.010, 0.020, d));
	gel = mix(gel, col * vec3(0.62, 0.58, 0.62), wall * 0.85);
	vec3 body = mix(gel, well_col, w);

	float alpha = a + shadow * (1.0 - a);
	vec3 rgb = (body * a + vec3(0.05, 0.04, 0.10) * shadow * (1.0 - a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
