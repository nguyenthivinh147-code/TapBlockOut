extends RefCounted
## Layer Weekly Pass, layer Chain Offer, nút sự kiện ở Home.
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_ui_events"
const MON := 1699833600  # thứ Hai 00:00 UTC
const D := 86400


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _game(level: int) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_tz = 0
	g.test_now = MON + 2 * D
	g.s.level = level
	_root().get_node("Platform").iap = MockIap.new()
	return g


func _open(path: String) -> Control:
	var node := (load(path) as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.setup({})
	return node


func test_weekly_locked_and_waiting(t: T) -> void:
	var g := _game(5)
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(node.main_buttons.size(), 0, "Locked không có Main Tree")
	node.queue_free()
	g.s.level = 30
	g.test_now = MON + 3 * 3600
	var w := _open("res://scenes/weekly_pass.tscn")
	t.eq(w.main_buttons.size(), 0, "Waiting không có Main Tree")
	t.ok(w.close_button != null, "có nút đóng")
	w.queue_free()


func test_weekly_active_claim_and_buy(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	g.s.weekly.points = 8
	var node := _open("res://scenes/weekly_pass.tscn")
	t.eq(node.main_buttons.size(), 20, "10 mốc x (free + VIP)")
	t.eq(node.main_buttons["free_0"].disabled, false, "free mốc 0 nhận được")
	t.eq(node.main_buttons["free_2"].disabled, true, "mốc 2 chưa đủ điểm")
	t.eq(node.main_buttons["vip_0"].disabled, true, "VIP khoá")
	t.ok(node.main_buttons["free_0"].custom_minimum_size.y >= 96, "nút đủ lớn")
	var c0 := int(g.s.coins)
	node.main_buttons["free_0"].pressed.emit()
	t.eq(int(g.s.coins), c0 + 100, "nhận thưởng free")
	t.eq(node.main_buttons["free_0"].disabled, true, "đã nhận thì khoá")
	t.ok(node.buy_vip_button != null, "có nút mua VIP")
	node.buy_vip_button.pressed.emit()
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(bool(g.s.weekly.vip), true, "đã mua VIP")
	t.ok(node.buy_vip_button == null, "ẩn nút mua sau khi có VIP")
	t.eq(node.main_buttons["vip_0"].disabled, false, "VIP mở khoá")
	t.eq(node.claim_all_button.disabled, false, "còn thưởng để nhận hết")
	node.claim_all_button.pressed.emit()
	t.eq(node.claim_all_button.disabled, true, "nhận hết")
	node.queue_free()


func test_weekly_end_popup(t: T) -> void:
	var g := _game(30)
	g.weekly_refresh()
	g.s.weekly.points = 4
	g.test_now = MON + 9 * D
	var node := _open("res://scenes/weekly_pass.tscn")
	t.ok(not node.end_info.is_empty(), "hiện popup cuối mùa")
	t.eq(bool(node.end_info.vip), false, "người không VIP")
	t.eq(node.main_buttons.size(), 0, "popup cuối mùa che Main Tree")
	node.queue_free()


func test_chain_layer(t: T) -> void:
	var g := _game(24)
	g.s.chain = {"active": true, "id": "chain_a", "step": 0, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	var node := _open("res://scenes/chain_offer.tscn")
	t.eq(node.node_states, ["claimable", "locked", "locked", "locked", "locked", "locked"], "cửa sổ 6 bước")
	t.ok(node.claim_button != null, "có nút nhận")
	var c0 := int(g.s.coins)
	node.claim_button.pressed.emit()
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.eq(int(g.s.coins), c0 + 300, "nhận bước free")
	t.eq(node.node_states[0], "claimed", "bước 1 đã nhận")
	t.eq(node.node_states[1], "claimable", "bước 2 nhận được")
	node.queue_free()


func test_chain_window_slides(t: T) -> void:
	var cls := preload("res://src/ui/chain_offer.gd")
	t.eq(cls.window_start(0, 8, 6), 0, "đầu chuỗi")
	t.eq(cls.window_start(3, 8, 6), 2, "giữ một bước đã nhận phía trước")
	t.eq(cls.window_start(7, 8, 6), 2, "kẹp ở cuối")
	t.eq(cls.window_start(8, 8, 6), 2, "xong hết")


func test_home_event_buttons(t: T) -> void:
	var g := _game(10)
	var home := _open("res://scenes/home.tscn")
	t.eq(home._weekly_col.visible, false, "Weekly ẩn khi Locked")
	t.eq(home._chain_col.visible, false, "Chain ẩn khi chưa có")
	t.eq(home._special_col.visible, false, "Special Pack ẩn khi chưa đủ điều kiện")
	g.s.level = 30
	g.s.buys.append({"token": "x", "sku": "starter_pack"})
	g.s.chain = {"active": true, "id": "chain_a", "step": 0, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	home.refresh()
	t.eq(home._weekly_col.visible, true, "Weekly hiện khi Active")
	t.eq(home.weekly_dot.visible, true, "chấm đỏ khi chưa mở chu kỳ")
	t.eq(home._chain_col.visible, true, "Chain hiện")
	t.eq(home._special_col.visible, true, "Special Pack hiện")
	var got := []
	home.closed.connect(func(r: Variant) -> void: got.append(r))
	home.special_btn.pressed.emit()
	t.eq(got[0], {"action": "offer", "id": "special_pack"}, "bấm mở popup offer")
	home.weekly_btn.pressed.emit()
	t.eq(got[1], {"action": "weekly"}, "bấm mở Weekly Pass")
	home.chain_btn.pressed.emit()
	t.eq(got[2], {"action": "chain"}, "bấm mở Chain Offer")
	home.queue_free()
