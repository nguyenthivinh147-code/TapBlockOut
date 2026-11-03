extends Control
## Loading curtain shown on the way into a level: the purple jelly slab slides in from the right, then the pink one
## from the left over its edge, both slowing down hard as they reach the middle; then the game logo pops in the
## middle, going from faint and blurred to sharp. Main swaps the screen while it is closed and
## then calls open(): the logo fades and both slabs slide back out. Blocks input for its whole life.
## Layout follows the demo art (768 px wide); every length scales with the curtain width.

const Config := preload("res://src/config.gd")
const SLAB_SHADER := preload("res://src/ui/curtain_slab.gdshader")
const LOGO_SHADER := preload("res://src/ui/logo_blur.gdshader")
const LOGO_TEX := "res://assets/ui/loading_logo.png"

const REF_W := 768.0
## Seam: the pink slab ends at PINK_RIGHT of the width; the purple one starts under it at PURPLE_LEFT (more than two
## radii left of the pink edge), so its rounded corner stays hidden and no gap opens at the ends of the seam.
const PINK_RIGHT := 0.535
const PURPLE_LEFT := 0.43
const RADIUS := 36.0
const RIM := 20.0
const MARGIN := 16.0
const GLOSS_Y := 6.0
const GLOSS_H := 7.0
const SHADOW_X := 4.0
const SHADOW_BLUR := 8.0
const LOGO_W := 0.6
const LOGO_CY := 0.45
## Logo pop: starting scale and blur (texels of the logo texture).
const LOGO_FROM_SCALE := 0.6
const LOGO_FROM_BLUR := 16.0

const PINK := {
	"top_color": Color("fbd3df"), "bottom_color": Color("f6a9cf"), "rim_color": Color("e88ac2"),
	"edge_color": Color("c96fb6"), "gloss_color": Color(1.0, 1.0, 1.0, 0.85), "gloss_inset": 12.0,
	"shadow_color": Color(0.54, 0.37, 0.78, 0.5),
}
const PURPLE := {
	"top_color": Color("e0c1f0"), "bottom_color": Color("c9abf1"), "rim_color": Color("b48fe3"),
	"edge_color": Color("9670d2"), "gloss_color": Color(0.99, 0.94, 0.98, 0.85), "gloss_inset": 28.0,
	"shadow_color": Color(0.4, 0.3, 0.6, 0.0),
}

var _pink: ColorRect = null
var _purple: ColorRect = null
var _logo: TextureRect = null
## Resting and hidden x of each slab.
var _pink_x := Vector2.ZERO
var _purple_x := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_purple = _slab("Purple", PURPLE)
	_pink = _slab("Pink", PINK)
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = load(LOGO_TEX) as Texture2D
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.modulate.a = 0.0
	var mat := ShaderMaterial.new()
	mat.shader = LOGO_SHADER
	_logo.material = mat
	add_child(_logo)
	_layout()
	_pink.position.x = _pink_x.y
	_purple.position.x = _purple_x.y
	resized.connect(_layout)


func _slab(slab_name: String, colors: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.name = slab_name
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SLAB_SHADER
	for k in colors:
		if k != "gloss_inset":
			mat.set_shader_parameter(k, colors[k])
	r.material = mat
	add_child(r)
	return r


## Slabs run the full height (1 px past it, so no antialiased row shows what is behind) and overhang the outer
## screen edges, so only the seam corners show.
## Sets each slab's size and y; x belongs to the tweens (resting and hidden x go to _pink_x / _purple_x).
func _layout() -> void:
	var s := size if size != Vector2.ZERO else get_viewport_rect().size
	var k := s.x / REF_W
	var m := MARGIN * k
	var r := RADIUS * k
	_pink_x = Vector2(-2.0 * r - m, -s.x * PINK_RIGHT - 2.0 * r - 2.0 * m)
	_purple_x = Vector2(s.x * PURPLE_LEFT - m, s.x)
	_place(_pink, PINK, Vector2(s.x * PINK_RIGHT + 2.0 * r + 2.0 * m, s.y + 2.0 * m + 2.0), k)
	_place(_purple, PURPLE, Vector2(s.x * (1.0 - PURPLE_LEFT) + 2.0 * r + 2.0 * m, s.y + 2.0 * m + 2.0), k)
	var tex := _logo.texture
	var logo_size := Vector2(s.x * LOGO_W, s.x * LOGO_W * tex.get_size().y / tex.get_size().x)
	_logo.size = logo_size
	_logo.position = Vector2(s.x * 0.5, s.y * LOGO_CY) - logo_size * 0.5
	_logo.pivot_offset = logo_size * 0.5


func _place(slab: ColorRect, colors: Dictionary, rect: Vector2, k: float) -> void:
	slab.position.y = -MARGIN * k - 1.0
	slab.size = rect
	var mat := slab.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", rect)
	mat.set_shader_parameter("margin", MARGIN * k)
	mat.set_shader_parameter("radius", RADIUS * k)
	mat.set_shader_parameter("rim", RIM * k)
	mat.set_shader_parameter("gloss_y", GLOSS_Y * k)
	mat.set_shader_parameter("gloss_h", GLOSS_H * k)
	mat.set_shader_parameter("gloss_inset", float(colors.gloss_inset) * k)
	mat.set_shader_parameter("shadow_offset", Vector2(SHADOW_X, 0.0) * k)
	mat.set_shader_parameter("shadow_blur", SHADOW_BLUR * k)


## Purple in from the right, pink in from the left, logo pops. Returns when the screen is fully covered.
func close() -> void:
	var c: Dictionary = Config.CONTENT
	var slide := float(c.curtain_slide_sec)
	# Quart ease-out: fast from the edge, then a long slowdown into the middle.
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_purple, "position:x", _purple_x.x, slide).from(_purple_x.y)
	# Pink leaves while purple is still settling (most of the way there by curtain_pink_at).
	tw.parallel().tween_property(_pink, "position:x", _pink_x.x, slide).from(_pink_x.y) \
		.set_delay(slide * float(c.curtain_pink_at))
	tw.tween_callback(_pop_logo)
	await tw.finished


## Jumps up with an overshoot while it fades in and the blur clears.
func _pop_logo() -> void:
	var sec := float(Config.CONTENT.curtain_logo_sec)
	_logo.scale = Vector2.ONE * LOGO_FROM_SCALE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_logo, "scale", Vector2.ONE, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "modulate:a", 1.0, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_logo_blur, LOGO_FROM_BLUR, 0.0, sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_logo_blur(b: float) -> void:
	(_logo.material as ShaderMaterial).set_shader_parameter("blur", b)


## Holds the logo for curtain_hold_sec, fades it, slides pink out left and purple out right, then frees itself.
func open() -> void:
	var c: Dictionary = Config.CONTENT
	var slide := float(c.curtain_open_sec)
	var tw := create_tween()
	tw.tween_interval(float(c.curtain_logo_sec) + float(c.curtain_hold_sec))
	tw.tween_property(_logo, "modulate:a", 0.0, slide * 0.5)
	tw.parallel().tween_property(_logo, "scale", Vector2.ONE * 0.8, slide * 0.5)
	tw.tween_property(_pink, "position:x", _pink_x.y, slide).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_purple, "position:x", _purple_x.y, slide).set_delay(slide * 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
