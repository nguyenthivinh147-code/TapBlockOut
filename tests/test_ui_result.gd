extends RefCounted
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const NoLives := preload("res://src/ui/no_lives.gd")

const DIR := "user://test_ui_result"
const NOW := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _plat() -> Node:
	return _tree().root.get_node("Platform")


func _g() -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var p := _plat()
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	return g


func _mount(scene: String, args: Dictionary) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", args)
	return node


func _watch(node: Control) -> Dictionary:
	var state := {}
	node.connect("closed", func(r: Variant) -> void: state["r"] = r)
	return state


func _wait_until(cond: Callable) -> void:
	for i in 120:
		if cond.call():
			return
		await _tree().process_frame


func _btn(node: Node, node_name: String) -> Button:
	return node.find_child(node_name, true, false) as Button


func _lbl(node: Node, node_name: String) -> Label:
	return node.find_child(node_name, true, false) as Label


func _won(g: Node, level: int) -> Dictionary:
	g.s.level = level
	var attempt: Dictionary = g.start_attempt()
	return g.on_level_won(attempt)


# --- win card ---

func test_win_l1_free_x2(t: T) -> void:
	var g := _g()
	var res := _won(g, 1)
	t.eq(int(g.s.coins), 1040, "thắng +40")
	t.ok(res.x2_free, "L1 x2 miễn phí")
	var p := _mount("win_card", res)
	var st := _watch(p)
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % 40, "hiện +40")
	t.eq(_btn(p, "X2Button").text, p.tr("win_x2_free"), "nút x2 miễn phí")
	t.ok(_lbl(p, "X2HintLabel") != null, "gợi ý L1")
	_btn(p, "X2Button").pressed.emit()
	await _wait_until(func() -> bool: return _btn(p, "X2Button").text == p.tr("win_x2_done"))
	t.eq(int(g.s.coins), 1080, "x2 cộng thêm 40")
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % 80, "hiện +80")
	t.ok(_btn(p, "X2Button").disabled, "x2 một lần")
	t.eq(_plat().ads.calls.size(), 0, "L1 không xem quảng cáo")
	_btn(p, "ContinueButton").pressed.emit()
	t.eq(st.get("r"), {"x2_offered": true, "x2_taken": true, "rate_prompt": false, "coins": 80}, "kết quả")
	p.free()


func test_win_x2_video_closed_then_ok(t: T) -> void:
	var g := _g()
	var res := _won(g, 2)
	t.ok(res.x2_available and not res.x2_free, "L2 x2 qua video")
	var p := _mount("win_card", res)
	var st := _watch(p)
	t.eq(_btn(p, "X2Button").text, p.tr("win_x2"), "nút x2")
	_plat().ads.simulate("closed")
	_btn(p, "X2Button").pressed.emit()
	await _wait_until(func() -> bool: return _lbl(p, "MessageLabel").visible)
	t.eq(_lbl(p, "MessageLabel").text, p.tr("ads_closed_early"), "đóng sớm")
	t.eq(int(g.s.coins), 1040, "không thưởng")
	t.ok(not _btn(p, "X2Button").disabled, "thử lại được")
	_btn(p, "X2Button").pressed.emit()
	await _wait_until(func() -> bool: return _btn(p, "X2Button").disabled)
	t.eq(int(g.s.coins), 1080, "xem hết thì x2")
	_btn(p, "ContinueButton").pressed.emit()
	t.eq(st.get("r").x2_taken, true, "x2_taken")
	p.free()


func test_win_no_x2_without_ads(t: T) -> void:
	var g := _g()
	_plat().ads.set_ready(false, false)
	var res := _won(g, 2)
	_plat().ads.set_ready(true, true)
	t.ok(not res.x2_available, "không có video thì không mời x2")
	var p := _mount("win_card", res)
	var st := _watch(p)
	t.ok(_btn(p, "X2Button") == null, "không nút x2")
	_btn(p, "ContinueButton").pressed.emit()
	t.eq(st.get("r").x2_offered, false, "x2_offered false")
	t.eq(st.get("r").x2_taken, false, "x2_taken false")
	p.free()


func test_win_rate_prompt_passthrough(t: T) -> void:
	_g()
	var p := _mount("win_card", {"coins": 40, "x2_available": false, "x2_free": false, "rate_prompt": true})
	var st := _watch(p)
	_btn(p, "ContinueButton").pressed.emit()
	t.eq(st.get("r").rate_prompt, true, "chuyển rate_prompt cho level")
	p.free()


# --- lose card ---

func test_lose_retry_home(t: T) -> void:
	_g()
	var p := _mount("lose_card", {"offer": "", "life_charged": false})
	var st := _watch(p)
	t.ok(_btn(p, "PackBuyButton") == null, "không gói khi Game không báo")
	t.ok(_lbl(p, "LifeLabel") == null, "không dòng mất mạng")
	_btn(p, "RetryButton").pressed.emit()
	t.eq(st.get("r"), "retry", "chơi lại")
	p.free()
	var p2 := _mount("lose_card", {"life_charged": true})
	var st2 := _watch(p2)
	t.eq(_lbl(p2, "LifeLabel").text, p2.tr("lose_life_lost"), "báo mất 1 mạng")
	_btn(p2, "HomeButton").pressed.emit()
	t.eq(st2.get("r"), "home", "về Home")
	p2.free()


func test_lose_rescue_pack_buy(t: T) -> void:
	var g := _g()
	var p := _mount("lose_card", {"offer": "rescue_pack", "life_charged": false})
	t.ok(_btn(p, "PackBuyButton") != null, "có gói cứu nguy")
	t.eq(_btn(p, "PackBuyButton").text, p.tr("lose_pack_buy") % _plat().price("rescue_pack"), "giá lấy từ store")
	_btn(p, "PackBuyButton").pressed.emit()
	await _wait_until(func() -> bool: return int(g.s.inv.move) > 0)
	t.eq(int(g.s.inv.move), 1, "giao +3 Move")
	await _wait_until(func() -> bool: return not (p.find_child("PackBox", true, false) as Control).visible)
	t.ok(not (p.find_child("PackBox", true, false) as Control).visible, "ẩn gói sau khi mua")
	t.eq(_lbl(p, "MessageLabel").text, p.tr("shop_buy_ok"), "cảm ơn")
	p.free()


func test_lose_rescue_pack_cancel_keeps_open(t: T) -> void:
	var g := _g()
	_plat().iap.simulate("cancel")
	var p := _mount("lose_card", {"offer": "rescue_pack"})
	var st := _watch(p)
	_btn(p, "PackBuyButton").pressed.emit()
	for i in 10:
		await _tree().process_frame
	t.eq(int(g.s.inv.move), 0, "huỷ thì không giao")
	t.ok(not st.has("r"), "không đóng")
	t.ok(not _btn(p, "PackBuyButton").disabled, "mua lại được")
	p.free()


# --- no lives ---

func _no_lives_state(g: Node) -> void:
	g.s.level = 10
	g.s.lives = {"count": 0, "next_at": NOW + 900}


func test_no_lives_countdown(t: T) -> void:
	var g := _g()
	_no_lives_state(g)
	var p := _mount("no_lives", {})
	var st := _watch(p)
	t.eq(NoLives.format_time(65), "1:05", "format mm:ss")
	t.eq(NoLives.format_time(3725), "1:02:05", "format h:mm:ss")
	t.eq(_lbl(p, "NextLabel").text, p.tr("no_lives_next") % "15:00", "đếm ngược 15:00")
	t.eq(_lbl(p, "LivesLabel").text, p.tr("no_lives_lives") % [0, 10], "số mạng")
	t.eq(_lbl(p, "FullLabel").text, p.tr("no_lives_full_in") % "2:30:00", "đầy mạng sau 2:30:00")
	t.eq(_btn(p, "GoldButton").text, p.tr("no_lives_refill_gold") % 900, "nút 900 gold")
	g.test_now = NOW + 301
	p.refresh()
	t.eq(_lbl(p, "NextLabel").text, p.tr("no_lives_next") % "9:59", "đếm ngược sau 301 giây")
	t.ok(not st.has("r"), "chưa đóng")
	g.test_now = NOW + 901
	p.refresh()
	t.eq(st.get("r"), "refilled", "mạng hồi thì đóng")
	p.free()


func test_no_lives_gold(t: T) -> void:
	var g := _g()
	_no_lives_state(g)
	g.s.coins = 100
	var p := _mount("no_lives", {})
	var st := _watch(p)
	_btn(p, "GoldButton").pressed.emit()
	t.ok(not st.has("r"), "thiếu gold không đóng")
	t.eq(_lbl(p, "MessageLabel").text, p.tr("no_lives_not_enough_gold"), "báo thiếu gold")
	t.eq(int(g.s.coins), 100, "không trừ")
	g.s.coins = 5000
	_btn(p, "GoldButton").pressed.emit()
	t.eq(st.get("r"), "refilled", "nạp xong")
	t.eq(int(g.s.lives.count), 5, "5 mạng")
	t.eq(int(g.s.coins), 4100, "trừ 900")
	p.free()


func test_no_lives_video(t: T) -> void:
	var g := _g()
	_no_lives_state(g)
	var p := _mount("no_lives", {})
	var st := _watch(p)
	t.ok(not (_lbl(p, "NoAdsLabel") as Label).visible, "có video thì không báo")
	_plat().ads.simulate("closed")
	_btn(p, "VideoButton").pressed.emit()
	await _wait_until(func() -> bool: return _lbl(p, "MessageLabel").visible)
	t.eq(int(g.s.lives.count), 0, "đóng sớm không có mạng")
	t.ok(not st.has("r"), "vẫn ở màn hết mạng")
	_btn(p, "VideoButton").pressed.emit()
	await _wait_until(func() -> bool: return st.has("r"))
	t.eq(st.get("r"), "refilled", "xem hết")
	t.eq(int(g.s.lives.count), 1, "+1 mạng")
	p.free()


func test_no_lives_no_ads_message(t: T) -> void:
	var g := _g()
	_no_lives_state(g)
	_plat().ads.set_ready(false, false)
	var p := _mount("no_lives", {})
	var st := _watch(p)
	t.ok((_lbl(p, "NoAdsLabel") as Label).visible, "báo không có video")
	t.ok(_btn(p, "VideoButton").disabled, "nút video tắt")
	_btn(p, "HomeButton").pressed.emit()
	t.eq(st.get("r"), "home", "về Home được")
	_plat().ads.set_ready(true, true)
	p.free()


func test_result_layout_rules(t: T) -> void:
	var g := _g()
	_no_lives_state(g)
	var nodes: Array[Control] = [
		_mount("win_card", {"coins": 40, "x2_available": true, "x2_free": true}),
		_mount("lose_card", {"offer": "rescue_pack", "life_charged": true}),
		_mount("no_lives", {}),
	]
	for n in nodes:
		for b in n.find_children("*", "Button", true, false):
			var btn := b as Button
			t.ok(btn.custom_minimum_size.x >= 96 and btn.custom_minimum_size.y >= 96, "nút >= 96x96: %s/%s" % [n.name, btn.name])
	t.eq(nodes[0].find_children("*", "Timer", true, false).size(), 0, "thẻ thắng không đếm ngược")
	t.eq(nodes[1].find_children("*", "Timer", true, false).size(), 0, "thẻ thua không đếm ngược")
	for n in nodes:
		n.free()


func test_win_feature_progress(t: T) -> void:
	var g := _g()
	var res := _won(g, 3)
	t.eq(res.unlocked, ["daily_gift"] as Array[String], "thắng L3 mở quà ngày")
	t.eq(g.next_after_win(res, false), "home", "mở tính năng Home thì về Home")
	var p := _mount("win_card", res)
	t.ok(_lbl(p, "FeatureLabel").text.contains(p.tr("feature_daily_gift")), "tên tính năng")
	await _wait_until(func() -> bool: return _lbl(p, "FeaturePercent").text == "100%")
	t.eq(_lbl(p, "FeaturePercent").text, "100%", "thanh chạy tới 100%")
	await _wait_until(func() -> bool: return _lbl(p, "FeatureLabel").text == p.tr("feature_unlocked") % p.tr("feature_daily_gift"))
	t.ok(_lbl(p, "FeatureLabel").text == p.tr("feature_unlocked") % p.tr("feature_daily_gift"), "báo đã mở")
	p.free()
	var res2 := _won(g, 6)
	t.eq(g.next_after_win(res2, false), "level", "không mở gì thì vào level kế")
	t.eq(g.next_after_win(res2, true), "home", "challenge về Home")


func test_win_no_progress_when_exhausted(t: T) -> void:
	var g := _g()
	var res := _won(g, 95)
	t.eq(res.progress.has_next, false, "hết tính năng")
	var p := _mount("win_card", res)
	t.ok(p.find_child("FeatureProgress", true, false) == null, "ẩn thanh")
	p.free()


func test_level_end_params(t: T) -> void:
	var g := _g()
	g.s.level = 2
	var a1: Dictionary = g.start_attempt()
	g.on_level_lost(a1)
	var a2: Dictionary = g.start_attempt()
	g.on_level_lost(a2)
	var ends: Array = _plat().an.named("level_end")
	t.eq(int(ends[0].params.replay), 0, "lần đầu không phải chơi lại")
	t.eq(int(ends[1].params.replay), 1, "lần hai là chơi lại")
	t.ok(ends[1].params.has("blocks_left") and ends[1].params.has("rescues"), "có blocks_left, rescues")
