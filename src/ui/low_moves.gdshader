shader_type canvas_item;
// Red warning vignette along the screen edge for the last move. `amount` fades the whole effect in and out,
// `breath` (0..1, driven by level.gd in step with the MOVES chip pulse) swells it a little.

uniform vec4 tint : source_color = vec4(0.95, 0.1, 0.12, 1.0);
uniform vec2 rect_size = vec2(886.0, 1920.0);
uniform float reach = 150.0;  // px from the edge where the glow dies out
uniform float max_alpha = 0.5;
uniform float amount = 0.0;
uniform float breath = 0.0;

void fragment() {
	vec2 px = UV * rect_size;
	float d = min(min(px.x, rect_size.x - px.x), min(px.y, rect_size.y - px.y));
	float k = 1.0 - clamp(d / reach, 0.0, 1.0);
	k = k * k;
	COLOR = vec4(tint.rgb, k * max_alpha * amount * (0.65 + 0.35 * breath));
}
