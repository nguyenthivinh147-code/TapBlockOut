extends RefCounted
## Dữ liệu level (kế hoạch mục 1.6): hằng màu/hướng/cạnh và kiểm khung level.
## Gốc toạ độ ở góc trên trái, x sang phải, y xuống dưới.

const Config := preload("res://src/config.gd")

const COLORS := ["yellow", "green", "blue", "purple"]
const SIDES := ["up", "left", "right", "down"]
const DIR := {
	"yellow": Vector2i(0, -1),
	"green": Vector2i(-1, 0),
	"blue": Vector2i(1, 0),
	"purple": Vector2i(0, 1),
}
const SIDE_OF := {"yellow": "up", "green": "left", "blue": "right", "purple": "down"}
const HEX := {"yellow": "#F5C518", "green": "#43B649", "blue": "#2F80ED", "purple": "#9B51E0"}
const STONE := "stone"
## Chất liệu lớp phủ (khoá `cover` của level, thiếu là pudding); số lớp ở khoá `ice` của khối.
const COVERS := ["pudding", "frost"]
## Màu cổng của level nhiều cổng (Road Trip, design.md mục 7 "Road Trip"): mỗi cạnh chia 2-3 cổng, mỗi cổng một màu,
## khối mang màu cổng nó thoát qua và có hướng riêng ở khoá `dir`. 8 màu đầu dùng cho level 8 cổng.
const GATE_COLORS := ["yellow", "green", "blue", "purple", "red", "orange", "teal", "brown",
	"pink", "indigo", "cream", "licorice"]
const SIDE_DIR := {"up": Vector2i(0, -1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0), "down": Vector2i(0, 1)}


static func dir_of(color: String) -> Vector2i:
	return DIR.get(color, Vector2i.ZERO)


static func side_of(color: String) -> String:
	return SIDE_OF.get(color, "")


## Cạnh khối thoát ra: khoá `dir` nếu có (level nhiều cổng), không thì theo màu.
static func block_side(b: Dictionary) -> String:
	var d := str(b.get("dir", ""))
	return d if d != "" else side_of(str(b.get("color", "")))


static func side_dir(side: String) -> Vector2i:
	return SIDE_DIR.get(side, Vector2i.ZERO)


## `[x, y]` (từ JSON có thể là float) thành Vector2i.
static func cell_of(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	return Vector2i(int(v[0]), int(v[1]))


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and v == floorf(v)


static func _is_cell(v: Variant) -> bool:
	return v is Array and v.size() == 2 and _is_int(v[0]) and _is_int(v[1])


## Trả danh sách lỗi; rỗng nghĩa là hợp lệ.
## Bắt buộc: id, w, h, moves, blocks. Các khoá còn lại tuỳ chọn nhưng nếu có thì phải đúng kiểu.
static func validate(d: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	for k in ["id", "w", "h", "moves", "blocks"]:
		if not d.has(k):
			errs.append("thiếu khoá %s" % k)
	if not errs.is_empty():
		return errs
	for k in ["id", "w", "h", "moves"]:
		if not _is_int(d[k]):
			errs.append("%s phải là số nguyên" % k)
	if not (d["blocks"] is Array):
		errs.append("blocks phải là mảng")
	if not errs.is_empty():
		return errs
	var w := int(d["w"])
	var h := int(d["h"])
	if w < 1 or h < 1:
		errs.append("kích thước bàn phải >= 1")
		return errs
	if int(d["moves"]) < 0:
		errs.append("moves < 0")
	if d.has("min_taps"):
		if not _is_int(d["min_taps"]) or int(d["min_taps"]) < 0:
			errs.append("min_taps không hợp lệ")
		elif int(d["moves"]) < int(d["min_taps"]):
			errs.append("moves nhỏ hơn min_taps")
	if d.has("hard") and typeof(d["hard"]) != TYPE_BOOL:
		errs.append("hard phải là bool")
	if d.has("seed") and not _is_int(d["seed"]):
		errs.append("seed phải là số nguyên")
	if d.has("cover") and not COVERS.has(str(d["cover"])):
		errs.append("cover phải là pudding hoặc frost")
	var taken := {}  # Vector2i -> mô tả
	if d.has("stones"):
		if not (d["stones"] is Array):
			errs.append("stones phải là mảng")
		else:
			for s in d["stones"]:
				if not _is_cell(s):
					errs.append("ô đá sai khuôn dạng")
					continue
				var c := cell_of(s)
				if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
					errs.append("đá ngoài bàn: %s" % str(c))
				elif taken.has(c):
					errs.append("ô trùng %s (đá và %s)" % [str(c), taken[c]])
				else:
					taken[c] = STONE
	if d.has("pulse_sides"):
		if not (d["pulse_sides"] is Array):
			errs.append("pulse_sides phải là mảng")
		else:
			var seen_sides := {}
			for p in d["pulse_sides"]:
				if not (p is Dictionary) or not p.has("side") or not SIDES.has(str(p["side"])):
					errs.append("pulse_sides: cạnh sai")
					continue
				if seen_sides.has(p["side"]):
					errs.append("pulse_sides: cạnh trùng %s" % p["side"])
				seen_sides[p["side"]] = true
				if p.has("open") and typeof(p["open"]) != TYPE_BOOL:
					errs.append("pulse_sides: open phải là bool")
	if d.has("gates"):
		errs.append_array(_validate_gates(d["gates"], w, h))
	if d.has("choco_sides"):
		errs.append_array(_validate_choco(d))
	var ids := {}
	var parent := {}
	for b in d["blocks"]:
		if not (b is Dictionary):
			errs.append("khối sai khuôn dạng")
			continue
		var id := str(b.get("id", ""))
		if id == "":
			errs.append("khối thiếu id")
			continue
		if ids.has(id):
			errs.append("id khối trùng: %s" % id)
			continue
		ids[id] = b
		var bdir := str(b.get("dir", ""))
		if bdir != "" and not SIDES.has(bdir):
			errs.append("khối %s: dir sai" % id)
		var palette: Array = GATE_COLORS if bdir != "" else COLORS
		if not palette.has(str(b.get("color", ""))):
			errs.append("khối %s: màu sai" % id)
		var inner := str(b.get("inner_color", ""))
		if inner != "" and not COLORS.has(inner):
			errs.append("khối %s: inner_color sai" % id)
		if b.has("ribbons"):
			errs.append_array(_validate_ribbons(id, b))
		if b.has("ice") and (not _is_int(b["ice"]) or int(b["ice"]) < 0 or int(b["ice"]) > Config.COVER_MAX_LAYERS):
			errs.append("khối %s: ice phải trong 0..%d" % [id, Config.COVER_MAX_LAYERS])
		if b.has("fog") and typeof(b["fog"]) != TYPE_BOOL:
			errs.append("khối %s: fog phải là bool" % id)
		if b.has("pop"):
			errs.append_array(_validate_pop(id, b))
		var cells = b.get("cells", null)
		if not (cells is Array) or cells.is_empty():
			errs.append("khối %s: thiếu ô" % id)
			continue
		var mine := {}
		var cell_ok := true
		for raw in cells:
			if not _is_cell(raw):
				errs.append("khối %s: ô sai khuôn dạng" % id)
				cell_ok = false
				continue
			var c := cell_of(raw)
			if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
				errs.append("khối %s: ô ngoài bàn %s" % [id, str(c)])
				cell_ok = false
			elif taken.has(c):
				errs.append("ô trùng %s (%s và %s)" % [str(c), taken[c], id])
				cell_ok = false
			else:
				taken[c] = id
				mine[c] = true
		if cell_ok and not connected(mine):
			errs.append("khối %s: các ô không liền nhau" % id)
		var key := str(b.get("chained_by", ""))
		if key != "":
			parent[id] = key
	for id in parent:
		var key: String = parent[id]
		if ids.has(key) and bool(ids[key].get("pop", false)):
			errs.append("khối %s: bom kẹo không làm chìa" % key)
		if key == id:
			errs.append("khối %s tự xích chính nó" % id)
		elif not ids.has(key):
			errs.append("khối %s: chained_by %s không tồn tại" % [id, key])
	for id in parent:
		var cur: String = id
		var steps := 0
		while parent.has(cur) and steps <= ids.size():
			cur = parent[cur]
			steps += 1
			if cur == id:
				errs.append("chu trình xích qua khối %s" % id)
				break
	return errs


## `pop` (bom kẹo): bool; khối bom kẹo không có cơ chế nào khác (lớp phủ, sương, xích, hộp giấy, ruy băng, dir; không
## làm chìa, kiểm ở `validate`).
static func _validate_pop(id: String, b: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if typeof(b["pop"]) != TYPE_BOOL:
		errs.append("khối %s: pop phải là bool" % id)
		return errs
	if not bool(b["pop"]):
		return errs
	var rib: Variant = b.get("ribbons", [])
	if int(b.get("ice", 0)) > 0 or bool(b.get("fog", false)) or str(b.get("chained_by", "")) != "" \
			or str(b.get("inner_color", "")) != "" or (rib is Array and not (rib as Array).is_empty()) \
			or str(b.get("dir", "")) != "":
		errs.append("khối %s: bom kẹo không chung khối với lớp phủ, sương, xích, hộp giấy, ruy băng hay dir" % id)
	return errs


## `ribbons`: mảng màu (COLORS) ngoài vào trong, tối đa Config.RIBBON_MAX_LAYERS và theo cỡ khối
## (Config.RIBBON_CELL_CAP); lớp nào cũng khác màu lớp ngay trong nó (kẹo là `color`). Không chung khối với hộp giấy,
## lớp phủ, xích, hướng riêng (`dir`). Mảng rỗng là không có ruy băng.
static func _validate_ribbons(id: String, b: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var rib: Variant = b["ribbons"]
	if not (rib is Array):
		errs.append("khối %s: ribbons phải là mảng" % id)
		return errs
	if (rib as Array).is_empty():
		return errs
	var layers: Array = rib.duplicate()
	layers.append(str(b.get("color", "")))
	for k in rib.size():
		if not COLORS.has(str(rib[k])):
			errs.append("khối %s: màu ruy băng sai" % id)
		elif str(layers[k]) == str(layers[k + 1]):
			errs.append("khối %s: hai lớp ruy băng liền nhau cùng màu" % id)
	var cells: Variant = b.get("cells", [])
	var n: int = (cells as Array).size() if cells is Array else 0
	var cap: int = Config.RIBBON_CELL_CAP[mini(n, Config.RIBBON_CELL_CAP.size() - 1)]
	if rib.size() > mini(cap, Config.RIBBON_MAX_LAYERS):
		errs.append("khối %s: %d ô chỉ được tối đa %d ruy băng" % [id, n, mini(cap, Config.RIBBON_MAX_LAYERS)])
	if str(b.get("inner_color", "")) != "" or int(b.get("ice", 0)) > 0 or str(b.get("chained_by", "")) != "" \
			or str(b.get("dir", "")) != "":
		errs.append("khối %s: ruy băng không chung khối với hộp giấy, lớp phủ, xích hay dir" % id)
	return errs


## `choco_sides`: [{side, layers}], mỗi cạnh tối đa một lần, layers 1..Config.CHOCO_MAX_LAYERS, không chung cạnh với cổng
## nhịp (`pulse_sides`).
static func _validate_choco(d: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if not (d["choco_sides"] is Array):
		errs.append("choco_sides phải là mảng")
		return errs
	var pulse := {}
	if d.get("pulse_sides", []) is Array:
		for p in d.get("pulse_sides", []):
			if p is Dictionary:
				pulse[str(p.get("side", ""))] = true
	var seen := {}
	for p in d["choco_sides"]:
		if not (p is Dictionary) or not p.has("side") or not SIDES.has(str(p["side"])):
			errs.append("choco_sides: cạnh sai")
			continue
		var side := str(p["side"])
		if seen.has(side):
			errs.append("choco_sides: cạnh trùng %s" % side)
		seen[side] = true
		if pulse.has(side):
			errs.append("choco_sides: cạnh %s đã có cổng nhịp" % side)
		if not p.has("layers") or not _is_int(p["layers"]) \
				or int(p["layers"]) < 1 or int(p["layers"]) > Config.CHOCO_MAX_LAYERS:
			errs.append("choco_sides: số lớp sai ở cạnh %s" % side)
	return errs


## `gates`: cạnh -> [[màu, từ, tới), ...] theo ô dọc cạnh (x với up/down, y với left/right), nối liền từ 0 tới hết
## cạnh, màu trong GATE_COLORS, mỗi màu một cổng.
static func _validate_gates(g: Variant, w: int, h: int) -> Array[String]:
	var errs: Array[String] = []
	if not (g is Dictionary):
		errs.append("gates phải là dict")
		return errs
	var seen := {}
	for side in g:
		if not SIDES.has(str(side)) or not (g[side] is Array) or (g[side] as Array).is_empty():
			errs.append("gates: cạnh sai %s" % str(side))
			continue
		var at := 0
		for seg in g[side]:
			if not (seg is Array) or seg.size() != 3 or not GATE_COLORS.has(str(seg[0])) or not _is_int(seg[1]) \
					or not _is_int(seg[2]) or int(seg[1]) != at or int(seg[2]) <= at:
				errs.append("gates: cổng sai ở cạnh %s" % str(side))
				break
			if seen.has(str(seg[0])):
				errs.append("gates: màu trùng %s" % str(seg[0]))
			seen[str(seg[0])] = true
			at = int(seg[2])
		if at != (w if str(side) == "up" or str(side) == "down" else h):
			errs.append("gates: cạnh %s không phủ hết" % str(side))
	return errs


## Các ô (khoá của `cells`) có liền nhau theo 4 hướng không.
static func connected(cells: Dictionary) -> bool:
	if cells.size() <= 1:
		return true
	var start: Vector2i = cells.keys()[0]
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen.size() == cells.size()
