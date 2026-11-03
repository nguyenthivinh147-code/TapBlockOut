shader_type canvas_item;
// CutoutMaskUI (unity_ui.gd): the image shows only outside its parent Mask's sprite, like Unity's stencil NotEqual.

uniform sampler2D mask_tex : filter_linear;
uniform bool has_mask_tex = false;
// Mask rect in this control's local units, and the sprite region in texture UV (x, y, w, h).
uniform vec4 mask_rect = vec4(0.0);
uniform vec4 mask_uv = vec4(0.0, 0.0, 1.0, 1.0);
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = (local_pos - mask_rect.xy) / max(mask_rect.zw, vec2(0.0001));
	float a = 0.0;
	if (p.x >= 0.0 && p.y >= 0.0 && p.x <= 1.0 && p.y <= 1.0) {
		a = has_mask_tex ? texture(mask_tex, mask_uv.xy + p * mask_uv.zw).a : 1.0;
	}
	COLOR.a *= 1.0 - a;
}
