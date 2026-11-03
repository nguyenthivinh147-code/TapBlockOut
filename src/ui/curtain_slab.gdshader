shader_type canvas_item;
// One jelly slab of the level curtain (level_curtain.gd): a rounded rect inset by `margin` inside the node rect,
// vertical body gradient, darker bevel on the sides (lighter on top and bottom), a thin gloss line near the top
// and a soft drop shadow in the margin. All lengths are in pixels of the node rect.

uniform vec2 rect_size = vec2(400.0, 800.0);
uniform float margin = 16.0;
uniform float radius = 36.0;
uniform float rim = 14.0;
uniform vec4 top_color : source_color = vec4(0.98, 0.83, 0.87, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.96, 0.66, 0.81, 1.0);
uniform vec4 rim_color : source_color = vec4(0.91, 0.54, 0.76, 1.0);
uniform vec4 edge_color : source_color = vec4(0.79, 0.44, 0.71, 1.0);
uniform vec4 gloss_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform float gloss_y = 6.0;
uniform float gloss_h = 7.0;
uniform float gloss_inset = 12.0;
uniform vec4 shadow_color : source_color = vec4(0.54, 0.37, 0.78, 0.5);
uniform vec2 shadow_offset = vec2(4.0, 0.0);
uniform float shadow_blur = 8.0;

float sd_round_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 hs = c - vec2(margin);
	vec2 lp = p - c;
	float d = sd_round_box(lp, hs, radius);
	float depth = -d;

	// Side weight from the outward normal: 1 on the left and right edges, 0 on the top and bottom.
	vec2 q = abs(lp) - hs + radius;
	vec2 n = (q.x > 0.0 && q.y > 0.0) ? normalize(q) : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	float bevel = mix(0.35, 1.0, n.x);

	float ty = clamp((p.y - margin) / (hs.y * 2.0), 0.0, 1.0);
	vec3 col = mix(top_color.rgb, bottom_color.rgb, ty);
	col = mix(col, rim_color.rgb, (1.0 - smoothstep(0.0, rim, depth)) * bevel);
	col = mix(col, edge_color.rgb, (1.0 - smoothstep(0.0, rim * 0.3, depth)) * bevel);

	float gy = p.y - margin;
	float g = smoothstep(gloss_y, gloss_y + gloss_h * 0.4, gy) * (1.0 - smoothstep(gloss_y + gloss_h * 0.6, gloss_y + gloss_h, gy));
	float gl = margin + gloss_inset;
	float gr = rect_size.x - margin - gloss_inset;
	g *= smoothstep(gl, gl + gloss_h * 4.0, p.x) * (1.0 - smoothstep(gr - gloss_h * 4.0, gr, p.x));
	col = mix(col, gloss_color.rgb, g * gloss_color.a);

	float a = clamp(0.5 - d, 0.0, 1.0);
	float ds = sd_round_box(lp - shadow_offset, hs, radius);
	float sa = (1.0 - smoothstep(-shadow_blur * 0.5, shadow_blur, ds)) * shadow_color.a * (1.0 - a);
	float out_a = a + sa;
	COLOR = vec4((col * a + shadow_color.rgb * sa) / max(out_a, 0.0001), out_a);
}
