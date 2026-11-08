shader_type canvas_item;
// Tones down the candy-purple HUD sprites (assets/ui/hud): softens the gloss sheen, then scales HSV saturation and
// value. Hue of everything else and alpha are kept.
// The sheen is the pale, bright part of the purple body. It is pulled toward the body hue and saturation and dimmed.
// Near-white glyphs (saturation under SHEEN_S_FROM) and pink accents (outside the hue window) are left alone; the
// tiny pure-white glints have the same color as the glyphs, so they stay too.

uniform float saturation = 1.0;
uniform float value = 1.0;
uniform float gloss_cut = 0.0;  // 0: sheen as drawn, 1: sheen pulled all the way to the body color

const float BODY_HUE = 280.0;  // degrees; the body sits at 270-290
const float BODY_SAT = 0.72;   // the body peaks at 0.7-0.8
const float HUE_FULL = 15.0;   // sheen weight is full within this many degrees of BODY_HUE
const float HUE_NONE = 28.0;   // and zero past this; pink glyph accents start near 310
const float SHEEN_S_FROM = 0.06;
const float SHEEN_S_TO = 0.25;
const float SHEEN_V_FROM = 0.65;
const float SHEEN_V_TO = 0.9;
const float SHEEN_DIM = 0.12;  // value drop of a full-weight sheen pixel at gloss_cut 1

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 hsv = rgb2hsv(COLOR.rgb);
	float w = gloss_cut
			* (1.0 - smoothstep(HUE_FULL, HUE_NONE, abs(hsv.x * 360.0 - BODY_HUE)))
			* smoothstep(SHEEN_S_FROM, SHEEN_S_TO, hsv.y)
			* smoothstep(SHEEN_V_FROM, SHEEN_V_TO, hsv.z);
	hsv.x = mix(hsv.x, BODY_HUE / 360.0, w);
	hsv.y += max(0.0, BODY_SAT - hsv.y) * w;
	hsv.z *= 1.0 - SHEEN_DIM * w;
	COLOR.rgb = hsv2rgb(vec3(hsv.x, min(1.0, hsv.y * saturation), hsv.z * value));
}
