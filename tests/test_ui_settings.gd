extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")

const DIR := "user://test_ui_settings"


class FakePlugin extends RefCounted:
	var debugger_calls: int = 0
	var privacy_calls: int = 0

	func open_debugger() -> void:
		debugger_calls += 1

	func open_privacy() -> void:
		privacy_calls += 1


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _game() -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	var p: Node = _root().get_node("Platform")
	p.ads.has_privacy = false
	p._plugin = null
	TranslationServer.set_locale("en")
	return g


func _open(opened: Array) -> Control:
	var node := (load("res://scenes/settings.tscn") as PackedScene).instantiate() as Control
	node.opener = func(url: String) -> void: opened.append(url)
	_root().add_child(node)
	node.setup({})
	return node


func test_toggles_write_settings(t: T) -> void:
	var g := _game()
	var node := _open([])
	for key in ["sfx", "music", "haptics", "notif", "arrows"]:
		t.ok(node.toggle_buttons.has(key), "có nút " + key)
		t.eq(bool(g.s.settings[key]), true, key + " mặc định bật")
		node.toggle_buttons[key].pressed.emit()
		t.eq(bool(g.s.settings[key]), false, key + " tắt")
		t.ok(node.toggle_buttons[key].custom_minimum_size.y >= 96, key + " đủ lớn")
		node.toggle_buttons[key].pressed.emit()
		t.eq(bool(g.s.settings[key]), true, key + " bật lại")
	node.toggle_buttons["sfx"].pressed.emit()
	t.eq(_root().get_node("Sfx").sfx_on, false, "Sfx nhận cài đặt")
	node.toggle_buttons["sfx"].pressed.emit()
	node.queue_free()


func test_language(t: T) -> void:
	var g := _game()
	var node := _open([])
	t.eq(node.lang_buttons.size(), 3, "3 lựa chọn ngôn ngữ")
	node.lang_buttons["vi"].pressed.emit()
	t.eq(str(g.s.settings.lang), "vi", "lưu lang vi")
	t.eq(TranslationServer.get_locale().begins_with("vi"), true, "đổi locale")
	node.lang_buttons["en"].pressed.emit()
	t.eq(str(g.s.settings.lang), "en", "lưu lang en")
	node.lang_buttons[""].pressed.emit()
	t.eq(str(g.s.settings.lang), "", "theo thiết bị")
	node.queue_free()
	TranslationServer.set_locale("en")


func test_privacy_only_when_available(t: T) -> void:
	_game()
	var plugin := FakePlugin.new()
	var node := _open([])
	t.eq(node.privacy_button, null, "không có Privacy khi chưa cần")
	node.queue_free()
	_root().get_node("Platform").ads.has_privacy = true
	_root().get_node("Platform")._plugin = plugin
	node = _open([])
	t.ok(node.privacy_button != null, "có Privacy")
	node.privacy_button.pressed.emit()
	t.eq(plugin.privacy_calls, 1, "mở Privacy")
	node.queue_free()
	_root().get_node("Platform")._plugin = null


func test_support_mailto_not_really_opened(t: T) -> void:
	_game()
	var opened: Array = []
	var node := _open(opened)
	node.support_button.pressed.emit()
	t.eq(opened.size(), 1, "gọi opener một lần")
	t.ok(str(opened[0]).begins_with("mailto:" + str(Config.CONTENT.support_email)), "mailto tới email hỗ trợ")
	t.ok(str(opened[0]).contains("subject="), "có tiêu đề")
	t.ok(not str(opened[0]).contains(" "), "tiêu đề đã mã hoá")
	node.queue_free()


func test_restore(t: T) -> void:
	_game()
	var node := _open([])
	await node._on_restore()
	t.eq(node.status_label.text, "Nothing to restore.", "không có gì để khôi phục")
	node.queue_free()


func test_version_and_tester_menu(t: T) -> void:
	_game()
	var plugin := FakePlugin.new()
	_root().get_node("Platform")._plugin = plugin
	var node := _open([])
	t.ok(node.version_button.text.contains(str(Config.CONTENT.build)), "hiện phiên bản")
	for i in 6:
		node.version_button.pressed.emit()
	t.eq(node.tester_panel, null, "6 lần chưa mở")
	node.version_button.pressed.emit()
	t.ok(node.tester_panel != null, "7 lần mở menu tester")
	node.debugger_button.pressed.emit()
	t.eq(plugin.debugger_calls, 1, "mở mediation debugger")
	node.close_tester()
	t.eq(node.tester_panel, null, "đóng menu tester")
	node.queue_free()
	_root().get_node("Platform")._plugin = null


func test_close_signal(t: T) -> void:
	_game()
	var node := _open([])
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	node.close_button.pressed.emit()
	t.eq(got.size(), 1, "closed phát")
	node.queue_free()
