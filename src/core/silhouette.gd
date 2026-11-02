extends RefCounted
## Hình dạng level trên lưới (design.md mục 4): tên hình và khung (w, h) cho ra các ô thuộc hình, thuần và xác định.
## Mỗi hình mô tả trong toạ độ chuẩn u, v thuộc [-1, 1], đối xứng trái phải; hình trong V_SYMMETRIC đối xứng cả trên dưới.

const LevelData := preload("res://src/core/level_data.gd")

const RECT := "rect"
const KINDS := ["oval", "diamond", "heart", "cross", "hourglass", "arch", "ring", "arrow", "house"]
const V_SYMMETRIC := ["oval", "diamond", "cross", "hourglass", "ring"]

static var _cache: Dictionary = {}  # "kind:w:h" -> Array[Vector2i]


## Các ô của hình trong khung w x h, xếp theo hàng rồi cột. Rỗng nếu ở cỡ đó hình bị đứt thành nhiều mảng.
## Kết quả dùng chung qua cache: bên gọi không được sửa mảng trả về.
static func cells(kind: String, w: int, h: int) -> Array[Vector2i]:
	var key := "%s:%d:%d" % [kind, w, h]
	if not _cache.has(key):
		_cache[key] = _rasterize(kind, w, h)
	return _cache[key]


static func _rasterize(kind: String, w: int, h: int) -> Array[Vector2i]:
	var v_sym: bool = V_SYMMETRIC.has(kind)
	var out: Array[Vector2i] = []
	var mine := {}
	for y in h:
		for x in w:
			# Tính từ nửa khung trên trái để đối xứng đúng từng ô, không lệch vì làm tròn số thực.
			var u := absf(_norm(mini(x, w - 1 - x), w))
			var v := _norm(mini(y, h - 1 - y) if v_sym else y, h)
			if kind == RECT or _inside(kind, u, absf(v) if v_sym else v):
				var c := Vector2i(x, y)
				out.append(c)
				mine[c] = true
	if out.is_empty() or not LevelData.connected(mine):
		out.clear()
	return out


static func _norm(i: int, n: int) -> float:
	return (float(i) + 0.5) / float(n) * 2.0 - 1.0


## u >= 0 (đã lấy đối xứng trái phải); v tăng xuống dưới.
static func _inside(kind: String, u: float, v: float) -> bool:
	match kind:
		"oval":
			return u * u + v * v <= 1.0
		"diamond":
			return u + v <= 1.15
		"heart":
			var x := u * 1.15
			var y := 0.15 - v * 1.25
			var a := x * x + y * y - 1.0
			return a * a * a - x * x * y * y * y <= 0.0
		"cross":
			return u <= 0.4 or v <= 0.3
		"hourglass":
			return u <= 0.3 + 0.8 * v
		"arch":
			var top := minf(v + 0.2, 0.0) / 0.8
			return u * u + top * top <= 1.0 and not (u < 0.4 and v > 0.25)
		"ring":
			var r := u * u + v * v
			return r <= 1.0 and r >= 0.22
		"arrow":
			return u <= 1.1 * (v + 1.0) if v < 0.0 else u <= 0.42
		"house":
			return u <= 1.25 * (v + 1.0) if v < -0.2 else u <= 0.8
	return false
