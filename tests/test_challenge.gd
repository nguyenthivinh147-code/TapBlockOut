extends RefCounted
## Daily Challenge (Task 9.4): khoá dưới L50, mở ở L50, bàn xác định theo ngày, +100 gold lần thắng đầu trong ngày,
## x2, thua mất mạng, analytics, demo vẫn khoá; màn challenge chạy level thật; level dạy cơ chế có hướng dẫn.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")

const DIR := "user://test_challenge"
const NOW := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _plat() -> Node:
	return _tree().root.get_node("Platform")


func _g(level: int = 50) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.test_tz = 0
	var p := _plat()
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	p.save.last_json = ""
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	return g


func _wait_until(cond: Callable, ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


## Giải attempt bằng solver (qua Game.tap để đếm lượt chạm).
func _solve(g: Node, attempt: Dictionary) -> bool:
	var b: BoardState = attempt.board
	var r: Dictionary = Solver.solve_state(b)
	if not bool(r.ok):
		return false
	for id in r.order:
		g.tap(attempt, str(id))
	return b.is_won()


func _first_blocked(b: BoardState) -> String:
	for id in b.block_ids():
		if b.peek(id) == "blocked":
			return id
	return ""


# --- Game ---

func test_locked_below_50(t: T) -> void:
	var g := _g(49)
	var v: Dictionary = g.challenge_view()
	t.eq(v.open, false, "L49 chưa mở")
	t.eq(v.locked, true, "L49 khoá")
	t.eq(v.available, false, "L49 không chơi được")
	t.eq(v.unlock_level, 50, "mở ở L50")
	t.eq(g.start_challenge(), {}, "start_challenge rỗng khi khoá")
	t.eq(_plat().an.count("challenge_start"), 0, "không log khi khoá")


func test_open_at_50(t: T) -> void:
	var g := _g(50)
	var v: Dictionary = g.challenge_view()
	t.eq(v.open, true, "L50 mở")
	t.eq(v.available, true, "chơi được")
	t.eq(v.won, false, "chưa thắng")
	t.eq(v.coins, 100, "thưởng 100")
	var a: Dictionary = g.start_challenge()
	t.ok(not a.is_empty(), "có attempt")
	t.eq(a.challenge, true, "cờ challenge")
	t.eq(int(a.level), 50, "id bàn kẹp tối thiểu 50")
	t.eq(int(g.s.level), 50, "không đổi level người chơi")
	# id theo level đã thắng gần nhất, kẹp [50, 100]
	g.s.level = 80
	t.eq(g.challenge_level_id(), 79, "L80 -> id 79")
	g.s.level = 9999
	t.eq(g.challenge_level_id(), 100, "kẹp 100")
	g.s.level = 3
	t.eq(g.challenge_level_id(), 50, "kẹp 50")


func test_same_day_same_level_is_deterministic(t: T) -> void:
	var g := _g(60)
	var day: int = g.today()
	var d1: Dictionary = g.challenge_data()
	var d1s := JSON.stringify(d1)
	t.ok(not d1.is_empty(), "sinh được")
	t.eq(LevelData.validate(d1), [] as Array[String], "hợp lệ")
	t.ok(bool(Solver.solve(d1).ok), "solver giải được")
	t.eq(int(d1.id), g.challenge_level_id(), "id khớp")
	t.eq(JSON.stringify(g.challenge_data()), d1s, "lần 2 (cache) y hệt")
	# xoá cache (như mở game lại): vẫn y hệt
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.test_tz = 0
	g.s.level = 60
	t.eq(g.today(), day, "cùng ngày")
	t.eq(JSON.stringify(g.challenge_data()), d1s, "sau khi xoá cache y hệt")
	# hai attempt cùng ngày có cùng bàn
	var a1: Dictionary = g.start_challenge()
	var a2: Dictionary = g.start_challenge()
	t.eq((a1.board as BoardState).block_ids(), (a2.board as BoardState).block_ids(), "cùng khối")
	t.eq((a1.board as BoardState).moves_left(), (a2.board as BoardState).moves_left(), "cùng MOVES")
	# ngày khác thì bàn khác (hầu hết các ngày)
	var different := 0
	for i in range(1, 6):
		if JSON.stringify(g.challenge_data(day + i)) != d1s:
			different += 1
	t.ok(different >= 4, "ngày khác cho bàn khác (%d/5)" % different)


func test_first_win_of_day_bonus_only_once(t: T) -> void:
	var g := _g(50)
	var coins0 := int(g.s.coins)
	var a: Dictionary = g.start_challenge()
	t.ok(await _solve(g, a), "giải được bàn")
	var res: Dictionary = g.on_level_won(a)
	t.eq(res.coins, 100, "+100 gold lần thắng đầu")
	t.eq(int(g.s.coins), coins0 + 100, "ví +100")
	t.eq(int(g.s.level), 50, "level người chơi giữ nguyên")
	t.eq(int(g.s.challenge.day), g.today(), "ghi ngày")
	t.eq(bool(g.s.challenge.won), true, "ghi đã thắng")
	t.eq(g.challenge_view().won, true, "view: đã thắng")
	t.eq(g.challenge_view().available, false, "view: hết lượt hôm nay")
	t.eq(g.start_challenge(), {}, "không chơi lại hôm nay")
	# thắng lần nữa cùng ngày (ép attempt thủ công): không thêm gold
	var b2: Dictionary = g._begin_attempt(g.challenge_data(), g.challenge_level_id(), true)
	t.ok(await _solve(g, b2), "giải lại")
	var res2: Dictionary = g.on_level_won(b2)
	t.eq(res2.coins, 0, "lần thắng thứ hai trong ngày: 0 gold")
	t.eq(int(g.s.coins), coins0 + 100, "ví không đổi")
	t.eq(res2.x2_available, false, "không x2 khi 0 gold")
	# qua ngày: thưởng lại
	g.test_now = NOW + 86400
	t.eq(g.challenge_view().available, true, "ngày mới mở lại")
	var a3: Dictionary = g.start_challenge()
	t.ok(await _solve(g, a3), "giải ngày mới")
	t.eq(g.on_level_won(a3).coins, 100, "ngày mới +100")
	t.eq(int(g.s.coins), coins0 + 200, "ví +200")
	t.eq(_plat().an.count("level_end"), 0, "không log level_end cho challenge")
	t.eq(_plat().an.count("challenge_end"), 3, "3 sự kiện challenge_end")


func test_x2_doubles_challenge_gold(t: T) -> void:
	var g := _g(50)
	var coins0 := int(g.s.coins)
	var a: Dictionary = g.start_challenge()
	t.ok(await _solve(g, a), "giải được")
	var res: Dictionary = g.on_level_won(a)
	t.eq(res.x2_available, true, "có x2")
	t.eq(res.x2_free, false, "x2 phải xem video")
	t.eq(int(_plat().an.count("rv_offer")), 1, "log rv_offer")
	var ok: bool = await g.claim_x2()
	t.ok(ok, "xem video xong")
	t.eq(int(g.s.coins), coins0 + 200, "x2: 100 + 100")
	t.eq(_plat().an.named("rv_done")[0].params.pl, "x2_coins", "placement x2_coins")
	t.eq(bool(g.claim_x2()), false, "không x2 hai lần")


func test_lose_costs_a_life(t: T) -> void:
	var g := _g(50)
	var a: Dictionary = g.start_challenge()
	var lives0: int = g.lives_view().count
	t.eq(lives0, 10, "đủ mạng")
	g.on_level_lost(a)
	t.eq(int(g.lives_view().count), 9, "thua mất 1 mạng")
	t.eq(bool(a.life_charged), true, "đánh dấu trừ mạng")
	t.eq(bool(g.s.challenge.won), false, "thua không ghi thắng")
	t.eq(g.challenge_view().available, true, "thua thì chơi lại được")
	var ends: Array = _plat().an.named("challenge_end")
	t.eq(ends.size(), 1, "challenge_end")
	t.eq(int(ends[0].params.won), 0, "thua")
	t.eq(_plat().an.count("level_end"), 0, "không log level_end")
	# restart khi đã chạm cũng tốn mạng, theo cùng đường level thường
	var b: Dictionary = g.start_challenge()
	var blocked := _first_blocked(b.board)
	if blocked != "":
		g.tap(b, blocked)
		t.eq(g.restart_cost_life(b), true, "restart sau khi chạm mất mạng")
		t.eq(int(g.lives_view().count), 8, "còn 8 mạng")


func test_analytics_flat_snake_case_with_build(t: T) -> void:
	var g := _g(50)
	var a: Dictionary = g.start_challenge()
	t.ok(await _solve(g, a), "giải")
	g.on_level_won(a)
	var start: Array = _plat().an.named("challenge_start")
	var end: Array = _plat().an.named("challenge_end")
	t.eq(start.size(), 1, "challenge_start")
	t.eq(end.size(), 1, "challenge_end")
	t.eq(_plat().an.count("level_start"), 0, "không level_start")
	var re := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	for e in [start[0], end[0]]:
		t.eq(e.params.build, "v1", "kèm build")
		for k in e.params:
			t.ok(re.search(str(k)) != null, "tham số snake_case: " + str(k))
			t.ok(typeof(e.params[k]) in [TYPE_INT, TYPE_STRING, TYPE_FLOAT, TYPE_BOOL], "giá trị phẳng: " + str(k))
	t.eq(int(end[0].params.won), 1, "thắng")
	t.eq(int(end[0].params.coins), 100, "coins")
	t.eq(int(start[0].params.level), 50, "level")


func test_demo_keeps_challenge_locked(t: T) -> void:
	var g := _g(60)
	Config.demo_override = 1
	var v: Dictionary = g.challenge_view()
	t.eq(v.open, false, "demo luôn khoá")
	t.eq(v.locked, true, "locked")
	t.eq(g.start_challenge(), {}, "demo không bắt đầu được")
	Config.demo_override = 0
	t.eq(g.challenge_view().open, true, "bản phát hành mở")
	Config.demo_override = -1


# --- Home ---

func _home() -> Control:
	var h := (load("res://scenes/home.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(h)
	h.setup({})
	return h


func test_home_button_states(t: T) -> void:
	var g := _g(49)
	var h := _home()
	t.ok(h.challenge_btn.disabled, "L49 khoá")
	t.eq(h.challenge_btn.text, "Unlocked at Level 50", "ghi Unlocked at Level 50")
	h.queue_free()
	g.s.level = 50
	var h2 := _home()
	t.ok(not h2.challenge_btn.disabled, "L50 mở")
	t.eq(h2.challenge_btn.text, "Daily Challenge", "chữ")
	var got := {"r": {}}
	h2.closed.connect(func(r: Variant) -> void: got["r"] = r)
	h2.challenge_btn.pressed.emit()
	t.eq(got["r"], {"action": "challenge"}, "chạy lẻ: phát closed challenge")
	h2.queue_free()
	# demo: khoá và không bấm được
	Config.demo_override = 1
	var h3 := _home()
	t.ok(h3.challenge_btn.disabled, "demo: khoá")
	t.eq(h3.challenge_btn.text, "Unlocked at Level 50", "demo ghi Unlocked at Level 50")
	h3.queue_free()
	Config.demo_override = -1


func _main() -> Control:
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	return m


func test_home_opens_challenge_screen_in_main(t: T) -> void:
	var g := _g(50)
	var m := _main()
	t.ok(await _wait_until(func() -> bool: return m.is_booted), "boot xong")
	g.s.level = 50
	m.go("home")
	t.eq(m.current_name, "home", "Home")
	m.current_screen.challenge_btn.pressed.emit()
	t.eq(m.current_name, "challenge", "mở màn challenge")
	var ch: Control = m.current_screen
	t.eq(ch.title_label.text, "Daily Challenge", "tiêu đề")
	t.ok(ch.play_button.visible and not ch.play_button.disabled, "nút Chơi")
	t.eq(ch.bonus_label.text, "First win today: +100 gold", "dòng thưởng")
	t.ok(not ch.done_label.visible, "chưa xong")
	ch.back_button.pressed.emit()
	t.eq(m.current_name, "home", "Back về Home")
	# demo: Home không mở được challenge
	Config.demo_override = 1
	m.go("home")
	m.current_screen.challenge_btn.pressed.emit()
	t.eq(m.current_name, "home", "demo: không mở")
	Config.demo_override = -1
	m.free()


# --- màn challenge + level thật ---

func _level_of(ch: Control) -> Control:
	return ch.level_node


func _pop(lv: Control, node_name: String) -> Node:
	if lv == null or not is_instance_valid(lv):
		return null
	for c in lv.get_node("LocalPopups").get_children():
		if c.is_queued_for_deletion():
			continue
		var n := c.find_child(node_name, true, false)
		if n != null:
			return n
	return null


func _offer_popup(lv: Control) -> Node:
	for c in lv.get_node("LocalPopups").get_children():
		if not c.is_queued_for_deletion() and "later_button" in c:
			return c
	return null


func _mount_challenge() -> Control:
	var ch := (load("res://scenes/challenge.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(ch)
	ch.setup({})
	return ch


func test_challenge_screen_full_win(t: T) -> void:
	var g := _g(50)
	var coins0 := int(g.s.coins)
	var ch := _mount_challenge()
	var st := {}
	ch.closed.connect(func(r: Variant) -> void: st["r"] = r)
	ch.play_button.pressed.emit()
	var lv := _level_of(ch)
	t.ok(lv != null, "nhúng màn level")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "đang chơi")
	t.eq(lv.title_label.text, "Daily Challenge", "tiêu đề level là challenge")
	t.eq(bool(lv.attempt.challenge), true, "attempt challenge")
	t.eq(lv.tut_label.text, "", "challenge không có hướng dẫn cơ chế")
	# giải bằng solver
	for i in 200:
		if lv.board.is_won():
			break
		var r: Dictionary = Solver.solve_state(lv.board)
		if not bool(r.ok) or (r.order as Array).is_empty():
			break
		lv.board_view.block_tapped.emit(str(r.order[0]))
		await _tree().process_frame
	t.ok(lv.board.is_won(), "thắng")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "ContinueButton") != null), "thẻ thắng")
	t.eq(int(g.s.coins), coins0 + 100, "+100 gold")
	t.ok(_pop(lv, "X2Button") != null, "có nút x2 (video)")
	(_pop(lv, "X2Button") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return int(g.s.coins) == coins0 + 200), "x2 xong")
	(_pop(lv, "ContinueButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool:
		if is_instance_valid(lv) and _offer_popup(lv) != null:
			_offer_popup(lv).later_button.pressed.emit()
		return st.has("r")), "đóng màn")
	t.eq(st.get("r"), {"action": "home"}, "về Home sau khi thắng")
	t.eq(g.challenge_view().won, true, "đã thắng hôm nay")
	ch.free()
	# mở lại: hiện "xong hôm nay", không có nút Chơi
	var ch2 := _mount_challenge()
	t.ok(ch2.done_label.visible, "hiện đã xong")
	t.ok(not ch2.play_button.visible, "ẩn nút Chơi")
	t.ok(not ch2.bonus_label.visible, "ẩn dòng thưởng")
	ch2.free()


func test_challenge_screen_lose_path(t: T) -> void:
	var g := _g(50)
	var ch := _mount_challenge()
	var st := {}
	ch.closed.connect(func(r: Variant) -> void: st["r"] = r)
	ch.play_button.pressed.emit()
	var lv := _level_of(ch)
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "đang chơi")
	var blocked := _first_blocked(lv.board)
	if blocked == "":
		t.fail("bàn challenge không có khối bị chặn để đốt MOVES")
		ch.free()
		return
	for i in 80:
		if lv.board.moves_left() <= 0:
			break
		lv.board_view.block_tapped.emit(blocked)
		await _tree().process_frame
	t.eq(lv.board.moves_left(), 0, "hết MOVES")
	# popup cứu qua cùng luồng, bỏ qua thì hỏi xác nhận mất mạng rồi thẻ thua
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "SkipButton") != null), "popup cứu")
	(_pop(lv, "SkipButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "ConfirmButton") != null), "xác nhận mất mạng")
	(_pop(lv, "ConfirmButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "RetryButton") != null), "thẻ thua")
	t.eq(int(g.lives_view().count), 9, "mất 1 mạng")
	# thử lại: vẫn là bàn challenge, attempt mới
	(_pop(lv, "RetryButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and int(lv.board.moves_left()) > 0), "chơi lại")
	t.eq(bool(lv.attempt.challenge), true, "vẫn challenge")
	# Home giữa chừng sau khi đã chạm: mất mạng, về Home
	lv.board_view.block_tapped.emit(blocked)
	await _tree().process_frame
	lv.home_button.pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "ConfirmButton") != null), "hỏi xác nhận")
	(_pop(lv, "ConfirmButton") as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return st.has("r")), "đóng")
	t.eq(st.get("r"), {"action": "home"}, "về Home")
	t.eq(int(g.lives_view().count), 8, "bỏ giữa chừng mất thêm 1 mạng")
	t.eq(bool(g.s.challenge.won), false, "chưa thắng")
	ch.free()


func test_challenge_screen_no_lives(t: T) -> void:
	var g := _g(50)
	g.s.lives.count = 0
	g.s.lives.next_at = NOW + 900
	var ch := _mount_challenge()
	var st := {}
	ch.closed.connect(func(r: Variant) -> void: st["r"] = r)
	ch.play_button.pressed.emit()
	t.eq(st.get("r"), {"action": "no_lives"}, "hết mạng thì không vào chơi")
	t.ok(ch.level_node == null, "không dựng level")
	ch.free()


# --- hướng dẫn cơ chế và mở khoá nút ---

func _mount_level(g: Node, lvn: int) -> Control:
	g.s.level = lvn
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	return lv


func test_teaching_levels_show_one_line_hint(t: T) -> void:
	var g := _g(1)
	var want := {14: "stone", 30: "ice", 40: "chain", 55: "layer", 70: "fog", 90: "pulse"}
	for lvn in want:
		var lv := _mount_level(g, lvn)
		t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "L%d vào chơi" % lvn)
		var m: String = want[lvn]
		t.eq(lv.tut_label.text, "%s: %s" % [lv.tr("mech_" + m), lv.tr("mech_%s_desc" % m)], "L%d hướng dẫn %s" % [lvn, m])
		t.ok(not lv.tut_label.text.contains("\n"), "một dòng")
		lv.free()
	for lvn in [15, 31, 41, 100]:
		var lv2 := _mount_level(g, lvn)
		t.ok(await _wait_until(func() -> bool: return lv2.state == "playing"), "L%d vào chơi" % lvn)
		t.eq(lv2.tut_label.text, "", "L%d không có hướng dẫn" % lvn)
		lv2.free()


func test_booster_buttons_follow_unlocks(t: T) -> void:
	var g := _g(1)
	var cases := {4: [false, false, false], 5: [true, false, false], 12: [true, true, false], 17: [true, true, true]}
	for lvn in cases:
		var lv := _mount_level(g, lvn)
		t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "L%d chơi" % lvn)
		var kinds := ["hint", "move", "smash"]
		for i in 3:
			t.eq((lv.booster_buttons[kinds[i]] as Control).get_parent().visible, cases[lvn][i],
				"L%d nút %s" % [lvn, kinds[i]])
		lv.free()
	# quà 28 ngày, shop, mạng
	var g2 := _g(3)
	t.eq(g2.daily_view().open, false, "L3 chưa có quà")
	g2.s.level = 4
	t.eq(g2.daily_view().open, true, "L4 có quà")
	t.eq(g2.lives_view().open, false, "L4 chưa có mạng")
	g2.s.level = 10
	t.eq(g2.lives_view().open, true, "L10 có mạng")
