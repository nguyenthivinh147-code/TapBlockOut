extends RefCounted
## Kịch bản smoke (docs/TESTING.md "Tầng 2"). Mỗi hàm nhận runner `r` (tests/smoke/smoke.gd, không khai kiểu để
## tránh preload vòng) và trả true khi đi hết kịch bản; lỗi thì gọi r.fail(lý do).

const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Config := preload("res://src/config.gd")
const Lives := preload("res://src/meta/lives.gd")
const Cosmetics := preload("res://src/meta/cosmetics.gd")
const BOOSTERS := ["hint", "move", "smash"]
## Kịch bản G: tiến trình sau (G2) đọc kết quả mong đợi tiến trình trước ghi ở đây.
const G_EXPECT := "user://smoke_G/expect.json"


## Ads giả không bao giờ tải được video (Game.watch gọi Platform.load_ads trước khi chờ).
class NoLoadAds extends "res://src/platform/mock_ads.gd":
	func load_ads() -> void:
		pass

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
		"F":
			return await scen_f(r)
		"G":
			return await scen_g(r)
		"G2":
			return await scen_g2(r)
		"H":
			return await scen_h(r)
		"T":
			return await scen_t(r)
		"L":
			return await scen_l(r)
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


## F. Ads có thưởng (design.md mục 6, ads giả của Platform): x2 ở thẻ thắng (đóng sớm, không có video khi còn mạng và
## khi mất mạng, xem hết), ADS Daily trong Shop (đóng sớm, xem hết), mở avatar bằng video ở Profile. Chỉ thưởng khi xem
## hết và đúng một lần; đóng sớm hay không có video thì số dư không đổi.
static func scen_f(r) -> bool:
	if not await r.open_game("F", Callable(Saves, "veteran")):
		return false
	if not await win_level(r):
		return false
	var x2 := func() -> Control: return r.popup_node("X2Button") as Control
	if not await wait_for(r, func() -> bool: return x2.call() != null, 20000, "X2Button"):
		return r.fail("thắng L30 mà thẻ thắng không có nút x2")
	await r.wait_sec(0.8)
	await r.shot("win_card")
	var pending := int(r.game.get("_x2_pending"))
	var coins := int(r.game.s.coins)
	if pending <= 0:
		return r.fail("thẻ thắng có x2 mà không có gold chờ nhân đôi")
	if not await _ad_tap(r, x2.call(), "x2_coins", "closed", "x2 (đóng sớm)"):
		return false
	await r.wait_sec(0.5)
	if int(r.game.s.coins) != coins or x2.call() == null:
		return r.fail("x2 đóng sớm: gold %d → %d, nút x2 %s" % [coins, int(r.game.s.coins),
			"còn" if x2.call() != null else "mất"])
	await r.shot("x2_closed_early")
	for online in [true, false]:
		if not await _ad_unavailable(r, x2.call(), "x2", online):
			return false
		if int(r.game.s.coins) != coins:
			return r.fail("x2 không có video mà gold đổi %d → %d" % [coins, int(r.game.s.coins)])
	if not await _ad_tap(r, x2.call(), "x2_coins", "", "x2 (xem hết)"):
		return false
	if not await wait_for(r, func() -> bool: return int(r.game.s.coins) != coins, 10000, "*"):
		return r.fail("x2 xem hết mà gold không đổi")
	if int(r.game.s.coins) != coins + pending:
		return r.fail("x2 xem hết: gold %d → %d, mong đợi +%d" % [coins, int(r.game.s.coins), pending])
	r.step("x2 xem hết: gold %d → %d" % [coins, int(r.game.s.coins)])
	if not await wait_for(r, func() -> bool: return _playing(r) > 30 or r.screen_name() == "home", 20000):
		return r.fail("x2 xong thẻ thắng không tự đóng sang level kế")
	if not await go_home_from_level(r):
		return false
	await settle_all(r)
	if not await _f_shop(r):
		return false
	if not await back_home(r):
		return r.fail("Shop không về Home")
	await settle_all(r)
	if not await _f_profile(r):
		return false
	if not await back_home(r):
		return r.fail("Profile không về Home")
	return await verify_saved(r)


## ADS Daily trong Shop: đóng sớm không thưởng; xem hết cộng Config.ECON.shop_video_coins và bớt 1 lượt của ngày.
static func _f_shop(r) -> bool:
	if not await tap_named(r, "ShopButton", r.main.current_screen):
		return false
	if not await wait_for(r, func() -> bool: return r.screen_name() == "shop", 10000):
		return r.fail("bấm Shop không mở màn Shop")
	var btn := func() -> Control: return r.main.current_screen.get("video_button") as Control
	if btn.call() == null or not await scroll_into_view(r, btn.call()):
		return r.fail("Shop không có nút ADS Daily bấm được")
	await r.shot("shop_ads_daily")
	var coins := int(r.game.s.coins)
	var left := int(r.game.shop_videos_left())
	if left <= 0:
		return r.fail("save mới mà ADS Daily hết lượt")
	if not await _ad_tap(r, btn.call(), "shop_coins", "closed", "ADS Daily (đóng sớm)"):
		return false
	await r.wait_sec(0.5)
	if int(r.game.s.coins) != coins or int(r.game.shop_videos_left()) != left:
		return r.fail("ADS Daily đóng sớm: gold %d → %d, lượt %d → %d" % [coins, int(r.game.s.coins), left,
			int(r.game.shop_videos_left())])
	if not await _ad_tap(r, btn.call(), "shop_coins", "", "ADS Daily (xem hết)"):
		return false
	var gain := int(Config.ECON.shop_video_coins)
	if not await wait_for(r, func() -> bool: return int(r.game.s.coins) == coins + gain, 10000, "*"):
		return r.fail("ADS Daily xem hết: gold %d → %d, mong đợi +%d" % [coins, int(r.game.s.coins), gain])
	if int(r.game.shop_videos_left()) != left - 1:
		return r.fail("ADS Daily xem hết: lượt %d → %d" % [left, int(r.game.shop_videos_left())])
	r.step("ADS Daily: gold %d → %d, còn %d lượt" % [coins, coins + gain, left - 1])
	await settle_all(r)
	await r.shot("shop_after_video")
	return true


## Profile: món bán (Cosmetics.for_sale) chưa có ở tab đang hiện, chạm ô rồi xem hết video thì món đó vào kho.
static func _f_profile(r) -> bool:
	if not await tap_named(r, "ProfileButton", r.main.current_screen):
		return false
	if not await wait_for(r, func() -> bool: return r.screen_name() == "profile", 10000):
		return r.fail("bấm Profile không mở màn Profile")
	await r.wait_sec(0.6)
	var prof: Node = r.main.current_screen
	var id := ""
	for k in (prof.cells as Dictionary).keys():
		var cell := (prof.cells[k] as Dictionary).panel as Control
		if Cosmetics.for_sale(str(k)) and not Cosmetics.is_owned(r.game.s, str(k)) and cell.is_visible_in_tree():
			id = str(k)
			break
	if id == "":
		return r.fail("Profile không có món bán nào chưa có ở tab đang hiện")
	var panel := (prof.cells[id] as Dictionary).panel as Control
	if not await scroll_into_view(r, panel):
		return r.fail("không cuộn được tới ô %s" % id)
	if not await r.tap(panel, "ô %s" % id):
		return r.fail("không chạm được ô %s" % id)
	await r.wait_sec(0.4)
	var video := prof.get("video_button") as Control
	if video == null or not video.is_visible_in_tree():
		return r.fail("chọn món bán %s mà không có nút xem video" % id)
	if not await _ad_tap(r, video, "cosmetic_unlock", "", "mở %s bằng video" % id):
		return false
	if not await wait_for(r, func() -> bool: return Cosmetics.is_owned(r.game.s, id), 10000, "*"):
		return r.fail("xem hết video mà %s chưa vào kho" % id)
	r.step("mở %s bằng video" % id)
	await r.shot("profile_unlocked")
	return true


## Bấm `btn` (nút gọi Game.watch) sau khi ép kết quả ads giả `result` ("closed"; "" là xem như người dùng: headless
## trả ngay ok, cửa sổ thì settle bấm "Xem hết" trên lớp phủ); đợi lượt gọi ads mới đúng `placement`.
static func _ad_tap(r, btn: Control, placement: String, result: String, label: String) -> bool:
	if btn == null:
		return r.fail("%s: không có nút" % label)
	var calls: Array = r.plat.ads.calls
	var before := calls.size()
	if result != "":
		r.plat.ads.simulate(result)
	if not await r.tap(btn, label):
		return r.fail("không bấm được %s" % label)
	if not await wait_for(r, func() -> bool: return r.plat.ads.calls.size() > before, 10000, "*"):
		return r.fail("%s không gọi quảng cáo" % label)
	var last: Dictionary = r.plat.ads.calls.back()
	if str(last.placement) != placement:
		return r.fail("%s gọi placement %s, mong đợi %s" % [label, last.placement, placement])
	r.step("ads %s: %s" % [placement, JSON.stringify(last.result)])
	return true


## Không có video (design.md mục 6 "Chờ và lỗi"): lớp "Đang tải video" (Main.ad_loading) phủ màn trong lúc chờ, rồi
## popup "chưa có video" (popup_notice) khi còn mạng hoặc "Mất kết nối" (popup_no_internet) khi mất mạng. Đóng popup đó,
## trả ads giả và mạng như cũ.
static func _ad_unavailable(r, btn: Control, label: String, online: bool) -> bool:
	if btn == null:
		return r.fail("%s không có video: không có nút" % label)
	var stock: Variant = r.plat.ads
	var none := NoLoadAds.new()
	none.set_ready(false, false)
	r.plat.ads = none
	r.game.test_online = 1 if online else 0
	var wait0: Variant = Config.ADS.get("rv_wait_sec")
	Config.ADS["rv_wait_sec"] = 0.5
	var want := "popup_notice.gd" if online else "popup_no_internet.gd"
	var seen := {"wait": false}
	var shown: bool = await r.tap(btn, "%s (không có video, %s)" % [label, "còn mạng" if online else "mất mạng"])
	if shown:
		shown = await wait_for(r, func() -> bool:
			seen["wait"] = bool(seen["wait"]) or r.main.ad_loading != null
			return r.popup_script(want) != null, 15000, want)
	r.plat.ads = stock
	r.game.test_online = 1
	Config.ADS["rv_wait_sec"] = wait0
	if not shown:
		return r.fail("%s không có video mà không hiện %s" % [label, want])
	if not bool(seen["wait"]):
		return r.fail("%s không có video mà không thấy lớp Đang tải video" % label)
	if none.calls.size() != 0:
		return r.fail("%s không có video mà vẫn gọi phát video" % label)
	await r.wait_sec(0.5)
	await r.shot("%s_%s" % [label.to_snake_case(), "no_video" if online else "offline"])
	var pop: Node = r.popup_script(want)
	var close := find_close(pop)
	if close == null:
		return r.fail("%s không có nút đóng" % want)
	await r.tap(close, "%s: %s" % [want, close.name])
	if not await wait_for(r, func() -> bool: return r.popup_script(want) == null, 6000, "*"):
		return r.fail("không đóng được %s" % want)
	r.step("%s: không có video (%s) → %s, không thưởng" % [label, "còn mạng" if online else "mất mạng", want])
	return true


## G. Lưu qua khởi động lại: thắng L30 (gold, level), dùng một booster ở L31, tắt nhạc trong Settings, rồi như Android
## (Platform.paused) và bị tắt ngay. Một tiến trình Godot mới (kịch bản G2, cùng save) phải đọc lại đúng các số đó.
static func scen_g(r) -> bool:
	if not await r.open_game("G", Callable(Saves, "veteran")):
		return false
	if not await win_level(r):
		return false
	if not await after_win(r, 30):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == 31, 20000):
		return r.fail("thắng L30 không sang L31")
	var lv: Control = r.level_screen()
	var hint := int(r.game.s.inv.hint)
	await r.tap(lv.booster_buttons["hint"], "booster hint ở L31")
	if not await wait_for(r, func() -> bool: return int(r.game.s.inv.hint) == hint - 1, 6000):
		return r.fail("dùng hint ở L31 không trừ kho")
	if not await go_home_from_level(r):
		return false
	await settle_all(r)
	if not await tap_named(r, "SettingsButton", r.main.current_screen):
		return false
	if not await wait_for(r, func() -> bool: return r.popup_node("Toggle_music") != null, 6000, "Toggle_music"):
		return r.fail("Settings không có nút nhạc")
	var music := bool(r.game.s.settings.music)
	await r.tap(r.popup_node("Toggle_music") as Control, "Settings: nhạc")
	if not await wait_for(r, func() -> bool: return bool(r.game.s.settings.music) != music, 4000, "*"):
		return r.fail("bấm nút nhạc không đổi cài đặt")
	if not await close_to(r, 0):
		return r.fail("không đóng được Settings")
	await settle_all(r)
	var s: Dictionary = r.game.s
	var expect := {"level": int(s.level), "coins": int(s.coins), "hint": int(s.inv.hint), "move": int(s.inv.move),
		"smash": int(s.inv.smash), "lives": int(s.lives["count"]), "music": bool(s.settings.music),
		"sessions": int(s.meta.sessions)}
	var f := FileAccess.open(G_EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()
	r.step("trước khi tắt: %s" % JSON.stringify(expect))
	if str(r.args.get("restart", "")) == "external":
		# Máy thật (tools/device_smoke.sh): máy chủ bấm Home (onPause thật của Android) rồi force-stop app, sau đó mở
		# lại app với scen=G2. Kịch bản này không tự kết thúc.
		print("SMOKE G READY")
		await r.wait_until(func() -> bool: return false, 600000)
		return r.fail("không bị tắt từ ngoài sau 10 phút")
	# Như Android: onPause (Game lưu ngay) rồi tiến trình bị giết; vòng đợi G2 chặn luồng chính nên tiến trình này
	# không ghi thêm gì trong lúc G2 chạy.
	r.plat.emit_signal("paused")
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/smoke/smoke_main.gd", "--", "scen=G2", "out=%s" % r.out_dir.path_join("G2"),
		"speed=%s" % r.args.get("speed", "1"), "window=0", "max=240"])
	DirAccess.make_dir_recursive_absolute(r.out_dir.path_join("G2"))
	var res := _run_process(OS.get_executable_path(), args)
	for line in str(res.out).split("\n"):
		if line.begins_with("SMOKE ") or line.contains("ERROR"):
			print("G2 | %s" % line.strip_edges(false, true))
	var code := int(res.code)
	if code != 0:
		return r.fail("tiến trình sau (G2) thoát mã %d" % code)
	r.step("tiến trình sau (G2) đọc đúng save")
	return true


## Chạy `exe` tới khi xong (chặn luồng chính), trả {out, code}. Đọc stdout dạng byte rồi giải mã UTF-8: OS.execute trên
## Windows giải mã theo code page của máy nên chữ tiếng Việt trong log G2 bị vỡ.
static func _run_process(exe: String, args: PackedStringArray) -> Dictionary:
	var info := OS.execute_with_pipe(exe, args, false)
	if info.is_empty():
		return {"out": "", "code": -1}
	var pipe: FileAccess = info["stdio"]
	var pid := int(info["pid"])
	var buf := PackedByteArray()
	while OS.is_process_running(pid):
		buf.append_array(pipe.get_buffer(65536))
		OS.delay_msec(20)
	buf.append_array(pipe.get_buffer(1 << 20))
	pipe.close()
	return {"out": buf.get_string_from_utf8(), "code": OS.get_process_exit_code(pid)}


## G2 (chỉ scen_g gọi, tiến trình riêng): mở lại save của G như lần mở app sau, so với G_EXPECT.
static func scen_g2(r) -> bool:
	var text := FileAccess.get_file_as_string(G_EXPECT)
	var expect: Variant = JSON.parse_string(text)
	if not (expect is Dictionary):
		return r.fail("không đọc được %s" % G_EXPECT)
	if not await r.reopen_game("G"):
		return false
	var s: Dictionary = r.game.s
	var got := {"level": int(s.level), "coins": int(s.coins), "hint": int(s.inv.hint), "move": int(s.inv.move),
		"smash": int(s.inv.smash), "lives": int(s.lives["count"]), "music": bool(s.settings.music),
		"sessions": int(s.meta.sessions) - 1}
	r.step("sau khi mở lại: %s" % JSON.stringify(got))
	for k in (expect as Dictionary).keys():
		# JSON đọc mọi số thành float: so theo giá trị (3080 == 3080.0), in số nguyên.
		var want: Variant = expect[k]
		if want is float:
			want = int(want)
		if typeof(got.get(k)) != typeof(want) or got.get(k) != want:
			return r.fail("mở lại app: %s = %s, trước khi tắt là %s" % [k, str(got.get(k)), str(want)])
	if not await wait_for(r, func() -> bool: return _playing(r) == int(expect.level), 20000):
		return r.fail("mở lại app không vào L%d" % int(expect.level))
	return await verify_saved(r)


## H. Booster trong level (design.md mục 3): Gợi ý sáng một khối, Thêm lượt cộng ECON.rescue_moves MOVES, Búa phá một
## khối; mỗi lần trừ đúng 1 trong kho. Hết booster mà đủ gold thì mua (trừ ECON.booster_price), không đủ gold thì xem
## video (booster_free) để dùng một lần.
static func scen_h(r) -> bool:
	if not await r.open_game("H", Callable(Saves, "veteran")):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == 30, 20000):
		return r.fail("không vào được L30")
	await settle_all(r)
	for kind in BOOSTERS:
		if not await _use_booster(r, kind, "kho"):
			return false
	# Hết hint, đủ gold: mua bằng gold.
	r.game.s.inv["hint"] = 0
	var price := int(Config.ECON.booster_price.hint)
	var coins := int(r.game.s.coins)
	if not await _tap_booster(r, "hint"):
		return false
	if not await _tap_dialog(r, "BuyButton", "mua hint bằng gold"):
		return false
	if not await wait_for(r, func() -> bool: return int(r.game.s.coins) == coins - price, 6000, "*"):
		return r.fail("mua hint: gold %d → %d, mong đợi -%d" % [coins, int(r.game.s.coins), price])
	r.step("mua hint: gold %d → %d" % [coins, coins - price])
	await r.wait_sec(1.0)
	# Hết move, không đủ gold: xem video để dùng một lần.
	r.game.s.inv["move"] = 0
	r.game.s.coins = 0
	var lv: Control = r.level_screen()
	var moves: int = lv.board.moves_left()
	if not await _tap_booster(r, "move"):
		return false
	var video := await _dialog_button(r, "VideoButton")
	if video == null:
		return r.fail("hết move và không đủ gold mà không có nút xem video")
	if not await _ad_tap(r, video, "booster_free", "", "move bằng video"):
		return false
	var gain := int(Config.ECON.rescue_moves)
	if not await wait_for(r, func() -> bool: return r.level_screen().board.moves_left() == moves + gain, 8000, "*"):
		return r.fail("move bằng video: MOVES %d → %d, mong đợi +%d" % [moves, r.level_screen().board.moves_left(), gain])
	r.step("move bằng video: MOVES %d → %d" % [moves, moves + gain])
	await r.shot("booster_video")
	return await verify_saved(r)


## Dùng booster `kind` có sẵn trong kho và kiểm tác dụng của nó.
static func _use_booster(r, kind: String, how: String) -> bool:
	var lv: Control = r.level_screen()
	var have := int(r.game.s.inv[kind])
	if have <= 0:
		return r.fail("save không có %s trong kho" % kind)
	var moves: int = lv.board.moves_left()
	var blocks: Array = lv.board.block_ids()
	if not await _tap_booster(r, kind):
		return false
	match kind:
		"hint":
			if not await wait_for(r, func() -> bool: return is_instance_valid(lv.get("_hint_fx")), 4000, "*"):
				return r.fail("bấm hint không có hiệu ứng gợi ý")
		"move":
			var gain := int(Config.ECON.rescue_moves)
			if not await wait_for(r, func() -> bool: return lv.board.moves_left() == moves + gain, 4000, "*"):
				return r.fail("move: MOVES %d → %d, mong đợi +%d" % [moves, lv.board.moves_left(), gain])
		"smash":
			if not await wait_for(r, func() -> bool: return bool(lv.get("_smash_mode")), 4000, "*"):
				return r.fail("bấm búa không vào chế độ phá khối")
			var target := ""
			for id in blocks:
				if not lv.board.can_exit(str(id)):
					target = str(id)
					break
			if target == "":
				target = str(blocks[0])
			await r.tap_block(target)
			if not await wait_for(r, func() -> bool: return not lv.board.block_ids().has(target), 6000, "*"):
				return r.fail("búa không phá khối %s" % target)
	if not await wait_for(r, func() -> bool: return int(r.game.s.inv[kind]) == have - 1, 4000, "*"):
		return r.fail("dùng %s: kho %d → %d" % [kind, have, int(r.game.s.inv[kind])])
	r.step("dùng %s từ %s: kho %d → %d" % [kind, how, have, have - 1])
	await r.wait_sec(1.2)
	await r.shot("booster_%s" % kind)
	return true


static func _tap_booster(r, kind: String) -> bool:
	if not await wait_for(r, func() -> bool:
			return r.level_screen() != null and str(r.level_screen().state) == "playing", 10000):
		return r.fail("level không ở trạng thái chơi để bấm %s" % kind)
	var b: Control = r.level_screen().booster_buttons[kind]
	if not await r.tap(b, "booster %s" % kind):
		return r.fail("không bấm được booster %s" % kind)
	return true


## Nút `name` của hộp thoại đang hiện (hộp thoại booster của level), null nếu không thấy trong 6 giây.
static func _dialog_button(r, name: String) -> Control:
	var found := {"b": null}
	await wait_for(r, func() -> bool:
		found["b"] = find_visible(r.main, name)
		return found["b"] != null, 6000, "*")
	return found["b"] as Control


static func _tap_dialog(r, name: String, label: String) -> bool:
	var b := await _dialog_button(r, name)
	if b == null:
		return r.fail("%s: không thấy nút %s" % [label, name])
	await r.wait_sec(0.4)
	if not await r.tap(b, label):
		return r.fail("không bấm được %s" % label)
	return true


## T. Chuyển cảnh: ảnh mỗi 150 ms (r.film, chỉ khi có cửa sổ) qua level → Home, Home → Chơi (curtain kẹo), thắng →
## level kế (màn chuyển level), Home → Shop → Home (trượt tab), mở và đóng Settings.
static func scen_t(r) -> bool:
	if not await r.open_game("T", Callable(Saves, "veteran")):
		return false
	if not await wait_for(r, func() -> bool: return _playing(r) == 30, 20000):
		return r.fail("không vào được L30")
	await settle_all(r)
	var lv: Control = r.level_screen()
	await r.tap(lv.settings_button, "Cài đặt trong màn")
	if not await wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong màn không mở")
	await r.wait_sec(0.4)
	if not await tap_named(r, "HomeButton", r.popup_script("popup_ingame_settings.gd")):
		return false
	# Rời level có thể hỏi xác nhận (mất mạng): bấm xác nhận rồi mới quay cảnh chuyển.
	await wait_for(r, func() -> bool: return find_visible(r.main, "ConfirmButton") != null \
		or r.screen_name() == "home" or r.main.curtain != null, 1500, "*")
	var confirm := find_visible(r.main, "ConfirmButton") as Control
	if confirm != null:
		await r.tap(confirm, "xác nhận rời màn")
	await r.film("level_to_home", 1.5)
	if not await wait_for(r, func() -> bool: return r.screen_name() == "home" and r.main.curtain == null, 15000):
		return r.fail("Cài đặt → Home không về Home")
	await settle_all(r)
	await r.quiet()
	if not await tap_named(r, "PlayButton", r.main.current_screen):
		return false
	await r.film("play_curtain", 3.0)
	if not await win_level(r):
		return false
	var cont: Variant = null
	if await wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000, "ContinueButton"):
		cont = r.popup_node("ContinueButton")
	if cont == null:
		return r.fail("thắng mà không có thẻ thắng")
	await r.wait_sec(0.8)
	await r.tap(cont, "Tiếp tục")
	await r.film("next_level", 2.4)
	if not await go_home_from_level(r):
		return false
	await settle_all(r)
	await r.quiet()
	if not await tap_named(r, "ShopButton", r.main.current_screen):
		return false
	await r.film("home_to_shop", 0.9)
	if not await wait_for(r, func() -> bool: return r.screen_name() == "shop", 6000):
		return r.fail("bấm Shop không mở màn Shop")
	await r.quiet()
	var tab := find_visible(r.main.current_screen, "HomeTab") as Control
	if tab == null:
		return r.fail("màn Shop không có tab Home")
	await r.tap(tab, "tab Home")
	await r.film("shop_to_home", 0.9)
	if not await back_home(r):
		return r.fail("Shop không về Home")
	await settle_all(r)
	await r.quiet()
	if not await tap_named(r, "SettingsButton", r.main.current_screen):
		return false
	await r.film("popup_open", 0.9)
	if r.popups().is_empty():
		return r.fail("bấm Settings không mở popup")
	var close := find_close(r.popups().back())
	if close == null:
		return r.fail("Settings không có nút đóng")
	await r.tap(close, "đóng Settings")
	await r.film("popup_close", 0.9)
	return await verify_saved(r)


## L. Mỗi ngôn ngữ của Game.LANGS: Home và popup Settings, ảnh khi có cửa sổ và census mọi chế độ (cảnh báo chữ rộng
## hơn nhãn, ra ngoài màn, giống key chưa dịch). Đổi ngôn ngữ bằng Game.set_setting như ô của popup Language, rồi dựng
## lại Home như lúc đóng Settings sau khi đổi ngôn ngữ.
static func scen_l(r) -> bool:
	if not await r.open_game("L", Callable(Saves, "all_unlocked")):
		return false
	if not await go_home_from_level(r):
		return false
	await settle_all(r)
	var langs: Array = (r.game.get_script() as Script).get_script_constant_map()["LANGS"]
	for lang in langs:
		r.game.set_setting("lang", lang)
		r.main.go("home")
		await settle_all(r)
		await r.shot("home_%s" % lang)
		if not await tap_named(r, "SettingsButton", r.main.current_screen):
			return false
		if not await wait_for(r, func() -> bool: return r.popup_script("settings.gd") != null, 6000, "settings.gd"):
			return r.fail("%s: Settings không mở" % lang)
		await r.wait_sec(0.6)
		await r.shot("settings_%s" % lang)
		if not await close_to(r, 0):
			return r.fail("%s: không đóng được Settings" % lang)
		await settle_all(r)
	r.game.set_setting("lang", "en")
	r.step("đã soát %d ngôn ngữ" % langs.size())
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
	# idle=<giây>: đo khung hình lúc bàn đứng yên trước khi chạm (pha "idle L<n>"). pace=<giây>: nghỉ giữa hai lần chạm
	# như người chơi (mặc định 2 khung, nhanh hơn người thật nên hiệu ứng khối chồng lên nhau).
	var idle := float(r.args.get("idle", "0"))
	var pace := float(r.args.get("pace", "0"))
	if idle > 0.0:
		r.begin_phase("idle L%d" % lvl)
		await r.wait_sec(idle)
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
		if pace > 0.0:
			await r.wait_sec(pace)
		else:
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


## Nút bấm được ở lớp trên cùng: popup trên cùng (và lớp phủ giả) nếu có, không thì màn hiện tại. Màn chuyển cảnh
## (Main.curtain) phủ kín và chặn chạm nên lúc nó chạy không có gì để bấm: nút bên dưới bị gỡ khi nó phủ kín.
static func clickables(r) -> Array[Control]:
	if r.main.curtain != null:
		return []
	var roots: Array[Node] = []
	for name in ["MockAdOverlay", "MockIapOverlay"]:
		var o: Node = r.root.find_child(name, true, false)
		if o != null:
			roots.append(o)
	if roots.is_empty():
		var pops: Array = r.popups()
		if not pops.is_empty():
			var top: Node = pops.back()
			var inner := _nested_popup(top)
			roots.append(inner if inner != null else top)
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
				var at: Vector2 = r.to_viewport(c, c.size * 0.5)
				# Ô đã cuộn khuất khỏi khung cắt (lưới Profile, danh sách Language) không thấy nên không bấm.
				var clip: Variant = r._clip_of(c)
				if view.has_point(at) and (clip == null or (clip as Rect2).has_point(at)):
					out.append(c)
		if out.is_empty() and root is Control and STRAY_SCRIPTS.has(script_file(root)):
			out.append(root as Control)
	return out


## Popup mở bên trong một popup (vd hướng dẫn của Weekly Pass, con của node WeeklyPass): node hiện, có signal closed,
## nằm sâu nhất và sau cùng theo thứ tự cây; null nếu không có. Nó che nút của popup chứa nó nên là lớp trên cùng.
static func _nested_popup(top: Node) -> Node:
	var found: Node = null
	var stack: Array[Node] = []
	for ch in top.get_children():
		stack.push_front(ch)
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if n.has_signal("closed") and script_file(n).begins_with("popup_"):
			found = n
		for ch in n.get_children():
			stack.push_front(ch)
	return found


static func _banned(n: Node) -> bool:
	if MONKEY_BANNED_NAMES.has(str(n.name)) or n.is_in_group("tester_menu"):
		return true
	return MONKEY_BANNED_SCRIPTS.has(script_file(n))


## Trạng thái nhìn thấy được: màn, popup, bàn chơi và các số trong save người chơi để ý.
static func _signature(r) -> String:
	var parts: PackedStringArray = [r.screen_name()]
	for c in r.popups():
		parts.append(script_file(c))
		var inner := _nested_popup(c)
		if inner != null:
			parts.append(script_file(inner))
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
