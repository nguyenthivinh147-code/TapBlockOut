extends RefCounted
## Trạng thái một bàn cờ (kế hoạch mục 1.7). Logic thuần, không Node, không Platform.
## Khối trượt cứng theo hướng màu tới khi rời hẳn bàn. Quy ước ưu tiên khi chạm:
## xích > băng > đường bị chặn > cổng nhịp đóng > thoát (hoặc bóc lớp ngoài).

const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")

const STONE := "stone"
const STEP_CAP := 256

var _w: int = 0
var _h: int = 0
var _moves_left: int = 0
var _won: bool = false
var _blocks: Dictionary = {}  # id -> {color, cells, ice, chained_by, inner_color, fog, revealed}
var _order: Array[String] = []
var _stones: Array[Vector2i] = []
var _occ: Dictionary = {}  # Vector2i -> id khối, hoặc STONE
var _vacated: Dictionary = {}  # ô từng có khối, nay đã trống
var _gates: Dictionary = {}  # cạnh -> đang mở?
var _gate_segs: Dictionary = {}  # level nhiều cổng: cạnh -> [[màu, từ, tới), ...] (chỉ để vẽ khung)


func _init(level: Dictionary) -> void:
	if level.is_empty():
		return
	_w = int(level.get("w", 0))
	_h = int(level.get("h", 0))
	_moves_left = int(level.get("moves", 0))
	for raw in level.get("stones", []):
		var c := LevelData.cell_of(raw)
		_stones.append(c)
		_occ[c] = STONE
	for bd in level.get("blocks", []):
		var id := str(bd.get("id", ""))
		var cells: Array[Vector2i] = []
		for raw in bd.get("cells", []):
			cells.append(LevelData.cell_of(raw))
		var fog := bool(bd.get("fog", false))
		_blocks[id] = {
			"color": str(bd.get("color", "")),
			"dir": str(bd.get("dir", "")),
			"cells": cells,
			"ice": int(bd.get("ice", 0)),
			"chained_by": str(bd.get("chained_by", "")),
			"inner_color": str(bd.get("inner_color", "")),
			"fog": fog,
			"revealed": not fog,
		}
		_order.append(id)
		for c in cells:
			_occ[c] = id
	for p in level.get("pulse_sides", []):
		_gates[str(p.get("side", ""))] = bool(p.get("open", false))
	var segs: Variant = level.get("gates", {})
	if segs is Dictionary:
		for side in segs:
			var list: Array = []
			for s in segs[side]:
				list.append([str(s[0]), int(s[1]), int(s[2])])
			_gate_segs[str(side)] = list
	_update_reveal()
	_won = _blocks.is_empty()


func clone() -> BoardState:
	var c := BoardState.new({})
	c._w = _w
	c._h = _h
	c._moves_left = _moves_left
	c._won = _won
	for id in _blocks:
		c._blocks[id] = _blocks[id].duplicate()  # nông: mảng `cells` không bao giờ bị sửa
	c._order = _order.duplicate()
	c._stones = _stones
	c._occ = _occ.duplicate()
	c._vacated = _vacated.duplicate()
	c._gates = _gates.duplicate()
	c._gate_segs = _gate_segs
	return c


func width() -> int:
	return _w


func height() -> int:
	return _h


func stones() -> Array[Vector2i]:
	return _stones


## Cạnh có cổng nhịp -> đang mở?
func gates() -> Dictionary:
	return _gates.duplicate()


func gate_open(side: String) -> bool:
	return not _gates.has(side) or bool(_gates[side])


## Level nhiều cổng (Road Trip): cạnh -> [[màu, từ, tới), ...] theo ô dọc cạnh; rỗng với level thường (một màu
## mỗi cạnh). Chỉ để vẽ khung, luật chạm dùng `dir` của khối.
func gate_segments() -> Dictionary:
	return _gate_segs


func moves_left() -> int:
	return _moves_left


func add_moves(n: int) -> void:
	_moves_left += n


func remaining_count() -> int:
	return _blocks.size()


func is_won() -> bool:
	return _won


func is_out_of_moves() -> bool:
	return _moves_left <= 0 and not _won


func block_ids() -> Array[String]:
	return _order.duplicate()


func block_view(block_id: String) -> Dictionary:
	if not _blocks.has(block_id):
		return {}
	var b: Dictionary = _blocks[block_id]
	var chained: bool = b["chained_by"] != "" and _blocks.has(b["chained_by"])
	return {
		"id": block_id,
		"color": b["color"],
		"dir": LevelData.block_side(b),
		"cells": b["cells"].duplicate(),
		"ice": b["ice"],
		"chained": chained,
		"chained_by": b["chained_by"] if chained else "",
		"inner_color": b["inner_color"],
		"fog": b["fog"],
		"is_fog_hidden": b["fog"] and not b["revealed"],
	}


## Chạm không đổi trạng thái: trả `kind` mà tap() sẽ cho (rejected nếu không chạm được).
func peek(block_id: String) -> String:
	if _won or _moves_left <= 0 or not _blocks.has(block_id):
		return "rejected"
	return _evaluate(block_id)["kind"]


func can_exit(block_id: String) -> bool:
	if _won or not _blocks.has(block_id):
		return false
	var k: String = _evaluate(block_id)["kind"]
	return k == "exit" or k == "peel"


func hint() -> String:
	if _won:
		return ""
	for id in _order:
		if can_exit(id):
			return id
	return ""


func tap(block_id: String) -> Dictionary:
	var res := {"kind": "rejected", "id": block_id, "distance": 0, "blocker": "",
		"moves_left": _moves_left, "won": _won, "revealed": [] as Array[String]}
	if _won or _moves_left <= 0 or not _blocks.has(block_id):
		return res
	var ev := _evaluate(block_id)
	_moves_left -= 1
	var b: Dictionary = _blocks[block_id]
	match ev["kind"]:
		"crack":
			b["ice"] = int(b["ice"]) - 1
		"peel":
			b["color"] = b["inner_color"]
			b["inner_color"] = ""
		"exit":
			_remove(block_id)
	for side in _gates:
		_gates[side] = not _gates[side]
	res["kind"] = ev["kind"]
	res["distance"] = ev["distance"]
	res["blocker"] = ev["blocker"]
	res["revealed"] = _update_reveal()
	_won = _blocks.is_empty()
	res["moves_left"] = _moves_left
	res["won"] = _won
	return res


## Phá khối: xoá hẳn, không tốn MOVES, không đổi cổng nhịp. Đá không chọn được.
func smash(block_id: String) -> bool:
	if _won or not _blocks.has(block_id):
		return false
	_remove(block_id)
	_update_reveal()
	_won = _blocks.is_empty()
	return true


## Khoá trạng thái chơi được (khối còn lại, băng, lớp, cổng); không gồm MOVES. Dùng cho solver và test.
func state_key() -> String:
	var parts := PackedStringArray()
	for id in _order:
		var b: Dictionary = _blocks[id]
		parts.append("%s:%s%d%s" % [id, b["color"], b["ice"], b["inner_color"]])
	var sides := _gates.keys()
	sides.sort()
	for s in sides:
		parts.append("%s=%d" % [s, 1 if _gates[s] else 0])
	return "|".join(parts)


func _remove(id: String) -> void:
	for c in _blocks[id]["cells"]:
		_occ.erase(c)
		_vacated[c] = true
	_blocks.erase(id)
	_order.erase(id)


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _w and c.y < _h


## Chạm sẽ cho kết quả gì, chưa đổi gì. Trả {kind, distance, blocker}.
func _evaluate(id: String) -> Dictionary:
	var b: Dictionary = _blocks[id]
	var key: String = b["chained_by"]
	if key != "" and _blocks.has(key):
		return {"kind": "chained", "distance": 0, "blocker": key}
	if int(b["ice"]) > 0:
		return {"kind": "crack", "distance": 0, "blocker": ""}
	var side := LevelData.block_side(b)
	var d := LevelData.side_dir(side)
	var cells: Array = b["cells"]
	var k := 0
	while k < STEP_CAP:
		k += 1
		var any_in := false
		for c in cells:
			var n: Vector2i = c + d * k
			if not _in_bounds(n):
				continue
			any_in = true
			var o: String = _occ.get(n, "")
			if o != "" and o != id:
				return {"kind": "blocked", "distance": k - 1, "blocker": o}
		if not any_in:
			break
	# Đường thông. Cổng nhịp đóng thì trượt tới mép rồi bật về.
	if not gate_open(side):
		var inside := 0
		while true:
			var all_in := true
			for c in cells:
				if not _in_bounds(c + d * (inside + 1)):
					all_in = false
					break
			if not all_in:
				break
			inside += 1
		return {"kind": "gate_closed", "distance": inside, "blocker": "gate"}
	var kind := "peel" if b["inner_color"] != "" else "exit"
	return {"kind": kind, "distance": k, "blocker": ""}


## Cập nhật sương mù: khối hết ẩn khi một khối kề (4 hướng) đã rời đi; ô trống sẵn quanh hình không tính. Trả id vừa lộ.
func _update_reveal() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		var b: Dictionary = _blocks[id]
		if not b["fog"] or b["revealed"]:
			continue
		var hit := false
		for c in b["cells"]:
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dv
				if _vacated.has(n):
					hit = true
					break
			if hit:
				break
		if hit:
			b["revealed"] = true
			out.append(id)
	return out
