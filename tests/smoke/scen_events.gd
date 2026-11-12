extends RefCounted
## Kịch bản smoke cho sự kiện mua hàng (design.md mục 7 "Sự kiện: Weekly Pass, Chain Offer, Special Pack").
## Gọi qua scenarios.gd SCEN_FILES. Mỗi hàm nhận runner `r` (tests/smoke/smoke.gd) như kịch bản trong scenarios.gd.
## Mua qua store giả (r.plat.iap là MockIap: headless trả ngay `ok`, có màn hình thì Scen.settle bấm "Mua" trên lớp
## phủ), video qua ads giả; số mong đợi đọc từ Config. Giờ chỉ đổi bằng r.game.test_now: smoke.gd đặt giờ cố định NOW
## (thứ Sáu 08:00 giờ máy giả lập), lúc đó mùa Weekly Pass đang Active và đang weekend sale.

const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Config := preload("res://src/config.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")

const DAY := 86400
const BOOSTERS := ["hint", "move", "smash"]


static func run(r, scen: String) -> bool:
	match scen:
		"WP":
			return await scen_wp(r)
		"CO":
			return await scen_co(r)
		"SP":
			return await scen_sp(r)
	return r.fail("không có kịch bản %s" % scen)


# ================================================================ Weekly Pass

## WP. Weekly Pass (design.md mục 7 "Weekly Pass"): save đứng ở level HARD thứ `WEEKLY.unlock_hard_index` (L26).
## [NEG] Home chưa có nút Weekly Pass, mùa Locked; thắng L26 không cộng key, thẻ thắng không có ô chìa. Sang L27:
## [EDGE] mùa Active nhưng chưa xem tutorial nên thắng không cộng key. Về Home: [HP] nút Weekly Pass hiện → mở: tutorial
## 3 bước (chạm đâu cũng sang bước, chỉ bước cuối lưu cờ) → popup "How to earn rewards" → nhận free mốc khởi đầu (mạng vô
## hạn `inf_min` phút). [NEG] Chạm lại ô vừa nhận, ô VIP khi chưa có VIP, ô mốc chưa đủ key: không nhận gì. Chơi L28,
## L29 (HARD): mỗi lần thắng +points_for(độ khó) key, thẻ thắng có ô "+N chìa". Về Home: [HP] popup Upsell tự hiện (có
## key, chưa VIP) → mua VIP qua store giả → VIP, +`vip_bonus_hearts` mạng tối đa cộng luôn vào số mạng → Weekly Pass tự
## mở, không chạy lại tutorial → nhận VIP mốc 0 và free mốc 1, để lại VIP mốc 1. [EDGE] Sang mùa (app tạm dừng, mở lại
## thứ Hai 03:00, Waiting): VIP tự nhận thưởng còn tồn, reset điểm, VIP, ô đã nhận, bỏ mạng tối đa tạm; nút ở Home còn;
## layer hiện popup cuối mùa rồi chỉ có đếm ngược Waiting.
static func scen_wp(r) -> bool:
	if not await r.open_game("WP", func(g: Node) -> void: _wp_save(g)):
		return false
	var u: int = r.game.weekly_unlock_level()
	if u <= 0:
		return r.fail("không tìm được level HARD thứ %d để mở Weekly Pass" % int(Config.WEEKLY.unlock_hard_index))
	if not await _ensure_playing(r, u):
		return false
	if not await _to_home(r, ""):
		return false
	await Scen.settle_all(r)
	if Scen.find_visible(r.main.current_screen, "WeeklyPassButton") != null:
		return r.fail("[NEG] chưa qua L%d mà Home đã có nút Weekly Pass" % u)
	if str(r.game.weekly_state()) != WeeklyPass.LOCKED:
		return r.fail("[NEG] chưa qua L%d mà Weekly Pass ở trạng thái %s" % [u, str(r.game.weekly_state())])
	r.step("[NEG] chưa qua L%d (HARD thứ %d): Weekly Pass khoá, Home không có nút" % [u,
		int(Config.WEEKLY.unlock_hard_index)])
	await r.shot("home_locked")
	if not await _ensure_playing(r, u):
		return false
	if not await _win_check_keys(r, u, 0):
		return false
	if not await Scen.after_win(r, u):
		return false
	if not await _ensure_playing(r, u + 1):
		return false
	if str(r.game.weekly_state()) != WeeklyPass.ACTIVE:
		return r.fail("qua L%d (giờ giả lập thứ Sáu) mà Weekly Pass ở trạng thái %s, mong đợi active" % [u,
			str(r.game.weekly_state())])
	# Chưa xem tutorial: thắng không cộng key.
	if not await _win_check_keys(r, u + 1, 0):
		return false
	r.step("[EDGE] mùa Active, chưa xem tutorial: thắng L%d không cộng key" % (u + 1))
	if not await Scen.after_win(r, u + 1):
		return false
	if not await _to_home(r, ""):
		return false
	await Scen.settle_all(r)
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "WeeklyPassButton") != null, 4000):
		return r.fail("[HP] qua L%d mà Home không có nút Weekly Pass" % u)
	r.step("[HP] qua L%d: Home có nút Weekly Pass" % u)
	await r.shot("home_weekly")
	var wp := await _open_from_home(r, "WeeklyPassButton", "weekly_pass.gd")
	if wp == null:
		return false
	if not await _wp_tutorial(r, wp):
		return false
	if not await _wp_claim(r, wp, "free", 0):
		return false
	if not await _wp_tap_nothing(r, wp, "free", 0, "ô free mốc 0 vừa nhận"):
		return false
	if not await _wp_tap_nothing(r, wp, "vip", 0, "ô VIP mốc 0 khi chưa mua VIP"):
		return false
	if not await _wp_tap_nothing(r, wp, "free", 1, "ô free mốc 1 khi chưa đủ key"):
		return false
	await r.shot("weekly_free_claimed")
	if not await _close_popup(r, wp, "Weekly Pass"):
		return false
	# Hai level có key: thường (+points_normal) rồi HARD (+points_hard).
	for lv in [u + 2, u + 3]:
		if not await _ensure_playing(r, lv):
			return false
		var want := WeeklyPass.points_for(str(r.game.difficulty_of(lv)))
		if not await _win_check_keys(r, lv, want):
			return false
		if not await Scen.after_win(r, lv):
			return false
	if not await _wp_upsell_buy(r):
		return false
	wp = await _wait_popup(r, "weekly_pass.gd", 8000, "weekly_pass.gd")
	if wp == null:
		return r.fail("[HP] mua VIP ở popup mời mà Weekly Pass không tự mở")
	await r.wait_sec(1.2)
	if is_instance_valid(wp.get("tutorial")):
		return r.fail("[NEG] đã xem tutorial mà mở Weekly Pass lại chạy tutorial")
	r.step("[HP] mua VIP xong Weekly Pass tự mở, không chạy lại tutorial")
	if not await _wp_claim(r, wp, "vip", 0):
		return false
	var main := WeeklyPass.main_milestones()
	if WeeklyPass.points(r.game.s) >= int(main[1].points):
		if not await _wp_claim(r, wp, "free", 1):
			return false
	if not await _wp_tap_nothing(r, wp, "vip", 0, "ô VIP mốc 0 vừa nhận"):
		return false
	await r.shot("weekly_vip")
	if not await _close_popup(r, wp, "Weekly Pass"):
		return false
	await Scen.settle_all(r)
	if not await _wp_new_season(r):
		return false
	return await Scen.verify_saved(r)


## Save của WP: người chơi lâu đứng ở level HARD thứ `unlock_hard_index` (chưa qua nên Weekly Pass còn khoá), đã xem
## giới thiệu cơ chế trước level đó, chưa xem tutorial Weekly Pass.
static func _wp_save(g: Node) -> void:
	Saves.veteran(g)
	Saves._at_level(g, int(g.weekly_unlock_level()), false)
	g.s.weekly["tut_seen"] = false


## Thắng level `lvl` đang chơi, đợi thẻ thắng, kiểm key Weekly Pass cộng đúng `want` và thẻ có ô "+N chìa" đúng khi
## `want` > 0 (design.md mục 4 "Thẻ thắng và thẻ thua", mục 7 "Weekly Pass").
static func _win_check_keys(r, lvl: int, want: int) -> bool:
	var before := WeeklyPass.points(r.game.s)
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000,
			"ContinueButton"):
		return r.fail("thắng L%d mà không có thẻ thắng" % lvl)
	var got := WeeklyPass.points(r.game.s) - before
	var kind := str(r.game.difficulty_of(lvl))
	if got != want:
		return r.fail("thắng L%d (%s, Weekly Pass %s): key +%d, mong đợi +%d" % [lvl, kind if kind != "" else "normal",
			str(r.game.weekly_state()), got, want])
	await r.wait_sec(0.6)
	var cell: Node = r.popup_node("WeeklyKeyReward")
	var shown := cell != null and (cell as CanvasItem).is_visible_in_tree()
	if shown != (want > 0):
		return r.fail("thắng L%d: key +%d mà thẻ thắng %s ô chìa" % [lvl, got, "có" if shown else "không có"])
	r.step("thắng L%d (%s): key +%d, thẻ thắng %s ô chìa" % [lvl, kind if kind != "" else "normal", got,
		"có" if shown else "không có"])
	if want > 0:
		await r.shot("win_card_keys_L%d" % lvl)
	return true


## Tutorial lần đầu mở layer (design.md mục 7 "Weekly Pass"): overlay 3 bước, chạm bất kỳ đâu để sang bước, chỉ bước
## cuối lưu cờ `tut_seen`, rồi popup "How to earn rewards" (Ok đóng).
static func _wp_tutorial(r, wp: Node) -> bool:
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp) and is_instance_valid(wp.get("tutorial")),
			8000, "weekly_pass.gd"):
		return r.fail("mở Weekly Pass lần đầu mà không chạy tutorial")
	var tut: Control = wp.get("tutorial")
	var n: int = (tut.get("steps") as Array).size()
	for k in n:
		var ready: bool = await r.wait_until(func() -> bool:
			return not is_instance_valid(tut) or (int(tut.get("index")) == k and not bool(tut.get("busy"))), 5000)
		if not ready or not is_instance_valid(tut):
			return r.fail("tutorial Weekly Pass không tới bước %d/%d" % [k + 1, n])
		if r.game.weekly_tutorial_seen():
			return r.fail("[NEG] tutorial mới ở bước %d/%d mà đã lưu cờ đã xem" % [k + 1, n])
		if k == 0:
			await r.shot("weekly_tutorial")
		await r.tap(tut, "tutorial Weekly Pass bước %d/%d" % [k + 1, n])
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(wp.get("howto")), 5000, "weekly_pass.gd"):
		return r.fail("xong tutorial mà không mở popup How to earn rewards")
	if not r.game.weekly_tutorial_seen():
		return r.fail("xong tutorial mà chưa lưu cờ đã xem")
	r.step("[HP] tutorial Weekly Pass %d bước xong, đã lưu cờ, mở popup How to earn rewards" % n)
	await r.wait_sec(0.5)
	await r.shot("weekly_howto")
	if not await Scen.tap_named(r, "OkButton", wp.get("howto")):
		return false
	if not await Scen.wait_for(r, func() -> bool: return not is_instance_valid(wp.get("howto")), 4000, "weekly_pass.gd"):
		return r.fail("Ok không đóng popup How to earn rewards")
	return true


## Ô thưởng Main Tree `kind` ("free" | "vip") của mốc `i` đang hiện (layer dựng lại ô sau mỗi lần nhận).
static func _wp_card(wp: Node, kind: String, i: int) -> Control:
	var b: Variant = (wp.get("main_buttons") as Dictionary).get("%s_%d" % [kind, i])
	if b == null or not is_instance_valid(b):
		return null
	return b as Control


## Chạm ô `kind` mốc `i` và kiểm nhận đúng thưởng của mốc trong Config.WEEKLY.main.
static func _wp_claim(r, wp: Node, kind: String, i: int) -> bool:
	var btn := _wp_card(wp, kind, i)
	if btn == null:
		return r.fail("Weekly Pass không có ô %s mốc %d" % [kind, i])
	if (btn as BaseButton).disabled:
		return r.fail("ô %s mốc %d đang khoá mà theo luật nhận được (%d key)" % [kind, i, WeeklyPass.points(r.game.s)])
	var reward: Dictionary = (WeeklyPass.main_milestones()[i] as Dictionary).get(kind, {})
	var before := _bal(r)
	if not await Scen.scroll_into_view(r, btn):
		return r.fail("không cuộn được tới ô %s mốc %d" % [kind, i])
	if not await r.tap(btn, "Weekly Pass: nhận %s mốc %d" % [kind, i]):
		return r.fail("ô %s mốc %d bị che" % [kind, i])
	var list := "claimed_%s" % kind
	if not await Scen.wait_for(r, func() -> bool: return _has_int(r.game.s.weekly.get(list, []), i), 4000,
			"weekly_pass.gd"):
		return r.fail("chạm ô %s mốc %d mà chưa nhận" % [kind, i])
	var problem := _gain_problem(before, _bal(r), reward, int(r.game.now()))
	if problem != "":
		return r.fail("nhận %s mốc %d: %s" % [kind, i, problem])
	r.step("[HP] Weekly Pass: nhận %s mốc %d (%d key): %s" % [kind, i, WeeklyPass.points(r.game.s),
		JSON.stringify(reward)])
	await r.wait_sec(0.6)
	return true


## [NEG] Chạm ô không nhận được (đã nhận, VIP khi chưa có VIP, chưa đủ key): số dư và danh sách đã nhận không đổi.
static func _wp_tap_nothing(r, wp: Node, kind: String, i: int, label: String) -> bool:
	var btn := _wp_card(wp, kind, i)
	if btn == null:
		return r.fail("Weekly Pass không có ô %s mốc %d" % [kind, i])
	var before := _bal(r)
	var w: Dictionary = r.game.s.weekly
	var claimed := str(w.get("claimed_free")) + str(w.get("claimed_vip"))
	if not await Scen.scroll_into_view(r, btn):
		return r.fail("không cuộn được tới %s" % label)
	await r.tap(btn, "Weekly Pass: chạm %s" % label)
	await r.wait_sec(0.6)
	var now_claimed := str(w.get("claimed_free")) + str(w.get("claimed_vip"))
	if _bal(r) != before or now_claimed != claimed:
		return r.fail("[NEG] chạm %s mà nhận được thưởng (%s → %s)" % [label, JSON.stringify(before),
			JSON.stringify(_bal(r))])
	r.step("[NEG] chạm %s: không nhận gì" % label)
	return true


## Về Home sau khi có key: popup Upsell tự hiện một lần trong mùa; mua VIP qua store giả. Kiểm VIP, mạng tối đa tạm cộng
## luôn vào số mạng, gói không cho gold hay booster, đơn ghi đúng SKU `WEEKLY.sku`.
static func _wp_upsell_buy(r) -> bool:
	if not await _to_home(r, "popup_weekly_upsell.gd"):
		return false
	var up := await _wait_popup(r, "popup_weekly_upsell.gd", 10000, "popup_weekly_upsell.gd")
	if up == null:
		return r.fail("[HP] về Home lúc có %d key, chưa VIP mà không hiện popup mời mua VIP" % WeeklyPass.points(r.game.s))
	var w: Dictionary = r.game.s.weekly
	if str(w.get("upsell", "")) != str(w.get("cycle", "")):
		return r.fail("popup mời mua VIP hiện mà chưa ghi mùa đã mời")
	var sku := str(Config.WEEKLY.sku)
	var price: Node = Scen.find_visible(up, "BuyButton")
	var out: Label = price.find_child("Out", true, false) as Label if price != null else null
	if out == null or out.text != str(r.plat.price(sku)):
		return r.fail("nút mua của popup mời ghi \"%s\", mong đợi giá %s" % [out.text if out != null else "",
			str(r.plat.price(sku))])
	await r.wait_sec(0.6)
	await r.shot("weekly_upsell")
	var before := _bal(r)
	if not await Scen.tap_named(r, "BuyButton", up):
		return false
	if not await Scen.wait_for(r, func() -> bool: return WeeklyPass.is_vip(r.game.s), 10000, "popup_weekly_upsell.gd"):
		return r.fail("[HP] mua VIP ở popup mời mà chưa có VIP")
	var after := _bal(r)
	var hearts := int(Config.WEEKLY.vip_bonus_hearts)
	if int(after.bonus) != hearts or int(after.lives) != int(before.lives) + hearts:
		return r.fail("mua VIP: mạng %d → %d, mạng tối đa tạm %d, mong đợi +%d mạng" % [int(before.lives),
			int(after.lives), int(after.bonus), hearts])
	var problem := _gain_problem(before, after, {}, int(r.game.now()))
	if problem != "":
		return r.fail("mua VIP mà %s" % problem)
	var last: Dictionary = (r.game.s.buys as Array).back()
	if int(after.buys) != int(before.buys) + 1 or str(last.get("sku", "")) != sku:
		return r.fail("mua VIP mà đơn ghi %s, mong đợi một đơn %s" % [str(last.get("sku", "")), sku])
	r.step("[HP] mua VIP (%s) ở popup mời: VIP, mạng %d → %d (+%d mạng tối đa tạm)" % [sku, int(before.lives),
		int(after.lives), hearts])
	return true


## Sang mùa (design.md mục 7 "Weekly Pass"): app tạm dừng rồi mở lại vào thứ Hai 03:00 của tuần sau (Waiting). VIP tự
## nhận mọi thưởng đang nhận được mà chưa nhận; điểm, VIP, ô đã nhận về 0; bỏ mạng tối đa tạm, số mạng kẹp lại. Nút ở Home
## còn; layer hiện popup cuối mùa, Ok thì chỉ còn đếm ngược Waiting.
static func _wp_new_season(r) -> bool:
	var s: Dictionary = r.game.s
	var expect := _wp_unclaimed(s)
	var vip := WeeklyPass.is_vip(s)
	var pts := WeeklyPass.points(s)
	var old_cycle := str(s.weekly.get("cycle", ""))
	var before := _bal(r)
	var win: Dictionary = WeeklyPass.window(int(r.game.now()), int(r.game.test_tz))
	var t := int(win.end) + 3 * 3600
	r.step("app tạm dừng, mở lại lúc thứ Hai 03:00 tuần sau (VIP %s, %d key, còn tồn %s)" % [vip, pts,
		JSON.stringify(expect)])
	r.plat.emit_signal("paused")
	r.game.test_now = t
	r.plat.emit_signal("resumed")
	if not await Scen.wait_for(r, func() -> bool: return str(r.game.s.weekly.get("cycle", "")) != old_cycle, 4000):
		return r.fail("mở lại app tuần sau mà Weekly Pass chưa sang mùa")
	if str(r.game.weekly_state()) != WeeklyPass.WAITING:
		return r.fail("thứ Hai 03:00 mà Weekly Pass ở trạng thái %s, mong đợi waiting" % str(r.game.weekly_state()))
	var problem := _gain_problem(before, _bal(r), expect if vip else {}, t)
	if problem != "":
		return r.fail("[EDGE] sang mùa (VIP %s): %s" % [vip, problem])
	var w: Dictionary = r.game.s.weekly
	if int(w.points) != 0 or bool(w.vip) or not (w.claimed_free as Array).is_empty() \
			or not (w.claimed_vip as Array).is_empty():
		return r.fail("[EDGE] sang mùa mà chưa reset: %d key, VIP %s, đã nhận %s / %s" % [int(w.points), bool(w.vip),
			str(w.claimed_free), str(w.claimed_vip)])
	var lives: Dictionary = r.game.s.lives
	if int(lives.get("bonus", 0)) != 0 or int(lives.count) > int(Config.LIVES.max):
		return r.fail("[EDGE] sang mùa mà còn mạng tối đa tạm %d, mạng %d" % [int(lives.get("bonus", 0)),
			int(lives.count)])
	r.step("[EDGE] sang mùa: VIP tự nhận %s, reset key và VIP, mạng %d → %d" % [JSON.stringify(expect),
		int(before.lives), int(lives.count)])
	if not await Scen.wait_for(r, func() -> bool:
			return r.screen_name() == "home" and Scen.find_visible(r.main.current_screen, "WeeklyPassButton") != null,
			4000):
		return r.fail("[EDGE] Waiting mà Home không còn nút Weekly Pass")
	var wp := await _open_from_home(r, "WeeklyPassButton", "weekly_pass.gd")
	if wp == null:
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen.find_visible(wp, "EndLabel") != null, 4000,
			"weekly_pass.gd"):
		return r.fail("[EDGE] mở Weekly Pass sau khi sang mùa mà không có popup cuối mùa")
	await r.wait_sec(0.6)
	await r.shot("weekly_end")
	if not await Scen.tap_named(r, "EndOkButton", wp):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen.find_visible(wp, "WaitingLabel") != null, 4000,
			"weekly_pass.gd"):
		return r.fail("[EDGE] Waiting mà layer không hiện đếm ngược")
	if Scen.find_visible(wp, "BuyVipButton") != null or Scen.find_visible(wp, "ClaimAllButton") != null:
		return r.fail("[EDGE] Waiting mà layer còn nút mua VIP hay nhận thưởng")
	r.step("[EDGE] Waiting: popup cuối mùa rồi chỉ còn đếm ngược")
	await r.wait_sec(0.4)
	await r.shot("weekly_waiting")
	if not await Scen.tap_named(r, "Ok", wp):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("weekly_pass.gd") == null, 4000):
		return r.fail("Ok ở Waiting không đóng Weekly Pass")
	return true


## Thưởng Main Tree đã đủ key mà chưa nhận: free, và VIP khi có VIP ({coins, items, inf_min}).
static func _wp_unclaimed(s: Dictionary) -> Dictionary:
	var total := {"coins": 0, "items": {}, "inf_min": 0}
	var w: Dictionary = s.weekly
	var pts := int(w.get("points", 0))
	var vip := bool(w.get("vip", false))
	for i in (Config.WEEKLY.main as Array).size():
		var m: Dictionary = Config.WEEKLY.main[i]
		if pts < int(m.points):
			continue
		if not _has_int(w.get("claimed_free", []), i):
			total = _add_reward(total, m.get("free", {}))
		if vip and not _has_int(w.get("claimed_vip", []), i):
			total = _add_reward(total, m.get("vip", {}))
	return total


# ================================================================ Chain Offer

## CO. Chain Offer (design.md mục 7 "Chain Offer"): save ở L(level_unlock − 2) = L128. [NEG] Thắng L128: level đang tới
## (129) dưới `CHAIN.level_unlock`, không bật chuỗi. [HP] Thắng L129: bật chuỗi đầu (`sequences[0]`), sống
## `days_to_existence` ngày. Về Home: layer tự mở một lần. [NEG] Chạm gói đang khoá: chỉ hiện dòng "nhận gói phía trước",
## không nhận gì. Nhận lần lượt mọi bước (free; ad qua ads giả; pay qua store giả, thưởng lấy từ chính gói, không cộng
## hai lần), mỗi bước một popup Reward, gói kế chỉ mở khi popup đóng. [NEG] Bước ad đóng video sớm, bước pay huỷ mua:
## không nhận, bước giữ nguyên. [EDGE] Cửa sổ `CHAIN.window` ô đứng ở đầu chuỗi, gói vừa nhận tích tại chỗ, chỉ trượt
## sau popup khi bước kế nằm ngoài cửa sổ; làm hết bước chuỗi vẫn sống. [EDGE] Hết hạn lúc layer đang mở: layer tự đóng,
## nút ở Home ẩn, cooldown `days_to_reset` ngày tính từ lúc hết hạn. [NEG] Thắng trong cooldown: không bật chuỗi.
## [HP] Thắng sau cooldown: bật chuỗi kế (xoay vòng), layer tự mở lại khi về Home.
static func scen_co(r) -> bool:
	if not await r.open_game("CO", func(g: Node) -> void: _co_save(g)):
		return false
	var lu := int(Config.CHAIN.level_unlock)
	var seqs: Array = Config.CHAIN.sequences
	if not await _ensure_playing(r, lu - 2):
		return false
	if not await _win_recorded(r, lu - 2):
		return false
	if bool(r.game.s.chain.get("active", false)) or not (r.game.chain_view() as Dictionary).is_empty():
		return r.fail("[NEG] thắng L%d (level đang tới %d < %d) mà đã bật Chain Offer" % [lu - 2, int(r.game.s.level), lu])
	r.step("[NEG] thắng L%d: level đang tới %d < %d, chưa bật Chain Offer" % [lu - 2, int(r.game.s.level), lu])
	if not await Scen.after_win(r, lu - 2):
		return false
	if not await _ensure_playing(r, lu - 1):
		return false
	if not await _co_win_starts(r, lu - 1, str(seqs[0].id)):
		return false
	if not await Scen.after_win(r, lu - 1):
		return false
	var co := await _co_autoshow(r, "chain_open")
	if co == null:
		return false
	if not await _co_locked_tap(r, co, 1):
		return false
	var id := str(r.game.s.chain.id)
	var steps: Array = _co_steps(id)
	var refused := {}
	for i in steps.size():
		var st: Dictionary = steps[i]
		var type := str(st.get("type", "free"))
		if not await _co_ready(r, co, i, steps.size()):
			return false
		if type in ["ad", "pay"] and not refused.has(type):
			refused[type] = true
			if not await _co_refuse(r, co, i, type):
				return false
		if not await _co_claim(r, co, i, st, steps.size()):
			return false
	if not await Scen.wait_for(r, func() -> bool: return Scen.find_visible(co, "DoneLabel") != null, 6000, "*"):
		return r.fail("nhận hết %d bước mà layer không báo xong" % steps.size())
	var c: Dictionary = r.game.s.chain
	if not bool(c.active) or int(c.step) != steps.size():
		return r.fail("[EDGE] nhận hết bước mà chuỗi %s (bước %d)" % ["còn" if bool(c.active) else "tắt", int(c.step)])
	r.step("[EDGE] nhận hết %d bước: chuỗi vẫn sống tới hết hạn" % steps.size())
	await r.shot("chain_done")
	if not await _co_expire(r):
		return false
	# Trong cooldown: thắng không bật chuỗi.
	var cool := int(r.game.s.chain.cooldown_until)
	var expired_at := int(r.game.s.chain.get("expires", 0))
	@warning_ignore("integer_division")
	r.game.test_now = expired_at + (cool - expired_at) / 2
	if not await _ensure_playing(r, lu):
		return false
	if not await _win_recorded(r, lu):
		return false
	if bool(r.game.s.chain.get("active", false)):
		return r.fail("[NEG] thắng L%d trong cooldown (còn %d giây) mà bật Chain Offer" % [lu, cool - int(r.game.now())])
	r.step("[NEG] thắng L%d trong cooldown: không bật chuỗi" % lu)
	if not await Scen.after_win(r, lu):
		return false
	# Hết cooldown: chuỗi kế theo vòng.
	r.game.test_now = cool + 60
	if not await _ensure_playing(r, lu + 1):
		return false
	if not await _co_win_starts(r, lu + 1, str(seqs[1 % seqs.size()].id)):
		return false
	if not await Scen.after_win(r, lu + 1):
		return false
	co = await _co_autoshow(r, "chain_next")
	if co == null:
		return false
	if not await _close_popup(r, co, "Chain Offer"):
		return false
	return await Scen.verify_saved(r)


## Save của CO: người chơi lâu ở L(level_unlock − 2), đã xem giới thiệu cơ chế trước đó, đã xem hướng dẫn và lời mời
## của Màn đặc biệt và Road Trip (mở trước L128) để Home chỉ tự mở Chain Offer.
static func _co_save(g: Node) -> void:
	Saves.veteran(g)
	Saves._at_level(g, int(Config.CHAIN.level_unlock) - 2, false)
	g.s.special["guide"] = true
	g.s.special["invited"] = true
	g.s.road_trip["guide"] = true


static func _co_steps(id: String) -> Array:
	for q in Config.CHAIN.sequences:
		if str(q.get("id", "")) == id:
			return q.get("steps", [])
	return []


## Thắng level `lvl` đang chơi; level đang tới >= level_unlock và hết cooldown nên bật chuỗi `want_id` ở bước 0, hạn
## `days_to_existence` ngày từ giờ thắng.
static func _co_win_starts(r, lvl: int, want_id: String) -> bool:
	var t0: int = r.game.now()
	if not await _win_recorded(r, lvl):
		return false
	if not await Scen.wait_for(r, func() -> bool: return bool(r.game.s.chain.get("active", false)), 6000, "*"):
		return r.fail("[HP] thắng L%d (level đang tới %d >= %d) mà không bật Chain Offer" % [lvl, int(r.game.s.level),
			int(Config.CHAIN.level_unlock)])
	var c: Dictionary = r.game.s.chain
	var want_exp := t0 + int(Config.CHAIN.days_to_existence) * DAY
	if str(c.id) != want_id or int(c.step) != 0 or int(c.expires) != want_exp or bool(c.shown):
		return r.fail("bật chuỗi %s bước %d hạn %d (đã mở %s), mong đợi %s bước 0 hạn %d" % [str(c.id), int(c.step),
			int(c.expires), bool(c.shown), want_id, want_exp])
	r.step("[HP] thắng L%d: bật Chain Offer %s, hạn %d giờ" % [lvl, want_id,
		int(Config.CHAIN.days_to_existence) * 24])
	return true


## Về Home sau khi chuỗi bật: layer tự mở đúng một lần (`s.chain.shown`).
static func _co_autoshow(r, shot_name: String) -> Node:
	if not await _to_home(r, "chain_offer.gd"):
		return null
	var co := await _wait_popup(r, "chain_offer.gd", 10000, "chain_offer.gd")
	if co == null:
		r.fail("[HP] về Home sau khi bật chuỗi mà layer Chain Offer không tự mở")
		return null
	if not bool(r.game.s.chain.get("shown", false)):
		r.fail("layer Chain Offer tự mở mà chưa ghi đã mở")
		return null
	r.step("[HP] về Home: layer Chain Offer tự mở")
	await r.wait_sec(0.8)
	await r.shot(shot_name)
	return co


## [NEG] Chạm gói đang khoá (bước `i`, sau bước hiện tại): dòng "nhận gói phía trước", không nhận gì.
static func _co_locked_tap(r, co: Node, i: int) -> bool:
	var slot: Node = co.find_child("Node%d" % i, true, false)
	var lock: Control = null
	if slot != null:
		for name in ["Button_Free_Lock", "Button_Purchase_Lock"]:
			lock = Scen.find_visible(slot, name) as Control
			if lock != null:
				break
	if lock == null:
		return r.fail("Chain Offer: gói bước %d không có nút khoá" % i)
	var before := _bal(r)
	var step := int(r.game.s.chain.step)
	await r.tap(lock, "Chain Offer: gói bước %d đang khoá" % i)
	var want := TranslationServer.translate("chain_unlock_first")
	if not await Scen.wait_for(r, func() -> bool:
			var t := Scen.find_visible(co, "ToastLabel") as Label
			return t != null and t.text == want, 3000, "*"):
		return r.fail("[NEG] chạm gói khoá mà không hiện dòng \"%s\"" % want)
	if _bal(r) != before or int(r.game.s.chain.step) != step or r.popup_script("popup_reward.gd") != null:
		return r.fail("[NEG] chạm gói khoá mà nhận được thưởng hoặc sang bước")
	r.step("[NEG] chạm gói khoá: chỉ nhắc nhận gói phía trước")
	await r.shot("chain_locked_tap")
	return true


## Đợi gói bước `i` mở để nhận: layer không bận, nút nhận nằm ở ô bước `i`, cửa sổ đứng ở đầu chuỗi và chỉ trượt khi
## bước hiện tại phải sang ô cuối (first = clamp(i − (window − 1), 0, count − window)).
static func _co_ready(r, co: Node, i: int, count: int) -> bool:
	var ok: bool = await Scen.wait_for(r, func() -> bool:
		return is_instance_valid(co) and not bool(co.get("_busy")) and is_instance_valid(co.get("claim_button")), 8000, "*")
	if not ok:
		return r.fail("Chain Offer: gói bước %d không mở để nhận" % i)
	var slot: Node = co.find_child("Node%d" % i, true, false)
	var b: Node = co.get("claim_button")
	if slot == null or not slot.is_ancestor_of(b):
		return r.fail("Chain Offer: nút nhận không nằm ở ô bước %d" % i)
	var size := mini(int(Config.CHAIN.window), count)
	var want_first := clampi(i - (size - 1), 0, maxi(0, count - size))
	if int(co.get("_first")) != want_first:
		return r.fail("[EDGE] bước %d: cửa sổ bắt đầu ở bước %d, mong đợi %d" % [i, int(co.get("_first")), want_first])
	return true


## Thưởng của một bước: free / ad lấy từ bước, pay lấy từ gói Config.SKUS của bước ({coins, items}).
static func _co_step_reward(st: Dictionary) -> Dictionary:
	if str(st.get("type", "")) == "pay":
		var info: Dictionary = Config.SKUS.get(str(st.get("sku", "")), {})
		return {"coins": int(info.get("gold", 0)), "items": info.get("inv", {})}
	return {"coins": int(st.get("coins", 0)), "items": st.get("items", {})}


## [NEG] Bước ad: đóng video sớm (ads giả "closed"); bước pay: huỷ trên store giả. Không nhận gì, bước giữ nguyên, không
## có popup Reward, gói vẫn nhận được.
static func _co_refuse(r, co: Node, i: int, type: String) -> bool:
	var before := _bal(r)
	var calls: Array = r.plat.ads.calls if type == "ad" else r.plat.iap.calls
	var n := calls.size()
	var how := "đóng video sớm" if type == "ad" else "huỷ mua"
	if type == "ad":
		r.plat.ads.simulate("closed")
	else:
		r.plat.iap.simulate("cancel")
	if not await r.tap(co.get("claim_button"), "Chain Offer bước %d (%s, %s)" % [i, type, how]):
		return r.fail("nút nhận bước %d bị che" % i)
	if not await Scen.wait_for(r, func() -> bool: return calls.size() > n, 8000, "*"):
		return r.fail("bước %d (%s) không gọi %s" % [i, type, "quảng cáo" if type == "ad" else "store"])
	if not await Scen.wait_for(r, func() -> bool:
			return not bool(co.get("_busy")) and is_instance_valid(co.get("claim_button")), 6000, "*"):
		return r.fail("[NEG] bước %d %s mà gói không mở lại" % [i, how])
	if _bal(r) != before or int(r.game.s.chain.step) != i or r.popup_script("popup_reward.gd") != null:
		return r.fail("[NEG] bước %d %s mà vẫn nhận thưởng hoặc sang bước (%s → %s)" % [i, how, JSON.stringify(before),
			JSON.stringify(_bal(r))])
	r.step("[NEG] Chain Offer bước %d (%s) %s: không nhận, bước giữ nguyên" % [i, type, how])
	return true


## Nhận bước `i`: số dư cộng đúng thưởng của bước (bước pay: đúng một lần gói), popup Reward hiện; gói vừa nhận tích
## tại ô đã chạm, cửa sổ chưa trượt; Claim đóng popup.
static func _co_claim(r, co: Node, i: int, st: Dictionary, count: int) -> bool:
	var type := str(st.get("type", "free"))
	var reward := _co_step_reward(st)
	var before := _bal(r)
	var first := int(co.get("_first"))
	if not await r.tap(co.get("claim_button"), "Chain Offer: nhận bước %d (%s)" % [i, type]):
		return r.fail("nút nhận bước %d bị che" % i)
	if not await Scen.wait_for(r, func() -> bool: return int(r.game.s.chain.step) == i + 1, 10000, "*"):
		return r.fail("chạm nhận bước %d (%s) mà chưa sang bước" % [i, type])
	var problem := _gain_problem(before, _bal(r), reward, int(r.game.now()))
	if problem != "":
		return r.fail("Chain Offer bước %d (%s): %s" % [i, type, problem])
	var pop := await _wait_popup(r, "popup_reward.gd", 6000, "*")
	if pop == null:
		return r.fail("nhận bước %d mà không có popup Reward" % i)
	var states: Array = co.get("node_states")
	if int(co.get("_first")) != first or i - first >= states.size() or str(states[i - first]) != "claimed":
		return r.fail("[EDGE] nhận bước %d: cửa sổ %d → %d, ô đã chạm %s" % [i, first, int(co.get("_first")),
			str(states[i - first]) if i - first < states.size() else "(ngoài cửa sổ)"])
	if i + 1 < count and i + 1 - first < states.size() and str(states[i + 1 - first]) != "locked":
		return r.fail("[EDGE] popup Reward bước %d còn mở mà gói kế đã mở" % i)
	r.step("[HP] Chain Offer bước %d (%s): %s" % [i, type, JSON.stringify(reward)])
	await r.wait_sec(0.5)
	if i == 0 or type == "pay":
		await r.shot("chain_reward_%d" % i)
	if not await Scen.tap_named(r, "ClaimBtn", pop):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_reward.gd") == null, 4000, "*"):
		return r.fail("Claim không đóng popup Reward")
	return true


## [EDGE] Hết hạn khi layer đang mở (giờ nhảy qua `expires`): layer tự đóng, nút Chain Offer ở Home ẩn, cooldown tính
## từ lúc hết hạn.
static func _co_expire(r) -> bool:
	var expires := int(r.game.s.chain.expires)
	r.game.test_now = expires + 1
	r.step("giờ nhảy qua hạn chuỗi (%d)" % expires)
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("chain_offer.gd") == null, 5000, "*"):
		return r.fail("[EDGE] chuỗi hết hạn mà layer Chain Offer không tự đóng")
	var c: Dictionary = r.game.s.chain
	var want := expires + int(Config.CHAIN.days_to_reset) * DAY
	if bool(c.active) or int(c.cooldown_until) != want:
		return r.fail("[EDGE] hết hạn: chuỗi %s, cooldown tới %d, mong đợi %d (hạn + %d ngày)" % [
			"còn" if bool(c.active) else "tắt", int(c.cooldown_until), want, int(Config.CHAIN.days_to_reset)])
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "ChainOfferButton") == null, 4000):
		return r.fail("[EDGE] chuỗi hết hạn mà Home còn nút Chain Offer")
	r.step("[EDGE] hết hạn: layer tự đóng, nút ở Home ẩn, cooldown %d ngày từ lúc hết hạn" %
		int(Config.CHAIN.days_to_reset))
	await r.shot("chain_expired")
	return true


# ================================================================ Special Pack

## SP. Special Pack (design.md mục 7 "Special Pack", Config.PACKS.special_pack): save ở L(level_appear − 1) = L15, offer
## Starter đang mở, chưa mua gì. [NEG] Home không có Special Pack (chưa mua gói `required`). Mua Starter qua icon offer ở
## Home (store giả, số dư theo Config.SKUS). [NEG] Vẫn không có: level đang tới dưới `level_appear`. Thắng L15 → Home:
## [HP] icon Special Pack hiện → popup offer chung; [EDGE] đang weekend sale nên bán SKU `<sku>_sale` với giá của nó.
## [NEG] Huỷ trên store: không nhận, popup còn mở. Mua: gold và booster đúng Config.SKUS, popup đóng; [EDGE] icon ẩn
## (`purchase_limit`). [EDGE] Hết sale: vẫn ẩn, bản thường cũng không bán (`buy_sku` trả `owned`, không gọi store).
static func scen_sp(r) -> bool:
	var cond: Dictionary = Config.PACKS.special_pack
	var appear := int(cond.level_appear)
	var base_sku := str(cond.sku)
	if not await r.open_game("SP", func(g: Node) -> void: _sp_save(g, appear - 1)):
		return false
	if not await _ensure_playing(r, appear - 1):
		return false
	if not await _to_home(r, ""):
		return false
	await Scen.settle_all(r)
	if Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null or str(r.game.special_pack_id()) != "":
		return r.fail("[NEG] chưa mua %s mà Home có Special Pack" % str(cond.required))
	r.step("[NEG] chưa mua %s: Home không có Special Pack" % str(cond.required))
	await r.shot("home_no_special")
	var chip := Scen.find_visible(r.main.current_screen, "OfferChip") as Control
	if chip == null:
		return r.fail("Home không có icon offer Starter đang mở")
	var pop := await _tap_open(r, chip, "icon offer Starter", "popup_offer.gd")
	if pop == null:
		return false
	if str(pop.get("offer_id")) != "starter_pack":
		return r.fail("icon offer mở popup %s, mong đợi starter_pack" % str(pop.get("offer_id")))
	await r.wait_sec(0.6)
	await r.shot("starter_offer")
	if not await _offer_buy(r, pop, str(pop.get("sku"))):
		return false
	await Scen.settle_all(r)
	await r.wait_sec(1.2)
	if Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null or str(r.game.special_pack_id()) != "":
		return r.fail("[NEG] level đang tới %d < %d mà Home có Special Pack" % [int(r.game.s.level), appear])
	r.step("[NEG] đã mua Starter, level đang tới %d < %d: chưa có Special Pack" % [int(r.game.s.level), appear])
	if not await _ensure_playing(r, appear - 1):
		return false
	if not await Scen.win_level(r):
		return false
	if not await Scen.after_win(r, appear - 1):
		return false
	if not await _to_home(r, ""):
		return false
	await Scen.settle_all(r)
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null, 4000):
		return r.fail("[HP] L%d, đã mua Starter mà Home không có Special Pack" % appear)
	r.step("[HP] L%d, đã mua Starter: Home có Special Pack" % appear)
	await r.shot("home_special")
	pop = await _tap_open(r, Scen.find_visible(r.main.current_screen, "SpecialPackButton") as Control, "Special Pack",
		"popup_offer.gd")
	if pop == null:
		return false
	if str(pop.get("offer_id")) != "special_pack":
		return r.fail("icon Special Pack mở popup %s" % str(pop.get("offer_id")))
	var sale: bool = r.game.is_sale_active()
	var sale_sku := base_sku + "_sale"
	var want_sku := sale_sku if sale and Config.SKUS.has(sale_sku) else base_sku
	var sku := str(pop.get("sku"))
	if sku != want_sku:
		return r.fail("[EDGE] weekend sale %s mà popup bán %s, mong đợi %s" % [sale, sku, want_sku])
	var out := (pop.get("buy_button") as Node).find_child("Out", true, false) as Label
	if out == null or out.text != str(r.plat.price(sku)):
		return r.fail("nút mua Special Pack ghi \"%s\", mong đợi %s" % [out.text if out != null else "",
			str(r.plat.price(sku))])
	r.step("[EDGE] weekend sale %s: popup bán %s giá %s" % [sale, sku, out.text])
	await r.wait_sec(0.6)
	await r.shot("special_offer")
	if not await _offer_cancel(r, pop):
		return false
	if not await _offer_buy(r, pop, sku):
		return false
	await Scen.settle_all(r)
	if not await Scen.wait_for(r, func() -> bool:
			return Scen.find_visible(r.main.current_screen, "SpecialPackButton") == null, 4000):
		return r.fail("[EDGE] mua %s (giới hạn %d) mà Home còn Special Pack" % [sku, int(cond.purchase_limit)])
	r.step("[EDGE] đã mua %s: Special Pack ẩn (giới hạn %d lần)" % [sku, int(cond.purchase_limit)])
	await r.shot("home_after_special")
	# Hết weekend sale: bản thường cũng tính là đã mua.
	var t: int = r.game.now()
	for k in 7:
		if not r.game.is_sale_active():
			break
		t += DAY
		r.game.test_now = t
	if r.game.is_sale_active():
		return r.fail("không tìm được ngày hết weekend sale")
	await r.wait_sec(1.5)
	if Scen.find_visible(r.main.current_screen, "SpecialPackButton") != null or str(r.game.special_pack_id()) != "":
		return r.fail("[EDGE] hết sale mà Special Pack hiện lại")
	if str(r.game.offer_sku("special_pack")) != base_sku or not r.game.owns_once(base_sku):
		return r.fail("[EDGE] hết sale: offer bán %s, đã sở hữu %s" % [str(r.game.offer_sku("special_pack")),
			r.game.owns_once(base_sku)])
	var n: int = r.plat.iap.calls.size()
	var before := Scen._balance(r)
	var res: Dictionary = await r.game.buy_sku(base_sku)
	if str(res.get("status", "")) != "owned" or r.plat.iap.calls.size() != n or Scen._balance(r) != before:
		return r.fail("[EDGE] mua %s sau khi đã mua %s: %s, gọi store %d lần" % [base_sku, sku,
			str(res.get("status", "")), r.plat.iap.calls.size() - n])
	r.step("[EDGE] hết sale: %s vẫn ẩn, mua bản thường trả owned, không gọi store" % base_sku)
	return await Scen.verify_saved(r)


## Save của SP: người chơi lâu ở L`level`, offer Starter vừa hiện và còn hạn `OFFERS.starter_pack.hours` giờ (icon
## offer ở Home), chưa mua gói nào.
static func _sp_save(g: Node, level: int) -> void:
	Saves.veteran(g)
	Saves._at_level(g, level, false)
	var now: int = g.now()
	var hours := int(Config.OFFERS.starter_pack.hours)
	g.s.offers["last_run"] = int(g.s.runs)
	g.s.offers["items"]["starter_pack"] = {"shown": 1, "at": now, "until": now + hours * 3600}


## [NEG] Huỷ trên store giả ở popup offer: không nhận gì, không ghi đơn, popup còn mở và bấm mua lại được.
static func _offer_cancel(r, pop: Node) -> bool:
	var before := Scen._balance(r)
	var n: int = r.plat.iap.calls.size()
	r.plat.iap.simulate("cancel")
	if not await r.tap(pop.get("buy_button"), "mua %s (huỷ trên store)" % str(pop.get("sku"))):
		return r.fail("nút mua %s bị che" % str(pop.get("sku")))
	if not await Scen.wait_for(r, func() -> bool: return r.plat.iap.calls.size() > n, 8000, "popup_offer.gd"):
		return r.fail("bấm mua %s không gọi store" % str(pop.get("sku")))
	if not await Scen.wait_for(r, func() -> bool: return is_instance_valid(pop) and not bool(pop.get("_busy")), 4000,
			"popup_offer.gd"):
		return r.fail("[NEG] huỷ mua mà popup offer không thôi chờ")
	if Scen._balance(r) != before or r.popup_script("popup_offer.gd") != pop:
		return r.fail("[NEG] huỷ mua %s mà số dư đổi hoặc popup đóng" % str(pop.get("sku")))
	r.step("[NEG] huỷ mua %s trên store: không nhận gì, popup còn mở" % str(pop.get("sku")))
	return true


## Mua `sku` ở popup offer qua store giả: một đơn đúng SKU, số dư đúng Config.SKUS, popup đóng.
static func _offer_buy(r, pop: Node, sku: String) -> bool:
	var before := Scen._balance(r)
	var n := (r.game.s.buys as Array).size()
	if not await r.tap(pop.get("buy_button"), "mua %s" % sku):
		return r.fail("nút mua %s bị che" % sku)
	if not await Scen.wait_for(r, func() -> bool: return (r.game.s.buys as Array).size() > n, 10000, "popup_offer.gd"):
		return r.fail("mua %s mà không có đơn" % sku)
	var last: Dictionary = (r.game.s.buys as Array).back()
	if str(last.get("sku", "")) != sku:
		return r.fail("mua %s mà đơn ghi %s" % [sku, str(last.get("sku", ""))])
	var problem := Scen._check_purchase(before, Scen._balance(r), Config.SKUS.get(sku, {}))
	if problem != "":
		return r.fail("mua %s: %s" % [sku, problem])
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_offer.gd") == null, 6000, "*"):
		return r.fail("mua %s xong mà popup offer không đóng" % sku)
	r.step("[HP] mua %s: gold %d → %d" % [sku, int(before.coins), int(r.game.s.coins)])
	return true


# ================================================================ dùng chung

## Level `lvl` đang chơi; đang ở Home thì bấm Chơi.
static func _ensure_playing(r, lvl: int) -> bool:
	if r.screen_name() == "home":
		await Scen.settle_all(r)
		if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
			return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == lvl, 20000):
		return r.fail("không vào được L%d (đang %s, level %d)" % [lvl, r.screen_name(), Scen._playing(r)])
	return true


## Như Scen.go_home_from_level nhưng giữ popup `keep` (popup tự mở khi về Home: Upsell, Chain Offer) thay vì đóng nó
## như popup lạc.
static func _to_home(r, keep: String) -> bool:
	if r.screen_name() == "home":
		return true
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > 0, 20000, keep):
		return r.fail("không ở màn level để về Home")
	var lv: Control = r.level_screen()
	await r.tap(lv.settings_button, "Cài đặt trong màn")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong màn không mở")
	await r.wait_sec(0.4)
	if not await Scen.tap_named(r, "HomeButton", r.popup_script("popup_ingame_settings.gd")):
		return false
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if r.screen_name() == "home" and r.main.curtain == null:
			return true
		var confirm := Scen.find_visible(r.main, "ConfirmButton") as Control
		if confirm != null:
			await r.wait_sec(0.3)
			await r.tap(confirm, "xác nhận rời màn")
		else:
			await Scen.settle(r, keep)
		await r.wait_frames(2)
	return r.fail("Cài đặt → Home không về Home")


## Thắng level `lvl` đang chơi và đợi Game ghi lần thắng (level đang tới sang `lvl` + 1, Game.on_level_won chạy sau
## hiệu ứng bàn trống, trước thẻ thắng).
static func _win_recorded(r, lvl: int) -> bool:
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return int(r.game.s.level) > lvl, 15000, "ContinueButton"):
		return r.fail("thắng L%d mà Game chưa ghi lần thắng (level đang tới %d)" % [lvl, int(r.game.s.level)])
	return true


static func _wait_popup(r, file: String, ms: int, keep: String) -> Node:
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script(file) != null, ms, keep):
		return null
	return r.popup_script(file)


## Bấm `btn` rồi đợi popup có script `file` (giữ nó, đóng popup lạc khác).
static func _tap_open(r, btn: Control, label: String, file: String) -> Node:
	if btn == null:
		r.fail("không có nút %s" % label)
		return null
	if not await r.tap(btn, label):
		r.fail("nút %s bị che" % label)
		return null
	var pop := await _wait_popup(r, file, 8000, file)
	if pop == null:
		r.fail("bấm %s không mở %s" % [label, file])
	return pop


static func _open_from_home(r, name: String, file: String) -> Node:
	var btn := Scen.find_visible(r.main.current_screen, name) as Control
	return await _tap_open(r, btn, name, file)


## Đóng popup bằng nút đóng của nó (X), đợi nó đi.
static func _close_popup(r, pop: Node, label: String) -> bool:
	var close := Scen.find_close(pop)
	if close == null:
		return r.fail("%s không có nút đóng" % label)
	await r.tap(close, "đóng %s" % label)
	if not await Scen.wait_for(r, func() -> bool: return r.popups().find(pop) < 0, 4000, "*"):
		return r.fail("không đóng được %s" % label)
	await Scen.settle_all(r)
	return true


## Số dư người chơi thấy: gold, từng booster, hạn mạng vô hạn, số mạng, mạng tối đa tạm của VIP, số đơn đã mua.
static func _bal(r) -> Dictionary:
	var s: Dictionary = r.game.s
	var lives: Dictionary = s.lives
	return {"coins": int(s.coins), "inv": (s.inv as Dictionary).duplicate(), "inf_until": int(lives.get("inf_until", 0)),
		"lives": int(lives.get("count", 0)), "bonus": int(lives.get("bonus", 0)), "buys": (s.buys as Array).size()}


## "" khi từ `before` tới `after` gold, booster, hạn mạng vô hạn cộng đúng `reward` ({coins, items, inf_min}; mạng vô hạn
## cộng dồn từ max(hạn cũ, `now`)); không thì mô tả chỗ lệch.
static func _gain_problem(before: Dictionary, after: Dictionary, reward: Dictionary, now: int) -> String:
	var coins := int(after.coins) - int(before.coins)
	if coins != int(reward.get("coins", 0)):
		return "gold +%d, mong đợi +%d" % [coins, int(reward.get("coins", 0))]
	var items: Dictionary = reward.get("items", {})
	for k in BOOSTERS:
		var got := int((after.inv as Dictionary).get(k, 0)) - int((before.inv as Dictionary).get(k, 0))
		if got != int(items.get(k, 0)):
			return "%s +%d, mong đợi +%d" % [k, got, int(items.get(k, 0))]
	var inf_min := int(reward.get("inf_min", 0))
	var want_inf := int(before.inf_until)
	if inf_min > 0:
		want_inf = maxi(int(before.inf_until), now) + inf_min * 60
	if int(after.inf_until) != want_inf:
		return "hạn mạng vô hạn %d, mong đợi %d (+%d phút)" % [int(after.inf_until), want_inf, inf_min]
	return ""


static func _add_reward(a: Dictionary, b: Dictionary) -> Dictionary:
	var items: Dictionary = (a.get("items", {}) as Dictionary).duplicate()
	var bi: Dictionary = b.get("items", {})
	for k in bi:
		items[k] = int(items.get(k, 0)) + int(bi[k])
	return {"coins": int(a.get("coins", 0)) + int(b.get("coins", 0)), "items": items,
		"inf_min": int(a.get("inf_min", 0)) + int(b.get("inf_min", 0))}


## Mảng số đọc từ save (JSON trả float) có `i`.
static func _has_int(arr: Variant, i: int) -> bool:
	if not (arr is Array):
		return false
	for v in arr:
		if int(v) == i:
			return true
	return false
