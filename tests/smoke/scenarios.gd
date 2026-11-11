extends RefCounted
## Kịch bản smoke (docs/TESTING.md "Tầng 2"). Mỗi hàm nhận runner `r` (tests/smoke/smoke.gd, không khai kiểu để
## tránh preload vòng) và trả true khi đi hết kịch bản; lỗi thì gọi r.fail(lý do).

const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Config := preload("res://src/config.gd")
const Lives := preload("res://src/meta/lives.gd")

## Popup không thuộc kịch bản (quà booster, giới thiệu, offer, mời tính năng): settle() tự đóng.
const STRAY_SCRIPTS := ["booster_unlocked.gd", "booster_soon.gd", "tutorial_intro.gd", "popup_rate.gd",
	"popup_remove_ads.gd", "popup_notice.gd", "popup_streak_intro.gd", "popup_weekly_upsell.gd",
	"popup_weekly_tutorial.gd", "popup_special.gd", "chain_offer.gd", "popup_lb_howto.gd", "popup_lb_result.gd",
	"popup_streak_rewards.gd", "popup_offer.gd", "popup_reward.gd"]
## Nút đóng popup thường gặp, thử theo thứ tự.
const CLOSE_NAMES := ["CloseX", "CloseButton", "btnTurnOff", "Continue", "ClaimBtn", "SkipButton", "HomeButton",
	"OkButton", "Bg", "Dim"]
## Nút ở Home mở popup hoặc màn (kịch bản D), theo thứ tự trên màn.
const HOME_BUTTONS := ["ProfileButton", "LivesPlus", "GoldPlus", "SettingsButton", "GiftButton", "LeaderboardButton",
	"StreakButton", "BombButton", "ChallengeButton", "OfferChip", "SpecialPackButton", "WeekendSaleButton",
	"WeeklyPassButton", "ChainOfferButton", "RemoveAdsButton", "ShopButton", "RoadTripTab"]
## Monkey không bao giờ bấm: rời app (mail, store), công cụ tester và dev.
const MONKEY_BANNED_NAMES := ["SupportButton", "VersionButton", "GalleryButton", "DebuggerButton", "WipeButton",
	"SaveButton", "PrivacyButton"]
const MONKEY_BANNED_SCRIPTS := ["tester_menu.gd", "popup_update.gd", "ui_gallery.gd"]
const MONKEY_STUCK := 20


static func run(r, scen: String) -> bool:
	match scen:
		"A":
			return await scen_a(r)
		"B":
			return await scen_b(r)
		"C":
			return await scen_c(r)
		"D":
			return await scen_d(r)
		"E":
			return await scen_e(r)
		"M":
			return await scen_m(r)
		"S":
			return await scen_s(r)
	return r.fail("không có kịch bản %s" % scen)


# ================================================================ kịch bản

## A. Cài mới: splash → hướng dẫn chạm khối ở L1 → thắng L1 (dưới L11 không có thẻ) → L2 → về Home.
static func scen_a(r) -> bool:
	if not await r.open_game("A", Callable(Saves, "fresh"), true):
		return false
	if not await wait_for(r, func() -> bool: return r.popup_script("tutorial_intro.gd") != null, 15000, "tutorial_intro.gd"):
		return r.fail("không thấy hướng dẫn chạm khối ở L1")
	await r.wait_sec(0.5)
	await r.shot("tutorial")
	if not await tap_tutorial(r):
		return false
	if not await win_level(r):
		return false
	if not await after_win(r, 1):
		return false
	await r.shot("level2")
	if not await go_home_from_level(r):
		return false
	await r.shot("home")
	return await verify_saved(r)


## B. Người chơi lâu: boot vào L30 (popup giới thiệu cơ chế băng) → về Home → Chơi → thắng → thẻ thắng → Tiếp tục
## → level kế → về Home.
static func scen_b(r) -> bool:
	if not await r.open_game("B", Callable(Saves, "veteran")):
		return false
	if await wait_for(r, func() -> bool: return r.popup_script("booster_unlocked.gd") != null or _playing(r) > 0, 15000,
			"booster_unlocked.gd") and r.popup_script("booster_unlocked.gd") != null:
		await r.wait_sec(0.6)
		await r.shot("mech_intro")
	if not await wait_for(r, func() -> bool: return _playing(r) == 30, 15000):
		return r.fail("không vào được L30")
	await r.shot("level30")
	if not await go_home_from_level(r):
		return false
	await r.shot("home")
	if not await tap_named(r, "PlayButton", r.main.current_screen):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == 30, 20000):
		return r.fail("bấm Chơi không vào L30")
	if not await win_level(r):
		return false
	if not await after_win(r, 30):
		return false
	await r.shot("next_level")
	if not await go_home_from_level(r):
		return false
	await r.shot("home_after")
	return await verify_saved(r)


## C. Thua: hết MOVES → cứu bằng video → hết MOVES lần nữa → bỏ cuộc → xác nhận mất mạng → thẻ thua → Chơi lại;
## thua lần nữa với mạng cuối → Chơi lại mở màn hết mạng → về Home.
static func scen_c(r) -> bool:
	var target := _blocked_level(10, 120)
	if int(target[0]) == 0:
		return r.fail("không tìm được level có khối bị chặn từ đầu trong L10–120")
	var lvl := int(target[0])
	var prep := func(g: Node) -> void:
		Saves.veteran(g)
		g.s.level = lvl
		g.s.coins = 500
		g.s.inv["move"] = 0
		g.s.lives["count"] = 2
	if not await r.open_game("C", prep):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == lvl, 20000):
		return r.fail("không vào được L%d" % lvl)
	r.step("L%d, khối %s bị chặn từ đầu" % [lvl, target[1]])
	# Lượt 1: cứu bằng video rồi bỏ cuộc.
	if not await burn_to_rescue(r, str(target[1])):
		return false
	await r.shot("rescue")
	if not await tap_named(r, "VideoButton", r.popup_script("popup_rescue.gd")):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == lvl and r.level_screen().board.moves_left() > 0, 15000):
		return r.fail("xem video ở popup cứu lượt không cộng MOVES")
	if not await burn_to_rescue(r, str(target[1])):
		return false
	if not await give_up(r, "lose_card_1"):
		return false
	if not await tap_named(r, "RetryButton", r.popup_script("lose_card.gd")):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == lvl, 20000):
		return r.fail("Chơi lại không vào lại L%d" % lvl)
	# Lượt 2: mạng cuối.
	if not await burn_to_rescue(r, str(target[1])):
		return false
	if not await give_up(r, "lose_card_2"):
		return false
	if int(r.game.s.lives["count"]) != 0:
		return r.fail("thua hai lần từ 2 mạng mà còn %d mạng" % int(r.game.s.lives["count"]))
	if not await tap_named(r, "RetryButton", r.popup_script("lose_card.gd")):
		return false
	if not await wait_for(r, func() -> bool: return r.screen_name() == "no_lives", 15000):
		return r.fail("hết mạng mà Chơi lại không mở màn hết mạng")
	await r.wait_sec(0.5)
	await r.shot("no_lives")
	if not await tap_named(r, "HomeButton", r.main.current_screen):
		return false
	if not await wait_for(r, func() -> bool: return r.screen_name() == "home", 15000):
		return r.fail("màn hết mạng không về Home")
	await r.shot("home")
	return await verify_saved(r)


## D. Save mở hết tính năng: mở rồi đóng mọi nút ở Home (popup hoặc màn), chụp từng cái.
static func scen_d(r) -> bool:
	if not await r.open_game("D", Callable(Saves, "all_unlocked")):
		return false
	if not await go_home_from_level(r):
		return false
	await settle_all(r)
	await r.shot("home")
	var opened := 0
	for name in HOME_BUTTONS:
		var home: Node = r.main.current_screen
		var b := find_visible(home, name) as Control
		if b == null or (b is BaseButton and (b as BaseButton).disabled):
			r.step("bỏ qua %s (không hiện hoặc đang khoá)" % name)
			continue
		var before_pop: int = r.main.popup_count()
		if not await r.tap(b, name):
			return r.fail("không bấm được %s ở Home" % name)
		var changed := await wait_for(r, func() -> bool:
			return r.main.popup_count() > before_pop or r.screen_name() != "home", 6000, "*")
		if not changed:
			return r.fail("bấm %s ở Home không mở gì" % name)
		await r.wait_sec(0.6)
		await r.shot("open_%s" % name)
		opened += 1
		if not await close_to(r, before_pop):
			return r.fail("không đóng được thứ mà %s mở" % name)
		if not await back_home(r):
			return r.fail("không về được Home sau %s" % name)
		await settle_all(r)
	r.step("đã mở và đóng %d mục ở Home" % opened)
	await r.shot("home_end")
	return await verify_saved(r)


## E. Shop: mua mọi SKU đang bán qua store giả, nhận popup thưởng, kiểm số dư theo Config.SKUS.
static func scen_e(r) -> bool:
	if not await r.open_game("E", Callable(Saves, "rich")):
		return false
	if not await go_home_from_level(r):
		return false
	await settle_all(r)
	if not await tap_named(r, "ShopButton", r.main.current_screen):
		return false
	if not await wait_for(r, func() -> bool: return r.screen_name() == "shop", 10000):
		return r.fail("bấm Shop không mở màn Shop")
	await r.wait_sec(0.6)
	await r.shot("shop")
	var skus: Array = (r.main.current_screen.buy_buttons as Dictionary).keys()
	r.step("Shop bán %d SKU: %s" % [skus.size(), ", ".join(PackedStringArray(skus.map(func(x): return str(x))))])
	var bought := 0
	for sku in skus:
		var shop: Node = r.main.current_screen
		var btn := (shop.buy_buttons as Dictionary).get(sku) as Control
		if btn == null or not is_instance_valid(btn) or not btn.is_visible_in_tree():
			r.step("bỏ qua %s (không còn hiện sau lần mua trước)" % sku)
			continue
		if not await scroll_into_view(r, btn):
			return r.fail("không cuộn được tới nút mua %s" % sku)
		var before := _balance(r)
		if not await r.tap(btn, "mua %s" % sku):
			return r.fail("nút mua %s bị che" % sku)
		await confirm_mock_purchase(r)
		var def: Dictionary = Config.SKUS.get(sku, {})
		if not await wait_for(r, func() -> bool: return _balance(r) != before, 10000, "popup_reward.gd"):
			return r.fail("mua %s không đổi số dư" % sku)
		var reward = r.popup_script("popup_reward.gd")
		if reward != null:
			await r.wait_sec(0.5)
			if bought == 0:
				await r.shot("reward_%s" % sku)
			await tap_named(r, "ClaimBtn", reward)
			await wait_for(r, func() -> bool: return r.popup_script("popup_reward.gd") == null, 6000)
		var problem := _check_purchase(before, _balance(r), def)
		if not problem.is_empty():
			return r.fail("mua %s: %s" % [sku, problem])
		r.step("mua %s: gold %d → %d" % [sku, int(before["coins"]), int(_balance(r)["coins"])])
		bought += 1
		await settle_all(r)
	if bought == 0:
		return r.fail("không mua được SKU nào")
	await r.shot("shop_after")
	if not await back_home(r):
		return false
	return await verify_saved(r)


## M. Monkey: bấm ngẫu nhiên (seed cố định) trên save cài mới rồi save mở hết; đạt khi không lỗi và không kẹt.
static func scen_m(r) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r.args.get("seed", "1"))
	var taps := int(r.args.get("taps", "250"))
	r.step("monkey seed=%d, %d lần bấm mỗi save" % [rng.seed, taps])
	for save in [["M_fresh", Callable(Saves, "fresh")], ["M_all", Callable(Saves, "all_unlocked")]]:
		if not await r.open_game(str(save[0]), save[1]):
			return false
		r.begin_phase(str(save[0]))
		if not await monkey(r, rng, taps):
			return false
		r.end_phase()
		r.mem(str(save[0]))
		await r.shot(str(save[0]))
		if not await verify_saved(r):
			return false
	return true


## S. Soak: 10 level liên tiếp từ L30, FRAMES theo từng level và MEM sau mỗi level.
static func scen_s(r) -> bool:
	if not await r.open_game("S", Callable(Saves, "veteran")):
		return false
	r.mem("start")
	for i in 10:
		if not await wait_for(r, func() -> bool: return _playing(r) > 0, 20000):
			return r.fail("level thứ %d không vào trạng thái chơi" % (i + 1))
		var lvl := _playing(r)
		if not await win_level(r):
			return false
		if not await after_win(r, lvl):
			return false
		r.mem("sau L%d" % lvl)
		if r.screen_name() == "home":
			await settle_all(r)
			if not await tap_named(r, "PlayButton", r.main.current_screen):
				return false
	await r.shot("soak_end")
	return await verify_saved(r)


# ================================================================ luồng dùng chung

## Đóng một popup lạc (STRAY_SCRIPTS, lớp phủ ads và mua hàng giả, hướng dẫn Road Trip) nếu có; true khi đã làm gì
## đó. `keep` là tên node hoặc tên script của popup kịch bản đang đợi; "*" là không đóng popup nào.
static func settle(r, keep: String = "") -> bool:
	if await confirm_mock_ad(r):
		return true
	if await confirm_mock_purchase(r):
		return true
	if keep == "*":
		return false
	for c in r.popups():
		var file := script_file(c)
		if keep != "" and (file == keep or c.find_child(keep, true, false) != null):
			continue
		if not STRAY_SCRIPTS.has(file):
			continue
		await r.wait_sec(0.3)
		if not is_instance_valid(c) or r.popups().find(c) < 0:
			return true
		if file == "tutorial_intro.gd":
			return await tap_tutorial(r)
		if file in ["booster_unlocked.gd", "booster_soon.gd"]:
			r.step("đóng %s (chạm để tiếp tục)" % file)
			await r.tap(c, file)
			return true
		if "later_button" in c and c.later_button is Control and (c.later_button as Control).is_visible_in_tree():
			await r.tap(c.later_button, "%s: để sau" % file)
			return true
		var close := find_close(c)
		if close != null:
			await r.tap(close, "%s: %s" % [file, close.name])
		else:
			await r.back()
		return true
	if r.screen_name() == "home":
		var guide := find_visible(r.main.current_screen, "RoadTripGuide") as Control
		if guide != null:
			await r.tap(guide, "hướng dẫn Road Trip")
			return true
	return false


static func settle_all(r) -> void:
	for i in 10:
		await r.wait_frames(3)
		if not await settle(r):
			return


## Đợi `cond`, trong lúc đợi đóng popup lạc (trừ `keep`).
static func wait_for(r, cond: Callable, ms: int = 10000, keep: String = "") -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		if not r.failed_reason.is_empty():
			return false
		await settle(r, keep)
		await r.wait_frames(1)
	return bool(cond.call())


## Lớp phủ ads giả (chỉ khi chạy cửa sổ): bấm "Xem hết" như người xem hết video.
static func confirm_mock_ad(r) -> bool:
	var o: Node = r.root.find_child("MockAdOverlay", true, false)
	if o == null:
		return false
	var b := _button_with_text(o, ["Xem hết", "Đóng"])
	if b == null:
		return false
	await r.tap(b, "ads giả: %s" % b.text)
	return true


## Lớp phủ store giả (chỉ khi chạy cửa sổ): bấm "Mua".
static func confirm_mock_purchase(r) -> bool:
	var o: Node = r.root.find_child("MockIapOverlay", true, false)
	if o == null:
		return false
	var b := _button_with_text(o, ["Mua"])
	if b == null:
		return false
	await r.tap(b, "store giả: Mua")
	return true


static func tap_tutorial(r) -> bool:
	var c: Node = r.popup_script("tutorial_intro.gd")
	if c == null:
		return r.fail("không có hướng dẫn chạm khối")
	var p: Vector2 = c.call("aim_point")
	var h: Control = await r.hovered_at(p)
	r.step("chạm khối dưới bàn tay hướng dẫn (trúng %s)" % r.node_label(h))
	await r.click_at(p)
	var closed: bool = await wait_for(r, func() -> bool: return r.popup_script("tutorial_intro.gd") == null, 6000)
	return closed or r.fail("chạm khối dưới bàn tay hướng dẫn không đóng hướng dẫn")


## Chơi level đang mở tới khi thắng: mỗi nước do solver chọn, chạm bằng input thật.
static func win_level(r) -> bool:
	if not await wait_for(r, func() -> bool: return _playing(r) > 0, 20000):
		return r.fail("level không vào trạng thái chơi")
	var lv: Control = r.level_screen()
	var lvl := int(lv.attempt.level)
	r.begin_phase("L%d" % lvl)
	var misses := 0
	for i in 600:
		if not r.failed_reason.is_empty():
			return false
		lv = r.level_screen()
		if lv == null or lv.board.is_won():
			break
		if str(lv.state) != "playing":
			await settle(r)
			await r.wait_frames(1)
			continue
		if not await r.tap_next_move():
			misses += 1
			if misses > 5:
				return r.fail("L%d: 5 lần chạm khối theo solver không trúng" % lvl)
		await r.wait_frames(2)
	r.end_phase()
	lv = r.level_screen()
	if lv != null and not lv.board.is_won():
		return r.fail("L%d chưa thắng sau 600 vòng" % lvl)
	r.step("thắng L%d" % lvl)
	return true


## Sau khi thắng `from_level`: bấm Tiếp tục ở thẻ thắng nếu có, đợi level kế hoặc Home.
static func after_win(r, from_level: int) -> bool:
	var next_or_home := func() -> bool: return _playing(r) > from_level or r.screen_name() == "home"
	if not await wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null or next_or_home.call(),
			20000, "ContinueButton"):
		return r.fail("thắng L%d mà không thấy thẻ thắng hay level kế" % from_level)
	var cont = r.popup_node("ContinueButton")
	if cont != null:
		await r.wait_sec(0.8)
		await r.shot("win_card_L%d" % from_level)
		await r.tap(cont, "Tiếp tục")
	var moved: bool = await wait_for(r, next_or_home, 20000)
	return moved or r.fail("sau thẻ thắng L%d không sang level kế hay Home" % from_level)


## Từ màn level: Cài đặt → Home, xác nhận nếu game hỏi (mất mạng), đợi Home.
static func go_home_from_level(r) -> bool:
	if r.screen_name() == "home":
		return true
	if not await wait_for(r, func() -> bool: return _playing(r) > 0, 20000):
		return r.fail("không ở màn level để về Home")
	var lv: Control = r.level_screen()
	await r.tap(lv.settings_button, "Cài đặt trong màn")
	if not await wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong màn không mở")
	await r.wait_sec(0.4)
	if not await tap_named(r, "HomeButton", r.popup_script("popup_ingame_settings.gd")):
		return false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if r.screen_name() == "home" and r.main.curtain == null:
			return true
		var confirm := find_visible(r.main, "ConfirmButton") as Control
		if confirm != null:
			await r.wait_sec(0.3)
			await r.tap(confirm, "xác nhận rời màn")
		else:
			await settle(r)
		await r.wait_frames(2)
	return r.fail("Cài đặt → Home không về Home")


## Chạm khối bị chặn tới khi hết MOVES và hiện popup cứu lượt.
static func burn_to_rescue(r, id: String) -> bool:
	for i in 120:
		if r.popup_script("popup_rescue.gd") != null:
			await r.wait_sec(0.5)
			return true
		var lv: Control = r.level_screen()
		if lv != null and str(lv.state) == "playing" and lv.board.moves_left() > 0:
			await r.tap_block(id)
		else:
			await settle(r, "popup_rescue.gd")
		await r.wait_frames(3)
	return r.fail("chạm khối bị chặn không làm hết MOVES")


## Ở popup cứu lượt: Bỏ cuộc → xác nhận mất mạng → đợi thẻ thua.
static func give_up(r, shot_name: String) -> bool:
	if not await tap_named(r, "SkipButton", r.popup_script("popup_rescue.gd")):
		return false
	if not await wait_for(r, func() -> bool:
			return r.popup_script("popup_keep_playing.gd") != null or r.popup_script("lose_card.gd") != null, 8000, "*"):
		return r.fail("Bỏ cuộc không hỏi xác nhận hay ra thẻ thua")
	var keep = r.popup_script("popup_keep_playing.gd")
	if keep != null:
		await r.wait_sec(0.4)
		await tap_named(r, "ConfirmButton", keep)
	if not await wait_for(r, func() -> bool: return r.popup_script("lose_card.gd") != null, 10000, "lose_card.gd"):
		return r.fail("bỏ cuộc không ra thẻ thua")
	await r.wait_sec(0.6)
	await r.shot(shot_name)
	return true


## Đóng popup tới khi còn `count` cái (nút đóng, không có thì Back).
static func close_to(r, count: int) -> bool:
	for i in 8:
		await r.wait_frames(2)
		if r.main.popup_count() <= count:
			return true
		var top = r.popups().back()
		var close := find_close(top)
		if close != null:
			await r.tap(close, "%s: %s" % [script_file(top), close.name])
		else:
			await r.back()
		await r.wait_sec(0.5)
	return r.main.popup_count() <= count


## Về Home từ màn khác (tab Home, nút Back trên màn, hoặc phím Back của Android).
static func back_home(r) -> bool:
	for i in 4:
		if r.screen_name() == "home" and r.main.curtain == null:
			return true
		var scr: Node = r.main.current_screen
		var b: Control = null
		for name in ["HomeTab", "BackButton", "btnBack"]:
			b = find_visible(scr, name) as Control
			if b != null:
				break
		if b != null:
			await r.tap(b, "%s ở màn %s" % [b.name, r.screen_name()])
		else:
			await r.back()
		await wait_for(r, func() -> bool: return r.screen_name() == "home", 4000)
	return r.screen_name() == "home"


## Cuộn (kéo) tới khi nút hit-test được ở tâm.
static func scroll_into_view(r, c: Control) -> bool:
	var view: Rect2 = r.view_rect()
	for i in 14:
		if await r.reachable(c):
			return true
		var center: Vector2 = r.to_viewport(c, c.size * 0.5)
		var x := view.size.x * 0.5
		var up := center.y > view.size.y * 0.5
		var from := Vector2(x, view.size.y * (0.7 if up else 0.35))
		var to := Vector2(x, view.size.y * (0.4 if up else 0.65))
		await r.drag(from, to)
		await r.wait_sec(0.4)
	return await r.reachable(c)


## Kiểm save trên đĩa khớp dữ liệu trong bộ nhớ sau khi lưu.
static func verify_saved(r) -> bool:
	r.game.save_now()
	var text := FileAccess.get_file_as_string(str(r.game.save_path))
	var disk: Variant = JSON.parse_string(text)
	if not (disk is Dictionary):
		return r.fail("save trên đĩa không đọc được: %s" % str(r.game.save_path))
	var s: Dictionary = r.game.s
	for key in ["coins", "level"]:
		if int(disk.get(key, -1)) != int(s[key]):
			return r.fail("save trên đĩa lệch bộ nhớ ở %s: %s và %s" % [key, str(disk.get(key)), str(s[key])])
	for k in ["hint", "move", "smash"]:
		if int((disk.get("inv", {}) as Dictionary).get(k, -1)) != int(s.inv[k]):
			return r.fail("save trên đĩa lệch bộ nhớ ở inv.%s" % k)
	if int((disk.get("lives", {}) as Dictionary).get("count", -1)) != int(s.lives["count"]):
		return r.fail("save trên đĩa lệch bộ nhớ ở lives.count")
	r.step("save trên đĩa khớp bộ nhớ (gold %d, level %d)" % [int(s.coins), int(s.level)])
	return true


# ================================================================ monkey

static func monkey(r, rng: RandomNumberGenerator, taps: int) -> bool:
	var sig := _signature(r)
	var same := 0
	for i in taps:
		if not r.failed_reason.is_empty():
			return false
		var lv: Control = r.level_screen()
		var tut: Node = r.popup_script("tutorial_intro.gd")
		if tut != null:
			# Người chơi làm theo bàn tay hướng dẫn: không có cách nào khác để đi tiếp.
			await tap_tutorial(r)
		elif r.popups().is_empty() and lv != null and str(lv.state) == "playing" and rng.randf() < 0.4:
			var bv: Control = lv.board_view
			var p := Vector2(rng.randf() * bv.size.x, rng.randf() * bv.size.y)
			r.step("monkey %d: chạm bàn (%d, %d)" % [i, int(p.x), int(p.y)])
			await r.click_at(r.to_viewport(bv, p))
		else:
			var cands := clickables(r)
			if cands.is_empty():
				r.step("monkey %d: không có gì để bấm" % i)
				await r.wait_frames(10)
			else:
				var c: Control = cands[rng.randi() % cands.size()]
				await r.tap(c, "monkey %d: %s" % [i, r.root.get_path_to(c)], 0)
		await r.wait_frames(rng.randi_range(3, 20))
		var now := _signature(r)
		if now == sig:
			same += 1
			if same >= MONKEY_STUCK:
				return r.fail("monkey kẹt: %d lần bấm liền không đổi gì (%s)" % [MONKEY_STUCK, now])
		else:
			same = 0
			sig = now
	return true


## Nút bấm được ở lớp trên cùng: popup trên cùng (và lớp phủ giả) nếu có, không thì màn hiện tại.
static func clickables(r) -> Array[Control]:
	var roots: Array[Node] = []
	for name in ["MockAdOverlay", "MockIapOverlay"]:
		var o: Node = r.root.find_child(name, true, false)
		if o != null:
			roots.append(o)
	if roots.is_empty():
		var pops: Array = r.popups()
		if not pops.is_empty():
			roots.append(pops.back())
		elif r.main.current_screen != null:
			roots.append(r.main.current_screen)
	var out: Array[Control] = []
	var view: Rect2 = r.view_rect()
	for root in roots:
		var stack: Array[Node] = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if _banned(n):
				continue
			for ch in n.get_children():
				stack.append(ch)
			if n is BaseButton and (n as Control).is_visible_in_tree() and not (n as BaseButton).disabled \
					and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				var c := n as Control
				if view.has_point(r.to_viewport(c, c.size * 0.5)):
					out.append(c)
		if out.is_empty() and root is Control and STRAY_SCRIPTS.has(script_file(root)):
			out.append(root as Control)
	return out


static func _banned(n: Node) -> bool:
	if MONKEY_BANNED_NAMES.has(str(n.name)) or n.is_in_group("tester_menu"):
		return true
	return MONKEY_BANNED_SCRIPTS.has(script_file(n))


## Trạng thái nhìn thấy được: màn, popup, bàn chơi và các số trong save người chơi để ý.
static func _signature(r) -> String:
	var parts: PackedStringArray = [r.screen_name()]
	for c in r.popups():
		parts.append(script_file(c))
	for name in ["MockAdOverlay", "MockIapOverlay"]:
		if r.root.find_child(name, true, false) != null:
			parts.append(name)
	var lv: Control = r.level_screen()
	if lv != null:
		parts.append("%s:%d:%d" % [lv.state, lv.board.moves_left(), lv.board.block_ids().size()])
	var s: Dictionary = r.game.s
	parts.append(str([s.coins, s.inv, s.level, s.lives["count"], s.settings, s.cos, s.daily, s.profile, s.no_ads,
		(s.buys as Array).size()]).sha1_text().substr(0, 8))
	return "|".join(parts)


# ================================================================ bất biến (smoke.gd gọi mỗi INVARIANT_EVERY khung)

static func invariants(r) -> Array:
	var out: Array = []
	var s: Dictionary = r.game.s
	out.append(_num_check("gold", s.get("coins")))
	for k in ["hint", "move", "smash"]:
		out.append(_num_check("inv_" + k, (s.get("inv", {}) as Dictionary).get(k)))
	var lives: Dictionary = s.get("lives", {})
	var count: Variant = lives.get("count")
	var max_lives := Lives.max_for(s)
	var bad_lives := _num_check("lives", count)
	out.append(["lives", bool(bad_lives[1]) or int(count) > max_lives, "%s / %d" % [str(count), max_lives]])
	out.append(["level", not (s.get("level") is int or s.get("level") is float) or int(s.get("level", 0)) < 1, s.get("level")])
	var lv: Control = r.level_screen()
	if lv != null and lv.board != null:
		out.append(["moves", lv.board.moves_left() < 0, lv.board.moves_left()])
	if r.main != null:
		out.append(["popup_stack", r.main.popup_count() > 3, r.main.popup_count()])
	return out


static func _num_check(name: String, v: Variant) -> Array:
	var ok := (v is int or v is float) and is_finite(float(v)) and float(v) >= 0.0
	return [name, not ok, v]


# ================================================================ tiện ích

static func script_file(n: Node) -> String:
	if n == null:
		return ""
	var s := n.get_script() as Script
	return s.resource_path.get_file() if s != null else ""


static func find_visible(root: Node, name: String) -> Node:
	if root == null:
		return null
	for n in root.find_children(name, "", true, false):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return n
	return null


static func find_close(popup: Node) -> Control:
	for name in CLOSE_NAMES:
		var n := find_visible(popup, name)
		if n is BaseButton and not (n as BaseButton).disabled:
			return n as Control
	return null


## Bấm node tên `name` đang hiện trong `scope`; báo lỗi nếu không có hoặc bị che.
static func tap_named(r, name: String, scope: Node) -> bool:
	var n := find_visible(scope, name) as Control
	if n == null:
		return r.fail("không thấy nút %s trong %s" % [name, r.node_label(scope)])
	var hit: bool = await r.tap(n, name)
	return hit or r.fail("nút %s bị che" % name)


static func _button_with_text(root: Node, texts: Array) -> Button:
	for t in texts:
		for n in root.find_children("*", "Button", true, false):
			var b := n as Button
			if b.is_visible_in_tree() and b.text == t:
				return b
	return null


static func _playing(r) -> int:
	var lv: Control = r.level_screen()
	if lv == null or str(lv.state) != "playing":
		return 0
	return int(lv.attempt.level)


static func _balance(r) -> Dictionary:
	var s: Dictionary = r.game.s
	return {"coins": int(s.coins), "inv": (s.inv as Dictionary).duplicate(), "no_ads": bool(s.no_ads),
		"inf": bool(s.lives.get("inf_forever", false)), "vip": bool(s.weekly.get("vip", false)),
		"buys": (s.buys as Array).size()}


## "" khi số dư sau khi mua khớp Config.SKUS; không thì mô tả chỗ lệch.
static func _check_purchase(before: Dictionary, after: Dictionary, def: Dictionary) -> String:
	if def.has("gold") and int(after["coins"]) - int(before["coins"]) != int(def["gold"]):
		return "gold +%d, mong đợi +%d" % [int(after["coins"]) - int(before["coins"]), int(def["gold"])]
	for k in (def.get("inv", {}) as Dictionary):
		var got := int(after["inv"][k]) - int(before["inv"][k])
		if got != int(def["inv"][k]):
			return "%s +%d, mong đợi +%d" % [k, got, int(def["inv"][k])]
	if bool(def.get("no_ads", false)) and not bool(after["no_ads"]):
		return "chưa bật no_ads"
	if bool(def.get("inf_forever", false)) and not bool(after["inf"]):
		return "chưa có mạng vô hạn"
	if bool(def.get("weekly_vip", false)) and not bool(after["vip"]):
		return "chưa bật Weekly Pass VIP"
	return ""


## Level đầu tiên trong [from, to] có khối bị chặn ngay từ đầu: [level, id]; [0, ""] nếu không có.
static func _blocked_level(from: int, to: int) -> Array:
	var BoardState := load("res://src/core/board_state.gd")
	for lvn in range(from, to + 1):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_%04d.json" % lvn))
		if not (data is Dictionary):
			continue
		var b: Object = BoardState.new(data)
		for id in b.call("block_ids"):
			if str(b.call("peek", id)) == "blocked":
				return [lvn, str(id)]
	return [0, ""]
