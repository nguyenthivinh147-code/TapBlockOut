extends RefCounted
## Win Streak screens wired to Game (design.md mục 7 "Win Streak"): Main claims, End sums up, quitting a level with
## the streak at stake asks first and then reports the lost streak.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const Config := preload("res://src/config.gd")
const WinStreak := preload("res://src/meta/win_streak.gd")

const DIR := "user://test_ui_streak"
## 2027-01-15 08:00 UTC, a Friday (an Active day).
const FRI := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g(level: int = 47) -> Node:  # Win Streak opens at L45, which also teaches chains (mechanic popup)
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = FRI
	g.test_tz = 0
	var p: Node = _tree().root.get_node("Platform")
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


## A started event with `wins` wins.
func _streak(g: Node, wins: int) -> void:
	g.streak_refresh()
	g.streak_start()
	for i in wins:
		WinStreak.on_win(g.s, FRI, 0)


func _open(scene: String, args: Dictionary = {}) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", args)
	return node


func _wait_until(cond: Callable, ms: int = 6000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _labels(n: Node, out: Array) -> Array:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func test_entry_follows_state(t: T) -> void:
	var g := _g()
	t.eq(g.streak_entry(), "intro", "lượt đang chạy, chưa Start")
	t.ok(g.streak_take_auto_intro(), "tự mở giới thiệu lần đầu")
	t.ok(not g.streak_take_auto_intro(), "chỉ một lần")
	g.streak_start()
	t.eq(g.streak_entry(), "main", "đã Start")
	g.test_now = FRI + 3 * 86400
	t.eq(g.streak_entry(), "end", "thứ Hai, không còn quà")


func test_main_claims_milestone(t: T) -> void:
	var g := _g()
	_streak(g, 5)
	var node := _open("streak_main")
	var items: Dictionary = node.get("items")
	t.ok((items[2].claim as Control).visible, "mốc 2 có nút Nhận")
	t.ok((items[4].claim as Control).visible, "mốc 4 có nút Nhận")
	t.ok(not (items[7].claim as Control).visible, "mốc 7 chưa đạt")
	var hint0 := int(g.s.inv.hint)
	(items[4].claim as Button).pressed.emit()
	t.eq(int(g.s.inv.hint), hint0 + 1, "mốc 4: +1 Gợi ý")
	t.ok((g.s.streak.claimed as Array).has(4), "ghi đã nhận")
	t.ok(not (items[4].claim as Control).visible, "nút Nhận ẩn")
	t.ok((items[4].check as Control).visible, "dấu tích hiện")
	(items[2].chest_btn as Button).pressed.emit()
	t.ok((node.get("ui").node(node.INFO) as Control).visible, "chạm rương hiện bảng thưởng")
	for c in _tree().root.get_children():
		if c != node and c.scene_file_path == "res://scenes/popup_reward.tscn":
			c.queue_free()
	node.free()


func test_end_sums_up(t: T) -> void:
	var g := _g()
	_streak(g, 3)
	g.test_now = FRI + 3 * 86400  # Monday: claim only
	var node := _open("popup_streak_end")
	var texts := str(_labels(node, []))
	t.ok(texts.contains(node.tr("streak_end_final") % 3), "chuỗi cuối")
	t.ok(texts.contains("3d 16h"), "thời gian tới 0:00 thứ Sáu")
	t.ok(not (node.find_child("Rewards", true, false) as Control).visible, "không có ô thưởng")
	node.free()


func test_quit_with_streak_at_stake(t: T) -> void:
	var g := _g()
	_streak(g, 3)
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	# Touch the board: one tap on a block that can leave.
	lv.call("_on_block_tapped", lv.board.hint())
	t.ok(g.streak_at_stake(lv.attempt), "chuỗi 3 > mốc 2: đang bị đe doạ")
	await _wait_until(func() -> bool: return lv.state == "playing", 3000)
	lv.call("_on_home_pressed")
	var pop := func(name: String) -> Node:
		for c in lv.get_node("LocalPopups").get_children():
			if not c.is_queued_for_deletion() and c.find_child(name, true, false) != null:
				return c
		return null
	t.ok(await _wait_until(func() -> bool:
		var p: Node = pop.call("StreakText")
		return p != null), "popup Giữ chuỗi")
	var keep: Node = pop.call("StreakText")
	(keep.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool:
		for c in lv.get_node("LocalPopups").get_children():
			if not c.is_queued_for_deletion() and c.scene_file_path == "res://scenes/popup_notice.tscn":
				return true
		return false), "báo mất chuỗi")
	t.eq(WinStreak.count(g.s), 2, "chuỗi tụt về mốc 2")
	lv.free()
