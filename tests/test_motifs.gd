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
			# Vùng vẽ (kiểu cắt "template"): lật qua trục đối xứng thì vùng thành vùng (cùng tên hoặc một cặp tên), mỗi
			# mảnh vùng ít nhất 2 ô để không ép ra khối 1 ô.
			var regions: Dictionary = v["regions"]
			for axis in ["h", "v"]:
				if not bool(v["sym_" + axis]):
					continue
				var fwd := {}
				var back := {}
				var ok := true
				for c: Vector2i in regions:
					var m := Vector2i(w - 1 - c.x, c.y) if axis == "h" else Vector2i(c.x, h - 1 - c.y)
					var r: String = regions[c]
					var rm: String = regions[m]
					ok = ok and str(fwd.get(r, rm)) == rm and str(back.get(rm, r)) == r
					fwd[r] = rm
					back[rm] = r
				t.ok(ok, "%s vùng vẽ đối xứng qua trục %s" % [tag, axis])
			var by_region := {}
			for c: Vector2i in regions:
				if not by_region.has(regions[c]):
					by_region[regions[c]] = []
				by_region[regions[c]].append(c)
			for r in by_region:
				for size in _components(by_region[r]):
					t.ok(size >= 2, "%s vùng '%s' không có mảnh 1 ô" % [tag, r])


func test_arrows_point_four_ways(t: T) -> void:
	# Mũi tên lên và lật xuống; mũi tên ngang sang phải và lật sang trái.
	var up := Motifs.variants("arrow")
	t.eq(up.size(), Motifs.MOTIFS["arrow"]["sizes"].size() * 2, "mũi tên dọc: mỗi cỡ hai bản (lên, xuống)")
	var top: Array = up[0]["cells"]
	var down: Array = up[1]["cells"]
	t.ok(top.has(Vector2i(3, 0)) and down.has(Vector2i(3, int(up[1]["h"]) - 1)), "mũi nhọn ở đầu tương ứng")
	var side := Motifs.variants("arrow_side")
	t.eq(side.size(), Motifs.MOTIFS["arrow_side"]["sizes"].size() * 2, "mũi tên ngang: mỗi cỡ hai bản (phải, trái)")
	t.ok(bool(side[0]["sym_v"]) and not bool(side[0]["sym_h"]), "mũi tên ngang đối xứng trên dưới")


func test_every_size_band_has_choices(t: T) -> void:
	# Mọi số khối mục tiêu của level dùng hình vẽ tay từ L11 (gồm Daily Challenge) có ít nhất 8 hình vừa (không tính
	# đá); dưới 20 khối (L11-13) ít nhất 4 hình. L5 tới Config.EARLY_SHAPE_UNTIL chỉ lấy hình đặc, một trục đối xứng
	# (Gen._early_shape) với Config.EARLY_FILL_*: ít nhất 4 hình mỗi level.
	for id in range(DifficultyCurve.MOTIF_FROM, Config.EARLY_SHAPE_UNTIL + 1):
		var n := DifficultyCurve.block_count(id)
		var solid := {}
		for kind in Motifs.KINDS:
			for v in Motifs.variants(kind):
				var per := float(v["cells"].size()) / float(n)
				if per >= Config.EARLY_FILL_MIN and per <= Config.EARLY_FILL_MAX and Gen._early_shape(v):
					solid[kind] = true
		t.ok(solid.size() >= 4, "L%d (%d khối): %d hình đặc vừa %s" % [id, n, solid.size(), str(solid.keys())])
	var lo := 1 << 20
	var hi := 0
	for id in range(Config.EARLY_SHAPE_UNTIL + 1, DifficultyCurve.last_level() + 1):
		lo = mini(lo, DifficultyCurve.block_count(id))
		hi = maxi(hi, DifficultyCurve.block_count(id))
	for n in range(lo, hi + 1):
		var kinds := {}
		for kind in Motifs.KINDS:
			for v in Motifs.variants(kind):
				var per := float(v["cells"].size()) / float(n)
				if per >= Config.MOTIF_FILL_MIN and per <= Config.MOTIF_FILL_MAX:
					kinds[kind] = true
		t.ok(kinds.size() >= (4 if n < 20 else 8), "%d khối: %d hình vừa" % [n, kinds.size()])


func test_symmetric_tiling(t: T) -> void:
	var tried := 0
	var styles: Array = ["sym", "template"] + Gen.GEO_STYLES
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
			var style: String = styles[tried % styles.size()]
			var groups := Gen._tile_sym(cells, w, h, stones, n, sym_h, sym_v, rng, style, v["regions"])
			tried += 1
			var tag := "%s %dx%d %s" % [kind, w, h, style]
			if groups.is_empty():
				t.fail("%s: không lát được %d khối" % [tag, n])
				continue
			t.ok(absi(groups.size() - n) <= 2, "%s: %d khối ~ %d" % [tag, groups.size(), n])
			var stone_set := _set_of(stones)
			for s in stones:
				t.ok(not sym_h or stone_set.has(Vector2i(w - 1 - s.x, s.y)), "%s: đá đối xứng trái phải" % tag)
				t.ok(not sym_v or stone_set.has(Vector2i(s.x, h - 1 - s.y)), "%s: đá đối xứng trên dưới" % tag)
			# Khối phủ đúng các ô của hình trừ đá, không chồng nhau, liền mảng; cỡ khối không giới hạn.
			var covered := {}
			var sigs := {}
			for g in groups:
				t.ok(g.size() >= 1 and g.size() <= Config.BLOCK_MAX_CELLS, "%s: khối %d ô" % [tag, g.size()])
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


## Mỗi kiểu cắt có chủ đích (hình học, theo vùng vẽ) đi đúng quy luật của nó: hầu hết khối chỉ nối qua cạnh hợp kiểu
## (`Gen._edge_ok`); bộ sinh chỉ gộp tự do khi kẹt.
func test_cut_styles_follow_their_rule(t: T) -> void:
	var styles: Array = ["template"] + Gen.GEO_STYLES
	for style: String in styles:
		var blocks := 0
		var follow := 0
		for kind in Motifs.KINDS:
			var v: Dictionary = Motifs.variants(kind)[-1]
			var w: int = v["w"]
			var h: int = v["h"]
			var cells: Array[Vector2i] = []
			cells.assign(v["cells"])
			var n := roundi(cells.size() / 3.0)
			var none: Array[Vector2i] = []
			var groups := Gen._tile_sym(cells, w, h, none, n, v["sym_h"], v["sym_v"], Gen._rng(n, kind.length()), style,
				v["regions"])
			t.ok(not groups.is_empty(), "%s %s: lát được %d khối" % [style, kind, n])
			var ctx := {"style": style, "w": w, "h": h, "sym_h": v["sym_h"], "sym_v": v["sym_v"], "regions": v["regions"],
				"layer": Gen._layers(cells)}
			for g in groups:
				var set := _set_of(g)
				var ok := true
				for c: Vector2i in g:
					for dv in Gen.NEIGHBORS:
						if set.has(c + dv) and not Gen._edge_ok(c, c + dv, ctx):
							ok = false
				# Kiểu dải có móc (2026-11-10): dải bẻ góc một ô thành chữ L cũng đúng quy luật.
				if not ok and Gen.HOOK_STYLES.has(style):
					ok = Gen._hook_ok(Gen._shape_info(g), style)
				blocks += 1
				follow += int(ok)
		# Kiểu dải có móc hết cách gộp theo kiểu sớm hơn (móc ăn bớt ô lẻ) nên gộp tự do nhiều hơn ở cuối: 80%.
		var need := 0.8 if Gen.HOOK_STYLES.has(style) else 0.9
		t.ok(float(follow) >= need * blocks, "kiểu %s: %d/%d khối đúng quy luật" % [style, follow, blocks])


func test_picker_uses_every_kind(t: T) -> void:
	var seen := {}
	for id in range(14, 14 + Motifs.KINDS.size() * 4):
		for n in [16, 30, 42, 56]:
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
		var kind: String = Gen._pick_motif(id, 0, 45, 0, Gen._rng(id, 0)).get("kind", "")
		if kind == prev:
			same += 1
		prev = kind
	t.eq(same, 0, "không có hai level liền nhau cùng hình")
