extends RefCounted
## Dữ liệu level (kế hoạch mục 1.6): hằng màu/hướng/cạnh và kiểm khung level.
## Gốc toạ độ ở góc trên trái, x sang phải, y xuống dưới.

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


static func dir_of(color: String) -> Vector2i:
	return DIR.get(color, Vector2i.ZERO)


static func side_of(color: String) -> String:
	return SIDE_OF.get(color, "")


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
		if not COLORS.has(str(b.get("color", ""))):
			errs.append("khối %s: màu sai" % id)
		var inner := str(b.get("inner_color", ""))
		if inner != "" and not COLORS.has(inner):
			errs.append("khối %s: inner_color sai" % id)
		if b.has("ice") and (not _is_int(b["ice"]) or int(b["ice"]) < 0 or int(b["ice"]) > 1):
			errs.append("khối %s: ice phải là 0 hoặc 1" % id)
		if b.has("fog") and typeof(b["fog"]) != TYPE_BOOL:
			errs.append("khối %s: fog phải là bool" % id)
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
		if cell_ok and not _connected(mine):
			errs.append("khối %s: các ô không liền nhau" % id)
		var key := str(b.get("chained_by", ""))
		if key != "":
			parent[id] = key
	for id in parent:
		var key: String = parent[id]
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


static func _connected(cells: Dictionary) -> bool:
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
