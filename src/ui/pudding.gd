extends RefCounted
## Thân khối kẹo: dựng texture khoảng cách-tới-mép (SDF) cho từng hình khối rồi tô bằng `pudding.gdshader`.
## SDF không phụ thuộc màu hay cỡ ô nên cache theo hình. Hàm tĩnh, cache tĩnh.

const SHADER := preload("res://src/ui/pudding.gdshader")

const RES := 16  # px mỗi ô trong texture SDF
const PAD_PX := 5  # lề quanh khối (px SDF), chứa bóng đổ và viền khử răng cưa
const PAD := float(PAD_PX) / RES  # cùng lề đó tính theo ô
const GAP := 0.014  # mỗi khối lùi vào chừng này (ô), khe giữa hai khối gấp đôi
const RADIUS := 0.25  # bo góc lồi (ô)
const FILLET := 0.13  # bo góc lõm (ô)
const SHADOW_A := 0.34  # độ đậm bóng đổ
const FAR := 1.0e6

static var _cache: Dictionary = {}  # khoá hình -> {tex, dims}


## Control chứa thân khối, nằm sau phần vẽ của BlockNode.
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


## Thân chỉ vẽ bóng đổ, đặt ở lớp nằm dưới mọi khối.
static func make_shadow() -> Control:
	var b := Body.new()
	var m: ShaderMaterial = b.material
	m.set_shader_parameter("body_a", 0.0)
	m.set_shader_parameter("shadow_a", SHADOW_A)
	return b


## Viên trong của khối hai lớp: thân kèm bóng đổ, vì bóng rơi lên chính khối ngoài.
static func make_inner() -> Control:
	var b := Body.new()
	(b.material as ShaderMaterial).set_shader_parameter("shadow_a", SHADOW_A)
	return b


## Đặt lại thân khối theo ô và màu hiện tại. `cells` theo toạ độ ô gốc của BlockNode, `at` là góc ô gốc.
## `ramp` có deep, side, face, stripe; `overlay` phủ trong hình khối, `flash` 0..1 là nháy sáng.
static func update_body(body: Control, cells: Array, cell: float, ramp: Dictionary, overlay: Color = Color(0, 0, 0, 0), flash: float = 0.0, at: Vector2 = Vector2.ZERO) -> void:
	var entry := sdf_for(cells)
	var dims: Vector2 = entry["dims"]
	body.position = at + Vector2(-PAD, -PAD) * cell
	body.size = dims * cell
	body.tex = entry["tex"]
	var m: ShaderMaterial = body.material
	apply_material(m, entry, cell, ramp)
	m.set_shader_parameter("overlay", overlay)
	m.set_shader_parameter("flash", flash)
	body.queue_redraw()


## Đặt các tham số chất liệu chung (`candy_body.gdshaderinc`) cho một material.
static func apply_material(m: ShaderMaterial, entry: Dictionary, cell: float, ramp: Dictionary) -> void:
	m.set_shader_parameter("sdf", entry["tex"])
	for tone in ["deep", "side", "face", "stripe"]:
		m.set_shader_parameter(tone, ramp[tone])
	m.set_shader_parameter("dims", entry["dims"])
	m.set_shader_parameter("pad", PAD)
	m.set_shader_parameter("cell_px", cell)


static func sdf_for(cells: Array) -> Dictionary:
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


static func _build(cells: Array) -> Dictionary:
	var f := field(cells)
	var w: int = f["w"]
	var h: int = f["h"]
	var data: PackedFloat32Array = f["data"]
	var img := Image.create(w, h, false, Image.FORMAT_RH)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(data[y * w + x], 0.0, 0.0, 1.0))
	return {"tex": ImageTexture.create_from_image(img), "dims": Vector2(w, h) / float(RES)}


## Khoảng cách có dấu tới mép hình khối (đơn vị ô, dương là bên trong): {"w", "h", "data"}, ô (0, 0) bắt đầu ở pixel PAD_PX.
static func field(cells: Array) -> Dictionary:
	var max_c := Vector2i.ZERO
	for c: Vector2i in cells:
		max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
	var w := (max_c.x + 1) * RES + 2 * PAD_PX
	var h := (max_c.y + 1) * RES + 2 * PAD_PX
	# mặt nạ hình khối, ô liền nhau thì liền
	var inside := PackedByteArray()
	inside.resize(w * h)
	for c: Vector2i in cells:
		var x0 := PAD_PX + c.x * RES
		var y0 := PAD_PX + c.y * RES
		for y in range(y0, y0 + RES):
			for x in range(x0, x0 + RES):
				inside[y * w + x] = 1
	# bo góc lõm: nở ra FILLET rồi co lại
	var fillet_px := FILLET * RES
	var d_out := _chamfer(inside, w, h, true)
	var grown := PackedByteArray()
	grown.resize(w * h)
	for i in w * h:
		if inside[i] == 1 or d_out[i] - 0.5 <= fillet_px:
			grown[i] = 1
	var d_grown := _chamfer(grown, w, h, false)
	var closed := PackedByteArray()
	closed.resize(w * h)
	for i in w * h:
		if grown[i] == 1 and d_grown[i] - 0.5 > fillet_px:
			closed[i] = 1
	# bo góc lồi: co vào RADIUS rồi nở ra lại (SDF của phần đã co, cộng lại RADIUS)
	var radius_px := RADIUS * RES
	var d_in := _chamfer(closed, w, h, false)
	var eroded := PackedByteArray()
	eroded.resize(w * h)
	for i in w * h:
		if closed[i] == 1 and d_in[i] - 0.5 >= radius_px:
			eroded[i] = 1
	var e_in := _chamfer(eroded, w, h, false)
	var e_out := _chamfer(eroded, w, h, true)
	var sd_cells := PackedFloat32Array()
	sd_cells.resize(w * h)
	for i in w * h:
		var sd: float = e_in[i] - 0.5 if eroded[i] == 1 else -(e_out[i] - 0.5)
		sd_cells[i] = (sd + radius_px) / float(RES) - GAP
	return {"w": w, "h": h, "data": _smooth(sd_cells, w, h)}


## Làm mượt 1-2-1 theo hai chiều: mặt nạ nhị phân để lại bậc thang nhỏ trên đường cong của SDF.
static func _smooth(f: PackedFloat32Array, w: int, h: int) -> PackedFloat32Array:
	var a := f.duplicate()
	for y in h:
		for x in range(1, w - 1):
			var i := y * w + x
			a[i] = (f[i - 1] + 2.0 * f[i] + f[i + 1]) * 0.25
	var b := a.duplicate()
	for y in range(1, h - 1):
		for x in w:
			var i := y * w + x
			b[i] = (a[i - w] + 2.0 * a[i] + a[i + w]) * 0.25
	return b


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
