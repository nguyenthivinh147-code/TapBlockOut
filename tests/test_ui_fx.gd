extends RefCounted
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const CandyShards := preload("res://src/ui/candy_shards.gd")
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
	return v.board_rect().position + Vector2(n.origin_cell) * v.cell_size()


func test_exit_grinds_through_the_bar_and_cleans_up(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 3], [2, 4]]), _b("c", "blue", [[4, 6]])]))
	var v := _make(board)
	await _frames()
	var node: Control = v.block_node("a")
	v.apply_result(board.tap("a"))
	t.eq(v.block_count(), 1, "khối rời bàn ngay khi chạm")
	t.ok(v.block_at(v.cell_center(Vector2i(2, 3))) == "", "ô đã trống ngay khi chạm")
	t.eq(_fx_named(v, "Shards").size(), 0, "chưa nghiền khi còn đang lao")
	await _tree().create_timer(0.30).timeout
	var bursts := _fx_named(v, "Shards")
	t.eq(bursts.size(), 1, "tới thanh thì bắt đầu nghiền")
	t.ok(is_instance_valid(node) and (node.get_parent() as Control).clip_contents, "khối trôi vào vùng cắt ở mặt trong thanh")
	t.ok(_fx_named(v, "Sparkles").size() >= 1, "có sao lấp lánh")
	t.ok(await _wait_done(v), "báo xong hoạt ảnh")
	await _frames(2)
	t.ok(not is_instance_valid(node), "khối đã xoá")
	if bursts.size() == 1 and is_instance_valid(bursts[0]):
		t.ok(bursts[0].top_level, "vụn thoát khỏi vùng cắt của bàn")
		# hai ô đi qua thanh, mỗi ô diện tích ra GRIND_BITS khối vuông
		t.ok(bursts[0].shard_count() >= 24, "đủ khối vuông nhỏ (%d)" % bursts[0].shard_count())
	await _tree().create_timer(1.3).timeout
	t.eq(_fx_named(v, "Shards").size(), 0, "vụn tự dọn khi hết đời")
	v.queue_free()


func test_bar_reacts_to_the_hit(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 3]])]))
	var v := _make(board)
	await _frames()
	var bar: ColorRect = v.get_node("Frame")._bars["up"]
	var m: ShaderMaterial = bar.material
	var home: Vector2 = bar.position
	v.apply_result(board.tap("a"))
	await _tree().create_timer(0.30).timeout
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
