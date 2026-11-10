extends RefCounted
## Trạng thái một bàn cờ (kế hoạch mục 1.7). Logic thuần, không Node, không Platform.
## Khối trượt cứng theo hướng màu tới khi rời hẳn bàn. Quy ước ưu tiên khi chạm:
## sương mù > socola > xích > lớp phủ > đường bị chặn > cổng nhịp đóng > thoát (hoặc bóc lớp ngoài).
## Khối còn trong sương (chưa lộ màu) chạm vào không đi, không tốn MOVES, không đổi gì (`fog`).
## Lớp phủ (pudding, hoặc băng ở level có `cover` = "frost"; trường `ice` là số lớp, 0..COVER_MAX_LAYERS): khối còn phủ
## chạm vào không đi, không tốn MOVES (`covered`). Mỗi khối kề (chung cạnh) rời bàn, tức thoát hoặc bị Phá, bóc 1 lớp;
## một khối kề nhiều ô vẫn chỉ bóc 1 lớp. Bóc vỏ hộp giấy, bị chặn, dội cổng không bóc.
## Cổng nhịp chỉ đổi khi khối của cạnh đó chạm tới thanh: dội vào cổng khoá thì cổng mở, thoát (hoặc hộp giấy bay)
## qua cổng mở thì cổng khoá lại. Chạm khác (khối cạnh khác, bị chặn, xích, khối còn phủ) không đổi cổng.
## Ruy băng (`ribbons` trong dữ liệu, ngoài vào trong; `color` là màu kẹo): màu của khối là màu ruy băng ngoài cùng; chạm
## khi đường thông thì ruy băng đó bay đi như vỏ hộp giấy (`peel`) và lộ lớp kế. Lớp chưa lộ nằm trong `under`.
## Socola (`choco_sides`: [{side, layers}]): thanh bị phủ không nhận gì. Khối (hoặc ruy băng, vỏ hộp) đang hướng về thanh
## đó chạm vào không đi, không tốn MOVES (`choco`), kể cả khi đường đang bị chặn. Mỗi lần có thứ đi qua một thanh khác
## (thoát, bóc vỏ hộp hoặc ruy băng) hay một khối bị Phá, mỗi thanh còn socola bớt 1 lớp; hết lớp thì thanh dùng lại.
## Bom kẹo (`pop` trong dữ liệu): khối bom kẹo rời bàn (thoát hoặc bị Phá) thì mọi khối có ô cách một ô của nó tối đa
## Config.POP_RADIUS ô (theo cả hai trục) mất hết lớp phủ và lộ khỏi sương (`popped`); không nổ dây chuyền.

const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Config := preload("res://src/config.gd")

const STONE := "stone"
const STEP_CAP := 256
## Chất liệu lớp phủ của level (khoá `cover`): pudding (mặc định) hoặc băng.
const COVER_PUDDING := "pudding"
const COVER_FROST := "frost"
const ADJ := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _w: int = 0
var _h: int = 0
var _cover: String = COVER_PUDDING
var _moves_left: int = 0
var _won: bool = false
var _blocks: Dictionary = {}  # id -> {color, cells, ice, chained_by, inner_color, under, fog, revealed, pop}
var _order: Array[String] = []
var _stones: Array[Vector2i] = []
var _occ: Dictionary = {}  # Vector2i -> id khối, hoặc STONE
var _vacated: Dictionary = {}  # ô từng có khối, nay đã trống
var _gates: Dictionary = {}  # cạnh -> đang mở?
var _gate_segs: Dictionary = {}  # level nhiều cổng: cạnh -> [[màu, từ, tới), ...] (chỉ để vẽ khung)
var _choco: Dictionary = {}  # cạnh -> số lớp socola còn lại (> 0)
var _last_popped: Array[String] = []  # khối vừa được bom kẹo gỡ ở lần `smash` gần nhất


func _init(level: Dictionary) -> void:
	if level.is_empty():
		return
	_w = int(level.get("w", 0))
	_h = int(level.get("h", 0))
	_moves_left = int(level.get("moves", 0))
	_cover = COVER_FROST if str(level.get("cover", "")) == COVER_FROST else COVER_PUDDING
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
		# Ruy băng: màu hiện tại là ruy băng ngoài cùng; `under` là các ruy băng bên dưới rồi tới kẹo.
		var color := str(bd.get("color", ""))
		var under: Array = []
		var rib: Variant = bd.get("ribbons", [])
		if rib is Array and not (rib as Array).is_empty():
			for k in range(1, rib.size()):
				under.append(str(rib[k]))
			under.append(color)
			color = str(rib[0])
		_blocks[id] = {
			"color": color,
			"under": under,
			"dir": str(bd.get("dir", "")),
			"cells": cells,
			"ice": int(bd.get("ice", 0)),
			"chained_by": str(bd.get("chained_by", "")),
			"inner_color": str(bd.get("inner_color", "")),
			"fog": fog,
			"revealed": not fog,
			"pop": bool(bd.get("pop", false)),
		}
		_order.append(id)
		for c in cells:
			_occ[c] = id
	for p in level.get("pulse_sides", []):
		_gates[str(p.get("side", ""))] = bool(p.get("open", false))
	for p in level.get("choco_sides", []):
		var n := int(p.get("layers", 0))
		if n > 0:
			_choco[str(p.get("side", ""))] = n
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
	c._cover = _cover
	c._won = _won
	for id in _blocks:
		c._blocks[id] = _blocks[id].duplicate()  # nông: mảng `cells`, `under` không bao giờ bị sửa tại chỗ
	c._order = _order.duplicate()
	c._stones = _stones
	c._occ = _occ.duplicate()
	c._vacated = _vacated.duplicate()
	c._gates = _gates.duplicate()
	c._gate_segs = _gate_segs
	c._choco = _choco.duplicate()
	return c


func width() -> int:
	return _w


func height() -> int:
	return _h


func stones() -> Array[Vector2i]:
	return _stones


## Chất liệu lớp phủ của level: COVER_PUDDING hoặc COVER_FROST.
func cover_kind() -> String:
	return _cover


## Cạnh có cổng nhịp -> đang mở?
func gates() -> Dictionary:
	return _gates.duplicate()


func gate_open(side: String) -> bool:
	return not _gates.has(side) or bool(_gates[side])


## Level nhiều cổng (Road Trip): cạnh -> [[màu, từ, tới), ...] theo ô dọc cạnh; rỗng với level thường (một màu
## mỗi cạnh). Chỉ để vẽ khung, luật chạm dùng `dir` của khối.
func gate_segments() -> Dictionary:
	return _gate_segs


## Cạnh còn socola -> số lớp còn lại (thanh hết socola không có trong dict).
func choco() -> Dictionary:
	return _choco.duplicate()


func choco_layers(side: String) -> int:
	return int(_choco.get(side, 0))


## Bớt 1 lớp socola ở cạnh `side` (nếu còn), như khi có thứ nghiền qua thanh khác. Bộ sinh dùng để gỡ bàn kẹt.
func melt_choco(side: String) -> void:
	if not _choco.has(side):
		return
	_choco[side] = int(_choco[side]) - 1
	if int(_choco[side]) <= 0:
		_choco.erase(side)


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
		"cover": _cover,
		"chained": chained,
		"chained_by": b["chained_by"] if chained else "",
		"inner_color": b["inner_color"],
		"ribbons": (b["under"] as Array).size(),
		"fog": b["fog"],
		"is_fog_hidden": b["fog"] and not b["revealed"],
		"pop": b["pop"],
	}


## Chạm không đổi trạng thái: trả `kind` mà tap() sẽ cho (rejected nếu không chạm được).
func peek(block_id: String) -> String:
	if _won or _moves_left <= 0 or not _blocks.has(block_id):
		return "rejected"
	return _evaluate(block_id)["kind"]


## Như `peek` nhưng trả đủ {kind, distance, blocker}: `blocker` là khối chặn đầu tiên trên đường đi ("blocked"), chìa
## ("chained"), "gate" hoặc "choco" (thanh còn socola). Khối bị chặn chỉ đổi kết quả khi `blocker` rời bàn; bộ sinh dùng để khỏi tính lại mọi khối.
func inspect(block_id: String) -> Dictionary:
	if _won or _moves_left <= 0 or not _blocks.has(block_id):
		return {"kind": "rejected", "distance": 0, "blocker": ""}
	return _evaluate(block_id)


func can_exit(block_id: String) -> bool:
	if _won or not _blocks.has(block_id):
		return false
	var k: String = _evaluate(block_id)["kind"]
	return k == "exit" or k == "peel"


## Khối đầu tiên (theo thứ tự khối) thoát hoặc bóc lớp được ngay; "" nếu không có.
func first_exit() -> String:
	if _won:
		return ""
	for id in _order:
		if can_exit(id):
			return id
	return ""


## Gợi ý: bom kẹo thoát được ngay mà vùng nổ còn khối phủ hoặc ẩn; không có thì khối thoát được ngay; không có nữa thì
## khối dội vào cổng nhịp đang khoá (để mở cổng). "" nếu không có.
func hint() -> String:
	if _won:
		return ""
	for bid in _order:
		if _blocks[bid]["pop"] and can_exit(bid) and not pop_targets(bid).is_empty():
			return bid
	var id := first_exit()
	if id != "" or _won:
		return id
	for bid in _order:
		if _evaluate(bid)["kind"] == "gate_closed":
			return bid
	return ""


## Trả {kind, id, distance, blocker, moves_left, won, revealed (khối vừa lộ khỏi sương), stripped (khối kề vừa bị bóc
## 1 lớp phủ vì khối này rời bàn), popped (bom kẹo vừa thoát: khối trong vùng nổ vừa mất hết lớp phủ hoặc lộ khỏi sương;
## không nằm trong `stripped` hay `revealed`), choco (cạnh vừa bớt 1 lớp socola vì lượt này đi qua thanh khác)}. `fog`,
## `covered` và `choco`: khối không đi, không tốn MOVES.
func tap(block_id: String) -> Dictionary:
	var res := {"kind": "rejected", "id": block_id, "distance": 0, "blocker": "",
		"moves_left": _moves_left, "won": _won, "revealed": [] as Array[String], "stripped": [] as Array[String],
		"popped": [] as Array[String], "choco": [] as Array[String]}
	if _won or _moves_left <= 0 or not _blocks.has(block_id):
		return res
	var ev := _evaluate(block_id)
	if ev["kind"] == "fog" or ev["kind"] == "covered" or ev["kind"] == "choco":
		res["kind"] = ev["kind"]
		res["blocker"] = ev["blocker"]
		return res
	_moves_left -= 1
	var b: Dictionary = _blocks[block_id]
	var side := LevelData.block_side(b)  # trước khi bóc lớp: hộp giấy bay về cạnh của màu vỏ
	match ev["kind"]:
		"peel":
			if b["inner_color"] != "":
				b["color"] = b["inner_color"]
				b["inner_color"] = ""
			else:
				# Mảng mới, không sửa tại chỗ: `clone` sao chép nông nên các bản sao dùng chung `under`.
				var under: Array = b["under"]
				b["color"] = under[0]
				b["under"] = under.slice(1)
		"exit":
			var gone := _remove(block_id)
			res["stripped"] = gone["stripped"]
			res["popped"] = gone["popped"]
	if _gates.has(side):
		match ev["kind"]:
			"gate_closed":
				_gates[side] = true
			"exit", "peel":
				_gates[side] = false
	if ev["kind"] == "exit" or ev["kind"] == "peel":
		res["choco"] = _melt_all()
	res["kind"] = ev["kind"]
	res["distance"] = ev["distance"]
	res["blocker"] = ev["blocker"]
	res["revealed"] = _update_reveal()
	_won = _blocks.is_empty()
	res["moves_left"] = _moves_left
	res["won"] = _won
	return res


## Bỏ sương của khối (lộ màu ngay), như khi khối kề rời đi. Bộ sinh dùng để gỡ bàn kẹt vì sương mù.
func reveal(block_id: String) -> void:
	if _blocks.has(block_id):
		_blocks[block_id]["revealed"] = true


## Bóc một lớp phủ của khối (nếu còn), như khi một khối kề rời đi. Bộ sinh dùng để gỡ bàn kẹt vì lớp phủ.
func strip(block_id: String) -> void:
	if _blocks.has(block_id) and int(_blocks[block_id]["ice"]) > 0:
		_blocks[block_id]["ice"] = int(_blocks[block_id]["ice"]) - 1


## Phá khối: xoá hẳn (còn lớp phủ cũng vậy), không tốn MOVES, không đổi cổng nhịp. Đá không chọn được. Khối rời bàn
## nên bóc 1 lớp phủ của mỗi khối kề và bớt 1 lớp socola của mỗi thanh, như khi thoát; bom kẹo bị Phá thì nổ
## (`last_popped`).
func smash(block_id: String) -> bool:
	_last_popped = [] as Array[String]
	if _won or not _blocks.has(block_id):
		return false
	_last_popped = _remove(block_id)["popped"]
	_melt_all()
	_update_reveal()
	_won = _blocks.is_empty()
	return true


## Khoá trạng thái chơi được (khối còn lại, băng, lớp, cổng); không gồm MOVES. Dùng cho solver và test.
func state_key() -> String:
	var parts := PackedStringArray()
	for id in _order:
		var b: Dictionary = _blocks[id]
		parts.append("%s:%s%d%s/%s" % [id, b["color"], b["ice"], b["inner_color"], ",".join(b["under"])])
	var sides := _gates.keys()
	sides.sort()
	for s in sides:
		parts.append("%s=%d" % [s, 1 if _gates[s] else 0])
	var melts := _choco.keys()
	melts.sort()
	for s in melts:
		parts.append("%s~%d" % [s, int(_choco[s])])
	return "|".join(parts)


## Mỗi thanh còn socola bớt 1 lớp. Trả các cạnh vừa bớt (theo LevelData.SIDES).
func _melt_all() -> Array[String]:
	var out: Array[String] = []
	for s in LevelData.SIDES:
		if _choco.has(s):
			out.append(s)
			melt_choco(s)
	return out


## Bom kẹo vừa bị Phá (lần gọi `smash` gần nhất): các khối trong vùng nổ vừa mất hết lớp phủ hoặc lộ khỏi sương.
func last_popped() -> Array[String]:
	return _last_popped.duplicate()


## Khối trong vùng nổ của `block_id` (mọi khối có ô cách một ô của nó tối đa Config.POP_RADIUS ô theo cả hai trục) còn
## lớp phủ hoặc còn trong sương, theo thứ tự khối. Tính cho mọi khối, không cần là bom kẹo.
func pop_targets(block_id: String) -> Array[String]:
	var out: Array[String] = []
	if not _blocks.has(block_id):
		return out
	var zone := {}
	var r := Config.POP_RADIUS
	for c: Vector2i in _blocks[block_id]["cells"]:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var o: String = _occ.get(c + Vector2i(dx, dy), "")
				if o != "" and o != STONE and o != block_id:
					zone[o] = true
	for bid in _order:
		if zone.has(bid):
			var b: Dictionary = _blocks[bid]
			if int(b["ice"]) > 0 or (b["fog"] and not b["revealed"]):
				out.append(bid)
	return out


## Xoá khối khỏi bàn; mỗi khối kề còn phủ bị bóc 1 lớp; bom kẹo thì mọi khối trong vùng nổ mất hết lớp phủ và lộ khỏi
## sương. Trả {stripped: id khối vừa bị bóc 1 lớp, popped: id khối trong vùng nổ vừa được gỡ} theo thứ tự khối.
func _remove(id: String) -> Dictionary:
	var near := {}
	for c in _blocks[id]["cells"]:
		for dv in ADJ:
			var o: String = _occ.get(c + dv, "")
			if o != "" and o != id and o != STONE and int(_blocks[o]["ice"]) > 0:
				near[o] = true
	var blast := {}
	if _blocks[id]["pop"]:
		for bid in pop_targets(id):
			blast[bid] = true
	for c in _blocks[id]["cells"]:
		_occ.erase(c)
		_vacated[c] = true
	_blocks.erase(id)
	_order.erase(id)
	var stripped: Array[String] = []
	var popped: Array[String] = []
	for bid in _order:
		if blast.has(bid):
			_blocks[bid]["ice"] = 0
			_blocks[bid]["revealed"] = true
			popped.append(bid)
		elif near.has(bid):
			_blocks[bid]["ice"] = int(_blocks[bid]["ice"]) - 1
			stripped.append(bid)
	return {"stripped": stripped, "popped": popped}


func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _w and c.y < _h


## Chạm sẽ cho kết quả gì, chưa đổi gì. Trả {kind, distance, blocker}.
func _evaluate(id: String) -> Dictionary:
	var b: Dictionary = _blocks[id]
	if b["fog"] and not b["revealed"]:
		return {"kind": "fog", "distance": 0, "blocker": ""}
	if _choco.has(LevelData.block_side(b)):
		return {"kind": "choco", "distance": 0, "blocker": "choco"}
	var key: String = b["chained_by"]
	if key != "" and _blocks.has(key):
		return {"kind": "chained", "distance": 0, "blocker": key}
	if int(b["ice"]) > 0:
		return {"kind": "covered", "distance": 0, "blocker": ""}
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
	var kind := "peel" if b["inner_color"] != "" or not (b["under"] as Array).is_empty() else "exit"
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
