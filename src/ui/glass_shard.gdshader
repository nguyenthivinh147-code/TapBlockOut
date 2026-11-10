shader_type canvas_item;
// Loose shard of the cracked screen glass (glass_crack.gd): shows the screen below shifted a few pixels and lightened,
// so the shard reads as a separate piece of glass. Vertex colour: rg = shift (0.5 none, 0 / 1 = -/+ max_shift),
// b = sheen toward white, a = opacity.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 max_shift = vec2(0.008, 0.004);  // in SCREEN_UV units

void fragment() {
	vec2 shift = (COLOR.rg - 0.5) * 2.0 * max_shift;
	vec3 bg = texture(screen_tex, SCREEN_UV + shift).rgb;
	COLOR = vec4(mix(bg, vec3(1.0), COLOR.b), COLOR.a);
}
