extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const CandyShards := preload("res://src/ui/candy_shards.gd")
const CandyFrame := preload("res://src/ui/candy_frame.gd")
const BoardView := preload("res://src/ui/board_view.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array) -> Dictionary:
	return {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}


func _lv(blocks: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {"id": 7, "w": 6, "h": 8, "hard": false, "min_taps": 0, "moves": 30, "seed": 0, "stones": [], "pulse_sides": [], "blocks": blocks}
	d.merge(extra, true)
	return d


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make(board: BoardState) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_tree().root.add_child(v)
	v.setup(board, Vector2(664, 752))
	return v


func _wait_done(v: Control, limit_ms: int = 2500) -> bool:
	var state := {"done": false}
	v.animation_done.connect(func() -> void: state["done"] = true, CONNECT_ONE_SHOT)
	var deadline := Time.get_ticks_msec() + limit_ms
	while not state["done"] and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	return state["done"]


func _frames(n: int = 3) -> void:
	for i in n:
		await _tree().process_frame


func _fx_named(v: Control, prefix: String) -> Array:
	var out: Array = []
	for ch in v.get_node("Fx").get_children():
		if str(ch.name).begins_with(prefix) and not ch.is_queued_for_deletion():
			out.append(ch)
	return out


func _home(v: Control, id: String) -> Vector2:
	var n: Control = v.block_node(id)
	return v.cell_center(n.origin_cell) - Vector2(0.5, 0.5) * v.cell_size()


func test_exit_grinds_through_the_bar_and_cleans_up(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 3], [2, 4]]), _b("c", "blue", [[4, 6]])]))
	var v := _make(board)
	await _frames()
	var node: Control = v.block_node("a")
	# giây tới thanh theo đường lao (còn khối c nên có hãm); khối 2 ô còn trôi qua thanh 2 / GRIND_SPEED giây
	var steps: float = v._cells_to_bar(node, Vector2.UP)
	var plan: Array = v._exit_plan(steps * v.cell_size(), _dash(steps))
	v.apply_result(board.tap("a"))
	t.eq(v.block_count(), 1, "khối rời bàn ngay khi chạm")
	t.ok(v.block_at(v.cell_center(Vector2i(2, 3))) == "", "ô đã trống ngay khi chạm")
	t.eq(_fx_named(v, "Shards").size(), 0, "chưa nghiền khi còn đang lao")
	await _tree().create_timer(float(plan[0]) + float(plan[1]) + 0.1).timeout
	var bursts := _fx_named(v, "Shards")
	t.eq(bursts.size(), 1, "tới thanh thì bắt đầu nghiền")
	t.ok(is_instance_valid(node) and (node.get_parent() as Control).clip_contents, "khối trôi vào vùng cắt ở mặt trong thanh")
	t.ok(_fx_named(v, "Sparkles").size() >= 1, "có sao lấp lánh")
	t.ok(await _wait_done(v), "báo xong hoạt ảnh")
	await _frames(2)
	t.ok(not is_instance_valid(node), "khối đã xoá")
	if bursts.size() == 1 and is_instance_valid(bursts[0]):
		t.ok(bursts[0].top_level, "vụn thoát khỏi vùng cắt của bàn")
		# khối rộng 1 ô ra GRIND_BITS mảnh to và GRIND_SMALL mảnh nhỏ
		t.eq(bursts[0].shard_count(), BoardView.GRIND_BITS + BoardView.GRIND_SMALL, "đủ mảnh to và mảnh nhỏ")
	await _tree().create_timer(CandyShards.BIT_LIFE.y + 0.2).timeout
	t.eq(_fx_named(v, "Shards").size(), 0, "vụn tự dọn khi hết đời")
	v.queue_free()


func test_grind_bits_scale_with_the_block_width(t: T) -> void:
	# [ô của khối vàng (thoát lên trên), bề ngang dọc thanh]; khối dài theo hướng đi không ra thêm
	for entry: Array in [[[[2, 4]], 1], [[[2, 3], [2, 4], [2, 5]], 1], [[[2, 3], [3, 3], [2, 4], [3, 4]], 2],
			[[[1, 2], [2, 2], [3, 2], [1, 3], [2, 3], [3, 3]], 3]]:
		var cells: Array = entry[0]
		var k := 1.0 + BoardView.GRIND_BITS_EXTRA * float(int(entry[1]) - 1)
		var want := roundi(float(BoardView.GRIND_BITS) * k) + roundi(float(BoardView.GRIND_SMALL) * k)
		var board := BoardState.new(_lv([_b("a", "yellow", cells)]))
		var v := _make(board)
		await _frames()
		v.apply_result(board.tap("a"))
		t.ok(await _wait_done(v), "báo xong hoạt ảnh (khối %d ô)" % cells.size())
		var bursts := _fx_named(v, "Shards")
		t.eq(bursts.size(), 1, "một chỗ chứa khối vuông (khối %d ô)" % cells.size())
		if bursts.size() == 1:
			t.eq(bursts[0].shard_count(), want, "%d mảnh cho khối rộng %d ô (%d ô)" % [want, entry[1], cells.size()])
		v.queue_free()
		await _frames(1)


func test_grind_bit_count_follows_the_exit_side(t: T) -> void:
	var v := _make(BoardState.new(_lv([_b("a", "yellow", [[2, 4]])])))
	var row := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	t.eq(v._grind_counts(row, Vector2.RIGHT), Vector2i(15, 10), "hàng 3 ô thoát sang phải: rộng 1 ô, 15 to 10 nhỏ")
	t.eq(v._grind_counts([Vector2i(0, 0), Vector2i(1, 0)], Vector2.UP), Vector2i(23, 15), "rộng 2 ô: thêm 0,5 lần, 22,5 làm tròn lên 23")
	t.eq(v._grind_counts(row, Vector2.UP), Vector2i(30, 20), "hàng 3 ô thoát lên: rộng 3 ô, thêm 2 × 0,5 lần")
	var ell := [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	t.eq(v._grind_counts(ell, Vector2.DOWN), Vector2i(30, 20), "khối chữ L: tính mọi cột khối phủ, không chỉ hàng đầu")
	v.queue_free()


## Máy rung suốt lúc khối nghiền qua thanh, không chỉ một lần lúc chạm thanh; khối dài theo hướng đi rung lâu hơn.
func test_grind_vibrates_while_the_block_passes(t: T) -> void:
	var sfx: Node = _tree().root.get_node("Sfx")
	var was_on: bool = sfx.haptics_on
	sfx.haptics_on = true
	var counts: Array[int] = []
	# khối thoát lên trên: 1 ô, rồi 3 ô dọc (qua thanh lâu gấp 3)
	for cells: Array in [[[2, 4]], [[2, 3], [2, 4], [2, 5]]]:
		var board := BoardState.new(_lv([_b("a", "yellow", cells)]))
		var v := _make(board)
		await _frames()
		var before: int = sfx.haptic_count
		v.apply_result(board.tap("a"))
		t.ok(await _wait_done(v), "báo xong hoạt ảnh (khối %d ô)" % cells.size())
		counts.append(int(sfx.haptic_count) - before)
		v.queue_free()
		await _frames(1)
	sfx.haptics_on = was_on
	# 1 ô qua thanh 1 / GRIND_SPEED giây: rung lúc chạm thanh (sfx_shatter) và thêm nhịp trong lúc qua
	t.ok(counts[0] >= 2, "khối 1 ô rung hơn một lần (%d)" % counts[0])
	# trôi qua thanh hơn 3 ô một chút (mặt trong thanh nằm ngoài mép bàn); không rung mỗi khung
	var most := 2 + ceili(3.5 / BoardView.GRIND_SPEED / BoardView.GRIND_HAPTIC_EVERY)
	t.ok(counts[1] >= counts[0] + 2 and counts[1] <= most, "khối 3 ô dọc rung suốt lúc qua thanh (%d, tối đa %d)" % [counts[1], most])


## Giây nhanh dần của khối cách thanh `steps` ô, như _anim_exit().
func _dash(steps: float) -> float:
	return clampf(BoardView.SLIDE_MIN + BoardView.SLIDE_PER_CELL * steps, BoardView.SLIDE_MIN, BoardView.SLIDE_TIME)


## Quãng khối thoát đã đi ở giây `s` theo đường `plan` của _exit_plan(), px.
func _exit_at(v: Control, n: Control, plan: Array, s: float) -> float:
	v._exit_step(s, n, Vector2.ZERO, Vector2.UP, Vector2.ZERO, plan[0], plan[1], plan[2])
	return -n.position.y


func test_exit_slows_down_into_the_bar(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 7]])]))
	var v := _make(board)
	await _frames()
	var n: Control = v.block_node("a")
	var cell: float = v.cell_size()
	var grind := BoardView.GRIND_SPEED * cell
	for steps: int in [0, 3, 7, 18]:
		var travel := (float(steps) + CandyFrame.gap("up")) * cell
		var dash := _dash(float(steps))
		var plan: Array = v._exit_plan(travel, dash)
		var end: float = plan[0] + plan[1]
		t.near(_exit_at(v, n, plan, end), travel, 0.01, "%d ô: tới đúng mặt trong của thanh" % steps)
		var last := 0.0
		var steady := true
		for i in 41:
			var d := _exit_at(v, n, plan, end * float(i) / 40.0)
			steady = steady and d >= last - 0.001
			last = d
		t.ok(steady, "%d ô: không lùi lại" % steps)
		# đo tốc độ qua 0,2 ms: đường dài hãm gắt nên khoảng đo dài hơn sẽ lệch
		var arrive := (_exit_at(v, n, plan, end) - _exit_at(v, n, plan, end - 0.0002)) / 0.0002
		t.ok(arrive <= grind * 1.03, "%d ô: chạm thanh không nhanh hơn lúc nghiền (%.0f)" % [steps, arrive])
		if steps >= 3:
			t.near(arrive, grind, grind * 0.03, "%d ô: chạm thanh đúng tốc độ nghiền" % steps)
			var top := (_exit_at(v, n, plan, plan[0]) - _exit_at(v, n, plan, plan[0] - 0.0002)) / 0.0002
			if steps >= 7:
				t.ok(top > grind * 1.5, "%d ô: lao nhanh rồi mới chậm lại (%.0f)" % [steps, top])
				t.near(float(plan[1]), BoardView.EXIT_BRAKE, 0.0001, "%d ô: hãm trọn EXIT_BRAKE" % steps)
			else:
				# hãm EXIT_BRAKE cần quãng chừng 4 ô; gần hơn thì không đủ đường để hãm
				t.near(top, grind, grind * 0.03, "%d ô: sát thanh, nhanh dần tới tốc độ nghiền (%.0f)" % [steps, top])
				var mid := float(plan[0]) + float(plan[1]) * 0.5
				var cruise := (_exit_at(v, n, plan, mid) - _exit_at(v, n, plan, mid - 0.0002)) / 0.0002
				t.near(cruise, grind, grind * 0.03, "%d ô: sát thanh, rồi đi đều tới thanh (%.0f)" % [steps, cruise])
		var fast: Array = v._exit_plan(travel, dash, 0.0)
		t.near(float(fast[1]), 0.0, 0.0001, "%d ô: không hãm thì không có đoạn chậm dần" % steps)
		t.near(float(fast[2]), 2.0 * travel / dash, 0.01, "%d ô: không hãm thì nhanh dần tới tận thanh như cũ" % steps)
	v.queue_free()


func test_last_block_does_not_brake(t: T) -> void:
	# hai bàn chạy song song cùng quãng đường: một bàn chỉ còn khối này, một bàn còn khối khác
	var one := BoardState.new(_lv([_b("a", "yellow", [[2, 3]])]))
	var two := BoardState.new(_lv([_b("a", "yellow", [[2, 3]]), _b("c", "blue", [[4, 6]])]))
	var last := _make(one)
	var other := _make(two)
	await _frames()
	var nodes: Array = [last.block_node("a"), other.block_node("a")]
	last.apply_result(one.tap("a"))
	other.apply_result(two.tap("a"))
	var start := Time.get_ticks_msec()
	var reached: Array = [-1, -1]
	while (reached[0] < 0 or reached[1] < 0) and Time.get_ticks_msec() - start < 1000:
		await _tree().process_frame
		for i in 2:
			# khối tới trước bị xoá khi nghiền xong, trước lúc khối kia tới: kiểm còn sống trước khi gán vào biến có kiểu
			if reached[i] >= 0 or not is_instance_valid(nodes[i]):
				continue
			var n: Control = nodes[i]
			if (n.get_parent() as Control).clip_contents:
				reached[i] = Time.get_ticks_msec() - start
	t.ok(reached[0] >= 0 and reached[1] >= 0, "cả hai khối tới thanh")
	t.ok(reached[0] + 60 < reached[1], "khối cuối không hãm nên tới thanh sớm hơn (%d ms so với %d ms)" % reached)
	last.queue_free()
	other.queue_free()


func test_grind_bits_are_rounded_with_a_thin_rim(t: T) -> void:
	var at := Vector2(0.5, 0.5)
	var poly: PackedVector2Array = CandyShards._rounded_square(at, 0.15, 0.3)
	t.eq(poly.size(), 4 * CandyShards.BIT_ARC, "mỗi góc là một cung nhiều đỉnh")
	var far := 0.0
	for p in poly:
		far = maxf(far, p.distance_to(at))
	t.ok(far < 0.15 * 0.95, "góc đã bo, không còn đỉnh nhọn ở nửa đường chéo (%.3f)" % far)
	t.ok(far > 0.15 * 0.75, "vẫn ra hình vuông chứ chưa thành tròn (%.3f)" % far)
	var holder := Node.new()
	_tree().root.add_child(holder)
	var bits: Control = CandyShards.grinder(holder, [Vector2i.ZERO], 42.0, ThemeKit.block_ramp("yellow"))
	var rng := RandomNumberGenerator.new()
	bits.bit(at, Vector2(100, 100), Vector2.RIGHT, rng)
	bits.bit(at, Vector2(100, 100), Vector2.RIGHT, rng, true)
	bits.close()
	t.eq(bits.shard_count(), 2, "một mảnh to, một mảnh nhỏ")
	t.ok(bits._shards[0].rim < 1.0, "viền mặt gãy hẹp hơn mảnh thường")
	var reach := func(s: RefCounted) -> float:
		var far_px := 0.0
		for p: Vector2 in s.ring:
			far_px = maxf(far_px, p.length())
		return far_px
	for i in range(1, bits.shard_count()):
		t.ok(reach.call(bits._shards[i]) < reach.call(bits._shards[0]), "mảnh nhỏ nhỏ hơn mảnh to")
	holder.queue_free()


func test_bar_reacts_to_the_hit(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 3]])]))
	var v := _make(board)
	await _frames()
	var bar: ColorRect = v.get_node("Frame")._bars["up"]
	var m: ShaderMaterial = bar.material
	var home: Vector2 = bar.position
	v.apply_result(board.tap("a"))
	await _tree().create_timer(0.40).timeout
	var hit_t: float = m.get_shader_parameter("hit_t")
	t.ok(hit_t < 1.0, "sóng sáng đang chạy")
	await _tree().create_timer(0.5).timeout
	t.near(float(m.get_shader_parameter("hit_t")), 1.0, 0.001, "sóng đã tan")
	t.near(float(m.get_shader_parameter("pop")), 0.0, 0.001, "mũi tên về cỡ cũ")
	t.ok(bar.position.distance_to(home) < 0.5, "thanh về chỗ cũ")
	v.queue_free()


func test_collision_moves_both_blocks_and_restores_them(t: T) -> void:
	# a đi lên, đụng b; c nằm ngay sau b, d sau c, e sau d (dư chấn chỉ tới 2 khối)
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 6]]), _b("b", "blue", [[2, 4]]), _b("c", "blue", [[2, 3]]),
		_b("d", "blue", [[2, 2]]), _b("e", "blue", [[2, 1]])]))
	var v := _make(board)
	await _frames()
	var homes := {}
	for id in ["a", "b", "c", "d", "e"]:
		homes[id] = _home(v, id)
	v.apply_result(board.tap("a"))
	var moved := {}
	var deadline := Time.get_ticks_msec() + 600
	var saw_wobble := false
	var saw_chips := false
	while Time.get_ticks_msec() < deadline:
		await _tree().process_frame
		for id in homes:
			var n: Control = v.block_node(id)
			if n.position.distance_to(homes[id]) > 0.5:
				moved[id] = true
			if id == "a" and n.scale != Vector2.ONE:
				saw_wobble = true
		saw_chips = saw_chips or not _fx_named(v, "Shards").is_empty()
	t.ok(saw_wobble, "khối đi va nhún")
	t.ok(saw_chips, "có vụn kẹo")
	t.ok(moved.has("b"), "khối bị va giật lùi")
	t.ok(moved.has("c"), "dư chấn lan sang khối sau")
	t.ok(moved.has("d"), "dư chấn lan tiếp")
	t.ok(not moved.has("e"), "dư chấn dừng sau 2 khối")
	await _tree().create_timer(0.4).timeout
	for id in homes:
		var n: Control = v.block_node(id)
		t.ok(n.position.distance_to(homes[id]) < 0.01, "%s về đúng ô" % id)
		t.eq(n.scale, Vector2.ONE, "%s về đúng cỡ" % id)
	t.eq(v.block_node("a").pivot_offset, v.block_node("a").size * 0.5, "tâm xoay về giữa khối")
	v.queue_free()


func test_repeated_hits_do_not_drift(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 6]]), _b("b", "blue", [[2, 3]])], {"moves": 30}))
	var v := _make(board)
	await _frames()
	var home := _home(v, "b")
	for i in 6:
		v.apply_result(board.tap("a"))
		await _tree().create_timer(0.05).timeout
	t.ok(await _wait_done(v), "xong chuỗi chạm nhanh")
	await _tree().create_timer(0.4).timeout
	t.ok(v.block_node("b").position.distance_to(home) < 0.01, "khối bị va không trôi khỏi ô")
	v.queue_free()


func test_stone_and_closed_gate_hit_only_the_candy(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 6]]), _b("b", "blue", [[4, 3]])], {"stones": [[2, 3]]}))
	var v := _make(board)
	await _frames()
	var r := board.tap("a")
	t.eq(r["kind"], "blocked", "bị đá chặn")
	var node: Control = v.block_node("a")
	v.apply_result(r)
	var saw := false
	var deadline := Time.get_ticks_msec() + 400
	while Time.get_ticks_msec() < deadline:
		await _tree().process_frame
		saw = saw or node.scale != Vector2.ONE
	t.ok(saw, "khối kẹo nhún khi đụng đá")
	t.ok(await _wait_done(v, 800) or not v.is_animating(), "đụng đá xong")
	v.queue_free()

	var board2 := BoardState.new(_lv([_b("a", "yellow", [[2, 3]])], {"pulse_sides": [{"side": "up", "open": false}]}))
	var v2 := _make(board2)
	await _frames()
	var bar: ColorRect = v2.get_node("Frame")._bars["up"]
	var r2 := board2.tap("a")
	t.eq(r2["kind"], "gate_closed", "cổng đóng chặn")
	var a2: Control = v2.block_node("a")
	var home2: Vector2 = a2.position
	v2.apply_result(r2)
	var furthest := 0.0
	var hit := false
	deadline = Time.get_ticks_msec() + 350
	while Time.get_ticks_msec() < deadline:
		await _tree().process_frame
		furthest = maxf(furthest, a2.position.distance_to(home2))
		var hit_t: Variant = (bar.material as ShaderMaterial).get_shader_parameter("hit_t")
		hit = hit or (hit_t != null and float(hit_t) < 1.0)
	t.ok(furthest > 2.9 * v2.cell_size(), "khối đi hết đường tới thanh, thanh gần sát mép bàn (%f)" % furthest)
	t.ok(hit, "thanh cổng phản ứng khi bị va")
	v2.queue_free()


func test_fog_block_chips_do_not_reveal_color(t: T) -> void:
	const BoardFx := preload("res://src/ui/board_fx.gd")
	var ramp := BoardFx.block_ramp({"color": "yellow", "is_fog_hidden": true})
	t.eq(ramp["face"], BoardFx.FOG_COLOR, "khối còn trong sương dùng màu xám")
	t.ok(ramp["stripe"] != ThemeKit.BLOCK_RAMPS["yellow"]["stripe"], "tông sáng cũng không lộ màu")
