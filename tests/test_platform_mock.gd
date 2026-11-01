extends RefCounted
const T := preload("res://tests/t.gd")
const MockAds := preload("res://src/platform/mock_ads.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const MockAn := preload("res://src/platform/mock_an.gd")
const MockRc := preload("res://src/platform/mock_rc.gd")
const MockSave := preload("res://src/platform/mock_save.gd")
const MockNotif := preload("res://src/platform/mock_notif.gd")
const PlatformScript := preload("res://src/platform/platform.gd")

const DIR := "user://test_platform_mock"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## Bấm nút `idx` của overlay tên `overlay_name` sau vài khung hình.
func _press(overlay_name: String, idx: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for _i in 10:
		await tree.process_frame
		var layer := _root().get_node_or_null(overlay_name)
		if layer != null:
			var buttons := layer.find_children("*", "Button", true, false)
			if buttons.size() > idx:
				(buttons[idx] as Button).pressed.emit()
				return


func test_autoload_backend(t: T) -> void:
	var p: Node = _root().get_node("Platform")
	t.ok(p.ads is MockAds, "ads là mock")
	t.ok(p.iap is MockIap, "iap là mock")
	t.ok(p.an is MockAn, "an là mock")
	t.ok(p.rc is MockRc, "rc là mock")
	t.ok(p.save is MockSave, "save là mock")
	t.ok(p.notif is MockNotif, "notif là mock")
	t.eq(p.is_android, false, "không phải Android")
	t.eq(p.has_privacy, false, "has_privacy")
	t.eq(p.values, {}, "values rỗng")
	t.ok(p.has_signal("paused") and p.has_signal("resumed"), "signal")
	var r: Dictionary = await p.rewarded("test")
	t.eq(r["ok"], true, "headless rewarded ok")
	p.ads.calls.clear()


func test_pause_signals(t: T) -> void:
	var p: Node = PlatformScript.new()
	var seen := {"p": 0, "r": 0}
	p.paused.connect(func() -> void: seen["p"] += 1)
	p.resumed.connect(func() -> void: seen["r"] += 1)
	p._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	p._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	t.eq(seen["p"], 1, "paused")
	t.eq(seen["r"], 1, "resumed")
	p.free()


func test_ads_default_and_simulate(t: T) -> void:
	var a := MockAds.new()
	a.overlay_enabled = false
	t.eq(a.ready_rewarded(), true, "ready")
	t.eq((await a.rewarded("double"))["ok"], true, "mặc định ok")
	t.eq((await a.inter("level_end"))["shown"], true, "inter mặc định")
	a.simulate("closed")
	var r: Dictionary = await a.rewarded("double")
	t.eq(r["ok"], false, "closed ok=false")
	t.eq(r["reason"], "closed", "closed reason")
	a.simulate({"ok": false, "reason": "error"})
	t.eq((await a.rewarded("x"))["reason"], "error", "dictionary")
	a.simulate(false)
	t.eq((await a.inter("x"))["shown"], false, "inter false")
	a.simulate("ok")
	t.eq((await a.rewarded("x"))["ok"], true, "simulate ok")
	a.set_ready(false, false)
	t.eq((await a.rewarded("x"))["reason"], "not_ready", "chưa sẵn sàng")
	t.eq((await a.inter("x"))["shown"], false, "inter chưa sẵn sàng")
	a.load_ads()
	t.eq(a.ready_rewarded() and a.ready_inter(), true, "load_ads")
	t.eq(a.calls.size(), 8, "nhật ký")
	t.eq(a.calls[0]["placement"], "double", "placement")


func test_ads_overlay(t: T) -> void:
	var a := MockAds.new()
	a.overlay_enabled = true
	var seen := {"shown": 0, "hidden": 0}
	a.overlay_shown.connect(func() -> void: seen["shown"] += 1)
	a.overlay_hidden.connect(func() -> void: seen["hidden"] += 1)
	_press(MockAds.OVERLAY_NAME, 0)
	var r: Dictionary = await a.rewarded("double")
	t.eq(r["ok"], true, "Xem hết")
	_press(MockAds.OVERLAY_NAME, 1)
	r = await a.rewarded("double")
	t.eq(r["ok"], false, "Đóng")
	t.eq(r["reason"], "closed", "reason closed")
	_press(MockAds.OVERLAY_NAME, 0)
	t.eq((await a.inter("level_end"))["shown"], true, "inter overlay")
	t.eq(seen["shown"], 3, "overlay_shown")
	t.eq(seen["hidden"], 3, "overlay_hidden")
	await (Engine.get_main_loop() as SceneTree).process_frame
	t.ok(_root().get_node_or_null(MockAds.OVERLAY_NAME) == null, "overlay đã dọn")


func test_iap_flow(t: T) -> void:
	var i := MockIap.new()
	i.overlay_enabled = false
	t.eq(i.price("gold_pack_1"), "$1.99", "giá")
	t.eq(i.price("khong_co"), "", "giá sku lạ")
	t.eq((await i.buy("khong_co"))["status"], "error", "sku lạ")
	var r: Dictionary = await i.buy("gold_pack_1")
	t.eq(r["status"], "ok", "mua ok")
	t.ok(str(r["token"]) != "", "có token")
	t.eq(i.pending().size(), 1, "đơn treo")
	i.finish(r, true)
	t.eq(i.pending().size(), 0, "finish xoá đơn")
	var r2: Dictionary = await i.buy("gold_pack_1")
	t.ok(r2["token"] != r["token"], "token khác nhau")
	i.finish(r2, true)
	i.simulate("cancel")
	t.eq((await i.buy("gold_pack_1"))["status"], "cancel", "huỷ")
	i.simulate("invalid")
	var bad: Dictionary = await i.buy("gold_pack_1")
	t.eq(bad["status"], "invalid", "invalid")
	t.eq(i.pending().size(), 0, "invalid không vào đơn treo")
	i.simulate({"status": "pending"})
	t.eq((await i.buy("gold_pack_1"))["status"], "pending", "pending")
	t.eq(i.pending().size(), 0, "pending chưa giao")


func test_iap_non_consumable_and_restore(t: T) -> void:
	var i := MockIap.new()
	i.overlay_enabled = false
	t.eq(i.restore(), false, "chưa có gì để restore")
	var r: Dictionary = await i.buy("remove_ads")
	t.eq(r["status"], "ok", "mua remove_ads")
	i.finish(r, false)
	t.eq((await i.buy("remove_ads"))["status"], "owned", "đã sở hữu")
	t.eq(i.restore(), true, "restore")
	var pend := i.pending()
	t.eq(pend.size(), 1, "restore đưa vào đơn treo")
	t.eq(pend[0]["sku"], "remove_ads", "sku restore")
	i.restore()
	t.eq(i.pending().size(), 1, "restore không nhân đôi")
	i.finish(pend[0], false)
	t.eq(i.pending().size(), 0, "finish đơn restore")


func test_iap_persist(t: T) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR + "/iap.json"
	DirAccess.remove_absolute(path)
	var i := MockIap.new()
	i.overlay_enabled = false
	i.persist_path = path
	var r: Dictionary = await i.buy("gold_pack_2")
	var b: Dictionary = await i.buy("remove_ads")
	i.finish(b, false)
	var j := MockIap.new()
	j.persist_path = path
	j.load_state()
	t.eq(j.pending().size(), 1, "đơn treo còn sau khi mở lại")
	t.eq(j.pending()[0]["token"], r["token"], "đúng token")
	t.eq((await j.buy("remove_ads"))["status"], "owned", "sở hữu còn")
	DirAccess.remove_absolute(path)


func test_iap_overlay(t: T) -> void:
	var i := MockIap.new()
	i.overlay_enabled = true
	_press(MockIap.OVERLAY_NAME, 0)
	var r: Dictionary = await i.buy("gold_pack_1")
	t.eq(r["status"], "ok", "Mua")
	i.finish(r, true)
	_press(MockIap.OVERLAY_NAME, 1)
	t.eq((await i.buy("gold_pack_1"))["status"], "cancel", "Huỷ")


func test_an(t: T) -> void:
	var a := MockAn.new()
	a.log_event("level_start", {"level": 3})
	a.earn("gold", 50, "level_win")
	a.spend("gold", 900, "booster_hint")
	a.user({"level": 3})
	t.eq(a.events.size(), 3, "số sự kiện")
	t.eq(a.count("level_start"), 1, "count")
	t.eq(a.named("earn")[0]["params"]["amount"], 50, "earn amount")
	t.eq(a.named("earn")[0]["params"]["source"], "level_win", "earn source")
	t.eq(a.named("spend")[0]["params"]["sink"], "booster_hint", "spend sink")
	t.eq(a.user_props["level"], 3, "user props")
	a.clear()
	t.eq(a.events.size(), 0, "clear")


func test_rc_save_notif(t: T) -> void:
	var rc := MockRc.new()
	rc.set_values({"econ_win_coins": 60, "x": "y"})
	t.eq(rc.values["econ_win_coins"], "60", "rc là chuỗi")
	rc.fetch()
	t.eq(rc.fetch_count, 1, "fetch")
	var s := MockSave.new()
	t.eq(s.backup(), "", "chưa có backup")
	s.mirror("{\"a\":1}")
	t.eq(s.backup(), "{\"a\":1}", "backup")
	s.flush()
	s.sync_cloud()
	t.eq(s.mirror_count + s.flush_count + s.sync_count, 3, "đếm gọi")
	var n := MockNotif.new()
	t.eq(n.ask(), true, "ask")
	t.eq(n.enabled(), true, "enabled")
	n.schedule([{"at": 100, "kind": "daily", "title": "a", "body": "b"}])
	t.eq(n.scheduled.size(), 1, "schedule")
	t.eq(n.scheduled[0]["kind"], "daily", "kind")
	n.cancel_all()
	t.eq(n.scheduled.size(), 0, "cancel_all")
