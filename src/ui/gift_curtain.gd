extends Control
## Loading curtain of Road Trip (road_trip.gd, into a level and back to the map; main.gd curtain_swap): a giant pastel
## gift box closes over the screen. The lavender body slides up from the bottom; once it has covered gift_lid_at of its
## way, the pink lid with its bow drops from the top onto it and lands with a small bump (the bow squashes). The game
## logo rides on the lid above the bow and pops in (faint and blurred to sharp) once the lid has covered gift_logo_at of
## its fall. Main swaps the screen while it is closed and then calls open(): the logo fades, the lid lifts off the top
## and the body drops out the bottom. Blocks input for its whole life. Same interface as
## level_curtain.gd: close() returns once the screen is covered, open() frees the node at the end.
## Art: ComfyUI, cut by tools/cut_gift_curtain.py (art/manifest.json, gift_curtain_*). Lengths below are texels of the
## lid texture; the box scales to cover the screen (sides or top and bottom cropped), centred.

const Config := preload("res://src/config.gd")
const LOGO_SHADER := preload("res://src/ui/logo_blur.gdshader")
const LID_TEX := "res://assets/ui/gift_curtain/gift_lid.png"
const BODY_TEX := "res://assets/ui/gift_curtain/gift_body.png"
const BOW_TEX := "res://assets/ui/gift_curtain/gift_bow.png"
const LOGO_TEX := "res://assets/ui/loading_logo.png"

## Rows of the lid texture where its rim (the lip band at the bottom) starts.
const LIP_TOP := 685.0
## The body tucks this far under the lid, so no gap opens at the seam.
const SEAM_OVERLAP := 4.0
## The box covers the screen with this much to spare at the top and bottom (or sides), so the landing bump of the
## lid never shows what is behind.
const OVERSCAN := 20.0
## Soft shadow the lid casts on the body.
const SHADOW_H := 26.0
const SHADOW_COLOR := Color(0.45, 0.25, 0.6, 0.4)
## Bow width (fraction of the box width) and the height of its knot (fraction of the bow height), which sits on
## the middle of the lip.
const BOW_W := 0.6
const BOW_KNOT_Y := 0.38
## Landing: the lid presses LID_BUMP further down and the bow squashes to BOW_SQUASH, both springing back.
const LID_BUMP := 10.0
const BOW_SQUASH := Vector2(1.16, 0.84)
## Logo: width (fraction of the screen width), at most LOGO_FILL of the lid space between LOGO_TOP (fraction of the
## screen height, clear of a notch) and the bow, centred in it.
const LOGO_W := 0.6
const LOGO_FILL := 0.86
const LOGO_TOP := 0.04
## Logo pop: starting scale and blur (texels of the logo texture).
const LOGO_FROM_SCALE := 0.6
const LOGO_FROM_BLUR := 16.0
## Easing of the body slide in (fast from the edge, long slowdown) and of the lid fall (speeding up).
const BODY_TRANS := Tween.TRANS_QUART
const BODY_EASE := Tween.EASE_OUT
const LID_TRANS := Tween.TRANS_QUAD
const LID_EASE := Tween.EASE_IN

var _lid: TextureRect = null
var _body: TextureRect = null
var _bow: TextureRect = null
var _shadow: TextureRect = null
var _logo: TextureRect = null
## Resting and hidden y of the lid and the body.
var _lid_y := Vector2.ZERO
var _body_y := Vector2.ZERO
## Texture to screen scale of the box.
var _k := 1.0
## Seconds from the end of close() until the logo is fully in (set by close()); open() holds it from there.
var _logo_after_land := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_body = _sprite("Body", BODY_TEX, self)
	_lid = _sprite("Lid", LID_TEX, self)
	_shadow = _sprite("Shadow", "", _lid)
	var grad := Gradient.new()
	grad.set_color(0, SHADOW_COLOR)
	grad.set_color(1, Color(SHADOW_COLOR, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 4
	gt.height = 64
	_shadow.texture = gt
	_bow = _sprite("Bow", BOW_TEX, _lid)
	_logo = _sprite("Logo", LOGO_TEX, _lid)
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.modulate.a = 0.0
	var mat := ShaderMaterial.new()
	mat.shader = LOGO_SHADER
	_logo.material = mat
	_layout()
	_lid.position.y = _lid_y.y
	_body.position.y = _body_y.y
	resized.connect(_layout)


func _sprite(node_name: String, path: String, parent: Node) -> TextureRect:
	var r := TextureRect.new()
	r.name = node_name
	if path != "":
		r.texture = load(path) as Texture2D
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Sets sizes, x and the resting / hidden y (_lid_y, _body_y); y itself belongs to the tweens.
func _layout() -> void:
	var s := size if size != Vector2.ZERO else get_viewport_rect().size
	var lid_size := _lid.texture.get_size()
	var body_size := _body.texture.get_size()
	var box_h := lid_size.y + body_size.y - SEAM_OVERLAP
	_k = maxf(s.x / (lid_size.x - 2.0 * OVERSCAN), s.y / (box_h - 2.0 * OVERSCAN))
	var w := lid_size.x * _k
	var x0 := (s.x - w) * 0.5
	var y0 := (s.y - box_h * _k) * 0.5
	_lid.size = lid_size * _k
	_lid.position.x = x0
	_body.size = body_size * _k
	_body.position.x = x0
	_shadow.position = Vector2(0.0, _lid.size.y)
	_shadow.size = Vector2(w, SHADOW_H * _k)
	var bow_size := Vector2(w * BOW_W, w * BOW_W * _bow.texture.get_height() / _bow.texture.get_width())
	var knot_y := (LIP_TOP + lid_size.y) * 0.5 * _k
	_bow.size = bow_size
	_bow.position = Vector2((w - bow_size.x) * 0.5, knot_y - bow_size.y * BOW_KNOT_Y)
	_bow.pivot_offset = Vector2(bow_size.x * 0.5, bow_size.y * BOW_KNOT_Y)
	# Hidden: the lid with everything hanging below it above the top edge, the body below the bottom edge.
	var below := maxf(_bow.position.y + bow_size.y, _shadow.position.y + _shadow.size.y)
	_lid_y = Vector2(y0, -below - 1.0)
	_body_y = Vector2(y0 + (lid_size.y - SEAM_OVERLAP) * _k, s.y + 1.0)
	# Logo on the lid (lid coordinates), in the space between the top margin of the closed screen and the bow.
	var top := maxf(y0, 0.0) + s.y * LOGO_TOP
	var space := y0 + _bow.position.y - top
	var tex := _logo.texture
	var aspect := tex.get_size().y / tex.get_size().x
	var logo_w := minf(s.x * LOGO_W, space * LOGO_FILL / aspect)
	var logo_size := Vector2(logo_w, logo_w * aspect)
	_logo.size = logo_size
	_logo.position = Vector2(s.x * 0.5 - x0, top + space * 0.5 - y0) - logo_size * 0.5
	_logo.pivot_offset = logo_size * 0.5


## Body up from the bottom, lid down onto it (the logo pops on the way), landing bump. Returns when the screen is
## fully covered.
func close() -> void:
	var c: Dictionary = Config.CONTENT
	var slide := float(c.gift_slide_sec)
	var fall := float(c.gift_lid_sec)
	var lid_start := slide * time_at(float(c.gift_lid_at), BODY_TRANS, BODY_EASE)
	var logo_start := lid_start + fall * time_at(float(c.gift_logo_at), LID_TRANS, LID_EASE)
	# Covered once both are in place (the lid may land while the body is still easing its last pixels in).
	var covered := maxf(slide, lid_start + fall)
	_logo_after_land = maxf(logo_start + float(c.curtain_logo_sec) - covered, 0.0)
	var tw := create_tween()
	tw.tween_property(_body, "position:y", _body_y.x, slide).from(_body_y.y).set_trans(BODY_TRANS).set_ease(BODY_EASE)
	tw.parallel().tween_property(_lid, "position:y", _lid_y.x, fall).from(_lid_y.y).set_delay(lid_start) \
		.set_trans(LID_TRANS).set_ease(LID_EASE)
	tw.parallel().tween_callback(_pop_logo).set_delay(logo_start)
	tw.parallel().tween_callback(_land).set_delay(lid_start + fall)
	await tw.finished


## Fraction of the duration at which an eased tween has covered `way` of its distance (0..1).
static func time_at(way: float, trans_type: Tween.TransitionType, ease_type: Tween.EaseType) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		if float(Tween.interpolate_value(0.0, 1.0, mid, 1.0, trans_type, ease_type)) < way:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Lid presses down and springs back, the bow squashes and wobbles back.
func _land() -> void:
	var sec := float(Config.CONTENT.gift_bump_sec)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lid, "position:y", _lid_y.x + LID_BUMP * _k, sec * 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_lid, "position:y", _lid_y.x, sec * 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bow.scale = BOW_SQUASH
	var bow_tw := create_tween()
	bow_tw.tween_property(_bow, "scale", Vector2.ONE, sec * 2.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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


## Holds the logo for curtain_hold_sec once it is fully in, fades it, lifts the lid off the top and drops the body out
## the bottom, then frees itself.
func open() -> void:
	var c: Dictionary = Config.CONTENT
	var slide := float(c.gift_open_sec)
	var tw := create_tween()
	tw.tween_interval(_logo_after_land + float(c.curtain_hold_sec))
	tw.tween_property(_logo, "modulate:a", 0.0, slide * 0.5)
	tw.parallel().tween_property(_logo, "scale", Vector2.ONE * 0.8, slide * 0.5)
	tw.tween_property(_lid, "position:y", _lid_y.y, slide).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_body, "position:y", _body_y.y, slide).set_delay(slide * 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
