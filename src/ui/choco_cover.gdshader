shader_type canvas_item;
// Melted milk chocolate over one exit bar (design.md section 4 "Socola", concept art/concepts/concept_choco_v1.png A).
// Drawn in the bar's canonical frame (choco_cover.gd): x runs along the bar, y = 0 is the bar's outer edge and grows
// toward the board. Body: a rounded slab from `top_px` down `body_h`; drips: capsules hanging from the slab with a round
// bulb at the end, melted into the slab with a smooth union. Shading treats the signed distance as a rounded profile:
// steep near the edge, flat inside, lit from the screen's top left (`light_dir` already turned into this frame).

uniform vec2 rect_px = vec2(100.0, 40.0);
uniform vec2 origin_px = vec2(0.0);  // canonical point at the rect's top left
uniform float bar_len = 100.0;
uniform float top_px = 4.0;
uniform float body_h = 12.0;
uniform float inset = 4.0;  // the slab's ends stay this far inside the bar's ends
uniform int drip_count = 0;
uniform vec4 drips[24];  // x, stem half width, length below the slab, bulb radius
uniform vec3 light_dir = vec3(-0.45, -0.7, 0.55);
uniform vec2 shadow_off = vec2(0.0, 3.0);
uniform float bevel = 6.0;  // px over which the edge rounds off into the flat top
uniform vec4 col_body : source_color = vec4(0.482, 0.29, 0.165, 1.0);
uniform vec4 col_deep : source_color = vec4(0.27, 0.149, 0.071, 1.0);
uniform vec4 col_edge : source_color = vec4(0.2, 0.1, 0.04, 1.0);
uniform vec4 col_shine : source_color = vec4(0.85, 0.66, 0.5, 1.0);

const float SHADOW_A = 0.28;
const float RIM = 1.6;  // px of darker rim inside the edge
const float SPEC_POW = 28.0;
const float SPEC = 0.75;
const float GLOSS = 0.42;  // light streak along the slab

float sd_round_box(vec2 p, vec2 c, vec2 half_size, float r) {
	vec2 q = abs(p - c) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Vertical capsule from `a` down `len` px, radius `r`.
float sd_stem(vec2 p, vec2 a, float len, float r) {
	p -= a;
	p.y -= clamp(p.y, 0.0, len);
	return length(p) - r;
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float sdf(vec2 p) {
	float r = body_h * 0.5;
	float bottom = top_px + body_h;
	float d = sd_round_box(p, vec2(bar_len * 0.5, top_px + r), vec2(max(bar_len * 0.5 - inset, r), r), r);
	for (int i = 0; i < 24; i++) {
		if (i >= drip_count) {
			break;
		}
		vec4 dr = drips[i];
		float tip = bottom + dr.z - dr.w;
		float stem = sd_stem(p, vec2(dr.x, bottom - dr.y * 2.0), max(tip - (bottom - dr.y * 2.0), 0.0), dr.y);
		float bulb = length(p - vec2(dr.x, tip)) - dr.w;
		float drip = smin(stem, bulb, dr.y * 0.8);
		d = smin(d, drip, dr.y * 1.3);
	}
	return d;
}

void fragment() {
	vec2 p = origin_px + UV * rect_px;
	float d = sdf(p);
	float px = max(fwidth(d), 0.0001);
	float a = clamp(0.5 - d / px, 0.0, 1.0);
	float sh = SHADOW_A * clamp(0.5 - (sdf(p - shadow_off) - 1.5) / 3.0, 0.0, 1.0);
	if (a <= 0.0 && sh <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		float e = 0.75;
		vec2 g = vec2(sdf(p + vec2(e, 0.0)) - sdf(p - vec2(e, 0.0)), sdf(p + vec2(0.0, e)) - sdf(p - vec2(0.0, e)));
		g = length(g) > 0.0001 ? normalize(g) : vec2(0.0);
		float t = clamp(-d / bevel, 0.0, 1.0);
		float slope = 1.0 - t * t;
		vec3 n = normalize(vec3(g * slope * 1.8, 1.0));
		vec3 l = normalize(light_dir);
		float lambert = clamp(dot(n, l), 0.0, 1.0);
		vec3 col = mix(col_deep.rgb, col_body.rgb, 0.3 + 0.7 * lambert);
		vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
		float spec = pow(max(dot(n, h), 0.0), SPEC_POW) * SPEC * slope;
		col = mix(col, col_shine.rgb, spec);
		col += vec3(spec * 0.35);
		// soft streak along the slab, a third of the way in from the bar side
		float band = top_px + body_h * 0.32;
		float streak = (1.0 - smoothstep(0.0, body_h * 0.13, abs(p.y - band))) * step(-body_h * 0.3, -d);
		streak *= smoothstep(inset, inset + body_h * 1.5, p.x) * smoothstep(inset, inset + body_h * 1.5, bar_len - p.x);
		col = mix(col, col_shine.rgb, streak * GLOSS);
		col = mix(col, col_edge.rgb, (1.0 - smoothstep(0.0, RIM, -d)) * 0.75);
		float out_a = a + sh * (1.0 - a);
		COLOR = vec4(out_a > 0.0 ? col * a / out_a : col, out_a);
	}
}
