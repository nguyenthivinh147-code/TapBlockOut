extends Control
## Unity UI Image (Simple, Sliced, Tiled, Filled) drawn in _draw, in Unity canvas units.
## unity_ui.gd assigns the sprite with set_texture(); without a sprite it fills with color like Unity's white Image.

enum { SIMPLE, SLICED, TILED, FILLED }

var tex: Texture2D = null
## Sprite region in the imported texture (px).
var region := Rect2()
## 9-slice border in the imported texture (px): left, top, right, bottom.
var border := Vector4.ZERO
## Canvas units per imported texture px for borders (100 / ppu / ppu_multiplier / import scale).
var border_scale := 1.0
var kind := SIMPLE
var color := Color.WHITE
var preserve_aspect := false
## Unity pivot (y up), used by preserve_aspect.
var pivot := Vector2(0.5, 0.5)
var fill_center := true
## Filled: 0 horizontal, 1 vertical (no prefab uses Radial).
var fill_method := 0
var fill_amount := 1.0
var fill_origin := 0
var uv_rect := Rect2(0, 0, 1, 1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_texture(t: Texture2D, r: Rect2 = Rect2(), b: Vector4 = Vector4.ZERO, scale: float = 1.0) -> void:
	tex = t
	region = r if r.has_area() or t == null else Rect2(Vector2.ZERO, t.get_size())
	border = b
	border_scale = scale
	queue_redraw()


func set_fill(amount: float) -> void:
	fill_amount = clampf(amount, 0.0, 1.0)
	queue_redraw()


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if tex == null:
		draw_rect(rect, color)
		return
	if preserve_aspect and kind != SLICED and kind != TILED:
		rect = _aspect(rect)
	match kind:
		SLICED, TILED:
			if border == Vector4.ZERO and kind == SLICED:
				draw_texture_rect_region(tex, rect, region, color)
			else:
				_nine(rect)
		FILLED:
			_filled(rect)
		_:
			draw_texture_rect_region(tex, rect, region, color)


## Image.PreserveSpriteAspectRatio: shrink to the sprite aspect, placed by pivot.
func _aspect(rect: Rect2) -> Rect2:
	var ratio := region.size.x / maxf(region.size.y, 0.001)
	var r := rect
	if r.size.x / maxf(r.size.y, 0.001) > ratio:
		var w := r.size.y * ratio
		r.position.x += (r.size.x - w) * pivot.x
		r.size.x = w
	else:
		var h := r.size.x / ratio
		r.position.y += (r.size.y - h) * (1.0 - pivot.y)
		r.size.y = h
	return r


## 9-slice with borders in Unity units; a rect smaller than its borders shrinks them per axis like GetAdjustedBorders.
func _nine(rect: Rect2) -> void:
	var sx := border_scale
	var sy := border_scale
	var bw := (border.x + border.z) * border_scale
	var bh := (border.y + border.w) * border_scale
	if bw > rect.size.x and bw > 0.0:
		sx *= rect.size.x / bw
	if bh > rect.size.y and bh > 0.0:
		sy *= rect.size.y / bh
	var mode := RenderingServer.NINE_PATCH_TILE if kind == TILED else RenderingServer.NINE_PATCH_STRETCH
	draw_set_transform(rect.position, 0.0, Vector2(sx, sy))
	RenderingServer.canvas_item_add_nine_patch(get_canvas_item(), Rect2(Vector2.ZERO, rect.size / Vector2(sx, sy)), region,
		tex.get_rid(), Vector2(border.x, border.y), Vector2(border.z, border.w), mode, mode, fill_center, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _filled(rect: Rect2) -> void:
	var a := clampf(fill_amount, 0.0, 1.0)
	if a <= 0.0:
		return
	var dst := rect
	var src := region
	if fill_method == 0:
		dst.size.x *= a
		src.size.x *= a
		if fill_origin == 1:
			dst.position.x = rect.end.x - dst.size.x
			src.position.x = region.end.x - src.size.x
	else:
		# Unity origin 0 = Bottom.
		dst.size.y *= a
		src.size.y *= a
		if fill_origin == 0:
			dst.position.y = rect.end.y - dst.size.y
			src.position.y = region.end.y - src.size.y
	draw_texture_rect_region(tex, dst, src, color)
