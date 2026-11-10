shader_type canvas_item;
render_mode blend_premul_alpha;
// TextMeshPro "Distance Field" face/outline/underlay on the Baloo SDF atlas (assets/fonts/baloo.res keeps TMP's
// single-channel SDF and its 6-texel glyph padding). Thresholds are in atlas alpha units like TMP's material
// (edge at 0.5); unity_ui.gd computes them from data/ui_unity/_materials.json.
// The fallback fonts (Baloo 2, Jua, M PLUS Rounded; tools/gen_baloo_font.gd) are Godot MTSDF fonts with the same pixel
// range and size, so the distance is the median of RGB clamped by A; on the single-channel Baloo atlas that is just R.

uniform vec4 face_color : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 underlay_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// 0.5 - weight: where the face would end with no outline.
uniform float face_edge = 0.5;
// Half outline width; the outline straddles face_edge like TMP's GetColor().
uniform float outline_half = 0.0;
uniform bool underlay_on = false;
uniform float underlay_edge = 0.5;
// Sample offset in atlas texels, Godot UV axes.
uniform vec2 underlay_offset = vec2(0.0);
// Atlas texels spanned by alpha 0..1 (FontFile.msdf_pixel_range).
uniform float px_range = 14.0;
// Optional vertical face gradient (not a TMP feature; load_transition.gd sets grad_y0/1): the face color is multiplied
// by grad_top at label-local y grad_y0 blending to grad_bottom at grad_y1.
uniform bool grad_on = false;
uniform vec4 grad_top : source_color = vec4(1.0);
uniform vec4 grad_bottom : source_color = vec4(1.0);
uniform float grad_y0 = 0.0;
uniform float grad_y1 = 100.0;

varying vec4 vcolor;
varying float local_y;

float dist(vec4 t) {
	return min(max(min(t.r, t.g), min(max(t.r, t.g), t.b)), t.a);
}

void vertex() {
	vcolor = COLOR;
	local_y = VERTEX.y;
}

void fragment() {
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	// Screen pixels per alpha unit (same estimate Godot uses for MSDF text).
	float k = max(0.5 * dot(vec2(px_range) / tex_size, 1.0 / fwidth(UV)), 1.0);
	float a = dist(texture(TEXTURE, UV));
	float opacity = vcolor.a;

	vec4 face = vec4(vcolor.rgb, opacity) * face_color;
	if (grad_on) {
		float g = clamp((local_y - grad_y0) / max(grad_y1 - grad_y0, 1.0), 0.0, 1.0);
		face *= mix(grad_top, grad_bottom, g);
	}
	face.rgb *= face.a;
	vec4 line = outline_color;
	line.a *= opacity;
	line.rgb *= line.a;

	float face_alpha = clamp((a - (face_edge - outline_half)) * k + 0.5, 0.0, 1.0);
	float outline_alpha = 0.0;
	if (outline_half > 0.0) {
		float inner = clamp((a - (face_edge + outline_half)) * k + 0.5, 0.0, 1.0);
		outline_alpha = (1.0 - inner) * sqrt(min(1.0, 2.0 * outline_half * k));
	}
	vec4 c = mix(face, line, outline_alpha) * face_alpha;

	if (underlay_on) {
		float b = dist(texture(TEXTURE, UV + underlay_offset * TEXTURE_PIXEL_SIZE));
		vec4 under = underlay_color;
		under.a *= opacity;
		under.rgb *= under.a;
		c += under * clamp((b - underlay_edge) * k + 0.5, 0.0, 1.0) * (1.0 - c.a);
	}
	COLOR = c;
}
