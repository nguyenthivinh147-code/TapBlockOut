extends RefCounted
## Vòng lặp level (bản phát hành): sau level cuối, số hiển thị tăng mãi còn nội dung quay lại từ
## Config.CONTENT.loop_start_level; demo vẫn dừng ở L20.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Gen := preload("res://src/core/level_generator.gd")
const LevelLoop := preload("res://src/core/level_loop.gd")

const DIR := "user://test_level_loop"
const NOW := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g(level: int) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.test_tz = 0
	var p: Node = _tree().root.get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	p.save.last_json = ""
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	Config.demo_override = 0
	return g


func _wait_until(cond: Callable, ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func test_content_level_mapping(t: T) -> void:
	var L := LevelLoop
	t.eq(L.content_level(1, 101, 300), 1, "trước level cuối giữ nguyên")
	t.eq(L.content_level(300, 101, 300), 300, "level cuối giữ nguyên")
	t.eq(L.content_level(301, 101, 300), 101, "sau level cuối về loop_start")
	t.eq(L.content_level(302, 101, 300), 102, "tiếp tục tuần tự")
	t.eq(L.content_level(500, 101, 300), 300, "hết vòng 1")
	t.eq(L.content_level(501, 101, 300), 101, "vòng 2")
	t.eq(L.content_level(100000, 101, 300), 101 + (100000 - 101) % 200, "số lớn")
	t.eq(L.content_level(7, 1, 5), 2, "loop_start = 1")
	t.eq(L.content_level(8, 5, 5), 5, "vòng một level")
	t.eq(L.content_level(7, 99, 5), 5, "loop_start quá cuối kẹp về level cuối")
	t.eq(L.content_level(7, 0, 5), 2, "loop_start < 1 kẹp về 1")


func test_game_loops_content_keeps_display(t: T) -> void:
	var g := _g(100)
	t.eq(int(g.current_level_data().get("id", 0)), 100, "L100 đọc file 100")
	for pair in [[101, 51], [102, 52], [150, 100], [151, 51], [1234, 51 + (1234 - 51) % 50]]:
		g.s.level = pair[0]
		t.eq(g.level_exists(pair[0]), true, "L%d tồn tại" % pair[0])
		t.eq(int(g.current_level_data().get("id", 0)), pair[1], "L%d chơi nội dung L%d" % [pair[0], pair[1]])
	g.s.level = 101
	var a: Dictionary = g.start_attempt()
	t.eq(int(a.level), 101, "attempt giữ số hiển thị")
	t.eq(g._gen_cache.size(), 0, "không sinh gì")


func test_loop_start_configurable(t: T) -> void:
	var g := _g(101)
	var old: int = int(Config.CONTENT.loop_start_level)
	t.eq(int(old), 51, "mặc định lặp từ L51")
	Config.CONTENT["loop_start_level"] = 71
	t.eq(int(g.current_level_data().get("id", 0)), 71, "loop_start 71")
	g.s.level = 103
	t.eq(int(g.current_level_data().get("id", 0)), 73, "L103 -> 73")
	Config.CONTENT["loop_start_level"] = old
	Config.demo_override = -1


func test_win_advances_display_level_past_last(t: T) -> void:
	var g := _g(100)
	var a: Dictionary = g.start_attempt()
	var res: Dictionary = g.on_level_won(a)
	t.eq(int(g.s.level), 101, "thắng L100 lên L101")
	var a2: Dictionary = g.start_attempt()
	t.eq(int(a2.level), 101, "attempt kế là L101")
	t.eq(int(a2.board.moves_left()), int(g.current_level_data().moves), "bàn là nội dung vòng lặp")
	Config.demo_override = -1


func test_old_save_upgrade_gets_loop_content(t: T) -> void:
	# Bản lưu của bản cũ (đã sang level sinh trong game) mở bằng bản mới: giữ số level, nhận nội dung vòng lặp.
	var g := _g(1)
	var path := DIR + "/old_save.json"
	g.reset_for_test(path)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "level": 457, "runs": 900, "coins": 123}))
	f.close()
	Config.demo_override = 0
	g.s = g.store.load_state("")
	t.eq(int(g.s.level), 457, "giữ số level hiển thị")
	t.eq(int(g.current_level_data().get("id", 0)), 51 + (457 - 51) % 50, "nội dung theo vòng lặp")
	Config.demo_override = -1


func test_demo_still_stops_at_20(t: T) -> void:
	var g := _g(21)
	Config.demo_override = 1
	t.eq(g.level_exists(21), false, "demo: L21 không có")
	t.eq(g.level_exists(301), false, "demo: L301 không có")
	t.eq(g.current_level_data(), {}, "demo: dữ liệu rỗng")
	g.s.level = 301
	t.eq(g.current_level_data(), {}, "demo: sau L300 cũng rỗng")
	t.eq(g.start_attempt(), {}, "demo: không bắt đầu được")
	Config.demo_override = -1


func _mount(g: Node, lvn: int) -> Control:
	g.s.level = lvn
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	return lv


func _pop(lv: Control, node_name: String) -> Node:
	for c in lv.get_node("LocalPopups").get_children():
		if c.is_queued_for_deletion():
			continue
		var n := c.find_child(node_name, true, false)
		if n != null:
			return n
	return null


func test_level_screen_continues_into_loop(t: T) -> void:
	var g := _g(301)
	var lv := _mount(g, 301)
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	t.eq(lv.title_label.text, "Level 301", "tiêu đề")
	t.eq(lv.tut_label.text, "", "hết chữ chờ")
	t.eq(int(lv.attempt.level), 301, "attempt L301")
	# thắng L301 -> sang L302 (sinh tiếp, có màn chờ)
	for i in 200:
		if lv.board.is_won():
			break
		var r: Dictionary = Solver.solve_state(lv.board)
		if not bool(r.ok) or (r.order as Array).is_empty():
			break
		lv.board_view.block_tapped.emit(str(r.order[0]))
		await _tree().process_frame
	t.ok(lv.board.is_won(), "thắng L301")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "ContinueButton") != null), "thẻ thắng")
	t.eq(int(g.s.level), 302, "lên L302")
	(_pop(lv, "ContinueButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool:
		for c in lv.get_node("LocalPopups").get_children():
			if not c.is_queued_for_deletion() and "later_button" in c:
				c.later_button.pressed.emit()
		return lv.state == "playing" and int(lv.attempt.level) == 302), "vào L302")
	t.eq(lv.title_label.text, "Level 302", "tiêu đề L302")
	t.ok(_pop(lv, "OkButton") == null, "không có hộp hết level")
	lv.free()
	Config.demo_override = -1


func test_home_play_enabled_after_300(t: T) -> void:
	var g := _g(320)
	var h := (load("res://scenes/home.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(h)
	h.setup({})
	t.ok(not h.play_btn.disabled, "Play mở")
	t.ok(not h.coming_soon_label.visible, "không hiện sắp có level mới")
	t.eq(g._gen_cache.size(), 0, "Home không sinh level")
	h.queue_free()
	Config.demo_override = -1
