extends RefCounted
## Candy-rain curtain (src/ui/candy_curtain.gd) used by Home's Play and the No Lives refill.
const T := preload("res://tests/t.gd")
const CandyCurtain := preload("res://src/ui/candy_curtain.gd")
const BombCurtain := preload("res://src/ui/bomb_curtain.gd")
const Config := preload("res://src/config.gd")

const SCREEN := Vector2(886, 1920)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _host() -> Control:
	var host := Control.new()
	host.size = SCREEN
	_tree().root.add_child(host)
	return host


func _candies(curtain: Control) -> Array[TextureRect]:
	var out: Array[TextureRect] = []
	for c in curtain.get_children():
		if c is TextureRect:
			out.append(c)
	return out


func test_sprites_exist(t: T) -> void:
	t.eq(CandyCurtain.CANDY_TEX.size(), CandyCurtain.BACKING.size(), "mỗi loại kẹo một màu nền")
	for p in CandyCurtain.CANDY_TEX:
		t.ok(ResourceLoader.exists(p), "có sprite " + p)


## One kind per curtain, never the same kind twice in a row; `kind` set before adding forces it.
func test_one_random_kind_per_curtain(t: T) -> void:
	var host := _host()
	var prev := -1
	for i in 12:
		var curtain: Control = CandyCurtain.new()
		host.add_child(curtain)
		var k: int = curtain.kind
		t.ok(k >= 0 and k < CandyCurtain.CANDY_TEX.size(), "loại hợp lệ")
		t.ok(k != prev, "không trùng loại lần trước (lần %d)" % i)
		var tex: Texture2D = load(CandyCurtain.CANDY_TEX[k])
		t.ok(_candies(curtain).all(func(n: TextureRect) -> bool: return n.texture == tex), "mọi viên cùng một loại")
		t.eq((curtain.get_node("Backing") as ColorRect).color, CandyCurtain.BACKING[k], "nền theo loại kẹo")
		prev = k
		curtain.free()
	var forced: Control = CandyCurtain.new()
	forced.kind = 3
	host.add_child(forced)
	t.eq(forced.kind, 3, "đặt kind trước thì giữ")
	host.free()


## A candy that lands later draws behind every candy that landed before it (design.md mục 2, 2026-11-13); the
## backing stays behind them all. Landing order is close()'s: rows from the bottom, each row in its shuffled order.
func test_later_candy_draws_behind(t: T) -> void:
	var host := _host()
	for curtain: Control in [CandyCurtain.new(), BombCurtain.new()]:
		host.add_child(curtain)
		var order: Array[TextureRect] = []
		for row: Array in curtain._rows:
			for e: Dictionary in row:
				order.append(e.node)
		t.ok(order.size() > 10, "có kẹo")
		t.eq(curtain.get_node("Backing").get_index(), 0, "nền dưới mọi viên")
		var behind := 0
		for i in range(1, order.size()):
			if order[i].get_index() < order[i - 1].get_index():
				behind += 1
		t.eq(behind, order.size() - 1, "viên chạm sau vẽ sau viên chạm trước (%s)" % curtain.get_script().resource_path)
		curtain.free()
	host.free()


## close() drops the candies bottom row first and leaves every one at rest on its slot; the candies alone reach
## every point of the screen and the backing fills it. open() drops the pile off the screen and frees the curtain.
func test_close_fills_from_bottom_then_open_frees(t: T) -> void:
	var host := _host()
	var curtain: Control = CandyCurtain.new()
	host.add_child(curtain)
	t.eq(curtain.mouse_filter, Control.MOUSE_FILTER_STOP, "chặn chạm")
	var candies := _candies(curtain)
	var cols := int(Config.CONTENT.candy_curtain_cols)
	t.ok(candies.size() >= cols * int(SCREEN.y / (SCREEN.x / cols)), "đủ kẹo phủ màn (%d viên)" % candies.size())
	t.ok(candies.all(func(n: TextureRect) -> bool: return n.position.y + n.size.y <= 0.0), "kẹo bắt đầu trên màn")
	var rows: Array = curtain._rows
	t.ok(float(rows[0][0].slot.y) > float(rows[-1][0].slot.y), "hàng đầu tiên là hàng đáy")
	var t0 := Time.get_ticks_msec()
	curtain.close()
	# Partway through, the bottom row has landed and the top row has not.
	var bottom_first := false
	while Time.get_ticks_msec() - t0 < 3000:
		await _tree().process_frame
		var low: TextureRect = rows[0][0].node
		var high: TextureRect = rows[-1][-1].node
		if (low.position + low.pivot_offset).is_equal_approx(rows[0][0].slot):
			bottom_first = not (high.position + high.pivot_offset).is_equal_approx(rows[-1][-1].slot)
			break
	t.ok(bottom_first, "hàng đáy chạm chỗ trước hàng trên cùng")
	t.ok(await _wait(func() -> bool: return not curtain._filling, 3500), "khép trong 3,5 giây")
	for row: Array in rows:
		for e: Dictionary in row:
			var n: TextureRect = e.node
			if not (n.position + n.pivot_offset).is_equal_approx(e.slot):
				t.fail("%s chưa về chỗ: %s / %s" % [n.name, n.position + n.pivot_offset, e.slot])
	var backing: ColorRect = curtain.get_node("Backing")
	t.ok(backing.position.y <= 0.0 and backing.position.y + backing.size.y >= SCREEN.y
		and backing.size.x >= SCREEN.x, "nền phủ kín màn")
	# Every point is within the circle inscribed in some candy's sprite box (half its size): the sparse layout
	# (2026-11-13) lets the backing show between candies, but no wide hole opens.
	var reach: float = curtain._candy * 0.5
	var gaps := 0
	for gy in range(0, int(SCREEN.y) + 1, 40):
		for gx in range(0, int(SCREEN.x) + 1, 40):
			var p := Vector2(gx, gy)
			if not candies.any(func(n: TextureRect) -> bool:
					return (n.position + n.pivot_offset).distance_to(p) <= reach * n.scale.x):
				gaps += 1
	t.eq(gaps, 0, "kẹo phủ mọi điểm của màn")
	curtain.open()
	var ref: WeakRef = weakref(curtain)
	t.ok(await _wait(func() -> bool: return ref.get_ref() == null, 4000), "mở xong thì tự giải phóng")
	host.free()


## The Special Bomb rain: the bomb body sits low in its sprite box (the fuse takes the top), so the bombs are drawn
## bigger than the candies (Config.CONTENT.bomb_curtain_size) until, at rest, their opaque pixels alone cover every
## point of the screen and none of the backing shows (2026-11-13). Each point is mapped into every bomb's sprite
## through the node's transform (tilt, scale) and must land on an opaque pixel of one of them.
func test_bombs_cover_screen(t: T) -> void:
	var img: Image = (load(BombCurtain.BOMB_TEX) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var host := _host()
	var curtain: Control = BombCurtain.new()
	host.add_child(curtain)
	curtain.close()
	t.ok(await _wait(func() -> bool: return not curtain._filling, 4000), "khép trong 4 giây")
	var bombs := _candies(curtain)
	var holes: Array[Vector2] = []
	for gy in range(0, int(SCREEN.y) + 1, 20):
		for gx in range(0, int(SCREEN.x) + 1, 20):
			var p := Vector2(gx, gy)
			var hit := false
			for n in bombs:
				var local: Vector2 = n.get_transform().affine_inverse() * p
				var uv := local / n.size * Vector2(img.get_size())
				if uv.x >= 0.0 and uv.y >= 0.0 and uv.x < img.get_width() and uv.y < img.get_height() \
						and img.get_pixelv(Vector2i(uv)).a > 0.5:
					hit = true
					break
			if not hit:
				holes.append(p)
	t.eq(holes.size(), 0, "bom che kín màn, không lộ nền (lỗ đầu: %s)" % str(holes.slice(0, 5)))
	# Bigger bombs, fewer rows than the candies (Config.CONTENT.bomb_curtain_row_gap, 2026-11-13).
	var candy: Control = CandyCurtain.new()
	host.add_child(candy)
	t.ok(curtain._rows.size() < candy._rows.size(),
		"ít hàng bom hơn hàng kẹo (%d / %d)" % [curtain._rows.size(), candy._rows.size()])
	candy.free()
	curtain.free()
	host.free()


func _wait(cond: Callable, ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()
