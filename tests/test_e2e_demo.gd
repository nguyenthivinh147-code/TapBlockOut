extends RefCounted
## E2E headless qua main.tscn: chơi L1-20 bằng solver, thua, quà 8 ngày, mua avatar, x2, interstitial, đóng video sớm.
## Bấm nút thật theo tên trong popup (tests/e2e_driver.gd). Tween và timer chạy nhanh (Engine.time_scale).

const T := preload("res://tests/t.gd")
const D := preload("res://tests/e2e_driver.gd")
const Config := preload("res://src/config.gd")
const AdPacing := preload("res://src/meta/ad_pacing.gd")

const DIR := "user://test_e2e_demo"


func _tr(key: String) -> String:
	return TranslationServer.translate(key)


func _inters(d: D) -> Array:
	var out: Array = []
	for c in d.plat().ads.calls:
		if c.kind == "inter":
			out.append(c)
	return out


func _rewarded(d: D, placement: String) -> Array:
	var out: Array = []
	for c in d.plat().ads.calls:
		if c.kind == "rewarded" and c.placement == placement:
			out.append(c)
	return out


## Gold của lần thắng gần nhất (thưởng thắng + MOVES thừa), đọc từ level_end.
func _win_coins(d: D) -> int:
	return int(d.plat().an.named("level_end").back().params.coins)


## Đưa trạng thái về "đến lượt interstitial" cho lần thắng kế (trừ chuyện x2).
func _prep_inter(d: D) -> void:
	var g := d.game()
	g.s.ads["last_inter_run"] = -99
	g.s.ads["last_inter_at"] = 0
	g.test_now += 1000


func test_full_demo_l1_to_l20(t: T) -> void:
	var t0 := Time.get_ticks_msec()
	var d := D.new()
	await d.begin(DIR + "/full", 1)
	var g := d.game()
	t.eq(d.main.current_name, "home", "boot vào Home")
	t.eq(int(g.s.meta.sessions), 1, "Game.boot chạy một lần")
	t.ok(await d.play_from_home(1), "Home -> level 1")
	var reached := 0
	for lvn in range(1, 21):
		if not await d.wait_playing(lvn):
			t.fail("không vào được L%d (state=%s)" % [lvn, str(d.level_screen().state if d.level_screen() != null else "no level")])
			break
		g.test_now += 200
		if not await d.win_level():
			t.fail("không thắng được L%d" % lvn)
			break
		reached = lvn
		if lvn < 20:
			t.eq(int(g.s.level), lvn + 1, "lên level %d" % (lvn + 1))
			if not await d.continue_to(lvn + 1):
				t.fail("không sang L%d" % (lvn + 1))
				break
	t.eq(reached, 20, "thắng đủ 20 level")
	# L20: hết level demo -> hộp báo hết level -> Home
	if reached == 20:
		d.press("ContinueButton")
		t.ok(await d.wait_popup("OkButton"), "báo hết level demo")
		t.eq(int(g.s.level), 21, "đã lên L21")
		d.press("OkButton")
		t.ok(await d.wait_until(func() -> bool: return d.main.current_name == "home" and d.main.popup_count() == 0), "về Home")
	# Kết quả tổng
	t.eq(int(g.s.runs), 20, "20 lượt xong")
	var ends: Array = d.plat().an.named("level_end")
	t.eq(ends.size(), 20, "20 sự kiện level_end")
	var won := 0
	for e in ends:
		t.eq(int(e.params.won), 1, "level_end thắng")
		t.eq(int(e.params.coins), int(Config.ECON.win_coins) + int(e.params.moves_left) * int(Config.ECON.win_move_coins),
			"gold L%d = thưởng thắng + MOVES thừa" % int(e.params.level))
		won += int(e.params.coins)
	t.eq(int(g.s.coins), 1000 + won, "gold = ban đầu + thưởng 20 lần thắng, không chi")
	for k in ["hint", "move", "smash"]:
		t.ok(bool(g.s.gifted[k]), "đã tặng booster %s" % k)
		t.eq(int(g.s.inv[k]), 1, "kho %s" % k)
	t.ok(d.gifts_seen == 3, "thấy 3 hộp tặng booster (L4/6/9)")
	t.eq(d.mechs_seen, 1, "thấy 1 popup cơ chế mới (L14 thùng sắt)")
	t.eq(g.s.mech_seen, ["stone"], "đã ghi xem thùng sắt")
	t.ok(bool(g.s.meta.rated), "đã hỏi đánh giá sau L18")
	t.eq(_rewarded(d, "x2_coins").size(), 0, "không xem video x2 trong lượt chơi này")
	# luật interstitial: phiên đầu chặn tới hết L10, cách nhau >= inter_every lượt, chỉ ở result_exit
	var shows: Array = d.plat().an.named("inter_show")
	var levels: Array = []
	var prev_run := -99
	for e in shows:
		levels.append(int(e.params.level))
		t.ok(int(e.params.level) > int(Config.ADS.first_session_block_until_level), "phiên đầu không inter ở L<=10")
		t.ok(int(e.params.runs) >= int(Config.ADS.inter_from_run), "không inter trước lượt %d" % int(Config.ADS.inter_from_run))
		t.ok(int(e.params.runs) - prev_run >= int(Config.ADS.inter_every), "cách nhau >= %d lượt" % int(Config.ADS.inter_every))
		prev_run = int(e.params.runs)
	t.eq(levels, [11, 13, 15, 17, 19], "inter ở L11, 13, 15, 17, 19")
	t.eq(_inters(d).size(), shows.size(), "mỗi inter hiện đều ghi sự kiện")
	for c in _inters(d):
		t.eq(str(c.placement), "result_exit", "đúng placement")
	t.eq(d.main.popup_count(), 0, "không còn popup")
	d.finish()
	print("e2e full demo: %d ms, offers bỏ qua %d" % [Time.get_ticks_msec() - t0, d.offers_seen])


## Bản phát hành (override 0): thắng L20 thì sang thẳng L21, không có hộp báo hết level.
func test_release_continues_to_l21(t: T) -> void:
	var d := D.new()
	await d.begin(DIR + "/release", 20, -1, true, false)
	var g := d.game()
	t.ok(not Config.is_demo(), "không phải demo")
	t.ok(await d.play_from_home(20), "vào L20")
	t.ok(await d.win_level(), "thắng L20")
	t.ok(await d.continue_to(21), "sang L21")
	t.eq(int(g.s.level), 21, "đã lên L21")
	t.ok(d.popup("OkButton") == null, "không có hộp hết level")
	d.finish()


func test_lose_rescue_lose_card_retry(t: T) -> void:
	var bl := D.new().blocked_level(10, 20)
	var from_l10: bool = int(bl[0]) > 0
	if not from_l10:
		bl = D.new().blocked_level(2, 9)
	t.ok(bl[0] > 0, "có level có khối bị chặn ngay")
	var d := D.new()
	await d.begin(DIR + "/lose", int(bl[0]), 1000, true)
	var g := d.game()
	t.ok(await d.play_from_home(int(bl[0])), "vào level")
	var lv := d.level_screen()
	var count0: int = lv.board.remaining_count()
	await d.burn_moves(str(bl[1]))
	t.eq(lv.board.moves_left(), 0, "chạm sai tới hết MOVES")
	t.ok(await d.wait_popup("SkipButton"), "hiện popup cứu")
	t.eq(d.popup_title(), _tr("rescue_title"), "là popup cứu")
	t.eq(d.main.popup_count(), 1, "popup nằm ở lớp của main")
	d.press("SkipButton")
	if from_l10:
		t.ok(await d.wait_popup("ConfirmButton"), "từ L10 hỏi xác nhận mất mạng")
		d.press("ConfirmButton")
	t.ok(await d.wait_popup("RetryButton"), "hiện thẻ thua")
	t.eq(int(g.s.runs), 1, "thua tính một lượt")
	t.eq(int(g.s.level), int(bl[0]), "thua không đổi level")
	if from_l10:
		t.eq(int(g.s.lives.count), 9, "từ L10 thua mất 1 mạng")
	t.eq(int(g.s.coins), 1000, "bỏ qua popup cứu không tốn gold")
	t.eq(int(d.plat().an.named("level_end")[0].params.won), 0, "level_end thua")
	d.press("RetryButton")
	t.ok(await d.wait_playing(int(bl[0])), "chơi lại")
	lv = d.level_screen()
	t.eq(lv.board.remaining_count(), count0, "bàn mới")
	t.ok(lv.board.moves_left() > 0, "MOVES đầy lại")
	# thắng ở lượt sau
	t.ok(await d.win_level(), "thắng sau khi thua")
	t.eq(int(g.s.level), int(bl[0]) + 1, "lên level")
	t.eq(int(g.s.runs), 2, "hai lượt")
	d.finish()


func test_lose_last_life_goes_to_no_lives(t: T) -> void:
	var bl := D.new().blocked_level(10, 20)
	if bl[0] == 0:
		return  # không có level chặn ngay ở L10+: đã ghi nhận ở test trên
	var d := D.new()
	await d.begin(DIR + "/nolives", int(bl[0]), 0, true)
	var g := d.game()
	g.s.lives.count = 1
	g.s.lives.next_at = D.NOW + 900
	t.ok(await d.play_from_home(int(bl[0])), "vào level")
	await d.burn_moves(str(bl[1]))
	t.ok(await d.wait_popup("SkipButton"), "popup cứu")
	d.press("SkipButton")
	t.ok(await d.wait_popup("ConfirmButton"), "xác nhận mất mạng")
	d.press("ConfirmButton")
	t.ok(await d.wait_popup("RetryButton"), "thẻ thua")
	t.eq(int(g.s.lives.count), 0, "hết mạng")
	d.press("RetryButton")
	t.ok(await d.wait_until(func() -> bool: return d.main.current_name == "no_lives"), "sang màn hết mạng")
	var home := d.main.current_screen.find_child("HomeButton", true, false) as Button
	t.ok(home != null, "nút Home của màn hết mạng")
	if home != null:
		home.pressed.emit()
	t.ok(await d.wait_until(func() -> bool: return d.main.current_name == "home"), "về Home")
	d.main.current_screen.play_btn.pressed.emit()
	t.eq(d.main.current_name, "no_lives", "Chơi khi hết mạng quay lại màn hết mạng")
	d.finish()


func test_daily_gift_8_days(t: T) -> void:
	var d := D.new()
	await d.begin(DIR + "/daily", 4, 1000, true)
	var g := d.game()
	var coins := 1000
	var idx := 0
	var inv := {"hint": 0, "move": 0, "smash": 0}
	for day in 8:
		g.test_now = D.NOW + day * 86400
		d.main.go("home")
		await d.tree().process_frame
		t.ok(bool(g.daily_view().badge), "ngày %d: có chấm quà" % day)
		d.main.current_screen.gift_btn.pressed.emit()
		t.ok(await d.wait_until(func() -> bool: return d.popup_with("claim_button") != null), "ngày %d: mở popup quà" % day)
		var pop := d.popup_with("claim_button")
		t.ok(pop.claim_button.visible, "ngày %d: nút nhận" % day)
		var reward: Dictionary = Config.DAILY[idx]
		pop.claim_button.pressed.emit()
		coins += int(reward.coins)
		for k in reward.items:
			inv[k] += int(reward.items[k])
		idx += 1
		t.eq(int(g.s.coins), coins, "ngày %d: +gold" % day)
		t.eq(int(g.s.daily.idx), idx, "ngày %d: ô kế" % day)
		t.ok(not pop.claim_button.visible, "ngày %d: không nhận hai lần" % day)
		t.eq(g.daily_claim(), {}, "ngày %d: claim lần hai rỗng" % day)
		t.ok(pop.video_button.visible, "ngày %d: mời video nhận trước" % day)
		if day == 2:
			# đóng video sớm: không thưởng, vẫn thử lại được
			d.plat().ads.simulate("closed")
			pop.video_button.pressed.emit()
			await d.wait_until(func() -> bool: return pop.status_label.text == _tr("ads_closed_early"))
			t.eq(pop.status_label.text, _tr("ads_closed_early"), "đóng video sớm có báo")
			t.eq(int(g.s.coins), coins, "đóng sớm không thưởng")
			t.eq(int(g.s.daily.idx), idx, "đóng sớm không tiến ô")
			t.ok(pop.video_button.visible, "vẫn thử lại được")
			pop.video_button.pressed.emit()
			await d.wait_until(func() -> bool: return int(g.s.daily.idx) == idx + 1)
			var ahead: Dictionary = Config.DAILY[idx]
			coins += int(ahead.coins)
			for k in ahead.items:
				inv[k] += int(ahead.items[k])
			idx += 1
			t.eq(int(g.s.daily.idx), idx, "video nhận trước một ô")
			t.eq(int(g.s.coins), coins, "gold của ô nhận trước")
			t.ok(not pop.video_button.visible, "video chỉ một lần mỗi ngày")
			t.eq(_rewarded(d, "daily_next").size(), 2, "hai lần gọi video daily_next")
		pop.close()
		t.ok(await d.wait_until(func() -> bool: return d.main.popup_count() == 0), "ngày %d: đóng popup" % day)
	for k in inv:
		t.eq(int(g.s.inv[k]), int(inv[k]), "kho %s" % k)
	t.eq(idx, 9, "9 ô đã nhận (8 ngày + 1 video)")
	t.eq(int(g.daily_view().week), 1, "sang tuần thứ 2")
	# cùng ngày thì không nhận lại, ngày kế nhận được
	t.eq(g.daily_claim(), {}, "chưa sang ngày mới")
	g.test_now = D.NOW + 8 * 86400
	t.ok(bool(g.daily_view().can_claim), "ngày 9 nhận được")
	d.finish()


func test_buy_avatar_and_video_unlock(t: T) -> void:
	var d := D.new()
	await d.begin(DIR + "/avatar", 1, 1000, true)
	var g := d.game()
	d.main.current_screen.profile_btn.pressed.emit()
	t.ok(await d.wait_until(func() -> bool: return d.main.current_name == "profile"), "mở Profile")
	var pr: Control = d.main.current_screen
	t.ok(pr.cells.has("avatar_01"), "có ô avatar_01")
	pr.cells["avatar_01"].panel.pressed.emit()
	pr.buy_button.pressed.emit()
	var price: int = Config.cosmetic_price("avatar_01")
	t.eq(int(g.s.coins), 1000 - price, "trừ gold mua avatar")
	t.ok((g.s.cos.owned as Array).has("avatar_01"), "đã sở hữu")
	t.eq(str(g.s.cos.avatar), "avatar_01", "tự đeo")
	t.ok(await d.wait_until(func() -> bool: return pr.buy_button == null and pr.use_button != null), "ô chuyển sang đã có")
	t.eq(d.plat().an.named("spend").back().params.sink, "cosmetic", "analytics spend cosmetic")
	t.ok(d.plat().save.last_json.contains("avatar_01"), "đã mirror bản lưu")
	# thiếu gold
	g.s.coins = 0
	pr.cells["avatar_02"].panel.pressed.emit()
	pr.buy_button.pressed.emit()
	t.ok(not (g.s.cos.owned as Array).has("avatar_02"), "thiếu gold không mua được")
	t.eq(pr.status_label.text, _tr("profile_not_enough"), "báo thiếu gold")
	# đóng video sớm rồi xem hết
	d.plat().ads.simulate("closed")
	pr.cells["avatar_03"].panel.pressed.emit()
	pr.video_button.pressed.emit()
	await d.wait_until(func() -> bool: return pr.status_label.text == _tr("ads_closed_early"))
	t.ok(not (g.s.cos.owned as Array).has("avatar_03"), "đóng sớm không mở khoá")
	t.eq(pr.status_label.text, _tr("ads_closed_early"), "báo đóng sớm")
	pr.video_button.pressed.emit()
	await d.wait_until(func() -> bool: return (g.s.cos.owned as Array).has("avatar_03"))
	t.ok((g.s.cos.owned as Array).has("avatar_03"), "xem hết thì mở khoá")
	t.eq(_rewarded(d, "cosmetic_unlock").size(), 2, "hai lần gọi video cosmetic_unlock")
	# Back về Home, đồ vẫn đeo
	pr.back_btn.pressed.emit()
	t.ok(await d.wait_until(func() -> bool: return d.main.current_name == "home"), "về Home")
	t.eq(str(g.s.cos.avatar), "avatar_03", "đang đeo avatar vừa mở")
	d.finish()


func test_x2_free_video_and_closed_early(t: T) -> void:
	var d := D.new()
	await d.begin(DIR + "/x2", 1)
	var g := d.game()
	t.ok(await d.play_from_home(1), "vào L1")
	# L1: x2 miễn phí, không quảng cáo
	t.ok(await d.win_level(), "thắng L1")
	var win1 := _win_coins(d)
	t.ok(win1 > int(Config.ECON.win_coins), "L1 có gold MOVES thừa")
	t.eq(int(g.s.coins), 1000 + win1, "+gold thắng")
	t.ok(d.popup("X2Button") != null, "L1 có x2")
	d.press("X2Button")
	t.ok(await d.wait_until(func() -> bool: return int(g.s.coins) == 1000 + 2 * win1), "x2 miễn phí ở L1")
	t.eq(_rewarded(d, "x2_coins").size(), 0, "L1 không gọi quảng cáo")
	t.ok(await d.x2_to(2), "x2 xong tự sang L2")
	# L2: x2 bằng video
	t.ok(await d.win_level(), "thắng L2")
	var win2 := _win_coins(d)
	t.eq(int(g.s.coins), 1000 + 2 * win1 + win2, "+gold L2")
	d.press("X2Button")
	t.ok(await d.wait_until(func() -> bool: return int(g.s.coins) == 1000 + 2 * win1 + 2 * win2), "x2 L2 sau video")
	t.eq(_rewarded(d, "x2_coins").size(), 1, "một lần xem video x2")
	t.ok(await d.x2_to(3), "x2 xong tự sang L3")
	# L3: đóng video sớm không thưởng, thử lại được
	d.plat().ads.simulate("closed")
	t.ok(await d.win_level(), "thắng L3")
	var before := int(g.s.coins)
	d.press("X2Button")
	var msg := d.popup("MessageLabel") as Label
	await d.wait_until(func() -> bool: return msg.visible)
	t.ok(msg.visible, "báo đóng video sớm")
	t.eq(msg.text, _tr("ads_closed_early"), "nội dung báo")
	t.eq(int(g.s.coins), before, "đóng sớm không thưởng")
	d.press("X2Button")
	t.ok(await d.wait_until(func() -> bool: return int(g.s.coins) == before + _win_coins(d)), "thử lại xem hết thì x2")
	t.eq(_rewarded(d, "x2_coins").size(), 3, "tổng 3 lần gọi video x2")
	t.eq(d.plat().an.count("rv_done"), 2, "rv_done hai lần")
	t.ok(d.plat().an.count("rv_cancel") >= 1, "rv_cancel khi đóng sớm")
	t.ok(await d.x2_to(4), "x2 xong tự sang L4")
	t.eq(d.main.popup_count(), 0, "không còn popup")
	d.finish()


func test_interstitial_rules_with_x2(t: T) -> void:
	var d := D.new()
	await d.begin(DIR + "/inter", 12, -1, true)
	var g := d.game()
	g._first_session = false
	g.s.runs = 10
	g.test_now += 1000
	t.ok(await d.play_from_home(12), "vào L12")
	# L12: không x2, đến lượt: có interstitial
	t.ok(await d.win_level(), "thắng L12")
	t.ok(await d.continue_to(13), "sang L13")
	t.eq(_inters(d).size(), 1, "L12 đến lượt thì hiện inter")
	t.eq(str(_inters(d)[0].placement), "result_exit", "placement result_exit")
	# L13: đã sẵn lượt nhưng lấy x2 bằng video thì không inter
	_prep_inter(d)
	t.ok(await d.win_level(), "thắng L13")
	var coins13: int = int(g.s.coins)
	d.press("X2Button")
	t.ok(await d.wait_until(func() -> bool: return int(g.s.coins) == coins13 + _win_coins(d)), "x2 L13 cộng gold")
	t.eq(_rewarded(d, "x2_coins").size(), 1, "xem video x2 L13")
	t.ok(await d.x2_to(14), "x2 xong tự sang L14")
	t.eq(_inters(d).size(), 1, "lấy x2 thì không hiện inter")
	# L14: cùng điều kiện, không x2: hiện (đối chứng)
	_prep_inter(d)
	t.ok(await d.win_level(), "thắng L14")
	t.ok(await d.continue_to(15), "sang L15")
	t.eq(_inters(d).size(), 2, "không x2 thì hiện inter")
	# L15: mời x2, đóng video sớm (không lấy): vẫn tới lượt inter
	_prep_inter(d)
	t.ok(await d.win_level(), "thắng L15")
	d.plat().ads.simulate("closed")
	d.press("X2Button")
	var msg := d.popup("MessageLabel") as Label
	await d.wait_until(func() -> bool: return msg.visible)
	t.ok(msg.visible, "đóng sớm có báo")
	t.ok(await d.continue_to(16), "sang L16")
	t.eq(_inters(d).size(), 3, "đóng x2 sớm thì inter vẫn tới lượt")
	# L16: vừa hiện inter, chưa đủ cách quãng: không hiện nữa
	g.test_now += 1000
	t.ok(await d.win_level(), "thắng L16")
	t.ok(await d.continue_to(17), "sang L17")
	t.eq(_inters(d).size(), 3, "cách nhau chưa đủ lượt thì không inter")
	t.eq(AdPacing.inter_count_today(g.s, g.today()), 3, "đếm inter trong ngày")
	# không quảng cáo: không inter dù đến lượt
	g.s.no_ads = true
	_prep_inter(d)
	t.ok(await d.win_level(), "thắng L17")
	t.ok(await d.continue_to(18), "sang L18")
	t.eq(_inters(d).size(), 3, "đã mua bỏ quảng cáo thì không inter")
	d.finish()
