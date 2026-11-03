shader_type canvas_item;
// Blur for the level curtain logo (level_curtain.gd): two rings of taps around each pixel, `blur` texels wide.
// 0 draws the texture as is. The vertex color (modulate) still applies, so the logo can fade at the same time.

uniform float blur = 0.0;

void fragment() {
	vec4 tint = COLOR;
	if (blur <= 0.01) {
		COLOR = texture(TEXTURE, UV) * tint;
	} else {
		vec4 sum = texture(TEXTURE, UV);
		float w = 1.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5236;
			vec2 d = vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE * blur;
			sum += texture(TEXTURE, UV + d) * 0.6 + texture(TEXTURE, UV + d * 0.5) * 0.9;
			w += 1.5;
		}
		COLOR = sum / w * tint;
	}
}
