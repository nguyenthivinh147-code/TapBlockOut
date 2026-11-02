shader_type canvas_item;
// Thân khối kẹo: chất liệu chung từ `candy_body.gdshaderinc`, thêm lớp phủ, nháy sáng và bóng đổ.

#include "res://src/ui/candy_body.gdshaderinc"

uniform vec4 overlay = vec4(0.0);  // lớp phủ trong hình khối (băng)
uniform float flash = 0.0;         // nháy sáng trong hình khối (gợi ý, nảy)
uniform float body_a = 1.0;        // 0: chỉ vẽ bóng đổ
uniform float shadow_a = 0.0;      // độ đậm bóng đổ

const float SHADOW_DY = 0.09;
const float SHADOW_BLUR = 0.13;
const vec3 SHADOW_COL = vec3(0.09, 0.08, 0.26);

void fragment() {
	vec2 c = UV * dims;
	float d = dist(c);
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0) * body_a;

	// bóng đổ mềm lệch xuống dưới, ám chàm
	float ds = dist(c - vec2(0.0, SHADOW_DY));
	float shadow = smoothstep(-SHADOW_BLUR, 0.02, ds) * shadow_a;
	vec3 col = SHADOW_COL;

	if (a > 0.0) {
		col = candy_color(c, d);
		col = mix(col, overlay.rgb, overlay.a);
		col = mix(col, vec3(1.0), flash * 0.28);
	}

	float alpha = a + shadow * (1.0 - a);
	COLOR = vec4((col * a + SHADOW_COL * shadow * (1.0 - a)) / max(alpha, 0.0001), alpha);
}
