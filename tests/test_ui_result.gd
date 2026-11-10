extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const NoLives := preload("res://src/ui/no_lives.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")

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


## Chữ hiển thị của nút: nút prefab (unity_ui.gd) vẽ chữ bằng Label con, nút thường dùng Button.text.
func _btn_text(b: Button) -> String:
	if b.text != "":
		return b.text
	for l in b.find_children("*", "Label", true, false):
		if (l as Label).visible:
			return (l as Label).text
	return ""


func _won(g: Node, level: int) -> Dictionary:
	g.s.level = level
	var attempt: Dictionary = g.start_attempt()
	return g.on_level_won(attempt)


# --- win card ---

## L11 là thẻ thắng đầu tiên (L1–10 không có thẻ, Config.ECON.win_card_from_level): x2 miễn phí để biết nút.
func test_win_l11_free_x2(t: T) -> void:
	var g := _g()
	var res := _won(g, 11)
	var won := 40 + int(res.move_coins)
	t.ok(int(res.move_coins) > 0, "gold MOVES thừa")
	t.eq(int(res.coins), won, "+40 và MOVES thừa")
	t.eq(int(g.s.coins), 1000 + won, "thắng vào ví")
	t.ok(res.card, "L11 có thẻ thắng")
	t.ok(res.x2_free, "L11 x2 miễn phí")
	var p := _mount("win_card", res)
	var st := _watch(p)
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % won, "hiện tổng gold")
	t.eq(_btn_text(_btn(p, "X2Button")), p.tr("win_x2_free"), "nút x2 miễn phí")
	t.ok(_lbl(p, "X2HintLabel") != null, "gợi ý x2 ở thẻ đầu tiên")
	t.ok(p.find_child("HubTop", true, false) == null, "chưa x2 thì không có thanh trên")
	_btn(p, "X2Button").pressed.emit()
	await _wait_until(func() -> bool: return _btn_text(_btn(p, "X2Button")) == p.tr("win_x2_done"))
	t.eq(int(g.s.coins), 1000 + 2 * won, "x2 cộng thêm một lần nữa")
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % (2 * won), "hiện gấp đôi")
	t.ok(_btn(p, "X2Button").disabled, "x2 một lần")
	t.eq(_plat().ads.calls.size(), 0, "L11 không xem quảng cáo")
	# Gold x2 bay lên chip gold của thanh trên, chip đếm từ ví trước lúc thắng; xong thì thẻ tự đóng.
	var top: Control = p.find_child("HubTop", true, false)
	t.ok(top != null, "x2 xong thì thanh trên hiện")
	t.eq(top.gold_label.text, "1000", "chip gold bắt đầu từ ví trước lúc thắng")
	t.ok(_btn(p, "ContinueButton").disabled, "đang bay thì khoá Tiếp tục")
	_btn(p, "ContinueButton").pressed.emit()
	t.ok(not st.has("r"), "bấm Tiếp tục lúc đang bay không đóng thẻ")
	t.ok(await _wait_ms(func() -> bool: return p.find_child("X2GoldFx", true, false) != null), "gold bay lên thanh trên")
	t.ok(await _wait_ms(func() -> bool: return st.has("r"), 6000), "bay xong thì tự đóng")
	t.eq(top.gold_label.text, str(1000 + 2 * won), "chip gold hiện đủ số trong ví")
	t.eq(st.get("r"), {"x2_offered": true, "x2_taken": true, "rate_prompt": false, "coins": 2 * won}, "kết quả")
	p.free()


func test_win_x2_video_closed_then_ok(t: T) -> void:
	var g := _g()
	var res := _won(g, 12)
	var won := int(res.coins)
	t.ok(res.x2_available and not res.x2_free, "L12 x2 qua video")
	var p := _mount("win_card", res)
	var st := _watch(p)
	t.eq(_btn_text(_btn(p, "X2Button")), p.tr("win_x2"), "nút x2")
	_plat().ads.simulate("closed")
	_btn(p, "X2Button").pressed.emit()
	await _wait_until(func() -> bool: return _lbl(p, "MessageLabel").visible)
	t.eq(_lbl(p, "MessageLabel").text, p.tr("ads_closed_early"), "đóng sớm")
	t.eq(int(g.s.coins), 1000 + won, "không thưởng")
	t.ok(not _btn(p, "X2Button").disabled, "thử lại được")
	_btn(p, "X2Button").pressed.emit()
	await _wait_until(func() -> bool: return int(g.s.coins) == 1000 + 2 * won)
	t.eq(int(g.s.coins), 1000 + 2 * won, "xem hết thì x2")
	t.ok(await _wait_ms(func() -> bool: return st.has("r"), 6000), "gold bay lên thanh trên xong thì tự đóng")
	t.eq(st.get("r").x2_taken, true, "x2_taken")
	p.free()


func _wait_ms(cond: Callable, ms: int = 4000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


## Màn level truyền chip lượt: gold MOVES thừa bay vào ô gold, nút x2 đếm theo; bấm x2 giữa chừng thì cộng nốt rồi x2.
func test_win_move_gold_then_x2_mid_flight(t: T) -> void:
	var g := _g()
	g.s.level = 12
	var attempt: Dictionary = g.start_attempt()
	var res: Dictionary = g.on_level_won(attempt)
	var moves: int = attempt.board.moves_left()
	var won := int(res.coins)
	var base := won - int(res.move_coins)
	t.ok(moves > 1 and int(res.move_coins) == 10 * moves, "10 gold mỗi MOVES thừa")
	var chip := Control.new()
	chip.size = Vector2(120, 100)
	_tree().root.add_child(chip)
	var cashed := {"n": 0}
	var args := res.duplicate()
	args["moves_chip"] = chip
	args["moves_left"] = moves
	args["on_move_cashed"] = func(n: int) -> void: cashed.n += n
	var p := _mount("win_card", args)
	var amount := _btn(p, "X2Button").get_node("GameObject (1)/Text (TMP)") as Label
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % base, "ô gold bắt đầu ở thưởng gốc")
	t.eq(amount.text, str(base * 2), "nút x2 theo số đang hiện")
	t.ok(await _wait_ms(func() -> bool: return cashed.n > 0), "đồng đầu rời chip")
	t.ok(p.find_child("MoveGoldFx", true, false) != null, "đang bay")
	t.eq(chip.z_index, p.CHIP_Z, "khung chip lượt vẽ trên thẻ lúc bay")
	t.ok((p.find_child("MoveGoldFx", true, false) as Control).z_index > chip.z_index, "đồng gold vẽ trên chip")
	# Video đóng sớm: x2 không thành nhưng phần gold MOVES thừa đã cộng nốt.
	_plat().ads.simulate("closed")
	_btn(p, "X2Button").pressed.emit()
	t.ok(await _wait_ms(func() -> bool: return _lbl(p, "MessageLabel").visible), "báo đóng sớm")
	t.eq(cashed.n, moves, "bấm x2 thì chip lượt nhận đủ")
	t.ok(await _wait_ms(func() -> bool: return chip.z_index == 0 and chip.modulate.a == 1.0), "chip lượt về dưới nền tối")
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % won, "cộng nốt gold MOVES thừa")
	t.eq(amount.text, str(won * 2), "nút x2 hiện đủ")
	_btn(p, "X2Button").pressed.emit()
	t.ok(await _wait_ms(func() -> bool: return _btn(p, "X2Button").disabled), "x2 xong")
	t.eq(cashed.n, moves, "không báo thêm lượt")
	t.eq(int(g.s.coins), 1000 + 2 * won, "x2 nhân đôi cả gold MOVES thừa")
	t.eq(_lbl(p, "RewardLabel").text, p.tr("win_reward") % (2 * won), "hiện gấp đôi")
	await _tree().process_frame
	t.ok(p.find_child("MoveGoldFx", true, false) == null, "hiệu ứng đã xoá")
	p.free()
	chip.free()


func test_win_no_x2_without_ads(t: T) -> void:
	var g := _g()
	_plat().ads.set_ready(false, false)
	var res := _won(g, 12)
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


## Weekly Pass Active và đã xem tutorial: dải phần thưởng có ô "+N key" (icon chìa) ngay sau ô gold; chưa xem thì không.
func test_win_weekly_key_reward(t: T) -> void:
	var g := _g()
	var res := _won(g, 30)
	t.eq(int(res.weekly_points), 0, "chưa xem tutorial thì không có key")
	var p := _mount("win_card", res)
	t.ok(p.find_child("WeeklyKeyReward", true, false) == null, "không có ô key")
	p.free()
	g.weekly_mark_tutorial_seen()
	var res2 := _won(g, 30)
	t.eq(int(res2.weekly_points), 1, "level thường +1 key")
	var p2 := _mount("win_card", res2)
	var cell := p2.find_child("WeeklyKeyReward", true, false) as Control
	t.ok(cell != null and cell.visible, "có ô key")
	if cell != null:
		t.eq((cell.get_node("RewardLabel") as Label).text, p2.tr("weekly_key_reward_one"), "+1 key")
		var icon: Control = cell.get_node("CoinIcon")
		t.eq(icon.get("region").size, (icon.get("tex") as Texture2D).get_size(), "icon chìa vẽ cả ảnh, không giữ vùng cắt gold")
		var gold := p2.find_child("GoldReward", true, false) as Control
		t.eq(cell.get_index(), gold.get_index() + 1, "ngay sau ô gold")
	p2.free()
	var p3 := _mount("win_card", {"coins": 40, "weekly_points": 3, "special_tickets": 1})
	var c3 := p3.find_child("WeeklyKeyReward", true, false) as Control
	t.ok(c3 != null, "Hard: có ô key")
	if c3 != null:
		t.eq((c3.get_node("RewardLabel") as Label).text, p3.tr("weekly_key_reward") % 3, "+3 key")
		var ticket := p3.find_child("SpecialTicketReward", true, false) as Control
		t.eq(ticket.get_index(), c3.get_index() + 1, "ô vé sau ô key")
	p3.free()


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


func test_lose_art_is_the_crying_icon(t: T) -> void:
	_g()
	var p := _mount("lose_card", {"offer": "", "life_charged": false})
	var art: Control = p.get("ui").node("Panel/LossPanel/BG/Image")
	t.eq((art.get("tex") as Texture2D).resource_path, "res://assets/ui/art_lose.png", "icon art_lose thay tranh prefab")
	t.ok(bool(art.get("preserve_aspect")), "giữ tỉ lệ icon")
	var m := art.get_node_or_null(UiMotion.NODE_NAME)
	t.ok(m != null and int(m.get("kind")) == UiMotion.SOB, "icon nấc như đang khóc")
	var tear := art.get_node_or_null("Tear") as TextureRect
	t.ok(tear != null, "giọt lệ là node riêng trên icon")
	if tear != null:
		t.eq(tear.texture.resource_path, "res://assets/ui/art_lose_tear.png", "ảnh giọt lệ tách khỏi icon")
		var tm := tear.get_node_or_null(UiMotion.NODE_NAME)
		t.ok(tm != null and int(tm.get("kind")) == UiMotion.TEAR, "giọt lệ chảy")
		t.near(tear.modulate.a, 0.0, 0.0001, "giọt lệ chờ ứa ra")
	p.free()


func test_lose_rescue_pack_buy(t: T) -> void:
	var g := _g()
	var p := _mount("lose_card", {"offer": "rescue_pack", "life_charged": false})
	t.ok(_btn(p, "PackBuyButton") != null, "có gói cứu nguy")
	t.eq(_btn_text(_btn(p, "PackBuyButton")), _plat().price("rescue_pack"), "chỉ giá, lấy từ store")
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
	g.s.lives = {"count": 0, "next_at": NOW + int(Config.LIVES.regen_sec)}


func test_no_lives_countdown(t: T) -> void:
	var g := _g()
	_no_lives_state(g)
	var p := _mount("no_lives", {})
	var st := _watch(p)
	t.eq(NoLives.format_time(65), "1:05", "format mm:ss")
	t.eq(NoLives.format_time(3725), "1:02:05", "format h:mm:ss")
	# PopupMoreHeartLayer: "next life in" above, the clock chip holds the only countdown.
	t.eq(_lbl(p, "NextLabel").text, p.tr("no_lives_next"), "dòng mạng kế tiếp không có giờ")
	var rg: int = Config.LIVES.regen_sec
	t.eq(_lbl(p, "TimeLabel").text, NoLives.format_time(rg), "đếm ngược một chu kỳ hồi trên chip đồng hồ")
	# The count is written on the heart icon.
	t.eq(_lbl(p, "LivesLabel").text, "0", "số mạng")
	# GoldBtn of PopupMoreHeartLayer: gold icon + price, heart badge +refill_lives.
	t.eq(_lbl(p, "GoldPrice").text, "900", "nút 900 gold")
	t.ok(_btn(p, "GoldButton").is_ancestor_of(_lbl(p, "GoldPrice")), "giá nằm trên nút gold")
	g.test_now = NOW + 61
	p.refresh()
	t.eq(_lbl(p, "TimeLabel").text, NoLives.format_time(rg - 61), "đếm ngược sau 61 giây")
	t.ok(not st.has("r"), "chưa đóng")
	g.test_now = NOW + rg + 1
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


## Opened from the heart on the top bar with lives left: stays open, and refilling goes back Home, never into a level.
func test_no_lives_from_hub(t: T) -> void:
	var g := _g()
	g.s.level = 10
	g.s.lives = {"count": 3, "next_at": NOW + 900}
	g.s.coins = 5000
	var p := _mount("no_lives", {"source": "hub"})
	var st := _watch(p)
	t.ok(not st.has("r"), "còn mạng vẫn mở")
	t.eq(_lbl(p, "LivesLabel").text, "3", "số mạng")
	t.eq((p.get("_title") as Label).text, p.tr("no_lives_more_title"), "tiêu đề Thêm mạng")
	t.eq(_lbl(p, "BodyLabel").text, p.tr("no_lives_more_body"), "lời giải thích khi còn mạng")
	t.ok(_btn(p, "GoldButton").is_visible_in_tree() and _btn(p, "VideoButton").is_visible_in_tree(), "có nút nạp")
	t.ok(_lbl(p, "TimeLabel").is_visible_in_tree(), "có đếm ngược")
	t.ok(not _lbl(p, "FullLabel").is_visible_in_tree(), "chưa đầy thì không báo đầy")
	_btn(p, "GoldButton").pressed.emit()
	t.eq(st.get("r"), "home", "nạp xong về Home")
	p.free()


## Full lives: the heart popup still opens, without the video and gold buttons or the countdown.
func test_no_lives_from_hub_full(t: T) -> void:
	var g := _g()
	g.s.level = 10
	g.s.lives = {"count": int(g.lives_view().max), "next_at": 0}
	var p := _mount("no_lives", {"source": "hub"})
	var st := _watch(p)
	t.ok(not st.has("r"), "đầy mạng vẫn mở")
	t.ok(_lbl(p, "FullLabel").is_visible_in_tree(), "có dòng báo đầy trong popup")
	t.eq(_lbl(p, "FullLabel").text, p.tr("no_lives_full_body"), "báo đầy mạng")
	t.ok(not _lbl(p, "BodyLabel").visible, "không lặp lại dòng giải thích dưới popup")
	t.ok(not _btn(p, "Continue").is_visible_in_tree(), "không hiện nút Continue của prefab")
	t.ok(not _btn(p, "GoldButton").is_visible_in_tree(), "ẩn nút gold")
	t.ok(not _btn(p, "VideoButton").is_visible_in_tree(), "ẩn nút video")
	t.ok(not _lbl(p, "NextLabel").is_visible_in_tree() and not _lbl(p, "TimeLabel").is_visible_in_tree(), "ẩn đếm ngược")
	t.ok(not _lbl(p, "NoAdsLabel").visible, "không báo thiếu video")
	_btn(p, "HomeButton").pressed.emit()
	t.eq(st.get("r"), "home", "đóng về Home")
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
			# Prefab buttons (unity_ui.gd) keep the Unity art size and grow only their hit area.
			var hit: Vector2 = btn.call("hit_size") if btn.has_method("hit_size") else btn.custom_minimum_size
			t.ok(hit.x >= 96 - 0.01 and hit.y >= 96 - 0.01, "nút >= 96x96: %s/%s" % [n.name, btn.name])
	t.eq(nodes[0].find_children("*", "Timer", true, false).size(), 0, "thẻ thắng không đếm ngược")
	t.eq(nodes[1].find_children("*", "Timer", true, false).size(), 0, "thẻ thua không đếm ngược")
	for n in nodes:
		n.free()


func test_win_feature_progress(t: T) -> void:
	var g := _g()
	var res := _won(g, 13)
	t.eq(res.unlocked, ["daily_gift", "stone"] as Array[String], "thắng L13 mở quà ngày (và Thùng sắt)")
	t.eq(g.next_after_win(res, false), "home", "mở tính năng Home thì về Home")
	var p := _mount("win_card", res)
	t.ok(_lbl(p, "FeatureLabel").text.contains(p.tr("feature_daily_gift")), "tên tính năng")
	await _wait_until(func() -> bool: return _lbl(p, "FeaturePercent").text == "100%")
	t.eq(_lbl(p, "FeaturePercent").text, "100%", "thanh chạy tới 100%")
	var done: String = p.tr("feature_unlocked") % (p.tr("feature_daily_gift") + ", " + p.tr("feature_stone"))
	await _wait_until(func() -> bool: return _lbl(p, "FeatureLabel").text == done)
	t.eq(_lbl(p, "FeatureLabel").text, done, "báo đã mở")
	p.free()
	var res2 := _won(g, 6)
	t.eq(g.next_after_win(res2, false), "level", "không mở gì thì vào level kế")
	t.eq(g.next_after_win(res2, true), "home", "challenge về Home")


func test_win_no_progress_when_exhausted(t: T) -> void:
	const Config := preload("res://src/config.gd")
	var last := 0
	for k in Config.UNLOCK:
		last = maxi(last, int(Config.UNLOCK[k]))
	var g := _g()
	var res := _won(g, last + 5)
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
