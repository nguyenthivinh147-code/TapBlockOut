extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const GameScript := preload("res://src/game/game.gd")
const MockAds := preload("res://src/platform/mock_ads.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_game"


## Quảng cáo giả có danh sách `lost` như bản Android sẽ có.
class FakeAds extends MockAds:
	var lost: Array = []
	var lost_done_called: bool = false

	func lost_done() -> void:
		lost_done_called = true
		lost = []


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g() -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	var p: Node = _root().get_node("Platform")
	p.ads.calls.clear()
	p.save.last_json = ""
	p.iap = MockIap.new()
	p.notif.granted = true
	p.notif.asked = false
	p.notif.scheduled.clear()
	return g


func _p() -> Node:
	return _root().get_node("Platform")


## Thắng level hiện tại bằng cách chạm khối thoát được theo gợi ý.
func _win(g: Node, attempt: Dictionary) -> void:
	var b: RefCounted = attempt.board
	var guard := 0
	while not b.is_won() and guard < 200:
		var id: String = b.hint()
		if id == "":
			break
		g.tap(attempt, id)
		guard += 1


func test_win_gives_gold_level_and_free_x2(t: T) -> void:
	var g := _g()
	var a: Dictionary = g.start_attempt()
	t.ok(not a.is_empty(), "có level 1")
	_win(g, a)
	t.ok(a.board.is_won(), "thắng L1")
	var left: int = a.board.moves_left()
	t.ok(left > 0, "L1 dư MOVES")
	var r: Dictionary = g.on_level_won(a)
	t.eq(r.move_coins, left, "1 gold mỗi MOVES thừa")
	t.eq(r.coins, 40 + left, "gold thắng + MOVES thừa")
	t.eq(r.x2_free, true, "L1 x2 miễn phí")
	t.eq(r.x2_available, true, "x2 có")
	t.eq(int(g.s.coins), 1040 + left, "ví")
	t.eq(int(g.s.level), 2, "lên level 2")
	t.eq(int(g.s.runs), 1, "runs")
	t.eq(await g.claim_x2(), true, "nhận x2 free")
	t.eq(int(g.s.coins), 1080 + 2 * left, "ví sau x2 (nhân đôi cả MOVES thừa)")
	t.eq(_p().ads.calls.size(), 0, "x2 free không gọi quảng cáo")
	t.eq(await g.claim_x2(), false, "x2 không nhận hai lần")
	t.eq(g.on_level_won(a).coins, 0, "thắng hai lần không cộng")
	t.eq(int(g.s.coins), 1080 + 2 * left, "ví giữ nguyên")
	t.eq(int(_p().an.named("level_end")[0].params.coins), 40 + left, "level_end ghi tổng gold")
	var earns: Array = _p().an.named("earn")
	t.eq(earns.size(), 2, "ghi earn gold")
	t.ok(_p().an.named("level_end").size() == 1 and _p().an.named("level_end")[0].params.has("build"), "level_end có build")


func test_win_move_coins_from_remote_config(t: T) -> void:
	var g := _g()
	g.s.level = 2
	var a: Dictionary = g.start_attempt()
	_win(g, a)
	var left: int = a.board.moves_left()
	t.ok(left > 0, "L2 dư MOVES")
	Config.apply_remote({"econ_win_move_coins": "3"})
	var r: Dictionary = g.on_level_won(a)
	Config.reset()
	t.eq(r.move_coins, 3 * left, "3 gold mỗi MOVES thừa")
	t.eq(r.coins, 40 + 3 * left, "cộng vào thưởng thắng")
	t.eq(int(g.s.coins), 1040 + 3 * left, "ví")


func test_lose_l9_free_l10_costs_life(t: T) -> void:
	var g := _g()
	g.s.level = 9
	var a: Dictionary = g.start_attempt()
	g.on_level_lost(a)
	t.eq(int(g.s.lives.count), 10, "L9 không mất mạng")
	t.eq(int(g.s.level), 9, "level giữ nguyên")
	t.eq(int(g.s.runs), 1, "tính lượt")
	g.on_level_lost(a)
	t.eq(int(g.s.runs), 1, "thua hai lần không tính hai")
	g.s.level = 10
	a = g.start_attempt()
	g.on_level_lost(a)
	t.eq(int(g.s.lives.count), 9, "L10 mất 1 mạng")
	t.eq(int(g.s.fail_streak.count), 1, "chuỗi thua")
	t.eq(g.lives_view().count, 9, "lives_view")


func test_restart_cost(t: T) -> void:
	var g := _g()
	g.s.level = 10
	var a: Dictionary = g.start_attempt()
	t.eq(g.restart_cost_life(a), false, "chưa chạm: miễn phí")
	t.eq(int(g.s.lives.count), 10, "mạng giữ")
	t.eq(int(g.s.runs), 0, "chưa chạm không tính lượt")
	var id: String = a.board.block_ids()[0]
	g.tap(a, id)
	t.eq(g.restart_cost_life(a), true, "đã chạm: trừ mạng")
	t.eq(int(g.s.lives.count), 9, "mất mạng")
	g.on_level_lost(a)
	t.eq(int(g.s.lives.count), 9, "không trừ hai lần")
	g.s.level = 3
	a = g.start_attempt()
	g.tap(a, a.board.block_ids()[0])
	t.eq(g.restart_cost_life(a), false, "L3 miễn phí")


func test_rescue_gold_then_video_then_skip(t: T) -> void:
	var g := _g()
	g.s.coins = 5000
	var a: Dictionary = g.start_attempt()
	var m0: int = a.board.moves_left()
	var o: Dictionary = g.rescue_offer(a)
	t.eq(o.index, 0, "lần 1")
	t.eq(o.video, true, "lần 1 có video")
	t.eq(await g.rescue_accept(a, "gold"), true, "mua lần 1")
	t.eq(int(g.s.coins), 3100, "trừ 1900")
	t.eq(a.board.moves_left(), m0 + 3, "+3 MOVES")
	o = g.rescue_offer(a)
	t.eq(o.index, 1, "sang lần 2")
	t.eq(o.price, 2200, "giá lần 2")
	t.eq(o.video, true, "lần 2 có video")
	_p().ads.simulate("closed")
	t.eq(await g.rescue_accept(a, "video"), false, "đóng video sớm: không thưởng")
	t.eq(a.board.moves_left(), m0 + 3, "MOVES không đổi")
	t.eq(g.last_ad_reason, "closed", "lý do")
	t.eq(int(g.s.coins), 3100, "gold không đổi")
	g.rescue_offer(a)
	t.eq(await g.rescue_accept(a, "video"), true, "video lần 2")
	t.eq(a.board.moves_left(), m0 + 6, "+3 nữa")
	t.eq(int(g.s.coins), 3100, "video không tốn gold")
	t.eq(g.rescue_offer(a).index, 2, "lần 3")
	g.rescue_skip(a)
	o = g.rescue_offer(a)
	t.eq(o.lost, true, "bỏ qua là thua")
	t.eq(_p().an.count("rescue_show"), 4, "rescue_show")
	t.eq(_p().an.count("rescue_use"), 2, "rescue_use")
	t.eq(_p().an.count("rv_cancel"), 1, "rv_cancel")
	t.eq(_p().an.count("rv_done"), 1, "rv_done")
	t.eq(_p().an.count("rv_start"), 2, "rv_start")


func test_rescue_inventory_then_gold(t: T) -> void:
	var g := _g()
	g.s.inv.move = 1
	var a: Dictionary = g.start_attempt()
	var o: Dictionary = g.rescue_offer(a)
	t.eq(o.use_inventory, true, "dùng kho")
	t.eq(await g.rescue_accept(a, "inventory"), true, "dùng kho lần 1")
	t.eq(int(g.s.inv.move), 0, "kho giảm")
	t.eq(int(g.s.coins), 1000, "không tốn gold")
	g.rescue_offer(a)
	g.s.coins = 3000
	t.eq(await g.rescue_accept(a, "gold"), true, "lần 2 bằng gold 2200")
	t.eq(int(g.s.coins), 800, "trừ 2200")
	var b: Dictionary = g.start_attempt()
	g.rescue_offer(b)
	g.s.coins = 0
	t.eq(await g.rescue_accept(b, "gold"), false, "thiếu gold")
	g.rescue_skip(b)
	t.eq(g.rescue_offer(b).lost, true, "bỏ qua là thua")


func test_x2_needs_video_and_retry(t: T) -> void:
	var g := _g()
	g.s.level = 2
	var a: Dictionary = g.start_attempt()
	_win(g, a)
	var r: Dictionary = g.on_level_won(a)
	var won: int = r.coins
	t.eq(r.x2_free, false, "L2 x2 cần video")
	_p().ads.simulate("closed")
	t.eq(await g.claim_x2(), false, "đóng sớm")
	t.eq(int(g.s.coins), 1000 + won, "không thưởng")
	t.eq(int(g.s.ad_pend.size()), 0, "ad_pend xoá")
	t.eq(await g.claim_x2(), true, "xem hết")
	t.eq(int(g.s.coins), 1000 + 2 * won, "x2")
	t.eq(_p().an.count("rv_offer"), 1, "rv_offer một lần")
	t.eq(_p().an.count("rv_cancel"), 1, "rv_cancel")
	t.eq(_p().an.count("rv_done"), 1, "rv_done")
	t.ok(int(g.s.ads.last_rv_at) > 0, "ghi last_rv_at")


func test_purchase_delivered_once(t: T) -> void:
	var g := _g()
	var r: Dictionary = await g.buy_sku("gold_pack_1")
	t.eq(r.status, "ok", "mua ok")
	t.eq(r.granted, true, "đã giao")
	t.eq(int(g.s.coins), 2000, "+1000")
	t.eq(g.s.buys.size(), 1, "ghi buys")
	t.eq(_p().iap.pending().size(), 0, "finish xong")
	var tok := str(g.s.buys[0].token)
	t.eq(g.grant_purchase({"status": "ok", "sku": "gold_pack_1", "token": tok}), false, "token cũ không giao lại")
	t.eq(int(g.s.coins), 2000, "ví giữ")
	_p().iap.simulate("invalid")
	r = await g.buy_sku("gold_pack_1")
	t.eq(r.granted, false, "invalid không thưởng")
	t.eq(int(g.s.coins), 2000, "ví giữ sau invalid")
	_p().iap.simulate("cancel")
	r = await g.buy_sku("gold_pack_1")
	t.eq(r.granted, false, "huỷ không thưởng")
	# món mua một lần: khoá no_ads, restore không giao lại
	r = await g.buy_sku("remove_ads")
	t.eq(r.granted, true, "remove_ads")
	t.eq(bool(g.s.no_ads), true, "no_ads")
	t.eq(int(g.s.coins), 2500, "+500")
	t.eq(await g.restore_purchases(), true, "restore")
	t.eq(int(g.s.coins), 2500, "restore không cộng lại")
	t.eq(_p().iap.pending().size(), 0, "restore đã finish")
	t.eq(await g.buy_sku("nope"), {"status": "error", "sku": "nope", "granted": false}, "sku lạ")


func test_boot_delivers_pending_once(t: T) -> void:
	var g := _g()
	# trả tiền rồi app chết trước khi giao hàng
	var r: Dictionary = await _p().buy("gold_pack_2")
	t.eq(r.status, "ok", "đơn treo")
	t.eq(_p().pending().size(), 1, "có đơn treo")
	await g.boot()
	t.eq(int(g.s.coins), 6000, "giao 5000")
	t.eq(g.s.buys.size(), 1, "ghi buys")
	t.eq(_p().pending().size(), 0, "hết đơn treo")
	t.ok(int(g.s.meta.install_at) > 0, "install_at")
	t.eq(int(g.s.meta.sessions), 1, "sessions")
	t.eq(_p().an.count("boot"), 1, "log boot")
	t.eq(_p().an.named("boot")[0].params.has("ms"), true, "boot có ms")
	# mở lại: không giao nữa
	g._booted = false
	await g.boot()
	t.eq(int(g.s.coins), 6000, "không giao hai lần")
	t.eq(int(g.s.meta.sessions), 2, "sessions 2")
	t.ok(g.s.meta.ftue.has("open"), "ftue open")
	t.eq(_p().an.count("ftue"), 1, "ftue một lần")


func test_shop_video_close_early_no_reward(t: T) -> void:
	var g := _g()
	_p().ads.simulate("closed")
	t.eq(await g.shop_watch_video(), false, "đóng sớm")
	t.eq(int(g.s.coins), 1000, "không gold")
	t.eq(int(g.s.shop.videos), 0, "không tính lượt")
	t.eq(await g.shop_watch_video(), true, "xem hết")
	t.eq(int(g.s.coins), 1200, "+200")
	t.eq(g.shop_videos_left(), 4, "còn 4")
	for i in 4:
		await g.shop_watch_video()
	t.eq(await g.shop_watch_video(), false, "hết 5 lượt")
	t.eq(int(g.s.coins), 2000, "tối đa 1000 gold")


func test_lost_ad_recovered_once(t: T) -> void:
	var g := _g()
	var fake := FakeAds.new()
	fake.overlay_enabled = false
	var orig: Object = _p().ads
	_p().ads = fake
	g.s["ad_pend"] = {"pl": "x2_coins", "coins": 40, "at": 1}
	g.save_now()
	fake.lost = [{"pl": "x2_coins"}, {"pl": "shop_coins"}, {"pl": "refill_life"}]
	await g.boot()
	t.eq(int(g.s.coins), 1240, "x2 40 và shop 200")
	t.eq(int(g.s.ad_credit.get("refill_life", 0)), 1, "tín dụng refill_life")
	t.eq(int(g.s.shop.videos), 1, "tính 1 video shop")
	t.eq(g.s.ad_pend.size(), 0, "ad_pend xoá")
	t.eq(fake.lost_done_called, true, "lost_done")
	t.eq(_p().an.count("ad_reward_recovered"), 3, "log recovered")
	g.s.lives.count = 5
	t.eq(await g.refill_video(), true, "dùng tín dụng")
	t.eq(fake.calls.size(), 0, "không hiện quảng cáo")
	t.eq(int(g.s.lives.count), 6, "+1 mạng")
	t.eq(int(g.s.ad_credit.refill_life), 0, "tín dụng hết")
	_p().ads = orig


func test_ad_pend_cleared_on_boot_without_lost(t: T) -> void:
	var g := _g()
	g.s["ad_pend"] = {"pl": "x2_coins", "coins": 40, "at": 1}
	g.save_now()
	await g.boot()
	t.eq(g.s.ad_pend.size(), 0, "xoá")
	t.eq(int(g.s.coins), 1000, "không thưởng khi không có xác nhận")


func test_interstitial_rules(t: T) -> void:
	var g := _g()
	g.s.runs = 3
	g.s.level = 12
	var a: Dictionary = g.start_attempt()
	_win(g, a)
	g.on_level_won(a)
	t.eq(int(g.s.runs), 4, "lượt 4")
	g.test_now = int(Time.get_unix_time_from_system()) + 1000
	await g.leave_win_card(true, true)
	t.eq(_p().ads.calls.size(), 0, "đã nhận x2: không interstitial")
	await g.leave_win_card(true, false)
	t.eq(_p().ads.calls.size(), 1, "bỏ x2: có interstitial")
	t.eq(_p().ads.calls[0].placement, "result_exit", "placement")
	t.eq(_p().an.count("inter_show"), 1, "inter_show")
	t.eq(int(g.s.ads.inter_today), 1, "đếm trong ngày")
	await g.leave_win_card(true, false)
	t.eq(_p().ads.calls.size(), 1, "cách 2 lượt và 120 giây")
	g.s.no_ads = true
	g.s.ads.last_inter_run = -99
	g.s.ads.last_inter_at = 0
	await g.leave_win_card(true, false)
	t.eq(_p().ads.calls.size(), 1, "no_ads chặn")


func test_demo_end_returns_empty(t: T) -> void:
	var g := _g()
	# bản demo (override 1): dừng ở L20
	Config.demo_override = 1
	t.ok(Config.is_demo(), "override 1 là demo")
	g.s.level = 20
	t.ok(not g.current_level_data().is_empty(), "L20 có")
	t.ok(g.level_exists(20), "L20 tồn tại")
	g.s.level = 21
	t.ok(g.current_level_data().is_empty(), "sau L20 rỗng")
	t.ok(not g.level_exists(21), "L21 không tồn tại trong demo")
	t.ok(g.start_attempt().is_empty(), "start_attempt rỗng")
	# bản phát hành (override 0): đi tiếp L21 từ file data
	Config.demo_override = 0
	t.ok(not Config.is_demo(), "override 0 là bản phát hành")
	t.ok(not g.current_level_data().is_empty(), "phát hành: L21 có")
	t.eq(int(g.current_level_data().get("id", 0)), 21, "đúng L21")
	t.ok(not g.start_attempt().is_empty(), "phát hành: start_attempt có")
	Config.demo_override = -1
	g.reset_for_test(DIR + "/save.json")
	t.eq(Config.demo_override, -1, "reset_for_test trả công tắc về -1")


## Preset export: Demo mang feature `demo` (is_demo thật chạy theo OS.has_feature), Release thì không.
func test_demo_preset_features(t: T) -> void:
	var cf := ConfigFile.new()
	t.eq(cf.load("res://export_presets.cfg"), OK, "đọc export_presets.cfg")
	var feats := {}
	for sec in cf.get_sections():
		if sec.begins_with("preset.") and not sec.ends_with(".options"):
			feats[str(cf.get_value(sec, "name", ""))] = str(cf.get_value(sec, "custom_features", ""))
	t.ok(str(feats.get("Android Demo", "")).split(",").has("demo"), "preset Android Demo có feature demo")
	t.ok(not str(feats.get("Android Release", "x")).split(",").has("demo"), "preset Android Release không có demo")
	# có feature demo thật thì dừng ở L20: is_demo() không bị override thì theo OS.has_feature
	Config.demo_override = -1
	t.eq(Config.is_demo(), OS.has_feature("demo"), "mặc định theo OS.has_feature")
	t.eq(int(Config.CONTENT.demo_max_level), 20, "demo dừng ở L20")


func test_ftue_and_build_param(t: T) -> void:
	var g := _g()
	g.ftue("first_tap")
	g.ftue("first_tap")
	g.ftue("khong_co")
	t.eq(_p().an.count("ftue"), 1, "một lần, bỏ bước lạ")
	t.eq(_p().an.named("ftue")[0].params.step, "first_tap", "step")
	t.eq(_p().an.named("ftue")[0].params.build, "v1", "build")
	for i in 5:
		var a: Dictionary = g.start_attempt()
		g.on_level_lost(a)
	t.ok(g.s.meta.ftue.has("run_2") and g.s.meta.ftue.has("run_5"), "run_2, run_5")


func test_spend_and_booster(t: T) -> void:
	var g := _g()
	t.eq(g.buy_booster("hint"), true, "mua hint 900")
	t.eq(int(g.s.coins), 100, "còn 100")
	t.eq(int(g.s.inv.hint), 1, "kho")
	t.eq(g.buy_booster("smash"), false, "thiếu gold")
	t.eq(g.use_booster("hint"), true, "dùng")
	t.eq(g.use_booster("hint"), false, "hết")
	t.eq(g.spend_coins(500, "x"), false, "thiếu")
	t.eq(_p().an.count("spend"), 1, "một spend")
	t.eq(_p().an.named("spend")[0].params.currency, "gold", "đơn vị gold")


func test_booster_video_once_per_attempt(t: T) -> void:
	var g := _g()
	var a: Dictionary = g.start_attempt()
	t.eq(await g.booster_video(a, "hint"), true, "video booster")
	t.eq(int(g.s.inv.hint), 1, "+1")
	t.eq(await g.booster_video(a, "move"), false, "một lần mỗi lượt")


func test_daily_gift_and_next(t: T) -> void:
	var g := _g()
	t.eq(g.daily_claim(), {}, "chưa mở ở L1")
	g.s.level = 4
	var r: Dictionary = g.daily_claim()
	t.eq(int(r.coins), 50, "ô 1")
	t.eq(int(g.s.coins), 1050, "ví")
	t.eq(g.daily_claim(), {}, "một lần mỗi ngày")
	_p().ads.simulate("closed")
	t.eq(await g.daily_claim_next(), {}, "đóng sớm")
	r = await g.daily_claim_next()
	t.eq(int(r.coins), 100, "ô 2")
	t.eq(int(g.s.coins), 1150, "ví sau next")
	t.eq(await g.daily_claim_next(), {}, "một lần mỗi ngày")
	t.eq(_p().an.count("daily_claim"), 2, "log daily_claim")


func test_cosmetics(t: T) -> void:
	var g := _g()
	t.eq(g.cos_buy("avatar_01"), true, "mua 50")
	t.eq(int(g.s.coins), 950, "ví")
	t.eq(g.cos_buy("avatar_01"), false, "đã có")
	t.eq(g.cos_equip("avatar_01"), true, "đeo")
	t.eq(await g.cos_unlock_video("frame_02"), true, "mở bằng video")
	t.eq(int(g.s.coins), 950, "không trừ gold")
	t.eq(await g.cos_unlock_video("frame_02"), false, "đã có thì không xem")
	t.eq(_p().an.count("cos_buy"), 2, "log cos_buy")


func test_gift_booster(t: T) -> void:
	var g := _g()
	g.s.level = 12
	t.eq(g.claim_gift(), "hint", "hint")
	t.eq(g.claim_gift(), "move", "move")
	t.eq(g.claim_gift(), "", "hết")
	t.eq(int(g.s.inv.hint), 1, "kho hint")
	t.eq(int(g.s.inv.move), 1, "kho move")


func test_offer_flow(t: T) -> void:
	var g := _g()
	g.s.level = 11
	g.s.runs = 12
	var seen: Array = []
	g.offer_ready.connect(func(id: String) -> void: seen.append(id))
	var id: String = g.check_offer(false)
	t.eq(id, "starter_pack", "starter pack")
	t.eq(seen, ["starter_pack"], "tín hiệu")
	t.eq(g.check_offer(false), "", "không chồng offer")
	t.eq(_p().an.count("offer_show"), 1, "offer_show")
	var r: Dictionary = await g.offer_buy("starter_pack")
	t.eq(r.granted, true, "mua")
	t.eq(int(g.s.coins), 7000, "+6000")
	t.eq(int(g.s.inv.smash), 1, "kèm booster")
	t.eq(int(g.s.offers.items.starter_pack.bought), 1, "Offers.bought")
	t.eq(_p().an.count("offer_buy"), 1, "offer_buy")


func test_notifications(t: T) -> void:
	var g := _g()
	g.s.runs = 2
	await g.leave_win_card(false, false)
	t.eq(_p().notif.asked, true, "đã xin quyền")
	t.eq(bool(g.s.notify.asked), true, "ghi asked")
	_p().notif.asked = false
	await g.leave_win_card(false, false)
	t.eq(_p().notif.asked, false, "chỉ một lần")
	g.s.level = 5
	g.set_setting("notif", true)
	t.ok(_p().notif.scheduled.size() > 0, "có lịch")
	var first: Dictionary = _p().notif.scheduled[0]
	t.ok(str(first.title) != "" and not str(first.title).begins_with("notif_"), "có tiêu đề dịch")
	var evening: Array = _p().notif.scheduled.filter(func(e: Dictionary) -> bool: return e.kind == "evening")
	t.ok(evening.size() >= int(Config.NOTIF.evening_days) - 1, "thông báo 20:00 mỗi ngày (qua 20:00 thì từ mai)")
	t.ok(GameScript.EVENING_ICONS.has(str(evening[0].icon)), "kèm icon")
	t.ok(not str(evening[0].title).begins_with("notif_"), "tiêu đề buổi tối đã dịch")
	t.ok(not str(evening[0].body).begins_with("notif_"), "nội dung buổi tối đã dịch")
	g.set_setting("notif", false)
	t.eq(_p().notif.scheduled.size(), 0, "tắt thì huỷ hết")
	t.eq(bool(g.s.settings.notif), false, "ghi cài đặt")


func test_pause_saves(t: T) -> void:
	var g := _g()
	g.s.coins = 777
	var before: int = _p().save.mirror_count
	_p().paused.emit()
	t.ok(_p().save.mirror_count > before, "mirror khi pause")
	var loaded: Dictionary = g.store.load_state()
	t.eq(int(loaded.coins), 777, "đã ghi file")
	_p().resumed.emit()


func test_save_roundtrip_after_purchase(t: T) -> void:
	var g := _g()
	await g.buy_sku("gold_pack_1")
	var loaded: Dictionary = g.store.load_state()
	t.eq(int(loaded.coins), 2000, "gold đã lưu ngay")
	t.eq(loaded.buys.size(), 1, "buys đã lưu ngay")


func test_challenge_locked(t: T) -> void:
	var g := _g()
	t.eq(g.challenge_view().locked, true, "khoá")
	t.eq(g.start_challenge(), {}, "chưa có")
