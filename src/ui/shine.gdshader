shader_type canvas_item;
// Light band sweeping across a UI image (UiMotion.SHINE writes progress and box_size): a slanted "/" stripe, lighter
// in the middle, added on top of the drawing only where it is opaque. progress < 0 draws the image as it is.

uniform vec2 box_size = vec2(100.0, 100.0);
// 0 -> 1: the band enters at the left edge and leaves past the right one.
uniform float progress = -1.0;
// Half width of the band, share of the box height; the core is solid, the rest fades out.
uniform float width = 0.32;
uniform float core = 0.25;
// Horizontal shift per pixel of height (0.5: leans about 27 degrees).
uniform float slant = 0.5;
uniform float strength = 0.5;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	if (progress >= 0.0) {
		float w = width * box_size.y;
		float reach = w + slant * box_size.y * 0.5;
		float center = mix(-reach, box_size.x + reach, progress);
		float d = abs(local_pos.x + (local_pos.y - box_size.y * 0.5) * slant - center);
		float band = 1.0 - smoothstep(w * core, w, d);
		c.rgb += band * strength * c.a;
	}
	COLOR = c;
}
