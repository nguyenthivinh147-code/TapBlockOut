shader_type canvas_item;
// 3D pudding block, measured from art/concepts/concept_pudding_board.png.
// Texture channels (cell units, positive inside): R silhouette distance, G well distance, BA well gradient.
// A translucent cushion: pale rim, soft bevel, recessed well lit from the top left, a thick glowing bottom band,
// a thin bright lip and a dark side wall under it. Output is linear in the palette colours.

const int MAX_TL = 6;
const int MAX_CC = 4;

uniform sampler2D sdf : filter_linear, repeat_disable;
uniform vec2 dims = vec2(1.0);  // texture area, in cells
uniform float cell_px = 64.0;
uniform vec2 tl_corners[MAX_TL];  // convex top-left corners, in cells
uniform int tl_count = 0;
uniform vec2 cc_corners[MAX_CC];  // concave corners open to the top left, in cells
uniform int cc_count = 0;

uniform vec3 c_mid : source_color;
uniform vec3 c_deep : source_color;
uniform vec3 c_lit : source_color;
uniform vec3 c_top : source_color;
uniform vec3 c_left : source_color;
uniform vec3 c_right : source_color;
uniform vec3 c_band : source_color;
uniform vec3 c_glow : source_color;
uniform vec3 c_lip : source_color;
uniform vec3 c_wall : source_color;
uniform vec3 c_rim : source_color;
uniform vec3 c_spec : source_color;

const float GAP = 0.005;  // half of the gap between blocks: 1% of a cell in total
const float WALL = 0.04;  // visible height of the side wall
const float BAND = 0.21;  // bottom band thickness, well edge to lip
const float SHADOW_DY = 0.03;
const vec2 SPEC_SHIFT = vec2(0.02, 0.03);  // highlights follow the well toward the top left

const vec2 LIT_DIR = vec2(0.5, 0.87);
const vec2 SHADE_DIR = vec2(-0.82, -0.57);
const float LIT_RANGE = 0.36;
const float SHADE_RANGE = 0.36;

float ellipse(vec2 p, vec2 center, vec2 radius, float aa) {
	float k = length((p - center) / radius);
	return 1.0 - smoothstep(1.0 - aa, 1.0 + aa, k);
}

float gauss(float x, float sigma) {
	return exp(-(x * x) / (sigma * sigma));
}

// Highlights of one convex top-left corner; `p` is measured from the cell corner.
float corner_spec(vec2 corner_p, float aa) {
	vec2 p = corner_p + SPEC_SHIFT;
	// crescent: inside the outer circle, outside the inner one, crisp outside, fading inward
	float outer = 0.155 - length(p - vec2(0.293, 0.227));
	float inner = length(p - vec2(0.659, 0.977)) - 0.907;
	float body = smoothstep(-aa, aa, outer) * smoothstep(-0.006, 0.016, inner);
	float crescent = body * (0.70 + 0.30 * smoothstep(0.0, 0.04, inner) * smoothstep(0.0, 0.03, outer));
	float dash = ellipse(p, vec2(0.128, 0.268), vec2(0.012, 0.022), 0.35);
	float streak = 0.52 * gauss((p.x - 0.60) / 0.17, 1.0) * gauss((p.y - 0.122) / 0.030, 1.0);
	return max(max(crescent, dash * 0.9), streak);
}

void fragment() {
	vec2 c = UV * dims;
	vec4 f = texture(sdf, UV);
	float d = f.r - GAP;
	float w = f.g;
	vec2 n = f.ba;
	float d_wall = texture(sdf, (c + vec2(0.0, WALL)) / dims).r - GAP;
	float face = min(d, d_wall);

	// recessed well: lit from the top left, in shade at the bottom right
	float near = clamp(1.0 - w / LIT_RANGE, 0.0, 1.0);
	float lit = near * near * clamp(dot(n, LIT_DIR), 0.0, 1.0);
	float near_s = clamp(1.0 - w / SHADE_RANGE, 0.0, 1.0);
	float shade = near_s * near_s * clamp(dot(n, SHADE_DIR) * 1.15, 0.0, 1.0);
	vec3 well_col = mix(mix(c_mid, c_lit, lit), c_deep, shade);

	// bevel around the well: the colour depends on which way the slope faces; the bottom band glows toward its lip
	float t = clamp(-w / BAND, 0.0, 1.0);
	vec3 band_col = mix(c_band, c_glow, t * t);
	float w_top = max(n.y, 0.0);
	float w_bottom = max(-n.y, 0.0);
	float w_left = max(n.x, 0.0);
	float w_right = max(-n.x, 0.0);
	float w_sum = w_top + w_bottom + w_left + w_right + 0.001;
	vec3 bevel = (c_top * w_top + band_col * w_bottom + c_left * w_left + c_right * w_right) / w_sum;

	vec3 col = mix(bevel, well_col, smoothstep(-0.016, 0.016, w));

	// bright line just inside the left edge of the well; the top edge only gets the soft glow
	float ridge = gauss(w - 0.012, 0.016) * clamp(n.x, 0.0, 1.0);
	col = mix(col, c_lit, ridge * 0.75);

	// thin light crease just outside the shaded edge of the well
	float crease = gauss(w + 0.02, 0.012) * clamp(dot(n, SHADE_DIR), 0.0, 1.0);
	col = mix(col, c_glow, crease * 0.45);

	// pale rim on the top and the sides
	float rim_top = (1.0 - smoothstep(0.018, 0.04, face)) * w_top / w_sum;
	float rim_side = (1.0 - smoothstep(0.008, 0.02, face)) * (w_left + 0.5 * w_right) / w_sum;
	col = mix(col, c_rim, clamp(rim_top + 0.45 * rim_side, 0.0, 1.0));
	float turn = (1.0 - smoothstep(0.0, 0.028, d)) * w_right / w_sum;
	col = mix(col, c_wall, turn * 0.85);

	// lip and wall under the band
	float faces_down = smoothstep(0.0, 0.02, d - d_wall);
	float lip = gauss(face - 0.012, 0.012) * faces_down;
	col = mix(col, c_lip, lip);
	col = mix(c_wall, col, smoothstep(-0.006, 0.006, face));

	// speculars
	float aa = 1.2 / cell_px;
	float spec = 0.0;
	for (int i = 0; i < tl_count; i++) {
		spec = max(spec, corner_spec(c - tl_corners[i], aa));
	}
	for (int i = 0; i < cc_count; i++) {
		spec = max(spec, ellipse(c - cc_corners[i], vec2(0.035, 0.035), vec2(0.018, 0.022), 0.35) * 0.9);
	}
	spec *= smoothstep(0.0, 0.02, face);
	col = mix(col, c_spec, spec);

	// antialiased silhouette over a soft contact shadow
	float a = clamp(d * cell_px + 0.5, 0.0, 1.0);
	float ds = texture(sdf, (c - vec2(0.0, SHADOW_DY)) / dims).r - GAP;
	// tight at the sides, so it does not fall on a neighbour a hair away
	float shadow = smoothstep(-0.02, 0.02, ds) * 0.42;
	float alpha = a + shadow * (1.0 - a);
	vec3 rgb = (col * a + vec3(0.05, 0.04, 0.10) * shadow * (1.0 - a)) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
