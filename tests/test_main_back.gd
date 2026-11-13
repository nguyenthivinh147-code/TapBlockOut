extends RefCounted
## Android Back (Main._notification NOTIFICATION_WM_GO_BACK_REQUEST) on popups that must not just emit closed(null):
## - Language over Settings: Back closes Language only; Back again closes Settings through close(), so a language change
##   rebuilds Home. Before: Back closed Settings (Language is its child, not a Main popup) and Home kept the old texts.
## - League result (week result and league up): Back claims like a tap anywhere. Before: closed(null), no reward.
## - How to earn rewards over Weekly Pass: Back closes it only; Back again closes the pass. Before: closed(null) closed both.
## - Back reaches Main while the notification travels down the tree, so Main handles it a step later: before, the Home
##   rebuild and the reward fly failed ("Parent node is busy setting up children") and the screen stayed blank.
const T := preload("res://tests/t.gd")
const Driver := preload("res://tests/e2e_driver.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")

const DIR := "user://test_main_back"
const LB_RESULT := "res://scenes/popup_lb_result.tscn"


## Back as it reaches the game: the notification travels down from the root (smoke.gd back()), so every ancestor of
## Main is busy while Main handles it; a Back that rebuilds Home must still add the new screen.
func _back(main: Control) -> void:
	main.get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await main.get_tree().process_frame


func _idle(d: Driver) -> bool:
	return await d.wait_until(func() -> bool: return d.main.curtain == null and d.main.get("_slide_out") == null)


func test_back_closes_language_then_settings(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 20, -1, true, false)
	var main := d.main
	var lang: String = d.game().current_lang()
	t.ok(await _idle(d), "Home đứng yên")
	d.dismiss_strays()
	var home_id := (main.current_screen as Node).get_instance_id()
	main.call("_popup_then", main.SETTINGS, {}, true)
	var settings: Node = main.call("_top_popup")
	settings.call("open_language")
	var panel: Node = settings.get("language_panel")
	t.ok(panel != null, "mở Ngôn ngữ trên Settings")
	panel.call("_pick", "vi" if lang != "vi" else "en")
	var count: int = main.popup_count()
	await _back(main)
	t.eq(settings.get("language_panel"), null, "Back đóng Ngôn ngữ")
	t.eq(main.popup_count(), count, "Settings vẫn mở")
	t.eq(main.call("_top_popup"), settings, "Settings là popup trên cùng")
	await _back(main)
	t.eq(main.popup_count(), count - 1, "Back lần hai đóng Settings")
	t.ok((main.current_screen as Node).get_instance_id() != home_id, "đổi ngôn ngữ rồi Back thì dựng lại Home")
	d.game().set_setting("lang", lang)
	d.finish()


func test_back_on_week_result_claims(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 80, -1, true, false)
	var main := d.main
	var g := d.game()
	t.ok(await _idle(d), "Home đứng yên")
	d.dismiss_strays()
	g.lb_refresh()
	Leaderboard.add_points(g.s, 160)
	g.test_now = Driver.NOW + 7 * 86400
	var week: Dictionary = g.lb_week_result_view()
	t.ok(not week.is_empty(), "có kết quả tuần")
	var coins := int(g.s.coins)
	var p: Node = main.open_popup(LB_RESULT, {"week": week})
	t.eq(main.call("_top_popup"), p, "popup kết quả tuần trên cùng")
	await _back(main)
	t.eq(int(g.s.coins), coins + 300, "Back nhận thưởng Gold còn chờ")
	t.eq(g.lb_week_result_view(), {}, "hết kết quả tuần")
	t.ok(main.popup_count() == 0 or main.call("_top_popup") != p, "popup đã đóng")
	d.finish()


func test_back_on_league_up_claims(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 80, -1, true, false)
	var main := d.main
	var g := d.game()
	t.ok(await _idle(d), "Home đứng yên")
	d.dismiss_strays()
	g.lb_refresh()
	Leaderboard.add_points(g.s, 150)
	var view: Dictionary = g.lb_pending_view()
	t.ok(not view.is_empty(), "có thưởng lên giải")
	var coins := int(g.s.coins)
	var p: Node = main.open_popup(LB_RESULT, {"view": view})
	t.eq(main.call("_top_popup"), p, "popup lên giải trên cùng")
	await _back(main)
	t.eq(int(g.s.coins), coins + 300, "Back nhận thưởng lên Gold")
	t.eq(g.lb_pending_view(), {}, "hết thưởng chờ")
	d.finish()


## Weekly Pass (OQ-10 chốt 2026-11-13, TC_CA_WP_093): Back đóng popup How to earn rewards (con của layer, không phải
## popup của Main) trước, Back lần hai đóng layer. Trước khi sửa: layer không có on_back nên Main phát closed(null) và
## đóng cả layer cùng popup con.
func test_back_closes_weekly_howto_then_layer(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 27, -1, true, false)
	var main := d.main
	var g := d.game()
	t.ok(await _idle(d), "Home đứng yên")
	d.dismiss_strays()
	g.weekly_refresh()
	g.s.weekly.tut_seen = true  # layer không tự chạy tutorial
	t.eq(g.weekly_state(), "active", "Weekly Pass đang Active")
	var count: int = main.popup_count()
	main.call("_popup_then", main.WEEKLY_PASS, {}, false)
	var layer: Node = main.call("_top_popup")
	t.eq(main.popup_count(), count + 1, "mở layer Weekly Pass")
	var howto: Node = layer.call("open_howto")
	t.ok(howto != null, "mở How to earn rewards trên layer")
	# By id: before the fix Back frees the layer and its child, and a lambda capturing a freed node raises.
	var layer_id := layer.get_instance_id()
	var howto_id := howto.get_instance_id()
	await _back(main)
	await d.wait_until(func() -> bool: return not is_instance_id_valid(howto_id), 2000)
	t.ok(not is_instance_id_valid(howto_id), "Back đóng How to earn rewards")
	t.ok(is_instance_id_valid(layer_id), "Back không đóng layer")
	t.eq(main.popup_count(), count + 1, "layer vẫn mở")
	if not is_instance_id_valid(layer_id):
		d.finish()
		return
	t.eq(main.call("_top_popup"), layer, "layer là popup trên cùng")
	await _back(main)
	t.ok(await d.wait_until(func() -> bool: return main.popup_count() == count, 3000), "Back lần hai đóng layer")
	d.finish()
