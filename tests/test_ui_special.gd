extends RefCounted
## Màn đặc biệt trên màn level (level.gd chế độ special) và luồng của Game (design.md mục 7 "Màn đặc biệt").

const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const Config := preload("res://src/config.gd")
const SpecialBomb := preload("res://src/meta/special_bomb.gd")
const SpecialBoard := preload("res://src/core/special_board.gd")

const DIR := "user://test_ui_special"
const NOW := 1800000000
## Config.UNLOCK.special_bomb (L50 since 2026-11-09).
const OPEN := 50


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g(level: int = OPEN) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var p: Node = _tree().root.get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	g.s.special["guide"] = true
	return g


func _mount() -> Control:
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({"special": true})
	return lv


func _wait_until(cond: Callable, ms: int = 6000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


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


func _press(lv: Control, node_name: String) -> void:
	(_pop(lv, node_name) as Button).pressed.emit()


func _blocked(lv: Control) -> String:
	for id in lv.board.block_ids():
		if lv.board.peek(id) == "blocked":
			return id
	return ""


## Interstitial calls so far (mock ads log).
func _inters() -> Array:
	var calls: Array = _tree().root.get_node("Platform").ads.calls
	return calls.filter(func(c: Dictionary) -> bool: return c.kind == "inter")


func _inv_total(g: Node) -> int:
	return int(g.s.inv.hint) + int(g.s.inv.move) + int(g.s.inv.smash)


func test_bombs_mount_and_start(t: T) -> void:
	var g := _g()
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	t.ok(bool(lv.attempt.special), "attempt special")
	t.eq(lv.title_label.text, lv.tr("special_title"), "tiêu đề Màn đặc biệt")
	t.ok(not lv.hard_badge.visible, "không huy hiệu độ khó")
	t.eq(SpecialBomb.tickets(g.s, NOW), 0, "đã dùng vé chờ")
	var plan: Array = lv.attempt.bombs
	t.eq(plan.size(), 1, "trận đầu 1 bom")
	var id := str(plan[0].id)
	var host: Control = lv.board_view.block_node(id)
	t.ok(host != null and host.get_node_or_null("Bomb") != null, "bom là con của khối mang bom")
	t.ok(not bool(lv.bombs.started), "bom chưa đếm trước lần chạm đầu")
	var left0: float = lv.bombs.seconds_left(id)
	for i in 5:
		await _tree().process_frame
	t.eq(lv.bombs.seconds_left(id), left0, "chưa chạm thì không trừ")
	var b := _blocked(lv)
	t.ok(b != "", "có khối bị chặn")
	lv.board_view.block_tapped.emit(b)
	t.ok(bool(lv.bombs.started), "chạm khối bị chặn cũng bắt đầu đếm")
	await _wait_until(func() -> bool: return lv.bombs.seconds_left(id) < left0 - 0.05, 2000)
	t.ok(lv.bombs.seconds_left(id) < left0, "đang đếm")
	# Hộp thoại (popup của màn) giữ đồng hồ.
	lv._set_state("dialog")
	var held: float = lv.bombs.seconds_left(id)
	for i in 10:
		await _tree().process_frame
	t.eq(lv.bombs.seconds_left(id), held, "có hộp thoại thì bom dừng")
	lv._set_state("playing")
	lv.free()


func test_win_rewards_then_main_level(t: T) -> void:
	var g := _g()
	var lives0 := int(g.lives_view().count)
	var inv0 := _inv_total(g)
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	for i in 200:
		if lv.board.is_won() or lv.state != "playing":
			break
		var id: String = lv._hint_target()
		if id == "":
			break
		lv.board_view.block_tapped.emit(id)
		await _tree().process_frame
	t.ok(lv.board.is_won(), "thắng")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "ContinueButton") != null), "thẻ thắng như level thường")
	t.ok(_pop(lv, "LbRow") == null and _pop(lv, "FeatureProgress") == null, "không bảng xếp hạng, không thanh tính năng")
	var reward := _pop(lv, "GoldReward")
	t.ok(reward != null and (reward.get_node("RewardLabel") as Label).text == "x1", "ô thưởng là booster x1")
	var coins0 := int(g.s.coins)
	t.eq(_inv_total(g), inv0 + 1, "+1 booster")
	t.eq(SpecialBomb.wins(g.s), 1, "1 trận thắng")
	t.eq(SpecialBomb.board(g.s), 2, "sang bàn 2")
	t.eq(int(g.s.level), OPEN, "level chính không tăng")
	t.eq(int(g.s.coins), coins0, "không cộng gold")
	t.eq(((_pop(lv, "ContinueButton") as Node).find_child("Text (TMP)", true, false) as Label).text, lv.tr("level_home"),
		"nút dưới là Trang chủ")
	# The first Special x2 is free: FreeBtn (no video icon), the label says so, no rewarded ad.
	var x2 := _pop(lv, "X2Button") as Button
	t.ok(x2 != null and x2.get_node_or_null("Image") == null, "x2 lần đầu là nút miễn phí, không icon video")
	t.ok(x2.find_child("Text (TMP)", true, false) != null
		and (x2.find_child("Text (TMP)", true, false) as Label).text == lv.tr("win_x2_free"), "nhãn x2 miễn phí")
	t.ok(not bool(g.s.meta.get("special_x2_used", false)), "chưa dùng x2 miễn phí")
	x2.pressed.emit()
	t.ok(await _wait_until(func() -> bool: return bool(g.s.meta.get("special_x2_used", false))), "x2 miễn phí xong")
	t.eq(_inv_total(g), inv0 + 2, "x2: thêm 1 booster cùng loại")
	var closed: Array = []
	lv.closed.connect(func(r: Variant) -> void: closed.append(r))
	_press(lv, "ContinueButton")
	t.ok(await _wait_until(func() -> bool: return not closed.is_empty()), "về Home")
	t.eq(str((closed[0] as Dictionary).get("action", "")), "home", "action home")
	t.eq(int(g.s.level), OPEN, "level chính vẫn như cũ")
	t.eq(int(g.lives_view().count), lives0, "không mất mạng")
	lv.free()


func test_special_x2_first_free_then_video(t: T) -> void:
	var g := _g()
	var p: Node = _tree().root.get_node("Platform")
	g.s.special["wins"] = 0
	var a: Dictionary = g.special_start()
	t.ok(not a.is_empty(), "vào Special")
	var res: Dictionary = g.on_level_won(a)
	t.ok(res.x2_available and res.x2_free, "lần đầu x2 miễn phí")
	var inv0 := _inv_total(g)
	t.ok(await g.special_claim_x2(), "nhận x2 miễn phí")
	t.eq(_inv_total(g), inv0 + 1, "+1 booster")
	t.eq(p.ads.calls.size(), 0, "không gọi quảng cáo")
	SpecialBomb.add_bonus(g.s, 2)
	var a2: Dictionary = g.special_start()
	t.ok(not a2.is_empty(), "vào Special lần 2")
	var res2: Dictionary = g.on_level_won(a2)
	t.ok(res2.x2_available and not res2.x2_free, "lần sau x2 cần video")
	p.ads.set_ready(false, false)
	var a3: Dictionary = g.special_start()
	t.ok(not a3.is_empty() and not bool(g.on_level_won(a3).x2_available), "không có video thì không mời x2")


func test_bomb_explodes(t: T) -> void:
	var g := _g(OPEN + 4)
	var lives0 := int(g.lives_view().count)
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	var id := str(lv.attempt.bombs[0].id)
	lv.board_view.block_tapped.emit(_blocked(lv))
	lv.bombs._bombs[id]["left"] = 0.05
	t.ok(await _wait_until(func() -> bool: return lv.state == "over", 2000), "bom nổ: thua")
	t.ok(not lv.board_view.input_enabled, "chặn chạm")
	var cracked := func() -> bool:
		return (lv._overlay as Control).get_children().any(func(n: Node) -> bool: return n.name == "GlassCrack")
	t.ok(cracked.call(), "kính màn hình vỡ")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "LevelButton") != null, 4000), "popup Bùm")
	t.eq(SpecialBomb.wins(g.s), 0, "không tính thắng")
	t.eq(SpecialBomb.board(g.s), 1, "lần sau gặp lại bàn 1")
	t.eq(int(g.lives_view().count), lives0, "không mất mạng")
	t.eq(_inters().size(), 0, "popup Bùm đang mở: chưa có interstitial")
	_press(lv, "LevelButton")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and not bool(lv.attempt.get("special", false))),
		"Level N vào level chính")
	# design.md mục 7: leaving the lose popup runs the result_exit interstitial (level > 35, clock past 90 s).
	t.eq(_inters().size(), 1, "rời popup Bùm: có interstitial")
	t.eq(str(_inters()[0].placement), "result_exit", "placement result_exit")
	await _tree().process_frame
	t.ok(not cracked.call(), "level chính không còn kính vỡ")
	lv.free()


func test_out_of_steps_no_rescue(t: T) -> void:
	var g := _g(OPEN + 4)
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	var b := _blocked(lv)
	for i in 120:
		if lv.board.moves_left() <= 0:
			break
		lv.board_view.block_tapped.emit(b)
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "LevelButton") != null, 6000), "popup thua, không cứu lượt")
	t.eq(_pop(lv, "VideoButton"), null, "không có popup +3 Move")
	var closed: Array = []
	lv.closed.connect(func(r: Variant) -> void: closed.append(r))
	var x := _pop(lv, "CloseX")
	if x == null:
		# X của khung PopupOkLayer: emit closed(close) qua nút đóng của popup.
		var popup: Node = _pop(lv, "LevelButton")
		while popup != null and not popup.has_signal("closed"):
			popup = popup.get_parent()
		popup.call("_send", "close")
	t.ok(await _wait_until(func() -> bool: return not closed.is_empty()), "X về Home")
	t.eq(str((closed[0] as Dictionary).get("action", "")), "home", "action home")
	t.eq(_inters().size(), 1, "X ở popup thua hết bước: có interstitial")
	lv.free()


func test_leave_asks_then_home(t: T) -> void:
	var g := _g()
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	var closed: Array = []
	lv.closed.connect(func(r: Variant) -> void: closed.append(r))
	lv.restart_button.pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "LeaveButton") != null), "hỏi Rời màn")
	_press(lv, "StayButton")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "Chơi tiếp")
	lv.restart_button.pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "LeaveButton") != null), "hỏi lại")
	_press(lv, "LeaveButton")
	t.ok(await _wait_until(func() -> bool: return not closed.is_empty()), "về Home")
	t.eq(SpecialBomb.tickets(g.s, NOW), 0, "vé đã mất")
	t.eq(_inters().size(), 0, "rời màn giữa chừng: không interstitial")
	lv.free()


func test_game_tickets_from_hard_wins(t: T) -> void:
	var g := _g(OPEN)
	var hard := 0
	for lv in range(OPEN, 200):
		if g.difficulty_of(lv) != "":
			hard = lv
			break
	t.ok(hard > 0, "có level Hard từ mốc mở")
	g.s.level = hard
	var a: Dictionary = g.start_attempt()
	var res: Dictionary = g.on_level_won(a)
	t.eq(int(res.get("special_tickets", 0)), 1, "thắng Hard/VeryHard +1 vé")
	t.eq(SpecialBomb.bonus(g.s), 1, "ngăn thưởng 1")
	# Dưới mốc mở: không có vé.
	var g2 := _g(30)
	for lv in range(23, OPEN):
		if g2.difficulty_of(lv) != "":
			g2.s.level = lv
			break
	var res2: Dictionary = g2.on_level_won(g2.start_attempt())
	t.eq(int(res2.get("special_tickets", 0)), 0, "chưa mở thì không có vé")


func test_game_invite_and_start(t: T) -> void:
	var g := _g(OPEN - 1)
	t.ok(not bool(g.special_view().open), "trước mốc chưa mở")
	t.ok(not g.special_take_invite(), "chưa mở thì không mời")
	g.s.level = OPEN
	t.ok(g.special_take_invite(), "lần đầu về Home sau khi mở: mời")
	t.ok(not g.special_take_invite(), "chỉ một lần")
	var a: Dictionary = g.special_start()
	t.ok(not a.is_empty() and bool(a.special), "vào được bằng vé chờ")
	t.eq(str(a.ticket), "timer", "dùng vé chờ")
	t.ok(g.special_start().is_empty(), "hết vé thì không vào")
	g.special_queue_invite()
	t.ok(not g.special_take_invite(), "hết vé thì không mời")
	SpecialBomb.add_bonus(g.s, 1)
	g.special_queue_invite()
	t.ok(g.special_take_invite(), "còn vé: Home mời")
	g.test_now = NOW + int(Config.SPECIAL.timer_sec)
	t.eq(int(g.special_view().tickets), 2, "đủ 2 giờ: thêm vé chờ")
