extends RefCounted
## Road Trip (design.md mục 7 "Road Trip"): tiến độ trên đường level riêng, hộp quà, bố cục bản đồ. Logic thuần.
## Bản lưu s.road_trip = {"level": level đang chơi (1..levels+1, levels+1 là đã đi hết), "boxes": số hộp đã nhận,
## "guide": đã hiện hướng dẫn mở khoá}. Cộng vật phẩm vào kho (Wallet.inv_add) và mở avatar, frame của hộp
## (Cosmetics.unlock) do Game làm.

const Config := preload("res://src/config.gd")

const LEVEL_PATH := "res://data/road_trip/rt_%04d.json"
## Bản đồ: mỗi hàng chạy RUN_CELLS ô, hướng chạy đổi qua lại; giữa hai hàng chạy là một hàng nối chỉ có một mốc ở rìa.
## Hộp chiếm hai ô.
const RUN_CELLS := 6


static func levels() -> int:
	return int(Config.ROAD_TRIP.levels)


static func boxes() -> Array[int]:
	var out: Array[int] = []
	for b in Config.ROAD_TRIP.boxes:
		out.append(int(b))
	return out


## Level đang chơi; levels() + 1 khi đã đi hết đường.
static func current(s: Dictionary) -> int:
	return clampi(int(s.road_trip.get("level", 1)), 1, levels() + 1)


static func is_done(s: Dictionary) -> bool:
	return current(s) > levels()


static func box_index(level: int) -> int:
	return boxes().find(level)


## Hộp gần nhất ở level >= `level`; -1 khi không còn hộp.
static func next_box(level: int) -> int:
	for b in boxes():
		if b >= level:
			return b
	return -1


## Hộp gần nhất ở level < `level`; 0 khi chưa có.
static func prev_box(level: int) -> int:
	var out := 0
	for b in boxes():
		if b < level:
			out = b
	return out


## Chip tiến độ khi đang ở level `cur`: (số level đã qua từ hộp trước, khoảng cách hộp trước tới hộp kế).
## Không còn hộp: (0, 0).
static func progress(cur: int) -> Vector2i:
	var nb := next_box(cur)
	if nb < 0:
		return Vector2i.ZERO
	var pb := prev_box(cur)
	return Vector2i(cur - 1 - pb, nb - pb)


## Thưởng của hộp thứ i (0..15): {"hint": n, "smash": n, "move": n} (chỉ khoá có số).
static func reward(i: int) -> Dictionary:
	var r: Array = Config.ROAD_TRIP_REWARDS
	if i < 0 or i >= r.size():
		return {}
	return (r[i] as Dictionary).duplicate()


## Avatar hoặc frame tặng thêm ở hộp thứ i (0..15), "" khi hộp không có (Config.ROAD_TRIP_COSMETICS đếm hộp từ 1).
static func cosmetic(i: int) -> String:
	return str(Config.ROAD_TRIP_COSMETICS.get(i + 1, ""))


## Thắng level `level` của Road Trip. Chỉ level đang chơi mới tiến. Trả {advanced, box (chỉ số hộp vừa qua hoặc -1),
## reward, cos (avatar hoặc frame của hộp, "" khi không có; Game mở cho người chơi), before (tiến độ trước khi thắng),
## after}. Hộp chưa nhận ở level vừa qua thì tăng s.road_trip.boxes.
static func win(s: Dictionary, level: int) -> Dictionary:
	var res := {"advanced": false, "box": -1, "reward": {}, "cos": "", "before": progress(level),
		"after": progress(level)}
	if level != current(s) or is_done(s):
		return res
	var rt: Dictionary = s.road_trip
	rt["level"] = level + 1
	res.advanced = true
	var bi := box_index(level)
	if bi >= 0 and int(rt.get("boxes", 0)) <= bi:
		rt["boxes"] = bi + 1
		res.box = bi
		res.reward = reward(bi)
		res.cos = cosmetic(bi)
	# Tiến độ ngay sau khi thắng, vẫn theo khoảng của hộp vừa nhắm (thanh chạy tới đầy khi vừa qua hộp).
	var p: Vector2i = res.before
	res.after = Vector2i(mini(p.x + 1, p.y), p.y)
	return res


## Bố cục bản đồ tới level `max_n`: [{n, row, col, box}], row 0 ở đáy, col 0..RUN_CELLS-1 từ trái. Hàng chạy
## (row chẵn) có RUN_CELLS ô, chiều chạy đổi qua lại; hàng nối (row lẻ) có một mốc ở rìa cuối hàng chạy trước.
## Hộp chiếm hai ô (col là ô bên trái); thiếu chỗ cho hộp thì hàng chạy kết thúc sớm.
static func layout(max_n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var box_set := {}
	for b in boxes():
		box_set[b] = true
	var n := 1
	var row := 0
	var dir := 1
	while n <= max_n:
		var cells := RUN_CELLS
		var col := 0 if dir == 1 else RUN_CELLS - 1
		while cells > 0 and n <= max_n:
			if box_set.has(n):
				if cells < 2:
					break
				out.append({"n": n, "row": row, "col": col if dir == 1 else col - 1, "box": true})
				col += dir * 2
				cells -= 2
			else:
				out.append({"n": n, "row": row, "col": col, "box": false})
				col += dir
				cells -= 1
			n += 1
		if n <= max_n:
			out.append({"n": n, "row": row + 1, "col": RUN_CELLS - 1 if dir == 1 else 0, "box": box_set.has(n)})
			n += 1
		row += 2
		dir = -dir
	return out


## Trạng thái mốc `n` khi đang ở level `cur`: "done" | "current" | "locked"; hộp: "open" | "target" | "closed".
static func node_state(n: int, cur: int, is_box: bool) -> String:
	if is_box:
		if n < cur:
			return "open"
		return "target" if n == next_box(cur) else "closed"
	if n < cur:
		return "done"
	return "current" if n == cur else "locked"
