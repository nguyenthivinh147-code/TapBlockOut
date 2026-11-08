extends RefCounted
## Prism light when a crystal block grinds through its bar (`src/ui/crystal_grind.gd`).
const T := preload("res://tests/t.gd")
const BoardState := preload("res://src/core/board_state.gd")
const CrystalGrind := preload("res://src/ui/crystal_grind.gd")
const SCENE := "res://scenes/board_view.tscn"


func _b(id: String, color: String, cells: Array) -> Dictionary:
	return {"id": id, "color": color, "cells": cells, "ice": 0, "chained_by": "", "inner_color": "", "fog": false}


func _lv(blocks: Array) -> Dictionary:
	return {"id": 7, "w": 6, "h": 8, "hard": false, "min_taps": 0, "moves": 30, "seed": 0, "stones": [], "pulse_sides": [], "blocks": blocks}


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make(board: BoardState, specials: Array) -> Control:
	var v := (load(SCENE) as PackedScene).instantiate() as Control
	_tree().root.add_child(v)
	v.setup(board, Vector2(664, 752))
	v.set_specials(specials)
	return v


func _fx_named(v: Control, prefix: String) -> Array:
	var out: Array = []
	for ch in v.get_node("Fx").get_children():
		if str(ch.name).begins_with(prefix) and not ch.is_queued_for_deletion():
			out.append(ch)
	return out


func _until(cond: Callable, limit_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + limit_ms
	while not cond.call() and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	return cond.call()


func test_crystal_grind_lights_up_under_the_bits_and_cleans_up(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 3], [2, 4]]), _b("c", "blue", [[4, 6]])]))
	var v := _make(board, ["a"])
	await _tree().process_frame
	v.apply_result(board.tap("a"))
	t.eq(_fx_named(v, "CrystalGrind").size(), 0, "chưa có ánh lăng kính khi khối còn đang lao")
	t.ok(await _until(func() -> bool: return not _fx_named(v, "CrystalGrind").is_empty(), 1500), "tới thanh thì ánh lăng kính hiện")
	var fx: Array = _fx_named(v, "CrystalGrind")
	var shards: Array = _fx_named(v, "Shards")
	t.eq(fx.size(), 1, "một cụm ánh lăng kính cho khối crystal")
	if fx.size() == 1 and shards.size() == 1:
		var light: Control = fx[0]
		t.ok(light.top_level, "ánh lăng kính ló ra ngoài vùng cắt của bàn")
		t.ok(light.get_index() < (shards[0] as Node).get_index(), "vào cây trước vụn kẹo nên vụn bay đè lên ánh sáng")
		t.ok(light.life() < 1.2, "gọn: tắt hẳn trong vòng 1,2 giây")
		var streams: Array = light.streams()
		t.eq(streams.size(), 3, "tia lửa hai bên mép khối và kim tuyến")
		t.ok(streams.all(func(p: CPUParticles2D) -> bool: return p.emitting), "tia lửa, kim tuyến phun suốt lúc khối đang qua thanh")
		t.ok(await _until(func() -> bool: return streams.all(func(p: CPUParticles2D) -> bool: return not p.emitting), 1500), "khối qua hết thì thôi phun")
	t.ok(await _until(func() -> bool: return _fx_named(v, "CrystalGrind").is_empty(), 2500), "ánh lăng kính tự xoá khi xong")
	v.queue_free()


func test_plain_block_has_no_prism_light(t: T) -> void:
	var board := BoardState.new(_lv([_b("a", "yellow", [[2, 3], [2, 4]]), _b("c", "blue", [[4, 6]])]))
	var v := _make(board, [])
	await _tree().process_frame
	v.apply_result(board.tap("a"))
	t.ok(await _until(func() -> bool: return not _fx_named(v, "Shards").is_empty(), 1500), "khối thường vẫn nghiền")
	t.eq(_fx_named(v, "CrystalGrind").size(), 0, "khối thường không có ánh lăng kính")
	v.queue_free()
