extends RefCounted
## Weekly Pass, Chain Offer, Special Pack qua autoload Game (mock Platform).
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_game_events"
const MON := 1699833600  # thứ Hai 00:00 UTC
const D := 86400


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g() -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	var p: Node = _root().get_node("Platform")
	p.ads.calls.clear()
	p.iap = MockIap.new()
	g.test_tz = 0
	g.test_now = MON + 2 * D  # thứ Tư: Active
	return g


func _win(g: Node, attempt: Dictionary) -> void:
	var b: RefCounted = attempt.board
	var guard := 0
	while not b.is_won() and guard < 200:
		var id: String = b.hint()
		if id == "":
			break
		g.tap(attempt, id)
		guard += 1


func test_unlock_level(t: T) -> void:
	var g := _g()
	t.eq(g.weekly_unlock_level(), 26, "level HARD thứ hai là L26 (Hard: L23, L26)")
	g.s.level = 26
	t.eq(g.weekly_state(), "locked", "chưa qua L26")
	g.s.level = 27
	t.eq(g.weekly_state(), "active", "qua L26, thứ Tư")
	g.test_now = MON + 3 * 3600
	t.eq(g.weekly_state(), "waiting", "thứ Hai 03:00")


func test_win_gives_key_only_after_tutorial(t: T) -> void:
	var g := _g()
	g.s.level = 30
	t.eq(g.weekly_tutorial_seen(), false, "chưa xem tutorial")
	var a0: Dictionary = g.start_attempt()
	_win(g, a0)
	t.eq(g.on_level_won(a0).weekly_points, 0, "chưa xem tutorial thì không cộng key")
	t.eq(int(g.s.weekly.points), 0, "điểm vẫn 0")
	g.weekly_mark_tutorial_seen()
	t.eq(g.weekly_tutorial_seen(), true, "đã đánh dấu")
	t.eq(g.weekly_view().tut_seen, true, "view báo đã xem")
	g.s.level = 30
	var a1: Dictionary = g.start_attempt()
	_win(g, a1)
	t.eq(g.on_level_won(a1).weekly_points, 1, "xem rồi thì cộng key")


func test_win_gives_key_only_when_active(t: T) -> void:
	var g := _g()
	g.s.weekly.tut_seen = true
	g.s.level = 30
	var a: Dictionary = g.start_attempt()
	_win(g, a)
	var r: Dictionary = g.on_level_won(a)
	t.eq(r.weekly_points, 1, "level thường +1")
	t.eq(int(g.s.weekly.points), 1, "đã lưu")
	g.test_now = MON + 3 * 3600
	g.s.level = 31
	var a2: Dictionary = g.start_attempt()
	_win(g, a2)
	t.eq(g.on_level_won(a2).weekly_points, 0, "Waiting không cộng")
	g.s.level = 5
	g.test_now = MON + 2 * D
	var a3: Dictionary = g.start_attempt()
	_win(g, a3)
	t.eq(g.on_level_won(a3).weekly_points, 0, "Locked không cộng")


func test_vip_purchase_and_hearts(t: T) -> void:
	var g := _g()
	g.s.level = 30
	g.weekly_refresh()
	t.eq(g.lives_view().max, 10, "chưa VIP")
	var r: Dictionary = await g.weekly_buy_vip()
	t.eq(r.granted, true, "mua VIP")
	t.eq(bool(g.s.weekly.vip), true, "đặt cờ VIP")
	var lv: Dictionary = g.lives_view()
	t.eq(lv.max, 13, "+3 mạng tối đa")
	t.eq(lv.count, 13, "tặng đủ mạng")
	var again: Dictionary = await g.weekly_buy_vip()
	t.eq(again.granted, false, "đã VIP thì không mua nữa")
	g.test_now = MON + 7 * D + 3 * 3600  # thứ Hai tuần sau, Waiting
	g.weekly_refresh()
	t.eq(g.lives_view().max, 10, "hết thưởng khi sang mùa")
	t.eq(g.lives_view().count, 10, "kẹp lại về 10")
	t.eq(bool(g.s.weekly.vip), false, "reset VIP")


func test_claim_and_season_end(t: T) -> void:
	var g := _g()
	g.s.level = 30
	g.weekly_refresh()
	g.s.weekly.points = 8
	var before := int(g.s.coins)
	var r0: Dictionary = g.weekly_claim_free(0)
	t.eq(r0.inf_min, 15, "nhận free (mốc khởi đầu): mạng vô hạn 15 phút")
	t.eq(int(g.s.coins), before, "mốc khởi đầu không cộng gold")
	t.eq(g.lives_view().infinite, true, "đang vô hạn mạng")
	t.eq(g.lives_view().infinite_left, 900, "còn 15 phút")
	t.eq(g.weekly_claim_vip(0), {}, "chưa VIP không nhận được")
	await g.weekly_buy_vip()
	var v: Dictionary = g.weekly_view()
	t.eq(v.badge, 5, "free mốc 1 và 2, VIP mốc 0, 1 và 2")
	var c := int(g.s.coins)
	t.eq(g.weekly_claim_all().coins, 750, "nhận hết")
	t.eq(int(g.s.coins), c + 750, "ví")
	t.eq(g.weekly_view().badge, 0, "hết badge")
	# sang mùa: VIP chưa nhận gì thêm; mùa mới phát popup cuối mùa
	g.s.weekly.points = 20
	g.test_now = MON + 8 * D
	var inv_before := int(g.s.coins)
	var settled: Dictionary = g.weekly_refresh()
	t.eq(settled.settled, true, "chốt mùa")
	t.ok(int(g.s.coins) > inv_before, "VIP tự nhận thưởng tồn")
	t.eq(g.weekly_view().pending_end, true, "có popup cuối mùa")
	t.eq(g.weekly_take_end().vip, true, "popup VIP")
	t.eq(g.weekly_view().pending_end, false, "chỉ một lần")


func test_chain_on_lose(t: T) -> void:
	var g := _g()
	g.s.level = 129
	var a: Dictionary = g.start_attempt()
	g.on_level_lost(a)
	t.eq(g.chain_view().is_empty(), true, "L129 chưa bật")
	g.s.level = 130
	var b: Dictionary = g.start_attempt()
	g.on_level_lost(b)
	var v: Dictionary = g.chain_view()
	t.eq(v.id, "chain_a", "bật ở L130 sau ván thua")
	t.eq(g.chain_take_autoshow(), true, "tự mở một lần")
	t.eq(g.chain_take_autoshow(), false, "không mở lại")
	# bước 0: free
	var c0 := int(g.s.coins)
	var r0: Dictionary = await g.chain_claim()
	t.eq(r0.ok, true, "bước free")
	t.eq(int(g.s.coins), c0 + 300, "+300 gold")
	# bước 1: ad (mock headless xem hết)
	var hints := int(g.s.inv.hint)
	var r1: Dictionary = await g.chain_claim()
	t.eq(r1.ok, true, "bước ad")
	t.eq(int(g.s.inv.hint), hints + 1, "+1 hint")
	await g.chain_claim()  # bước 2 free
	# bước 3: pay, thưởng đến từ IAP đúng một lần
	var c3 := int(g.s.coins)
	var r3: Dictionary = await g.chain_claim()
	t.eq(r3.ok, true, "bước pay")
	t.eq(r3.reward.coins, 0, "pay không cộng thêm")
	t.eq(int(g.s.coins), c3 + 1500, "gói chain_pack_1 giao một lần")
	t.eq(int(g.chain_view().step), 4, "sang bước 4")
	# hết hạn rồi bật lại sau cooldown
	g.test_now += D + 10
	t.eq(g.chain_view().is_empty(), true, "hết hạn")
	g.s.level = 151
	var d: Dictionary = g.start_attempt()
	g.on_level_lost(d)
	t.eq(g.chain_view().is_empty(), true, "đang cooldown")
	g.test_now += 3 * D
	var e: Dictionary = g.start_attempt()
	g.on_level_lost(e)
	t.eq(g.chain_view().id, "chain_b", "chuỗi kế sau cooldown")


func test_chain_on_win(t: T) -> void:
	var g := _g()
	g.s.level = 150
	var a: Dictionary = g.start_attempt()
	g.on_level_won(a)
	t.eq(g.chain_view().id, "chain_a", "bật sau ván thắng")


func test_chain_skips_challenge(t: T) -> void:
	var g := _g()
	g.s.level = 150
	var a: Dictionary = g.start_attempt()
	a["challenge"] = true
	g.on_level_lost(a)
	t.eq(g.chain_view().is_empty(), true, "thua Challenge không bật")
	var b: Dictionary = g.start_attempt()
	b["challenge"] = true
	g.on_level_won(b)
	t.eq(g.chain_view().is_empty(), true, "thắng Challenge không bật")


func test_chain_pay_cancel_keeps_step(t: T) -> void:
	var g := _g()
	g.s.level = 150
	g.s.chain = {"active": true, "id": "chain_a", "step": 3, "expires": g.test_now + D,
		"cooldown_until": 0, "shown": true, "rotation": 1}
	var p: Node = _root().get_node("Platform")
	p.iap.simulate("cancel")
	var coins := int(g.s.coins)
	var r: Dictionary = await g.chain_claim()
	t.eq(r.ok, false, "huỷ mua không qua bước")
	t.eq(int(g.s.chain.step), 3, "giữ bước")
	t.eq(int(g.s.coins), coins, "không cộng")


func test_special_pack_flow(t: T) -> void:
	var g := _g()
	g.s.level = 16
	t.eq(g.special_pack_id(), "", "chưa mua Starter")
	var r0: Dictionary = await g.buy_sku("starter_pack")
	t.eq(r0.granted, true, "mua Starter")
	t.eq(g.special_pack_id(), "special_pack", "hiện Special Pack")
	g.s.level = 15
	t.eq(g.special_pack_id(), "", "dưới level 16")
	g.s.level = 16
	t.eq(g.offer_sku("special_pack"), "special_pack", "thứ Tư: giá thường")
	g.test_now = MON + 5 * D  # thứ Bảy: weekend sale
	t.eq(g.offer_sku("special_pack"), "special_pack_sale", "cuối tuần đổi sang gói sale")
	t.eq(g.offer_sku("starter_pack"), "starter_pack", "gói không có bản sale giữ nguyên")
	var coins := int(g.s.coins)
	var r: Dictionary = await g.offer_buy("special_pack")
	t.eq(r.granted, true, "mua bản sale")
	t.eq(int(g.s.coins), coins + 12000, "nội dung gói")
	# One-time (2026-11-10): the sale copy counts as the pack, the icon goes and neither SKU sells again.
	t.eq(g.special_pack_id(), "", "mua rồi: ẩn icon Special Pack")
	var r2: Dictionary = await g.offer_buy("special_pack")
	t.eq(r2.status, "owned", "không bán lại bản sale")
	t.eq(r2.granted, false, "không cộng lần hai")
	g.test_now = MON + 2 * D  # thứ Tư: giá thường
	var r3: Dictionary = await g.buy_sku("special_pack")
	t.eq(r3.status, "owned", "đã có bản sale: không bán bản thường")
	t.eq(g.grant_purchase({"token": "tok_restore", "sku": "special_pack", "status": "ok"}), false,
		"đơn bản thường về sau (Restore) không cộng lần hai")
	t.eq(int(g.s.coins), coins + 12000, "gold không cộng thêm")
