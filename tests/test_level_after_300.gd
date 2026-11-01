extends RefCounted
## Sau L300 (bản phát hành): level sinh trong game từ LevelGenerator, Solver kiểm, xác định; màn chờ ngắn;
## demo vẫn dừng ở L20.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")
const Gen := preload("res://src/core/level_generator.gd")

const DIR := "user://test_level_after_300"
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


func test_l300_from_file_l301_generated(t: T) -> void:
	var g := _g(300)
	t.ok(FileAccess.file_exists("res://data/levels/level_0300.json"), "có file L300")
	t.eq(int(g.current_level_data().get("id", 0)), 300, "L300 đọc từ file")
	t.eq(g.level_needs_generation(), false, "L300 không cần sinh")
	g.s.level = 301
	t.ok(not FileAccess.file_exists("res://data/levels/level_0301.json"), "không có file L301")
	t.eq(g.level_exists(301), true, "L301 tồn tại")
	t.eq(g.level_needs_generation(), true, "L301 phải sinh")
	var d: Dictionary = g.current_level_data()
	t.ok(not d.is_empty(), "sinh được L301")
	t.eq(int(d.id), 301, "id 301")
	t.eq(g.level_needs_generation(), false, "đã nhớ trong cache")
	Config.demo_override = -1


func test_generated_levels_valid_and_deterministic(t: T) -> void:
	var g := _g(301)
	var worst_ms := 0.0
	for lvn in range(301, 331):
		g.s.level = lvn
		var t0 := Time.get_ticks_usec()
		var d: Dictionary = g.current_level_data()
		worst_ms = maxf(worst_ms, float(Time.get_ticks_usec() - t0) / 1000.0)
		t.ok(not d.is_empty(), "L%d sinh được" % lvn)
		if d.is_empty():
			continue
		t.eq(int(d.id), lvn, "L%d id" % lvn)
		t.eq(LevelData.validate(d), [] as Array[String], "L%d hợp lệ" % lvn)
		var r := Solver.solve(d)
		t.ok(bool(r.ok), "L%d solver giải được" % lvn)
		t.eq(int(d.min_taps), int(r.min_taps), "L%d min_taps" % lvn)
		t.ok(int(d.moves) >= int(r.min_taps), "L%d MOVES đủ" % lvn)
		t.ok(not BoardState.new(d).hint().is_empty(), "L%d có khối thoát ngay" % lvn)
		t.eq(bool(d.hard), lvn % 4 == 0, "L%d HARD mỗi 4 level" % lvn)
		t.ok(d.blocks.size() <= Gen.MAX_BLOCKS, "L%d trần 30 khối" % lvn)
		# xác định: sinh lại sau khi xoá cache (như mở game lại) cho đúng cùng level
		var s1 := JSON.stringify(d)
		var d2: Dictionary = g.generate_checked(lvn, lvn * g.SEED_STRIDE)
		t.eq(JSON.stringify(d2), s1, "L%d xác định" % lvn)
	print("level_after_300: sinh chậm nhất %.0f ms" % worst_ms)
	t.ok(worst_ms < 1000.0, "mỗi level sinh dưới 1 giây (%.0f ms)" % worst_ms)
	# level khác nhau cho bàn khác nhau
	g.s.level = 301
	var a := JSON.stringify(g.current_level_data())
	g.s.level = 302
	t.ok(a != JSON.stringify(g.current_level_data()), "L301 khác L302")
	# cache xoá, cùng level cho đúng bàn cũ
	g.reset_for_test(DIR + "/save.json")
	Config.demo_override = 0
	g.s.level = 301
	t.eq(JSON.stringify(g.current_level_data()), a, "mở lại game vẫn cùng bàn L301")
	Config.demo_override = -1


func test_generate_checked_matches_generator(t: T) -> void:
	var g := _g(301)
	# Seed đầu hợp lệ thì generate_checked trả đúng LevelGenerator.generate(id, seed).
	var d: Dictionary = g.generate_checked(305, 5000)
	t.eq(JSON.stringify(d), JSON.stringify(Gen.generate(305, 5000)), "seed đầu đạt thì giữ nguyên")
	# Id không sinh được ở mọi seed: trả {} chứ không treo.
	var bad: Dictionary = g.generate_checked(0, 1)
	t.ok(bad.is_empty() or LevelData.validate(bad).is_empty(), "id lạ: rỗng hoặc hợp lệ")
	Config.demo_override = -1


func test_start_attempt_after_300(t: T) -> void:
	var g := _g(350)
	var a: Dictionary = g.start_attempt()
	t.ok(not a.is_empty(), "start_attempt L350")
	t.eq(int(a.level), 350, "level")
	t.eq(bool(a.challenge), false, "không phải challenge")
	t.ok((a.board as BoardState).moves_left() > 0, "có MOVES")
	t.eq(int(g._gen_cache.size()), 1, "một bàn trong cache")
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
	t.eq(g.level_needs_generation(), false, "demo: không sinh")
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


func test_level_screen_waits_then_plays_and_continues(t: T) -> void:
	var g := _g(301)
	var lv := _mount(g, 301)
	t.eq(lv.state, "intro", "chưa chơi ngay: màn chờ")
	t.eq(lv.tut_label.text, "Loading...", "hiện đang chuẩn bị level")
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
