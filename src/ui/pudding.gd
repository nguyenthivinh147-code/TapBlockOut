extends RefCounted
## 3D pudding block body: bakes distance fields for each block shape and shades them with `pudding.gdshader`.
## Fields do not depend on colour or cell size, so they are cached per shape. Static functions, static cache.

const SHADER := preload("res://src/ui/pudding.gdshader")

const RES := 16  # texture px per cell
const PAD := 0.25  # margin around the block (cells), holds the contact shadow and the antialiased edge
const RADIUS_PX := 2.4  # convex corner radius (texture px)
const SOFT_PX := 1  # box blur radius for the well outline; two passes round its corners like a cushion
const WELL_INSET_PX := 1.6  # well inset at the left and the top; the well sits toward the top-left corner
const WELL_RIGHT_PX := 0.8  # extra well inset at the right
const WELL_BOTTOM_PX := 2.64  # extra well inset at the bottom: the thick band
const MAX_TL := 6  # must match the shader
const MAX_CC := 4  # must match the shader
const FAR := 1.0e6

## Colours sampled from 23 single blocks of the concept. `mid` equals `ThemeKit.BLOCK_COLORS`.
const PALETTES := {
	"yellow": {
		"mid": Color("FDE437"), "deep": Color("F3CE26"), "lit": Color("FDFD94"), "top": Color("FEF47E"),
		"left": Color("F8E34C"), "right": Color("EDC930"), "band": Color("FDE654"), "glow": Color("FBF2A8"),
		"lip": Color("FFFBC8"), "wall": Color("DECE85"), "rim": Color("FDF5B2"), "spec": Color("FDFEEE"),
	},
	"green": {
		"mid": Color("8DD142"), "deep": Color("75BE21"), "lit": Color("D0E974"), "top": Color("BBE164"),
		"left": Color("94CB40"), "right": Color("7EB921"), "band": Color("88D03D"), "glow": Color("B0E365"),
		"lip": Color("DDF4A0"), "wall": Color("7DA040"), "rim": Color("C9E386"), "spec": Color("FDFEE7"),
	},
	"blue": {
		"mid": Color("2EA4FF"), "deep": Color("308DF4"), "lit": Color("8AD8FF"), "top": Color("66CBFF"),
		"left": Color("57A7F0"), "right": Color("3FA0F8"), "band": Color("4DBCFF"), "glow": Color("95EBFF"),
		"lip": Color("D0F4FD"), "wall": Color("3E8FD6"), "rim": Color("91D3F7"), "spec": Color("F3FBFD"),
	},
	"purple": {
		"mid": Color("8D45E0"), "deep": Color("743CBC"), "lit": Color("D498EF"), "top": Color("B177DF"),
		"left": Color("985CCE"), "right": Color("723BB8"), "band": Color("9852DD"), "glow": Color("D98CF5"),
		"lip": Color("F1B4FB"), "wall": Color("7A4CA8"), "rim": Color("B898DB"), "spec": Color("FEF6FD"),
	},
}

static var _cache: Dictionary = {}  # shape key -> {tex, dims, tl, cc}


## Control holding the block body; drawn behind the BlockNode.
class Body extends Control:
	var tex: Texture2D = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		material = ShaderMaterial.new()
		(material as ShaderMaterial).shader = SHADER

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)


static func make_body() -> Control:
	return Body.new()


## Palette of a block colour; an unknown name falls back to a palette derived from `fallback`.
static func palette_of(color_name: String, fallback: Color) -> Dictionary:
	return PALETTES.get(color_name, palette_from(fallback))


## Palette for a colour without measured values (fog grey), same structure as the measured ones.
static func palette_from(base: Color) -> Dictionary:
	return {
		"mid": base, "deep": base.darkened(0.12), "lit": base.lightened(0.28), "top": base.lightened(0.3),
		"left": base.lightened(0.04), "right": base.darkened(0.05), "band": base.lightened(0.14), "glow": base.lightened(0.4),
		"lip": base.lightened(0.72), "wall": base.darkened(0.25), "rim": base.lightened(0.45), "spec": base.lightened(0.92),
	}


static func palette_darkened(palette: Dictionary, amount: float) -> Dictionary:
	var out := {}
	for k: String in palette:
		out[k] = (palette[k] as Color).darkened(amount)
	return out


## Lays out and colours the body. `cells` are relative to the BlockNode's origin cell; `offset` is in px.
static func update_body(body: Control, cells: Array, cell: float, palette: Dictionary, offset: Vector2 = Vector2.ZERO) -> void:
	var entry := fields_for(cells)
	var dims: Vector2 = entry["dims"]
	body.position = offset + Vector2(-PAD, -PAD) * cell
	body.size = dims * cell
	body.tex = entry["tex"]
	var m: ShaderMaterial = body.material
	m.set_shader_parameter("sdf", entry["tex"])
	m.set_shader_parameter("dims", dims)
	m.set_shader_parameter("cell_px", cell)
	m.set_shader_parameter("tl_corners", entry["tl"])
	m.set_shader_parameter("tl_count", (entry["tl"] as PackedVector2Array).size())
	m.set_shader_parameter("cc_corners", entry["cc"])
	m.set_shader_parameter("cc_count", (entry["cc"] as PackedVector2Array).size())
	for k: String in palette:
		m.set_shader_parameter("c_" + k, palette[k])
	body.queue_redraw()


static func fields_for(cells: Array) -> Dictionary:
	var key := _key(cells)
	if not _cache.has(key):
		_cache[key] = _build(cells)
	return _cache[key]


static func _key(cells: Array) -> String:
	var parts: PackedStringArray = []
	for c: Vector2i in cells:
		parts.append("%d,%d" % [c.x, c.y])
	parts.sort()
	return ";".join(parts)


## Convex top-left corners (each gets the big highlight) and concave corners open to the top left (a small glint),
## in cells inside the texture area. Row by row, capped at what the shader holds.
static func corners_of(cells: Array) -> Dictionary:
	var occ := {}
	for c: Vector2i in cells:
		occ[c] = true
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var tl := PackedVector2Array()
	var cc := PackedVector2Array()
	for c: Vector2i in sorted:
		var left: bool = occ.has(c + Vector2i(-1, 0))
		var up: bool = occ.has(c + Vector2i(0, -1))
		if not left and not up and tl.size() < MAX_TL:
			tl.append(Vector2(c) + Vector2(PAD, PAD))
		elif left and up and not occ.has(c + Vector2i(-1, -1)) and cc.size() < MAX_CC:
			cc.append(Vector2(c) + Vector2(PAD, PAD))
	return {"tl": tl, "cc": cc}


static func _build(cells: Array) -> Dictionary:
	var img := bake_image(cells)
	var out := corners_of(cells)
	out["tex"] = ImageTexture.create_from_image(img)
	out["dims"] = Vector2(img.get_size()) / float(RES)
	return out


## Field texture of a shape: R silhouette distance, G well distance (cells, positive inside), BA well gradient.
static func bake_image(cells: Array) -> Image:
	var max_c := Vector2i.ZERO
	for c: Vector2i in cells:
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var pad_px := int(PAD * RES)
	var w := (max_c.x + 1) * RES + 2 * pad_px
	var h := (max_c.y + 1) * RES + 2 * pad_px
	var n := w * h
	var inside := PackedByteArray()
	inside.resize(n)
	for c: Vector2i in cells:
		for y in range(pad_px + c.y * RES, pad_px + (c.y + 1) * RES):
			for x in range(pad_px + c.x * RES, pad_px + (c.x + 1) * RES):
				inside[y * w + x] = 1
	var d_in := _chamfer(inside, w, h, false)
	var d_out := _chamfer(inside, w, h, true)
	var sd := PackedFloat32Array()
	sd.resize(n)
	for i in n:
		sd[i] = d_in[i] - 0.5 if inside[i] == 1 else 0.5 - d_out[i]
	_round_convex_corners(sd, cells, w, h, pad_px)
	# a light blur rounds concave corners and hides the grid
	var edge := _blur(sd, w, h, 1)
	var soft := _blur(_blur(sd, w, h, SOFT_PX), w, h, SOFT_PX)
	var well := PackedFloat32Array()
	well.resize(n)
	for y in h:
		for x in w:
			well[y * w + x] = minf(soft[y * w + x], _sample(soft, w, h, x + WELL_RIGHT_PX, y + WELL_BOTTOM_PX)) - WELL_INSET_PX
	well = _blur(well, w, h, 1)
	var slope := _blur(well, w, h, 1)
	var img := Image.create(w, h, false, Image.FORMAT_RGBAH)
	for y in h:
		for x in w:
			var i := y * w + x
			var nx := (slope[y * w + mini(x + 1, w - 1)] - slope[y * w + maxi(x - 1, 0)]) * 0.5
			var ny := (slope[mini(y + 1, h - 1) * w + x] - slope[maxi(y - 1, 0) * w + x]) * 0.5
			img.set_pixel(x, y, Color(edge[i] / RES, well[i] / RES, nx, ny))
	return img


## Replaces the distance around each convex corner with the distance to its rounding arc, exact at any radius.
static func _round_convex_corners(sd: PackedFloat32Array, cells: Array, w: int, h: int, pad_px: int) -> void:
	var occ := {}
	for c: Vector2i in cells:
		occ[c] = true
	var reach := int(ceilf(RADIUS_PX)) + pad_px
	for c: Vector2i in cells:
		for sx: int in [-1, 1]:
			for sy: int in [-1, 1]:
				if occ.has(c + Vector2i(sx, 0)) or occ.has(c + Vector2i(0, sy)):
					continue
				var vx := pad_px + (c.x + (1 if sx > 0 else 0)) * RES
				var vy := pad_px + (c.y + (1 if sy > 0 else 0)) * RES
				var center := Vector2(vx - sx * RADIUS_PX, vy - sy * RADIUS_PX)
				for oy in range(-reach, reach):
					for ox in range(-reach, reach):
						var x := vx + ox
						var y := vy + oy
						if x < 0 or y < 0 or x >= w or y >= h:
							continue
						var p := Vector2(x + 0.5, y + 0.5)
						# only the quarter turned toward the corner, and never over another arm of the shape
						if (p.x - center.x) * sx <= 0.0 or (p.y - center.y) * sy <= 0.0:
							continue
						var cx := floori(float(x - pad_px) / RES)
						var cy := floori(float(y - pad_px) / RES)
						if Vector2i(cx, cy) != c and occ.has(Vector2i(cx, cy)):
							continue
						sd[y * w + x] = RADIUS_PX - p.distance_to(center)


## Bilinear value of `f` at fractional pixel (`x`, `y`), clamped to the texture.
static func _sample(f: PackedFloat32Array, w: int, h: int, x: float, y: float) -> float:
	var x0 := clampi(floori(x), 0, w - 1)
	var y0 := clampi(floori(y), 0, h - 1)
	var x1 := mini(x0 + 1, w - 1)
	var y1 := mini(y0 + 1, h - 1)
	var fx := clampf(x - x0, 0.0, 1.0)
	var fy := clampf(y - y0, 0.0, 1.0)
	return lerpf(lerpf(f[y0 * w + x0], f[y0 * w + x1], fx), lerpf(f[y1 * w + x0], f[y1 * w + x1], fx), fy)


## Separable box blur of radius `r` (px).
static func _blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := src.duplicate()
	var out := src.duplicate()
	var k := 1.0 / float(2 * r + 1)
	for y in h:
		var row := y * w
		var s := 0.0
		for o in range(-r, r + 1):
			s += src[row + clampi(o, 0, w - 1)]
		for x in w:
			tmp[row + x] = s * k
			s += src[row + mini(x + r + 1, w - 1)] - src[row + maxi(x - r, 0)]
	for x in w:
		var s := 0.0
		for o in range(-r, r + 1):
			s += tmp[clampi(o, 0, h - 1) * w + x]
		for y in h:
			out[y * w + x] = s * k
			s += tmp[mini(y + r + 1, h - 1) * w + x] - tmp[maxi(y - r, 0) * w + x]
	return out


## Khoảng cách Euclid (px) từ mỗi pixel tới pixel gần nhất thuộc phía đối diện (Felzenszwalb, hai lượt 1 chiều).
## `to_inside` false: đo từ pixel trong mặt nạ tới pixel ngoài; true: từ pixel ngoài tới pixel trong.
static func _chamfer(mask: PackedByteArray, w: int, h: int, to_inside: bool) -> PackedFloat32Array:
	var target := 1 if to_inside else 0
	var f := PackedFloat32Array()
	f.resize(w * h)
	for i in w * h:
		f[i] = 0.0 if mask[i] == target else FAR
	var n := maxi(w, h)
	var col := PackedFloat32Array()
	col.resize(n)
	var out := PackedFloat32Array()
	out.resize(n)
	var v := PackedInt32Array()
	v.resize(n)
	var z := PackedFloat32Array()
	z.resize(n + 1)
	# lượt theo cột rồi theo hàng
	for pass_i in 2:
		var lines := w if pass_i == 0 else h
		var len_ := h if pass_i == 0 else w
		for l in lines:
			for k in len_:
				col[k] = f[k * w + l] if pass_i == 0 else f[l * w + k]
			_dt1d(col, out, v, z, len_)
			for k in len_:
				if pass_i == 0:
					f[k * w + l] = out[k]
				else:
					f[l * w + k] = out[k]
	for i in w * h:
		f[i] = sqrt(minf(f[i], 1.0e6))
	return f


static func _dt1d(src: PackedFloat32Array, dst: PackedFloat32Array, v: PackedInt32Array, z: PackedFloat32Array, n: int) -> void:
	var k := 0
	v[0] = 0
	z[0] = -FAR
	z[1] = FAR
	for q in range(1, n):
		var s := 0.0
		while true:
			var p := v[k]
			s = ((src[q] + q * q) - (src[p] + p * p)) / float(2 * q - 2 * p)
			if s <= z[k] and k > 0:
				k -= 1
			else:
				break
		if s <= z[k]:
			# k == 0 và vẫn thấp hơn: thay hẳn
			v[0] = q
			z[0] = -FAR
			z[1] = FAR
			continue
		k += 1
		v[k] = q
		z[k] = s
		z[k + 1] = FAR
	k = 0
	for q in n:
		while z[k + 1] < q:
			k += 1
		var p := v[k]
		dst[q] = float((q - p) * (q - p)) + src[p]
