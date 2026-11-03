extends RefCounted
## Thư viện hình vẽ tay (src/core/motifs.gd) và cách bộ sinh cắt khối đối xứng theo hình.
const T := preload("res://tests/t.gd")
const Motifs := preload("res://src/core/motifs.gd")
const Gen := preload("res://src/core/level_generator.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Config := preload("res://src/config.gd")
const DifficultyCurve := preload("res://src/core/difficulty_curve.gd")


func _set_of(cells: Array) -> Dictionary:
	var s := {}
	for c in cells:
		s[c] = true
	return s


## Các mảng liền nhau của một tập ô (4 hướng), trả cỡ từng mảng.
func _components(cells: Array) -> Array[int]:
	var left := _set_of(cells)
	var out: Array[int] = []
	while not left.is_empty():
		var stack: Array = [left.keys()[0]]
		left.erase(stack[0])
		var size := 0
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			size += 1
			for dv in Gen.NEIGHBORS:
				if left.has(c + dv):
					left.erase(c + dv)
					stack.append(c + dv)
		out.append(size)
	return out


func test_kinds_match_table(t: T) -> void:
	t.eq(Motifs.KINDS.size(), Motifs.MOTIFS.size(), "KINDS liệt kê đúng số hình trong MOTIFS")
	for kind in Motifs.KINDS:
		t.ok(Motifs.MOTIFS.has(kind), "%s có bản vẽ" % kind)
	t.ok(Motifs.KINDS.size() % Gen.MOTIF_STRIDE != 0 and Motifs.KINDS.size() % 2 != 0,
		"MOTIF_STRIDE (8) nguyên tố cùng nhau với số hình (%d)" % Motifs.KINDS.size())


func test_every_drawing_fits_and_is_symmetric(t: T) -> void:
	for kind in Motifs.KINDS:
		var vs := Motifs.variants(kind)
		t.ok(vs.size() >= 2, "%s có ít nhất 2 biến thể" % kind)
		for v in vs:
			var w: int = v["w"]
			var h: int = v["h"]
			var tag := "%s %dx%d" % [kind, w, h]
			t.eq(w % 2, 0, "%s rộng chẵn để nằm đúng giữa bàn 14 cột" % tag)
			t.ok(w <= Gen.MAX_W and h <= Gen.MAX_H, "%s vừa khung %dx%d" % [tag, Gen.MAX_W, Gen.MAX_H])
			t.ok(bool(v["sym_h"]) or bool(v["sym_v"]), "%s đối xứng" % tag)
			var cells: Array = v["cells"]
			t.ok(cells.size() < w * h, "%s có khoảng trống trong khung" % tag)
			for size in _components(cells):
				t.ok(size >= 2, "%s không có ô lẻ loi" % tag)
			var xs := {}
			var ys := {}
			for c: Vector2i in cells:
				xs[c.x] = true
				ys[c.y] = true
			t.ok(xs.has(0) and xs.has(w - 1) and ys.has(0) and ys.has(h - 1), "%s bản vẽ không thừa hàng hay cột trống" % tag)


func test_arrows_point_four_ways(t: T) -> void:
	# Mũi tên lên và lật xuống; mũi tên ngang sang phải và lật sang trái.
	var up := Motifs.variants("arrow")
	t.eq(up.size(), 6, "mũi tên dọc: 3 cỡ x (lên, xuống)")
	var top: Array = up[0]["cells"]
	var down: Array = up[1]["cells"]
	t.ok(top.has(Vector2i(3, 0)) and down.has(Vector2i(3, int(up[1]["h"]) - 1)), "mũi nhọn ở đầu tương ứng")
	var side := Motifs.variants("arrow_side")
	t.eq(side.size(), 4, "mũi tên ngang: 2 cỡ x (phải, trái)")
	t.ok(bool(side[0]["sym_v"]) and not bool(side[0]["sym_h"]), "mũi tên ngang đối xứng trên dưới")


func test_every_size_band_has_choices(t: T) -> void:
	# Mỗi số khối mục tiêu từ 15 tới 40 (nhân COUNT_SCALE) có ít nhất 8 hình vừa (không tính đá).
	var k := DifficultyCurve.COUNT_SCALE
	for n in range(15 * k, 40 * k + 1):
		var kinds := {}
		for kind in Motifs.KINDS:
			for v in Motifs.variants(kind):
				var per := float(v["cells"].size()) / float(n)
				if per >= Config.MOTIF_FILL_MIN and per <= Config.MOTIF_FILL_MAX:
					kinds[kind] = true
		t.ok(kinds.size() >= 8, "%d khối: %d hình vừa" % [n, kinds.size()])


func test_symmetric_tiling(t: T) -> void:
	var tried := 0
	for kind in Motifs.KINDS:
		for v in Motifs.variants(kind):
			var w: int = v["w"]
			var h: int = v["h"]
			var sym_h: bool = v["sym_h"]
			var sym_v: bool = v["sym_v"]
			var cells: Array[Vector2i] = []
			cells.assign(v["cells"])
			var n := roundi(cells.size() / ((Config.MOTIF_FILL_MIN + Config.MOTIF_FILL_MAX) / 2.0))
			var rng := Gen._rng(n, tried)
			var stones := Gen._place_stones_sym(cells, w, h, 2, sym_h, sym_v, rng)
			var groups := Gen._tile_sym(cells, w, h, stones, n, sym_h, sym_v, rng)
			tried += 1
			var tag := "%s %dx%d" % [kind, w, h]
			if groups.is_empty():
				t.fail("%s: không lát được %d khối" % [tag, n])
				continue
			t.ok(absi(groups.size() - n) <= 2, "%s: %d khối ~ %d" % [tag, groups.size(), n])
			var stone_set := _set_of(stones)
			for s in stones:
				t.ok(not sym_h or stone_set.has(Vector2i(w - 1 - s.x, s.y)), "%s: đá đối xứng trái phải" % tag)
				t.ok(not sym_v or stone_set.has(Vector2i(s.x, h - 1 - s.y)), "%s: đá đối xứng trên dưới" % tag)
			# Khối phủ đúng các ô của hình trừ đá, không chồng nhau, liền mảng, tối đa BLOCK_CAP ô.
			var covered := {}
			var sigs := {}
			for g in groups:
				t.ok(g.size() >= 1 and g.size() <= Gen.BLOCK_CAP, "%s: khối %d ô" % [tag, g.size()])
				t.ok(LevelData.connected(_set_of(g)), "%s: khối liền mảng" % tag)
				var sorted: Array = g.duplicate()
				sorted.sort()
				sigs[str(sorted)] = true
				for c in g:
					t.ok(not covered.has(c), "%s: ô %s thuộc một khối" % [tag, str(c)])
					covered[c] = true
			t.eq(covered.size() + stones.size(), cells.size(), "%s: khối và đá phủ kín hình" % tag)
			# Ảnh lật của mỗi khối cũng là một khối.
			for g in groups:
				for axis in ["h", "v"]:
					if (axis == "h" and not sym_h) or (axis == "v" and not sym_v):
						continue
					var m: Array = []
					for c: Vector2i in g:
						m.append(Vector2i(w - 1 - c.x, c.y) if axis == "h" else Vector2i(c.x, h - 1 - c.y))
					m.sort()
					t.ok(sigs.has(str(m)), "%s: khối lật qua trục %s vẫn là một khối" % [tag, axis])
	t.ok(tried >= 50, "đã thử %d biến thể" % tried)


func test_picker_uses_every_kind(t: T) -> void:
	var seen := {}
	for id in range(14, 14 + Motifs.KINDS.size() * 4):
		for base in [18, 26, 34]:
			var n: int = base * DifficultyCurve.COUNT_SCALE
			var v := Gen._pick_motif(id, 0, n, 0, Gen._rng(id, n))
			t.ok(not v.is_empty(), "L%d %d khối có hình" % [id, n])
			if not v.is_empty():
				seen[v["kind"]] = true
	for kind in Motifs.KINDS:
		t.ok(seen.has(kind), "có dùng hình %s" % kind)
	# Level liền nhau ra hình khác nhau (cùng số khối, cùng seed).
	var prev := ""
	var same := 0
	for id in range(14, 101):
		var kind: String = Gen._pick_motif(id, 0, 26 * DifficultyCurve.COUNT_SCALE, 0, Gen._rng(id, 0)).get("kind", "")
		if kind == prev:
			same += 1
		prev = kind
	t.eq(same, 0, "không có hai level liền nhau cùng hình")
