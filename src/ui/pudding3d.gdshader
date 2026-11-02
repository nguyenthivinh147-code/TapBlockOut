shader_type canvas_item;
// Khối pudding 3D (giả khối bằng shader): SDF của hình khối -> chiều cao mặt phồng -> pháp tuyến -> ánh sáng.
// Mặt trên phồng như viên gel đùn, có thành đùn ở đáy, sáng xuyên ở mép mỏng, vệt phản chiếu cửa sổ góc trên trái.
// Cùng uniform với pudding.gdshader nên đổi qua lại bằng Pudding.STYLE_3D.

uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec2 dims = vec2(1.0);  // cỡ vùng texture, đơn vị ô
uniform float cell_px = 64.0;

const float BEVEL = 0.40;      // độ rộng đoạn mặt phồng từ mép vào (ô)
const float FACE_UP = 0.03;   // mặt trên nhích lên (ô)
const float WALL = 0.09;      // độ dày thành đùn lộ ra ở đáy (ô)
const float SHADOW_DY = 0.05;
const vec3 KEY_DIR = vec3(-0.45, -0.55, 0.70);

float dist(vec2 c) {
	return texture(sdf, c / dims).r;
}

// khoảng cách có dấu của mặt trên
float face_d(vec2 c) {
	return dist(c + vec2(0.0, FACE_UP));
}

// silhouette của cả khối (mặt trên + thành đùn), lấy max theo vài mẫu quét xuống dưới
float body_d(vec2 c) {
	float m = face_d(c);
	m = max(m, dist(c - vec2(0.0, WALL * 0.33)));
	m = max(m, dist(c - vec2(0.0, WALL * 0.66)));
	m = max(m, dist(c - vec2(0.0, WALL)));
	return m;
}

void fragment() {
	vec2 c = UV * dims;
	vec3 col = base_color.rgb;
	float px = 1.0 / cell_px;

	float db = body_d(c);
	float a_body = clamp(db * cell_px + 0.5, 0.0, 1.0);
	float df = face_d(c);
	float a_face = clamp(df * cell_px + 0.5, 0.0, 1.0);

	// bóng đổ mềm phía dưới
	float ds = dist(c - vec2(0.0, WALL + SHADOW_DY));
	float shadow = smoothstep(-0.05, 0.04, ds) * 0.30;

	// thành đùn: tối và bão hoà hơn, sáng nhẹ ở sát mép dưới như gel dày
	float wall_t = clamp((db - df) / WALL, 0.0, 1.0);
	vec3 wall_col = col * vec3(0.62, 0.56, 0.70);
	wall_col = mix(wall_col, col * vec3(0.78, 0.72, 0.84), smoothstep(0.0, 0.6, 1.0 - wall_t));
	float wall_edge = smoothstep(0.0, 0.03, db) * (1.0 - smoothstep(0.03, 0.07, db));
	wall_col = mix(wall_col, mix(col, vec3(1.0), 0.35), wall_edge * 0.35);

	// mặt trên: pháp tuyến từ SDF (profile quarter-circle)
	float e = 0.045;
	vec2 g = vec2(face_d(c + vec2(e, 0.0)) - face_d(c - vec2(e, 0.0)),
				  face_d(c + vec2(0.0, e)) - face_d(c - vec2(0.0, e)));
	g = length(g) > 1e-5 ? normalize(g) : vec2(0.0);
	float x = clamp(df / BEVEL, 0.0, 1.0);
	float tilt = (1.0 - x) * 0.96;
	vec3 n = normalize(vec3(-g * tilt, sqrt(max(1.0 - tilt * tilt, 0.02))));

	vec3 L = normalize(KEY_DIR);
	float diff = dot(n, L) * 0.5 + 0.5;
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float nh = max(dot(n, H), 0.0);
	float spec = pow(nh, 70.0) * 1.0 + pow(nh, 12.0) * 0.28;

	// xuyên sáng: mép mỏng sáng và nhạt hơn, lòng dày đậm màu
	float thin = 1.0 - x;
	vec3 deep = col * vec3(0.90, 0.88, 0.95);
	vec3 lit = mix(deep, mix(col, vec3(1.0), 0.30), thin * thin);
	vec3 face = lit * mix(0.60, 1.16, diff);

	// ánh sáng phản từ đáy phải (gel trong mờ)
	vec3 L2 = normalize(vec3(0.5, 0.6, 0.35));
	float back = pow(max(dot(n, L2), 0.0), 2.0) * thin;
	face += col * 0.16 * back;

	// viền sáng Fresnel mảnh
	float fres = pow(1.0 - n.z, 3.0);
	face = mix(face, vec3(1.0), fres * 0.22);
	face += vec3(1.0) * spec;

	// vạch sáng mảnh sát mép mặt trên (gel bóng)
	float lip = smoothstep(0.0, 0.01, df) * (1.0 - smoothstep(0.012, 0.035, df));
	float top_facing = smoothstep(-0.2, 0.6, dot(-g, normalize(KEY_DIR.xy)));
	face = mix(face, vec3(1.0), lip * (0.18 + 0.30 * top_facing));

	vec3 body = mix(wall_col, face, a_face);
	float alpha = a_body + shadow * (1.0 - a_body);
	vec3 rgb = (body * a_body + vec3(0.05, 0.04, 0.10) * shadow * (1.0 - a_body)) / max(alpha, 0.0001);
	COLOR = vec4(clamp(rgb, 0.0, 1.0), alpha);
}
