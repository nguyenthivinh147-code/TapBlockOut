extends RefCounted
const T := preload("res://tests/t.gd")

const DIR := "user://test_ui_daily"
const DAY0 := 1_800_000_000  # giữa ngày, tránh sát nửa đêm


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _game(level: int) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = DAY0
	g.test_tz = 0
	g.s.level = level
	_root().get_node("Platform").ads.calls.clear()
	return g


func _open() -> Control:
	var node := (load("res://scenes/popup_daily.tscn") as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.setup({})
	return node


func _states(node: Control) -> Array:
	var out: Array = []
	for c in node.cell_nodes:
		out.append(str(c.get_meta("state")))
	return out


func test_seven_cells_and_claim(t: T) -> void:
	var g := _game(14)
	var node := _open()
	t.eq(node.cell_nodes.size(), 7, "7 ô")
	t.eq(_states(node), ["current", "locked", "locked", "locked", "locked", "locked", "locked"], "trạng thái ô")
	t.ok(node.claim_button.visible, "nút nhận hiện")
	t.ok(not node.video_button.visible, "video chưa hiện trước khi nhận")
	t.ok(node.claim_button.hit_size().y >= 96, "nút đủ lớn")
	var coins0 := int(g.s.coins)
	node.claim_button.pressed.emit()
	t.eq(int(g.s.coins), coins0 + 50, "nhận 50 gold ô 1")
	t.eq(int(g.s.daily.idx), 1, "lịch tiến một ô")
	t.eq(node.cell_nodes.size(), 7, "vẫn 7 ô")
	t.eq(_states(node)[0], "claimed", "ô 1 đã nhận")
	t.ok(not node.claim_button.visible, "nút nhận ẩn sau khi nhận")
	t.ok(node.video_button.visible, "video nhận trước hiện")
	node.claim_button.pressed.emit()
	t.eq(int(g.s.coins), coins0 + 50, "không nhận hai lần")
	node.queue_free()


func test_video_next_cell(t: T) -> void:
	var g := _game(14)
	var node := _open()
	node.claim_button.pressed.emit()
	var coins1 := int(g.s.coins)
	var calls0: int = _root().get_node("Platform").ads.calls.size()
	t.eq(_root().get_node("Platform").ads.calls.size(), calls0, "chưa tự chạy quảng cáo")
	await node._on_video()
	t.eq(int(g.s.coins), coins1 + 100, "video nhận ô 2")
	t.eq(int(g.s.daily.idx), 2, "lịch tiến thêm")
	t.eq(_root().get_node("Platform").ads.calls.size(), calls0 + 1, "một lần xem")
	t.ok(not node.video_button.visible, "mỗi ngày một video")
	t.ok(not node.claim_button.visible, "nút nhận vẫn ẩn")
	t.eq(_states(node)[0], "claimed", "ô 1 đã nhận")
	t.eq(_states(node)[1], "claimed", "ô 2 đã nhận")
	await node._on_video()
	t.eq(int(g.s.coins), coins1 + 100, "video lần hai không thưởng")
	node.queue_free()


func test_video_closed_gives_nothing(t: T) -> void:
	var g := _game(14)
	var node := _open()
	node.claim_button.pressed.emit()
	var coins1 := int(g.s.coins)
	_root().get_node("Platform").ads.simulate({"ok": false, "reason": "closed"})
	await node._on_video()
	t.eq(int(g.s.coins), coins1, "đóng sớm không thưởng")
	t.eq(int(g.s.daily.idx), 1, "lịch giữ nguyên")
	t.ok(node.status_label.text != "", "có báo lỗi")
	t.ok(node.video_button.visible, "còn thử lại được")
	node.queue_free()


func test_booster_cell_and_week_two(t: T) -> void:
	var g := _game(14)
	g.s.daily.idx = 7
	var node := _open()
	t.eq(node.cell_nodes.size(), 7, "tuần 2 có 7 ô")
	t.eq(_states(node)[0], "current", "ô 8 là ô hiện tại")
	t.eq(_states(node)[6], "locked", "ô 14 khoá")
	t.eq(node.cell_nodes[2].find_child("Quantity", true, false).text.contains("x1"), true, "ô quà booster có số lượng")
	node.queue_free()
	g.s.daily.idx = 27
	node = _open()
	t.eq(node.cell_nodes.size(), 7, "tuần 4 có 7 ô")
	# Mỗi món là một ItemReward (icon + số lượng) trong Rewards của ô.
	var last: Node = node.cell_nodes[6].find_child("Rewards", true, false)
	t.eq(last.find_children("Reward*", "", false, false).size(), 4, "ô 28: gold và ba booster")
	node.queue_free()


func test_locked_before_unlock_level(t: T) -> void:
	var g := _game(13)
	var node := _open()
	t.ok(not node.claim_button.visible, "chưa mở: không có nút nhận")
	t.ok(not node.video_button.visible, "chưa mở: không có video")
	node.queue_free()
	t.eq(int(g.s.daily.claim_day), -1, "không nhận được")


func test_close_signal_result(t: T) -> void:
	_game(14)
	var node := _open()
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	node.claim_button.pressed.emit()
	node.close_button.pressed.emit()
	t.eq(got.size(), 1, "closed phát một lần")
	t.eq(bool(got[0].claimed), true, "kết quả đã nhận")
	t.eq(bool(got[0].ahead), false, "chưa nhận trước")
	node.queue_free()
