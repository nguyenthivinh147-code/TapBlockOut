shader_type canvas_item;
// Praise caption (praise_fx.gd): the white text face gets a top-to-bottom candy gradient, a flash toward white and a
// slanted light band sweeping across. The outline and shadow (any non-white draw of the Label) are left as they are,
// so the face is told apart by its white vertex color; the Label's modulate must only change alpha.

uniform vec2 box_size = vec2(100.0, 100.0);
uniform vec4 top_color : source_color = vec4(1.0, 0.97, 0.69, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
// Gradient runs between these shares of the box height (the glyphs fill only the middle of a Label's line box).
uniform float grad_from = 0.25;
uniform float grad_to = 0.8;
// 0..1: mix of the face toward white.
uniform float flash = 0.0;
// 0 -> 1: the band enters at the left edge and leaves past the right one; < 0 draws no band.
uniform float shine = -1.0;
uniform float shine_width = 0.22;
uniform float shine_slant = 0.45;

varying vec2 local_pos;
varying vec4 vcolor;

void vertex() {
	local_pos = VERTEX;
	vcolor = COLOR;
}

void fragment() {
	vec4 c = COLOR;
	if (min(vcolor.r, min(vcolor.g, vcolor.b)) > 0.9) {
		float k = clamp((local_pos.y / box_size.y - grad_from) / (grad_to - grad_from), 0.0, 1.0);
		vec3 g = k < 0.5 ? mix(top_color.rgb, mid_color.rgb, k * 2.0) : mix(mid_color.rgb, bottom_color.rgb, k * 2.0 - 1.0);
		g = mix(g, vec3(1.0), flash);
		if (shine >= 0.0) {
			float w = shine_width * box_size.y;
			float reach = w + shine_slant * box_size.y * 0.5;
			float center = mix(-reach, box_size.x + reach, shine);
			float d = abs(local_pos.x + (local_pos.y - box_size.y * 0.5) * shine_slant - center);
			g = mix(g, vec3(1.0), (1.0 - smoothstep(w * 0.3, w, d)) * 0.85);
		}
		c.rgb = g;
	}
	COLOR = c;
}
