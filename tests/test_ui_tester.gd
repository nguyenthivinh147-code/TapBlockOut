extends RefCounted
## Menu tester (scenes/tester_menu.tscn) và Game.tester_edit / tester_wipe.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_ui_tester"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _game(account: bool = true) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	Config.account_tool_override = 1 if account else 0
	var p: Node = _root().get_node("Platform")
	p.save.last_json = ""
	p.save.cloud_json = ""
	p.iap = MockIap.new()
	p._plugin = null
	TranslationServer.set_locale("en")
	return g


func _open() -> Control:
	var node := (load("res://scenes/tester_menu.tscn") as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.setup({})
	return node


func test_fields_show_account(t: T) -> void:
	var g := _game()
	g.s.coins = 345
	g.s.level = 12
	g.s.inv = {"hint": 1, "move": 2, "smash": 3}
	var node := _open()
	t.ok(node.is_in_group(node.GROUP), "trong nhóm tester_menu (F1 tìm thấy)")
	var want := {"coins": "345", "level": "12", "hint": "1", "move": "2", "smash": "3"}
	for k in want:
		t.ok(node.fields.has(k), "có ô " + k)
		t.eq(node.fields[k].text, want[k], "ô %s hiện giá trị hiện tại" % k)
	t.ok(node.save_button != null and node.wipe_button != null, "có Save và Delete account")
	t.ok(node.debugger_button != null, "vẫn có Mediation debugger")
	node.queue_free()


func test_release_build_has_debugger_only(t: T) -> void:
	_game(false)
	var node := _open()
	t.eq(node.fields.size(), 0, "bản phát hành không có ô sửa tài khoản")
	t.eq(node.save_button, null, "không có Save")
	t.eq(node.wipe_button, null, "không có Delete account")
	t.ok(node.debugger_button != null, "có Mediation debugger")
	node.queue_free()


func test_save_writes_account(t: T) -> void:
	var g := _game()
	var node := _open()
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	var coins: Array = []
	g.coins_changed.connect(func(v: int) -> void: coins.append(v))
	var vals := {"coins": "5000", "level": "37", "hint": "4", "move": "5", "smash": "6"}
	for k in vals:
		node.fields[k].text = vals[k]
	node.save_button.pressed.emit()
	t.eq(int(g.s.coins), 5000, "gold")
	t.eq(int(g.s.level), 37, "level")
	t.eq(g.s.inv, {"hint": 4, "move": 5, "smash": 6}, "booster")
	t.eq(coins, [5000], "phát coins_changed cho thanh trên")
	t.eq(got, [{"action": "changed"}], "đóng với action changed")
	var an: Object = _root().get_node("Platform").an
	t.eq(an.count("earn") + an.count("spend"), 0, "không log earn/spend")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/save.json"))
	t.eq(int(saved.coins), 5000, "đã ghi file lưu")
	node.queue_free()


func test_save_rejects_bad_numbers(t: T) -> void:
	var g := _game()
	var node := _open()
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	node.fields["coins"].text = "12a"
	node.fields["level"].text = "0"
	node.save_button.pressed.emit()
	t.eq(got.size(), 0, "số sai thì không đóng")
	t.eq(int(g.s.coins), int(Config.ECON.start_coins), "không lưu gì")
	t.eq(int(g.s.level), 1, "level giữ nguyên")
	t.ok(node.fields["coins"].get_theme_color("font_color") == node.BAD_INK, "ô sai tô đỏ")
	t.ok(node.fields["hint"].get_theme_color("font_color") != node.BAD_INK, "ô đúng giữ màu")
	node.queue_free()


func test_wipe_needs_second_tap(t: T) -> void:
	var g := _game()
	await g.boot()
	g.s.coins = 9999
	g.s.level = 50
	g.s.runs = 80
	g.s.settings.lang = "vi"
	g.save_now()
	var p: Node = _root().get_node("Platform")
	p.iap.finish({"sku": "remove_ads", "token": "x"}, false)
	t.ok(p.save.backup() != "", "có bản backup trước khi xoá")
	var node := _open()
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	node.wipe_button.pressed.emit()
	t.eq(int(g.s.coins), 9999, "lần chạm đầu chỉ hỏi lại")
	t.eq(got.size(), 0, "chưa đóng")
	await node._on_wipe()
	t.eq(got, [{"action": "wiped"}], "đóng với action wiped")
	t.eq(int(g.s.coins), int(Config.ECON.start_coins), "gold về mặc định")
	t.eq(int(g.s.level), 1, "level 1")
	t.eq(int(g.s.runs), 0, "runs 0")
	t.eq(str(g.s.settings.lang), "", "cài đặt về mặc định")
	t.eq(int(g.s.meta.sessions), 1, "như lần cài đầu")
	t.eq(bool(await p.restore()), false, "mock IAP quên món đã mua")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/save.json"))
	t.eq(int(saved.runs), 0, "file lưu là tài khoản mới")
	t.eq(JSON.parse_string(p.save.backup()).get("runs"), 0.0, "backup là tài khoản mới")
	node.queue_free()
	TranslationServer.set_locale("en")


func test_game_refuses_without_account_tool(t: T) -> void:
	var g := _game(false)
	t.eq(g.tester_edit({"coins": 1000}), false, "tester_edit tắt ở bản phát hành")
	t.eq(int(g.s.coins), int(Config.ECON.start_coins), "gold không đổi")
	g.s.coins = 77
	t.eq(await g.tester_wipe(), false, "tester_wipe tắt ở bản phát hành")
	t.eq(int(g.s.coins), 77, "không xoá")


func _wait_until(cond: Callable, ms: int = 6000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _root().get_tree().process_frame
	return cond.call()


func _f1() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_F1
	e.pressed = true
	return e


func _menu() -> Node:
	for n in _root().get_tree().get_nodes_in_group("tester_menu"):
		if not n.is_queued_for_deletion():
			return n
	return null


func test_main_f1(t: T) -> void:
	var g := _game()
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_root().add_child(m)
	t.ok(await _wait_until(func() -> bool: return m.is_booted), "boot xong")
	m.go("home")
	m._input(_f1())
	t.ok(_menu() != null, "F1 mở menu tester")
	t.eq(m.popup_count(), 1, "nằm trong lớp popup")
	m._input(_f1())
	t.eq(_menu(), null, "F1 lần nữa đóng")
	t.eq(m.popup_count(), 0, "lớp popup trống")
	var home: Node = m.current_screen
	m._input(_f1())
	_menu().fields["level"].text = "5"
	_menu().save_button.pressed.emit()
	t.eq(int(g.s.level), 5, "lưu level")
	t.ok(m.current_screen != home, "dựng lại Home")
	t.eq(m.popup_count(), 0, "lưu xong menu đóng")
	m.current_screen.find_child("SettingsButton", true, false).pressed.emit()
	m._input(_f1())
	t.eq(m.popup_count(), 2, "F1 mở trên Settings")
	var menu := _menu()
	menu.wipe_button.pressed.emit()
	await menu._on_wipe()
	t.eq(int(g.s.level), 1, "xoá tài khoản: level 1")
	t.eq(m.popup_count(), 0, "xoá xong đóng mọi popup")
	t.eq(m.current_name, "home", "về Home")
	m.free()


func test_edit_clamps(t: T) -> void:
	var g := _game()
	g.tester_edit({"coins": -5, "level": -3, "inv": {"hint": -1, "bomb": 9}})
	t.eq(int(g.s.coins), 0, "gold không âm")
	t.eq(int(g.s.level), 1, "level ít nhất 1")
	t.eq(int(g.s.inv.hint), 0, "booster không âm")
	t.ok(not g.s.inv.has("bomb"), "bỏ loại booster lạ")
