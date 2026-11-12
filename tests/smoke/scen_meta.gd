extends RefCounted
## Kịch bản smoke cho quà 28 ngày, Profile (avatar, frame, biệt danh) (design.md mục 5) và tính năng đang tắt.
## Gọi qua scenarios.gd SCEN_FILES. Mỗi hàm nhận runner `r` (tests/smoke/smoke.gd) như kịch bản trong scenarios.gd.
## Hành vi trái design.md ghi bằng _bug (dòng "SMOKE WARN LỖI GAME"): kịch bản đi tiếp phần còn lại rồi mới fail ở cuối,
## để một lỗi không che các kiểm tra sau nó.

const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Config := preload("res://src/config.gd")
const Clock := preload("res://src/meta/clock.gd")
const DailyCalendar := preload("res://src/meta/daily_calendar.gd")
const Cosmetics := preload("res://src/meta/cosmetics.gd")
const Nickname := preload("res://src/meta/nickname.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const WinStreak := preload("res://src/meta/win_streak.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

const BOOSTERS := ["hint", "move", "smash"]
## Ảnh lớn đầu màn Profile (ProfileLayer): avatar và frame đang xem trước.
const PREVIEW := {"avatar": "Panel/ProfileMenu/PlayerInfo/CurrentAvt", "frame": "Panel/ProfileMenu/PlayerInfo/CurrentFrame"}
## Múi giờ thử ranh giới ngày (giờ Việt Nam): ngày địa phương sang trước ngày UTC 7 giờ.
const TZ_EAST := 7 * 3600
const LETTERS := "abcdefghijklmnopqrstuvwxyz"
## Tính năng đang tắt (design.md mục 4 "Phạm vi", mục 7 "Win Streak"; Config.FEATURES).
const OFF_FEATURES := ["challenge", "win_streak"]

## Lỗi game trái design.md của kịch bản đang chạy (mỗi kịch bản một tiến trình).
static var _bugs: Array[String] = []


static func run(r, scen: String) -> bool:
	_bugs.clear()
	match scen:
		"DG":
			return await scen_dg(r)
		"PR":
			return await scen_pr(r)
		"OFF":
			return await scen_off(r)
	return r.fail("không có kịch bản %s" % scen)


# ================================================================ DG: quà 28 ngày

## DG. Quà 28 ngày (design.md mục 5 "Quà 28 ngày", mục 4 "Mở khoá theo level"):
## [NEG] Save L13 (trước mốc Config.UNLOCK.daily_gift): Home không có icon quà, nhận quà không được gì.
## [HP] Chơi và thắng L13: thẻ thắng báo mở quà, Tiếp tục về Home. Từ đó: popup không tự mở; icon có chấm đỏ; bấm
## icon → 7 ô tuần 1, Nhận ô 1 (gold, booster đúng Config.DAILY), video nhận trước ô 2 (đóng sớm không thưởng [NEG],
## xem hết thưởng đúng ô 2). [NEG] Cùng ngày: không nhận lại, không video lần hai, chấm đỏ tắt.
## [EDGE] Ranh giới ngày theo giờ máy: 23:59:59 chưa có quà; qua 00:00 lúc vẫn mở Home thì chấm đỏ phải hiện; quay lại
## app sau 00:00 nhận ô kế, video lại có. Múi giờ +7: ngày địa phương sang trước ngày UTC thì có quà dù UTC chưa sang
## ngày. Giờ máy lùi 2 ngày: không có quà. Ô 28 (quà lớn tuần 4) rồi hôm sau quay về ô 1 tuần 1.
static func scen_dg(r) -> bool:
	var unlock := int(Config.UNLOCK.daily_gift)
	if not await _dg_unlock(r, unlock - 1):
		return false
	await Scen.settle_all(r)
	await r.wait_sec(1.5)
	if r.popup_script("popup_daily.gd") != null:
		_bug(r, "popup quà tự mở khi về Home (design: chỉ mở khi người chơi bấm icon)")
		await Scen.close_to(r, 0)
	if Scen.find_visible(r.main.current_screen, "GiftButton") == null:
		return r.fail("L%d (mốc mở quà) mà Home không có icon quà" % unlock)
	if not _gift_dot(r):
		_bug(r, "còn quà chưa nhận mà icon quà không có chấm đỏ")
	await r.shot("home_gift")

	# Ngày 1: nhận ô hiện tại, rồi video nhận trước ô kế.
	var pop := await _open_daily(r)
	if pop == null:
		return false
	if (pop.cell_nodes as Array).size() != DailyCalendar.WEEK:
		return r.fail("popup quà có %d ô, design là 7 ô của tuần đang đi" % (pop.cell_nodes as Array).size())
	_expect_week(r, pop, 1)
	if _cell_state(pop, 1) != "current":
		_bug(r, "ngày đầu mà ô 1 ở trạng thái %s, không phải hôm nay" % _cell_state(pop, 1))
	await r.shot("daily_week1")
	if not await _claim(r, pop, "ngày 1"):
		return false
	if (pop.claim_button as Control).is_visible_in_tree():
		_bug(r, "đã nhận quà hôm nay mà nút Nhận còn hiện")
	if str((pop.status_label as Label).text) != r.tr("daily_reward_received"):
		_bug(r, "nhận quà xong mà dòng trạng thái ghi \"%s\"" % (pop.status_label as Label).text)
	if _cell_state(pop, 1) != "claimed" or _cell_state(pop, 2) != "next":
		_bug(r, "sau khi nhận: ô 1 %s, ô 2 %s (mong đợi claimed, next)" % [_cell_state(pop, 1), _cell_state(pop, 2)])
	# [NEG] Nhận lần hai cùng ngày: hàm nút Nhận gọi (Game.daily_claim) không trả gì, số dư giữ nguyên.
	var before := _bal(r)
	var again: Dictionary = r.game.daily_claim()
	if not again.is_empty() or _bal(r) != before:
		_bug(r, "nhận quà lần hai cùng ngày vẫn được %s" % JSON.stringify(again))
	else:
		r.step("nhận lần hai cùng ngày: không có gì, số dư giữ nguyên")
	var video := pop.video_button as Control
	if video == null or not video.is_visible_in_tree():
		return r.fail("đã nhận ô hôm nay mà không có nút video nhận trước ô kế")
	if not await Scen._ad_tap(r, video, "daily_next", "closed", "quà ngày: video nhận trước (đóng sớm)"):
		return false
	await Scen.wait_for(r, func() -> bool: return str((pop.status_label as Label).text) == r.tr("ads_closed_early"),
		4000, "*")
	if _bal(r) != before or int(r.game.s.daily.idx) != 1:
		_bug(r, "video nhận trước đóng sớm mà vẫn thưởng (ô kế %d)" % (int(r.game.s.daily.idx) + 1))
	if str((pop.status_label as Label).text) != r.tr("ads_closed_early"):
		_bug(r, "video đóng sớm mà không báo \"%s\"" % r.tr("ads_closed_early"))
	if not video.is_visible_in_tree():
		return r.fail("video đóng sớm mà nút video nhận trước biến mất")
	if not await _claim_video(r, pop, "ngày 1, nhận trước ô 2"):
		return false
	if (pop.claim_button as Control).is_visible_in_tree() or (pop.video_button as Control).is_visible_in_tree():
		_bug(r, "đã nhận và đã xem video hôm nay mà còn nút Nhận hoặc video")
	var info := pop.find_child("InfoLabel", true, false) as Label
	if info == null or not info.text.contains(r.tr("daily_video_used")):
		_bug(r, "đã xem video hôm nay mà không ghi \"%s\"" % r.tr("daily_video_used"))
	await r.shot("daily_claimed")
	if not await _close_daily(r, pop):
		return false
	if _gift_dot(r):
		_bug(r, "đã nhận hết quà hôm nay mà icon quà còn chấm đỏ")
	# [NEG] Mở lại cùng ngày: không còn gì để nhận.
	pop = await _open_daily(r)
	if pop == null:
		return false
	if (pop.claim_button as Control).is_visible_in_tree() or (pop.video_button as Control).is_visible_in_tree():
		_bug(r, "mở lại popup cùng ngày mà còn nút Nhận hoặc video")
	if not await _close_daily(r, pop):
		return false

	# Ngày 2 (giờ máy, múi giờ 0): 23:59:59 chưa có quà; qua 00:00.
	var t0: int = r.game.now()
	var midnight := t0 + Clock.seconds_to_next_day(t0, 0)
	await _resume_at(r, midnight - 1, 0)
	if _gift_dot(r) or bool(r.game.daily_view().can_claim):
		_bug(r, "23:59:59 cùng ngày đã nhận mà có quà mới")
	# [EDGE] Qua 00:00 lúc vẫn mở Home (không rời app, màn hình bật): Home tự cập nhật mỗi giây.
	r.game.test_now = midnight
	r.step("đồng hồ qua 00:00 (%s) lúc vẫn ở Home" % _clock_text(midnight, 0))
	await r.wait_sec(2.0)
	if not _gift_dot(r):
		_bug(r, "đang ở Home lúc qua 00:00: đã có quà mới mà icon quà không có chấm đỏ tới khi Home làm mới (rời app " +
			"rồi quay lại, đóng một popup)")
	await _resume_at(r, midnight, 0)
	if not _gift_dot(r):
		_bug(r, "quay lại app sau 00:00 mà icon quà không có chấm đỏ")
	pop = await _open_daily(r)
	if pop == null:
		return false
	if _cell_state(pop, 3) != "current":
		_bug(r, "ngày 2 (đã nhận trước ô 2) mà ô 3 ở trạng thái %s" % _cell_state(pop, 3))
	if not await _claim(r, pop, "ngày 2"):
		return false
	if not (pop.video_button as Control).is_visible_in_tree():
		_bug(r, "ngày mới đã nhận ô hôm nay mà không có lại video nhận trước (1 video mỗi ngày)")
	await r.shot("daily_day2")
	if not await _close_daily(r, pop):
		return false

	# [EDGE] Múi giờ +7: cùng thời điểm vẫn là ngày 2 địa phương; ngày địa phương 3 tới lúc 17:00 UTC.
	var t_utc: int = r.game.now()
	await _resume_at(r, t_utc, TZ_EAST)
	if _gift_dot(r) or bool(r.game.daily_view().can_claim):
		_bug(r, "đổi múi giờ trong cùng một ngày địa phương mà có quà mới")
	var local_mid := t_utc + Clock.seconds_to_next_day(t_utc, TZ_EAST)
	if Clock.day_number(local_mid, 0) != Clock.day_number(t_utc, 0):
		return r.fail("dựng sai mốc: 00:00 giờ +7 không nằm trong cùng ngày UTC")
	await _resume_at(r, local_mid - 1, TZ_EAST)
	if _gift_dot(r) or bool(r.game.daily_view().can_claim):
		_bug(r, "23:59:59 giờ +7 mà có quà mới")
	await _resume_at(r, local_mid, TZ_EAST)
	if not _gift_dot(r):
		_bug(r, "00:00 giờ +7 (UTC chưa sang ngày) mà icon quà không có chấm đỏ: quà phải tính theo giờ máy")
	pop = await _open_daily(r)
	if pop == null:
		return false
	if not await _claim(r, pop, "ngày 3 theo giờ +7"):
		return false
	if not await _close_daily(r, pop):
		return false

	# [EDGE] Giờ máy lùi 2 ngày: không có quà cho tới khi vượt qua ngày đã nhận.
	await _resume_at(r, local_mid - 2 * Clock.DAY_SEC, TZ_EAST)
	if _gift_dot(r) or bool(r.game.daily_view().can_claim):
		_bug(r, "giờ máy lùi 2 ngày mà có quà")
	pop = await _open_daily(r)
	if pop == null:
		return false
	if (pop.claim_button as Control).is_visible_in_tree():
		_bug(r, "giờ máy lùi mà popup quà có nút Nhận")
	await r.shot("daily_clock_back")
	if not await _close_daily(r, pop):
		return false

	# [EDGE] Ô 28 (quà lớn của tuần 4), hôm sau về ô 1 tuần 1.
	var last := Config.DAILY.size() - 1
	r.game.s.daily["idx"] = last
	r.step("dựng lịch tới ô %d (ô cuối)" % (last + 1))
	var day4 := local_mid + Clock.DAY_SEC
	await _resume_at(r, day4, TZ_EAST)
	pop = await _open_daily(r)
	if pop == null:
		return false
	@warning_ignore("integer_division")
	var last_week := last / DailyCalendar.WEEK + 1
	_expect_week(r, pop, last_week)
	if _cell_state(pop, last + 1) != "current":
		_bug(r, "ô %d ở trạng thái %s, không phải hôm nay" % [last + 1, _cell_state(pop, last + 1)])
	await r.shot("daily_day28")
	if not await _claim(r, pop, "ô %d" % (last + 1)):
		return false
	if int(r.game.s.daily.idx) != 0:
		_bug(r, "nhận ô cuối mà ô kế là %d, không về ô 1" % (int(r.game.s.daily.idx) + 1))
	if not await _close_daily(r, pop):
		return false
	await _resume_at(r, day4 + Clock.DAY_SEC, TZ_EAST)
	pop = await _open_daily(r)
	if pop == null:
		return false
	_expect_week(r, pop, 1)
	if _cell_state(pop, 1) != "current":
		_bug(r, "hết vòng 28 ô mà hôm sau ô 1 ở trạng thái %s" % _cell_state(pop, 1))
	if not await _claim(r, pop, "vòng 2, ô 1"):
		return false
	await r.shot("daily_round2")
	if not await _close_daily(r, pop):
		return false
	if not _disk_same(r, "daily"):
		return false
	return await _finish(r)


## [NEG] Trước mốc mở quà (`lvl` = mốc - 1): Home không có icon quà, Game.daily_view() đóng, nhận quà không được gì.
## [HP] Chơi và thắng level đó: thẻ thắng báo mở quà, Tiếp tục về Home (design.md mục 4 "Mở khoá theo level").
static func _dg_unlock(r, lvl: int) -> bool:
	var prep := func(g: Node) -> void:
		Saves.veteran(g)
		g.s.level = lvl
	if not await r.open_game("DG", prep):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	if Scen.find_visible(r.main.current_screen, "GiftButton") != null:
		_bug(r, "L%d (trước mốc L%d) mà Home đã hiện icon quà" % [lvl, lvl + 1])
	if bool(r.game.daily_view().open):
		_bug(r, "L%d mà lịch quà đã mở" % lvl)
	var before := _bal(r)
	var got: Dictionary = r.game.daily_claim()
	if not got.is_empty() or _bal(r) != before:
		_bug(r, "L%d (chưa mở quà) mà nhận được %s" % [lvl, JSON.stringify(got)])
	r.step("L%d: không có icon quà, nhận quà không được gì" % lvl)
	await r.shot("home_locked")
	if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == lvl, 20000):
		return r.fail("bấm Chơi không vào L%d" % lvl)
	if not await Scen.win_level(r):
		return false
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000, "ContinueButton"):
		return r.fail("thắng L%d mà không có thẻ thắng" % lvl)
	var card: Node = r.popup_script("win_card.gd")
	var opened: Array = (card.get("_args") as Dictionary).get("unlocked", []) if card != null else []
	if not opened.has("daily_gift"):
		_bug(r, "thắng L%d mà thẻ thắng không báo mở quà 28 ngày (vừa mở: %s)" % [lvl, str(opened)])
	await r.wait_sec(1.5)
	await r.shot("win_card_L%d" % lvl)
	if not await Scen.tap_named(r, "ContinueButton", card):
		return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > lvl or r.screen_name() == "home", 20000):
		return r.fail("sau thẻ thắng L%d không sang level kế hay Home" % lvl)
	if r.screen_name() != "home":
		_bug(r, "thắng L%d (mở quà ở Home) mà vào thẳng L%d, không về Home" % [lvl, lvl + 1])
		if not await Scen.go_home_from_level(r):
			return false
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "home" and r.main.curtain == null, 15000):
		return r.fail("không về được Home sau thẻ thắng L%d" % lvl)
	r.step("thắng L%d về Home, level %d" % [lvl, int(r.game.s.level)])
	return true


static func _gift_dot(r) -> bool:
	if r.screen_name() != "home":
		return false
	var dot := r.main.current_screen.get("gift_badge") as Control
	return dot != null and dot.is_visible_in_tree()


static func _open_daily(r) -> Node:
	if not await Scen.tap_named(r, "GiftButton", r.main.current_screen):
		return null
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_daily.gd") != null, 6000,
			"popup_daily.gd"):
		r.fail("bấm icon quà không mở popup quà")
		return null
	await r.wait_sec(0.5)
	return r.popup_script("popup_daily.gd")


static func _close_daily(r, pop: Node) -> bool:
	await r.tap(pop.close_button as Control, "quà ngày: đóng")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_daily.gd") == null, 6000, "*"):
		return r.fail("không đóng được popup quà")
	await r.wait_frames(3)
	return true


static func _cell_state(pop: Node, day: int) -> String:
	for c in pop.cell_nodes:
		if is_instance_valid(c) and str(c.name) == "Cell%d" % day:
			return str(c.get_meta("state", ""))
	return "(không có ô %d)" % day


static func _expect_week(r, pop: Node, week: int) -> void:
	var l := pop.find_child("WeekLabel", true, false) as Label
	var want: String = r.tr("daily_week") % week
	if l == null or l.text != want:
		_bug(r, "popup quà ghi \"%s\", mong đợi \"%s\"" % [l.text if l != null else "", want])


## Bấm Nhận: số dư đổi đúng ô Config.DAILY đang tới (s.daily.idx).
static func _claim(r, pop: Node, label: String) -> bool:
	var idx := int(r.game.s.daily.idx)
	var reward: Dictionary = Config.DAILY[idx]
	var before := _bal(r)
	var btn := pop.claim_button as Control
	if btn == null or not btn.is_visible_in_tree():
		_bug(r, "%s: popup quà không có nút Nhận" % label)
		return true
	if not await r.tap(btn, "quà ngày: Nhận (%s)" % label):
		return r.fail("%s: nút Nhận bị che" % label)
	if not await Scen.wait_for(r, func() -> bool: return _bal(r) != before, 6000, "popup_daily.gd"):
		return r.fail("%s: bấm Nhận mà số dư không đổi" % label)
	var bad := _diff(before, _bal(r), reward)
	if not bad.is_empty():
		_bug(r, "%s, ô %d: %s" % [label, idx + 1, bad])
	r.step("%s: nhận ô %d %s → %s" % [label, idx + 1, JSON.stringify(reward), JSON.stringify(_bal(r))])
	return true


## Xem hết video nhận trước ô kế: số dư đổi đúng ô đó.
static func _claim_video(r, pop: Node, label: String) -> bool:
	var idx := int(r.game.s.daily.idx)
	var reward: Dictionary = Config.DAILY[idx]
	var before := _bal(r)
	if not await Scen._ad_tap(r, pop.video_button as Control, "daily_next", "", "quà ngày: video (%s)" % label):
		return false
	if not await Scen.wait_for(r, func() -> bool: return _bal(r) != before, 10000, "*"):
		return r.fail("%s: xem hết video mà số dư không đổi" % label)
	var bad := _diff(before, _bal(r), reward)
	if not bad.is_empty():
		_bug(r, "%s, ô %d: %s" % [label, idx + 1, bad])
	r.step("%s: video nhận ô %d %s → %s" % [label, idx + 1, JSON.stringify(reward), JSON.stringify(_bal(r))])
	return true


## Như người chơi rời app rồi quay lại lúc `t` (giờ máy, múi giờ `tz` giây): Platform.paused, đổi đồng hồ giả,
## Platform.resumed (Game._on_resumed làm mới Home qua lives_changed).
static func _resume_at(r, t: int, tz: int) -> void:
	r.plat.emit_signal("paused")
	r.game.test_now = t
	r.game.test_tz = tz
	r.plat.emit_signal("resumed")
	await r.wait_frames(4)
	r.step("rời app rồi quay lại lúc %s, ngày %d" % [_clock_text(t, tz), Clock.day_number(t, tz)])


static func _clock_text(t: int, tz: int) -> String:
	return "%s (giờ %+d)" % [Time.get_datetime_string_from_unix_time(t + tz).replace("T", " "), roundi(tz / 3600.0)]


# ================================================================ PR: Profile

## PR. Profile (design.md mục 5 "Avatar và frame", "Biệt danh"), save L30:
## [HP] Bấm avatar ở Home → Profile. Mỗi loại (avatar, frame): chạm món bán chưa có → xem trước, không có OK [NEG], video
## đóng sớm không mở [NEG], xem hết thì có và đeo; OK đeo món mặc định rồi đeo lại món vừa mở.
## [NEG] Món chỉ có từ Road Trip, từ thưởng league: xem trước được, không OK, không video, dòng "Mở khoá ở Level N".
## Biệt danh: mặc định là mã CD_ + chữ số; popup điền sẵn tên; gõ bằng phím thật. [NEG] Ngắn (sau khi bỏ khoảng trắng hai
## đầu), chữ có dấu, chỉ ký tự nối, từ dành riêng, từ cấm chen dấu chấm: popup giữ, báo nhanh, tên không đổi. [EDGE] Gõ
## quá dài: ô dừng ở Config.NAME_MAX. [HP] Tên có khoảng trắng hai đầu và chứa "admin" trong từ thường (Badminton) được
## lưu đã bỏ khoảng trắng. [NEG] Gõ rồi bấm X không lưu.
## [NEG] Xem trước món chưa có rồi thoát: Home vẫn là món đang đeo. Home hiện đúng avatar và frame; mở lại Profile thấy
## tên mới và dấu tích; save trên đĩa khớp.
static func scen_pr(r) -> bool:
	if not await r.open_game("PR", Callable(Saves, "veteran")):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	var shown := _home_avatar_problem(r)
	if not shown.is_empty():
		return r.fail("trước khi đổi: %s" % shown)
	var prof := await _open_profile(r)
	if prof == null:
		return false
	await r.shot("profile")
	var worn := {}
	for kind in Cosmetics.KINDS:
		if kind == "frame":
			if not await r.tap(prof.tab_buttons["frame"] as Control, "tab Frame"):
				return r.fail("không bấm được tab Frame")
			if not await Scen.wait_for(r, func() -> bool:
					return ((prof.cells["frame_00"] as Dictionary).panel as Control).is_visible_in_tree(), 4000, "*"):
				return r.fail("bấm tab Frame mà lưới frame không hiện")
		var id := await _pr_kind(r, prof, kind)
		if id.is_empty():
			return false
		worn[kind] = id
		if not await _pr_reserved(r, prof, kind):
			return false
	if not await _pr_name(r, prof):
		return false
	# [NEG] Món đang xem trước là món chỉ có từ league (chưa có): thoát thì Home vẫn là món đang đeo.
	if not await Scen.back_home(r):
		return r.fail("Profile không về Home")
	await Scen.settle_all(r)
	for kind in Cosmetics.KINDS:
		if Cosmetics.equipped(r.game.s, kind) != str(worn[kind]):
			_bug(r, "xem trước món chưa có rồi thoát mà %s đang đeo đổi thành %s" % [kind,
				Cosmetics.equipped(r.game.s, kind)])
	shown = _home_avatar_problem(r)
	if not shown.is_empty():
		_bug(r, "sau khi đổi ở Profile: %s" % shown)
	else:
		r.step("Home hiện %s, %s" % [worn.avatar, worn.frame])
	await r.shot("home_after")
	# Mở lại Profile: tên mới, dấu tích ở món đang đeo, ảnh lớn là món đang đeo.
	prof = await _open_profile(r)
	if prof == null:
		return false
	var name := Nickname.current(r.game.s)
	if str((prof.name_label as Label).text) != name:
		_bug(r, "mở lại Profile mà ô tên ghi \"%s\", tên đã lưu \"%s\"" % [(prof.name_label as Label).text, name])
	for kind in Cosmetics.KINDS:
		var e: Dictionary = prof.cells[str(worn[kind])]
		if not (e.check as Control).visible:
			_bug(r, "mở lại Profile mà %s đang đeo không có dấu tích" % worn[kind])
		if _preview(prof, kind) != ThemeKit.icon(str(worn[kind])):
			_bug(r, "mở lại Profile mà ảnh lớn không phải %s đang đeo" % worn[kind])
	await r.shot("profile_reopen")
	if not await Scen.back_home(r):
		return r.fail("Profile không về Home")
	if not _disk_same(r, "cos") or not _disk_same(r, "profile"):
		return false
	return await _finish(r)


static func _open_profile(r) -> Node:
	if not await Scen.tap_named(r, "ProfileButton", r.main.current_screen):
		return null
	if not await Scen.wait_for(r, func() -> bool: return r.screen_name() == "profile", 10000):
		r.fail("bấm avatar ở Home không mở Profile")
		return null
	await r.wait_sec(0.6)
	return r.main.current_screen


## Một loại (avatar hoặc frame) ở tab đang mở: món bán chưa có → xem trước, video đóng sớm, xem hết; OK đeo món mặc
## định rồi đeo lại món vừa mở. Trả id món vừa mở và đang đeo, "" khi dừng.
static func _pr_kind(r, prof: Node, kind: String) -> String:
	var s: Dictionary = r.game.s
	var worn0 := Cosmetics.equipped(s, kind)
	var id := ""
	for k in Config.cosmetic_ids(kind):
		if Cosmetics.for_sale(str(k)) and not Cosmetics.is_owned(s, str(k)):
			id = str(k)
			break
	if id.is_empty():
		r.fail("không còn %s bán nào chưa có" % kind)
		return ""
	if not await _tap_cell(r, prof, id):
		return ""
	# [NEG] Món chưa có: ảnh lớn xem trước, không có OK hay Đang dùng, chưa đeo.
	if _preview(prof, kind) != ThemeKit.icon(id):
		_bug(r, "chạm %s chưa có mà ảnh lớn không xem trước món đó" % id)
	var use := prof.use_button as Control
	if use != null and use.is_visible_in_tree():
		_bug(r, "%s chưa có mà có nút %s" % [id, use.name])
	if Cosmetics.equipped(s, kind) != worn0:
		_bug(r, "chạm %s chưa có mà đã đeo" % id)
	if not ((prof.cells[id] as Dictionary).lock as Control).visible:
		_bug(r, "ô %s chưa có mà không có khoá" % id)
	var video := prof.video_button as Control
	if video == null or not video.is_visible_in_tree():
		r.fail("chọn %s bán mà không có nút xem video" % id)
		return ""
	await r.shot("profile_%s_preview" % kind)
	# [NEG] Video đóng sớm: không mở.
	if not await Scen._ad_tap(r, video, "cosmetic_unlock", "closed", "mở %s bằng video (đóng sớm)" % id):
		return ""
	await Scen.wait_for(r, func() -> bool: return str((prof.status_label as Label).text) == r.tr("ads_closed_early"),
		4000, "*")
	if Cosmetics.is_owned(s, id) or Cosmetics.equipped(s, kind) != worn0:
		_bug(r, "video đóng sớm mà %s đã vào kho hoặc đã đeo" % id)
	if str((prof.status_label as Label).text) != r.tr("ads_closed_early"):
		_bug(r, "video đóng sớm ở Profile mà không báo \"%s\"" % r.tr("ads_closed_early"))
	# [HP] Xem hết: vào kho và đeo luôn.
	video = prof.video_button as Control
	if video == null or not video.is_visible_in_tree():
		r.fail("video đóng sớm mà nút xem video của %s biến mất" % id)
		return ""
	if not await Scen._ad_tap(r, video, "cosmetic_unlock", "", "mở %s bằng video" % id):
		return ""
	if not await Scen.wait_for(r, func() -> bool:
			return Cosmetics.is_owned(s, id) and Cosmetics.equipped(s, kind) == id, 10000, "*"):
		r.fail("xem hết video mà %s chưa vào kho hoặc chưa đeo" % id)
		return ""
	await r.wait_frames(3)
	use = prof.use_button as Control
	if use == null or str(use.name) != "UsedButton" or not use.is_visible_in_tree():
		_bug(r, "%s vừa đeo mà không có nút Đang dùng" % id)
	if ((prof.cells[id] as Dictionary).lock as Control).visible:
		_bug(r, "%s đã có mà ô còn khoá" % id)
	r.step("mở và đeo %s bằng video" % id)
	await r.shot("profile_%s_unlocked" % kind)
	# [HP] OK: đeo món mặc định, rồi đeo lại món vừa mở.
	for target in [str(Config.COSMETICS["default_" + kind]), id]:
		if not await _tap_cell(r, prof, target):
			return ""
		var ok := prof.use_button as Control
		if ok == null or str(ok.name) != "SaveButton" or not ok.is_visible_in_tree():
			r.fail("%s đã có, chưa đeo mà không có nút OK" % target)
			return ""
		if not await r.tap(ok, "OK đeo %s" % target):
			r.fail("nút OK của %s bị che" % target)
			return ""
		if not await Scen.wait_for(r, func() -> bool: return Cosmetics.equipped(s, kind) == target, 4000, "*"):
			r.fail("bấm OK mà %s chưa đeo" % target)
			return ""
		r.step("OK: đeo %s" % target)
	return id


## [NEG] Món chỉ có từ Road Trip và từ thưởng league ở tab đang mở: xem trước được, không có OK hay video, chưa mở thì
## có dòng "Mở khoá ở Level N" (nút Road Trip / Bảng xếp hạng khi đã mở); không đổi món đang đeo.
static func _pr_reserved(r, prof: Node, kind: String) -> bool:
	var s: Dictionary = r.game.s
	var worn := Cosmetics.equipped(s, kind)
	var rt_open := bool(r.game.road_trip_view().get("open", false))
	var lb_open: bool = r.game.lb_open()
	var picks: Array = []
	for k in Config.cosmetic_ids(kind):
		var id := str(k)
		if Cosmetics.is_owned(s, id):
			continue
		if Cosmetics.road_trip_box(id) > 0 and not picks.any(func(p: Array) -> bool: return p[1] == "rt"):
			picks.append([id, "rt"])
		elif Cosmetics.league_only(id) and not picks.any(func(p: Array) -> bool: return p[1] == "lb"):
			picks.append([id, "lb"])
	for p in picks:
		var id := str(p[0])
		if not await _tap_cell(r, prof, id):
			return false
		if _preview(prof, kind) != ThemeKit.icon(id):
			_bug(r, "chạm %s mà ảnh lớn không xem trước món đó" % id)
		var use := prof.use_button as Control
		var video := prof.video_button as Control
		if (use != null and use.is_visible_in_tree()) or (video != null and video.is_visible_in_tree()):
			_bug(r, "%s chỉ có từ %s mà có nút OK hoặc video" % [id, "Road Trip" if p[1] == "rt" else "league"])
		var expect := ""
		if p[1] == "rt":
			expect = "RoadTripButton" if rt_open else "RoadTripLocked"
		else:
			expect = "LeagueButton" if lb_open else "LeagueLocked"
		var shown := Scen.find_visible(prof, expect)
		if shown == null:
			_bug(r, "%s chưa có mà không hiện %s" % [id, expect])
		elif shown is Label:
			var lvl := int(Config.UNLOCK.get("road_trip" if p[1] == "rt" else "leaderboard", 0))
			var want: String = r.tr("common_locked_level") % lvl
			if (shown as Label).text != want:
				_bug(r, "%s: dòng khoá ghi \"%s\", mong đợi \"%s\"" % [id, (shown as Label).text, want])
		if p[1] == "lb" and Scen.find_visible(prof, "LeagueNote") == null:
			_bug(r, "%s chỉ có từ league mà không có dòng cách nhận" % id)
		if Cosmetics.equipped(s, kind) != worn or Cosmetics.is_owned(s, id):
			_bug(r, "chạm %s (không bán) mà món đó đã đeo hoặc vào kho" % id)
		r.step("%s (chỉ có từ %s): xem trước, không OK, không video, hiện %s" % [id,
			"Road Trip" if p[1] == "rt" else "league", expect])
		await r.shot("profile_%s_%s" % [kind, p[1]])
	return true


## Biệt danh qua popup đổi tên: luật Nickname.check (Config.NAME_MIN, NAME_MAX, ký tự, từ cấm), gõ bằng phím thật.
static func _pr_name(r, prof: Node) -> bool:
	var s: Dictionary = r.game.s
	var name0 := Nickname.current(s)
	var code_len := Config.NAME_CODE.length() + Config.NAME_CODE_DIGITS
	if not name0.begins_with(Config.NAME_CODE) or name0.length() != code_len \
			or not name0.substr(Config.NAME_CODE.length()).is_valid_int():
		_bug(r, "tên mặc định \"%s\" không phải %s + %d chữ số" % [name0, Config.NAME_CODE, Config.NAME_CODE_DIGITS])
	if str((prof.name_label as Label).text) != name0:
		_bug(r, "ô tên ở Profile ghi \"%s\", tên đã lưu \"%s\"" % [(prof.name_label as Label).text, name0])
	var pop := await _open_name(r, prof)
	if pop == null:
		return false
	var edit := pop.name_input as LineEdit
	if edit.text != name0:
		_bug(r, "popup đổi tên không điền sẵn tên hiện tại (ô ghi \"%s\")" % edit.text)
	await r.shot("change_name")
	var short := LETTERS.substr(0, Config.NAME_MIN - 1)
	var cases := [
		["  %s  " % short, "profile_name_invalid", "ngắn hơn %d ký tự sau khi bỏ khoảng trắng hai đầu" % Config.NAME_MIN],
		["Kẹo Ngọt", "profile_name_invalid", "chữ có dấu và khoảng trắng giữa"],
		["_.-_", "profile_name_invalid", "không có chữ hay số"],
		["Real_Admin", "profile_name_banned", "tên dành riêng cho nhân viên"],
		["S.u.p.p.o.r.t", "profile_name_banned", "từ dành riêng chen dấu chấm"],
	]
	for c in cases:
		if not await _type(r, edit, str(c[0])):
			return false
		pop.set("toast_text", "")
		if not await r.tap(pop.save_button as Control, "OK đổi tên (%s)" % c[2]):
			return r.fail("nút OK của popup đổi tên bị che")
		await Scen.wait_for(r, func() -> bool:
			return not is_instance_valid(pop) or not str(pop.get("toast_text")).is_empty(), 3000, "*")
		if not is_instance_valid(pop) or not pop.is_inside_tree() or bool(pop.get("_done")):
			_bug(r, "tên \"%s\" (%s) mà popup đổi tên đóng" % [c[0], c[2]])
			return await _finish(r)
		var want: String = r.tr(str(c[1]))
		if str(pop.get("toast_text")) != want:
			_bug(r, "tên \"%s\" (%s): báo \"%s\", mong đợi \"%s\"" % [c[0], c[2], pop.get("toast_text"), want])
		if Nickname.current(s) != name0:
			_bug(r, "tên sai luật \"%s\" (%s) mà đã lưu" % [c[0], c[2]])
			return await _finish(r)
		r.step("tên \"%s\" (%s): popup giữ, báo \"%s\"" % [c[0], c[2], pop.get("toast_text")])
	await r.shot("change_name_rejected")
	# [EDGE] Gõ dài hơn Config.NAME_MAX: ô nhập dừng ở NAME_MAX ký tự.
	if not await _type(r, edit, LETTERS.substr(0, Config.NAME_MAX + 6)):
		return false
	if edit.text.length() != Config.NAME_MAX:
		_bug(r, "gõ %d ký tự mà ô nhập giữ %d, mong đợi dừng ở %d" % [Config.NAME_MAX + 6, edit.text.length(),
			Config.NAME_MAX])
	# [HP] Tên hợp lệ có khoảng trắng hai đầu: lưu đã bỏ khoảng trắng; "Badminton" chứa "admin" nhưng là từ thường.
	var good := "Badminton_7"
	if not await _type(r, edit, " %s " % good):
		return false
	if not await r.tap(pop.save_button as Control, "OK đổi tên"):
		return r.fail("nút OK của popup đổi tên bị che")
	if not await Scen.wait_for(r, func() -> bool: return prof.get_node_or_null("ChangeName") == null, 4000, "*"):
		_bug(r, "tên hợp lệ \" %s \" mà popup đổi tên không đóng (báo \"%s\")" % [good,
			pop.get("toast_text") if is_instance_valid(pop) else ""])
		return await _finish(r)
	if Nickname.current(s) != good:
		_bug(r, "đổi tên \" %s \" mà tên đã lưu là \"%s\", mong đợi \"%s\"" % [good, Nickname.current(s), good])
	await r.wait_frames(3)
	if str((prof.name_label as Label).text) != Nickname.current(s):
		_bug(r, "đổi tên xong mà ô tên ở Profile ghi \"%s\"" % (prof.name_label as Label).text)
	r.step("đổi tên: \"%s\" → \"%s\"" % [name0, Nickname.current(s)])
	await r.shot("profile_renamed")
	# [NEG] Gõ tên khác rồi bấm X: không lưu.
	pop = await _open_name(r, prof)
	if pop == null:
		return false
	if not await _type(r, pop.name_input as LineEdit, "Other_Name"):
		return false
	var close := Scen.find_close(pop)
	if close == null:
		return r.fail("popup đổi tên không có nút đóng")
	await r.tap(close, "đổi tên: %s" % close.name)
	if not await Scen.wait_for(r, func() -> bool: return prof.get_node_or_null("ChangeName") == null, 4000, "*"):
		return r.fail("bấm X mà popup đổi tên không đóng")
	if Nickname.current(s) != good:
		_bug(r, "gõ tên rồi bấm X mà tên đổi thành \"%s\"" % Nickname.current(s))
	r.step("gõ tên khác rồi bấm X: tên giữ \"%s\"" % Nickname.current(s))
	return true


static func _open_name(r, prof: Node) -> Node:
	if not await Scen.tap_named(r, "EditNameButton", prof):
		return null
	if not await Scen.wait_for(r, func() -> bool:
			var p: Node = prof.get_node_or_null("ChangeName")
			return p != null and p.get("name_input") != null and (p.name_input as Control).is_visible_in_tree(), 4000, "*"):
		r.fail("bấm bút chì không mở popup đổi tên")
		return null
	await r.wait_sec(0.6)
	return prof.get_node("ChangeName")


## Gõ `text` vào ô nhập như bàn phím: chạm ô (lấy focus, vào chế độ sửa), End, xoá hết bằng Backspace, rồi từng ký tự
## (InputEventKey mang unicode, như bàn phím ảo của Android gửi). Đi qua runner (_push) để không bị coi là input thật.
static func _type(r, edit: LineEdit, text: String) -> bool:
	if not await r.tap(edit, "ô biệt danh"):
		return r.fail("không chạm được ô biệt danh")
	await r.wait_frames(2)
	if not edit.has_focus():
		return r.fail("chạm ô biệt danh mà ô không nhận bàn phím")
	_key(r, KEY_END)
	for i in edit.text.length() + 1:
		_key(r, KEY_BACKSPACE)
	for ch in text:
		_key(r, KEY_NONE, ch.unicode_at(0))
	await r.wait_frames(2)
	r.step("gõ \"%s\" → ô ghi \"%s\"" % [text, edit.text])
	return true


static func _key(r, code: Key, uni: int = 0) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.unicode = uni
		ev.pressed = pressed
		r._push(ev)


## Chạm ô `id` ở lưới Profile (cuộn tới nếu cần).
static func _tap_cell(r, prof: Node, id: String) -> bool:
	var panel := (prof.cells[id] as Dictionary).panel as Control
	if not await Scen.scroll_into_view(r, panel):
		return r.fail("không cuộn được tới ô %s" % id)
	if not await r.tap(panel, "ô %s" % id):
		return r.fail("không chạm được ô %s" % id)
	await r.wait_sec(0.3)
	return true


static func _preview(prof: Node, kind: String) -> Texture2D:
	var img: Control = prof.ui.image(str(PREVIEW[kind]))
	return img.get("tex") as Texture2D if img != null else null


## "" khi nút avatar ở Home (HubTop, Profile.make_avatar) vẽ đúng avatar và frame đang đeo, không thì mô tả chỗ sai.
static func _home_avatar_problem(r) -> String:
	if r.screen_name() != "home":
		return "không ở Home"
	var btn := r.main.current_screen.get("profile_btn") as Control
	var view: Node = btn.get_node_or_null("AvatarView") if btn != null else null
	if view == null:
		return "nút avatar ở Home không có ảnh"
	var av := Cosmetics.equipped(r.game.s, "avatar")
	var fr := Cosmetics.equipped(r.game.s, "frame")
	var a := view.get_node_or_null("Avatar") as TextureRect
	if a == null or a.texture != ThemeKit.icon(av):
		return "Home không vẽ avatar %s đang đeo" % av
	var f := view.get_node_or_null("Frame")
	if ThemeKit.has_real_icon(fr) and not (f is TextureRect and (f as TextureRect).texture == ThemeKit.icon(fr)):
		return "Home không vẽ frame %s đang đeo" % fr
	return ""


# ================================================================ OFF: tính năng đang tắt

## OFF. Tính năng đang tắt (Config.FEATURES; design.md mục 4 "Phạm vi" cho Daily Challenge, mục 7 "Win Streak"):
## [NEG] Logic: mọi level đều chưa mở, thanh tiến trình không ghi hai tính năng (bật thử thì có, để kiểm không rỗng).
## [NEG] Save mở hết (all_unlocked) có lượt Win Streak đang chạy chưa Start: Home không có icon Daily Challenge và Win
## Streak, Bảng xếp hạng dồn lên chỗ đó, không tự mở popup giới thiệu Win Streak, lệnh mở màn của hai tính năng bị bỏ qua.
## [NEG] L44 có lượt Win Streak đã Start (chuỗi 3): thẻ thắng không báo Win Streak, chuỗi không cộng, thắng xong vào
## thẳng L45 (không về Home); bỏ ván đã chạm ở L45: hỏi "Chơi tiếp chứ?" (không phải "Giữ chuỗi nhé?"), chuỗi không tụt,
## không báo mất chuỗi.
## [NEG] L49: thẻ thắng không báo Daily Challenge ở mốc L50 (chỉ Màn đặc biệt), về Home vẫn không có icon Daily Challenge.
static func scen_off(r) -> bool:
	for f in OFF_FEATURES:
		if Unlocks.enabled(f):
			return r.fail("Config.FEATURES.%s đang bật, design.md ghi tắt: kịch bản OFF không áp dụng" % f)
	if not _off_logic(r):
		return false
	if not await _off_home(r):
		return false
	if not await _off_streak_level(r):
		return false
	if not await _off_challenge_level(r):
		return false
	return await _finish(r)


## Logic thuần (Unlocks): từ L1 tới quá mọi mốc, hai tính năng không mở và không có trên thanh tiến trình.
static func _off_logic(r) -> bool:
	var top := 0
	for k in Config.UNLOCK:
		top = maxi(top, int(Config.UNLOCK[k]))
	top += 100
	for f in OFF_FEATURES:
		var at := int(Config.UNLOCK[f])
		var bad: Array[int] = []
		for lv in range(1, top + 1):
			var p := Unlocks.feature_progress(lv)
			if Unlocks.is_open(f, lv) or (p.features as Array).has(f) or (p.unlocked as Array).has(f):
				bad.append(lv)
		if not bad.is_empty():
			_bug(r, "%s đang tắt mà mở hoặc có trên thanh tiến trình ở L%s" % [f, str(bad.slice(0, 5))])
		var others := Unlocks.features_at(at)
		r.step("mốc L%d (%s tắt): thanh tiến trình còn %s" % [at, f, str(others)])
		# Bật thử: cùng mốc phải có tính năng này, để kiểm trên không rỗng. Trả công tắc ngay.
		Config.FEATURES[f] = true
		var on := Unlocks.is_open(f, at) and Unlocks.features_at(at).has(f)
		Config.FEATURES[f] = false
		if not on:
			return r.fail("bật thử %s mà L%d vẫn không mở: kiểm tra OFF không có nghĩa" % [f, at])
	return true


## Save mở hết, có lượt Win Streak tuần này đang chạy mà chưa Start (khi bật thì về Home tự mở popup giới thiệu).
static func _off_home(r) -> bool:
	var prep := func(g: Node) -> void:
		Saves.all_unlocked(g)
		_running_streak(g, 0, false)
	if not await r.open_game("OFF", prep):
		return false
	if not await Scen.go_home_from_level(r):
		return false
	await Scen.settle_all(r)
	await r.wait_sec(1.0)
	var home: Node = r.main.current_screen
	for name in ["GiftButton", "LeaderboardButton", "BombButton"]:
		if Scen.find_visible(home, name) == null:
			return r.fail("save mở hết mà Home không có %s" % name)
	for name in ["ChallengeButton", "StreakButton"]:
		if Scen.find_visible(home, name) != null:
			_bug(r, "tính năng đang tắt mà Home hiện %s" % name)
	# Bảng xếp hạng dồn lên chỗ Daily Challenge: cột trái còn quà, Bảng xếp hạng, Màn đặc biệt, cách đều.
	var ys: Array[float] = []
	for name in ["GiftItem", "LeaderboardItem", "BombItem"]:
		var c := home.find_child(name, true, false) as Control
		if c == null:
			return r.fail("Home không có %s" % name)
		ys.append(c.get_global_rect().position.y)
	if absf((ys[1] - ys[0]) - (ys[2] - ys[1])) > 2.0 or ys[1] <= ys[0]:
		_bug(r, "cột trái không dồn lên chỗ icon ẩn: y quà %d, BXH %d, Màn đặc biệt %d" % [ys[0], ys[1], ys[2]])
	if bool(r.game.s.streak.get("auto_shown", false)):
		_bug(r, "Win Streak đang tắt mà về Home tự mở popup giới thiệu")
	var ch: Dictionary = r.game.challenge_view()
	if bool(ch.enabled) or bool(ch.open) or not (r.game.start_challenge() as Dictionary).is_empty():
		_bug(r, "Daily Challenge đang tắt mà challenge_view %s" % JSON.stringify(ch))
	var sv: Dictionary = r.game.streak_view()
	if bool(sv.visible) or bool(sv.running) or str(r.game.streak_entry()) != "":
		_bug(r, "Win Streak đang tắt mà streak_view visible=%s running=%s entry=\"%s\"" % [sv.visible, sv.running,
			r.game.streak_entry()])
	await r.shot("home_off")
	# Lệnh mở màn của hai tính năng (như từ một link): Main bỏ qua.
	for action in ["challenge", "streak"]:
		var pops: int = r.main.popup_count()
		r.main.call("_home_action", action, {})
		await r.wait_sec(0.6)
		if r.screen_name() != "home" or r.main.popup_count() > pops:
			_bug(r, "tính năng đang tắt mà lệnh \"%s\" mở %s" % [action, r.describe()])
			await Scen.close_to(r, pops)
			await Scen.back_home(r)
		else:
			r.step("lệnh \"%s\" bị bỏ qua, vẫn ở Home" % action)
	return await Scen.verify_saved(r)


## L44 (trước mốc Win Streak), lượt Win Streak đã Start với chuỗi 3: thắng không cộng, không về Home; bỏ ván ở L45 không
## tụt chuỗi, không hỏi giữ chuỗi.
static func _off_streak_level(r) -> bool:
	var lvl := int(Config.UNLOCK.win_streak) - 1
	var count := 3
	var prep := func(g: Node) -> void:
		Saves.veteran(g)
		g.s.level = lvl
		_running_streak(g, count, true)
	if not await r.open_game("OFF_streak", prep):
		return false
	# Bật thử: save này đang đếm chuỗi nếu tính năng bật.
	Config.FEATURES["win_streak"] = true
	var would: bool = WinStreak.counting(r.game.s, r.game.now(), int(r.game.test_tz))
	Config.FEATURES["win_streak"] = false
	if not would:
		return r.fail("save dựng sai: bật Win Streak mà lượt không đếm chuỗi")
	if not await Scen.win_level(r):
		return false
	var card := await _win_card(r, lvl, "win_streak")
	if card == null:
		return false
	if int(r.game.s.streak.count) != count:
		_bug(r, "Win Streak đang tắt mà thắng L%d đổi chuỗi %d → %d" % [lvl, count, int(r.game.s.streak.count)])
	await Scen.tap_named(r, "ContinueButton", card)
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > lvl or r.screen_name() == "home", 20000):
		return r.fail("sau thẻ thắng L%d không sang level kế hay Home" % lvl)
	if r.screen_name() == "home":
		_bug(r, "Win Streak đang tắt mà thắng L%d về Home (design: vào thẳng L%d)" % [lvl, lvl + 1])
		await Scen.settle_all(r)
		if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
			return false
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == lvl + 1, 20000):
		return r.fail("không vào được L%d" % (lvl + 1))
	r.step("thắng L%d vào thẳng L%d" % [lvl, lvl + 1])
	# Bỏ ván đã chạm.
	await Scen.settle_all(r)
	if not await r.tap_next_move():
		return r.fail("L%d: không chạm được nước đầu" % (lvl + 1))
	await r.wait_sec(0.5)
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == lvl + 1, 10000):
		return r.fail("L%d không về trạng thái chơi sau nước đầu" % (lvl + 1))
	var lv: Control = r.level_screen()
	await r.tap(lv.settings_button, "Cài đặt trong màn")
	if not await Scen.wait_for(r, func() -> bool: return r.popup_script("popup_ingame_settings.gd") != null, 6000,
			"popup_ingame_settings.gd"):
		return r.fail("Cài đặt trong màn không mở")
	await r.wait_sec(0.4)
	if not await Scen.tap_named(r, "HomeButton", r.popup_script("popup_ingame_settings.gd")):
		return false
	if not await Scen.wait_for(r, func() -> bool:
			return r.popup_script("popup_keep_playing.gd") != null or r.popup_script("popup_streak_keep.gd") != null,
			8000, "*"):
		return r.fail("bỏ ván đã chạm ở L%d mà không hỏi xác nhận" % (lvl + 1))
	await r.wait_sec(0.4)
	var ask: Node = r.popup_script("popup_streak_keep.gd")
	if ask != null:
		_bug(r, "Win Streak đang tắt mà bỏ ván hỏi \"Giữ chuỗi nhé?\"")
	else:
		ask = r.popup_script("popup_keep_playing.gd")
		r.step("bỏ ván hỏi \"Chơi tiếp chứ?\" như thường")
	await r.shot("quit_confirm")
	if not await Scen.tap_named(r, "ConfirmButton", ask):
		return false
	var notice := {"seen": false}
	await Scen.wait_for(r, func() -> bool:
		notice["seen"] = bool(notice["seen"]) or r.popup_script("popup_notice.gd") != null
		return r.screen_name() == "home" and r.main.curtain == null, 15000, "*")
	await r.wait_sec(1.0)
	if bool(notice["seen"]) or r.popup_script("popup_notice.gd") != null:
		_bug(r, "Win Streak đang tắt mà bỏ ván báo mất chuỗi")
	if r.screen_name() != "home":
		return r.fail("xác nhận bỏ ván không về Home")
	if int(r.game.s.streak.count) != count:
		_bug(r, "Win Streak đang tắt mà bỏ ván đổi chuỗi %d → %d" % [count, int(r.game.s.streak.count)])
	await Scen.settle_all(r)
	if Scen.find_visible(r.main.current_screen, "StreakButton") != null:
		_bug(r, "Win Streak đang tắt mà Home hiện icon Win Streak")
	r.step("chuỗi giữ %d, Home không có icon Win Streak" % int(r.game.s.streak.count))
	await r.shot("home_after_quit")
	return await Scen.verify_saved(r)


## L49 (trước mốc Daily Challenge): thẻ thắng không báo Daily Challenge; về Home vẫn không có icon.
static func _off_challenge_level(r) -> bool:
	var lvl := int(Config.UNLOCK.challenge) - 1
	var prep := func(g: Node) -> void:
		Saves.veteran(g)
		g.s.level = lvl
	if not await r.open_game("OFF_challenge", prep):
		return false
	if not await Scen.win_level(r):
		return false
	var card := await _win_card(r, lvl, "challenge")
	if card == null:
		return false
	await Scen.tap_named(r, "ContinueButton", card)
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) > lvl or r.screen_name() == "home", 20000):
		return r.fail("sau thẻ thắng L%d không sang level kế hay Home" % lvl)
	if r.screen_name() != "home":
		if not await Scen.go_home_from_level(r):
			return false
	await Scen.settle_all(r)
	await r.wait_sec(0.5)
	if Scen.find_visible(r.main.current_screen, "ChallengeButton") != null:
		_bug(r, "Daily Challenge đang tắt mà Home L%d hiện icon Daily Challenge" % int(r.game.s.level))
	if not bool(r.game.challenge_view().get("open", true)) and not (r.game.start_challenge() as Dictionary).is_empty():
		_bug(r, "Daily Challenge đang tắt mà vẫn bắt đầu được")
	r.step("L%d: Home không có icon Daily Challenge" % int(r.game.s.level))
	await r.shot("home_L%d" % int(r.game.s.level))
	return await Scen.verify_saved(r)


## Thẻ thắng của `lvl`: thanh tiến trình và danh sách vừa mở không có `feature`, dòng chữ không ghi tên nó.
static func _win_card(r, lvl: int, feature: String) -> Node:
	if not await Scen.wait_for(r, func() -> bool: return r.popup_node("ContinueButton") != null, 20000, "ContinueButton"):
		r.fail("thắng L%d mà không có thẻ thắng" % lvl)
		return null
	var card: Node = r.popup_script("win_card.gd")
	if card == null:
		r.fail("thắng L%d mà không thấy win_card.gd" % lvl)
		return null
	var args: Dictionary = card.get("_args")
	var prog: Dictionary = args.get("progress", {})
	var feats: Array = prog.get("features", [])
	var opened: Array = args.get("unlocked", [])
	if feats.has(feature) or opened.has(feature):
		_bug(r, "%s đang tắt mà thẻ thắng L%d ghi nó (thanh: %s, vừa mở: %s)" % [feature, lvl, str(feats), str(opened)])
	if feature == "win_streak" and bool(args.get("streak_up", false)):
		_bug(r, "Win Streak đang tắt mà thẻ thắng L%d báo chuỗi tăng" % lvl)
	var label_name: String = r.tr("feature_" + feature)
	for i in 2:
		# Lần đầu khi thẻ vừa hiện ("Mở khoá tiếp: ..."), lần sau khi thanh đã chạy hết ("Đã mở khoá ...!").
		await r.wait_sec(0.8 if i == 0 else 1.6)
		var l := card.find_child("FeatureLabel", true, false) as Label
		if l != null and l.is_visible_in_tree() and l.text.contains(label_name):
			_bug(r, "thẻ thắng L%d ghi \"%s\" dù %s đang tắt" % [lvl, l.text, feature])
			break
	var l2 := card.find_child("FeatureLabel", true, false) as Label
	r.step("thẻ thắng L%d: thanh %s, vừa mở %s, dòng \"%s\"" % [lvl, str(feats), str(opened),
		l2.text if l2 != null and l2.is_visible_in_tree() else ""])
	await r.shot("win_card_L%d" % lvl)
	return card


## Lượt Win Streak của tuần đang giả lập (đồng hồ giả đã đặt trước khi dựng save): `count` trận, `started` đã bấm Start.
static func _running_streak(g: Node, count: int, started: bool) -> void:
	var w := WinStreak.empty()
	w["week"] = WinStreak.week_id(g.now(), int(g.test_tz))
	w["started"] = started
	w["count"] = count
	w["before"] = count
	g.s["streak"] = w


# ================================================================ tiện ích chung

## Lỗi game (trái design.md): ghi lại và đi tiếp; _finish làm kịch bản fail ở cuối.
static func _bug(r, text: String) -> void:
	_bugs.append(text)
	print("SMOKE WARN LỖI GAME %s" % text)
	print("SMOKE STATE %s" % r.describe())


static func _finish(r) -> bool:
	if not await Scen.verify_saved(r):
		return false
	if not _bugs.is_empty():
		return r.fail("%d lỗi game trái design.md: %s" % [_bugs.size(), " | ".join(PackedStringArray(_bugs))])
	return true


static func _bal(r) -> Dictionary:
	var s: Dictionary = r.game.s
	var out := {"coins": int(s.coins)}
	for k in BOOSTERS:
		out[k] = int(s.inv[k])
	return out


## "" khi số dư sau đúng bằng trước cộng `reward` ({coins, items}), không thì mô tả chỗ lệch.
static func _diff(before: Dictionary, after: Dictionary, reward: Dictionary) -> String:
	var want := {"coins": int(reward.get("coins", 0))}
	for k in BOOSTERS:
		want[k] = int((reward.get("items", {}) as Dictionary).get(k, 0))
	var bad: PackedStringArray = []
	for k in want:
		var got := int(after[k]) - int(before[k])
		if got != int(want[k]):
			bad.append("%s %+d, mong đợi %+d" % [k, got, int(want[k])])
	return ", ".join(bad)


## Phần `key` của save trên đĩa khớp bộ nhớ sau khi lưu (số JSON đọc thành float nên so sau khi chuẩn hoá).
static func _disk_same(r, key: String) -> bool:
	r.game.save_now()
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(r.game.save_path)))
	if not (disk is Dictionary):
		return r.fail("save trên đĩa không đọc được: %s" % str(r.game.save_path))
	var want: Variant = _norm(JSON.parse_string(JSON.stringify(r.game.s.get(key))))
	var got: Variant = _norm((disk as Dictionary).get(key))
	if typeof(got) != typeof(want) or got != want:
		return r.fail("save trên đĩa lệch bộ nhớ ở %s: %s và %s" % [key, JSON.stringify(got), JSON.stringify(want)])
	r.step("save trên đĩa khớp bộ nhớ ở %s: %s" % [key, JSON.stringify(got)])
	return true


static func _norm(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _norm(v[k])
		return o
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_norm(x))
		return a
	return v
