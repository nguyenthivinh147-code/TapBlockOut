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


## Text of the first label inside a prefab button (TMP child).
func _label_text(b: Node) -> String:
	var l := b.find_children("*", "Label", true, false)
	return (l[0] as Label).text if not l.is_empty() else ""


func _open(opened: Array) -> Control:
	var node := (load("res://scenes/settings.tscn") as PackedScene).instantiate() as Control
	node.opener = func(url: String) -> void: opened.append(url)
	_root().add_child(node)
	node.setup({})
	return node


func test_toggles_write_settings(t: T) -> void:
	var g := _game()
	var node := _open([])
	t.ok(not node.toggle_buttons.has("arrows"), "không còn nút mũi tên")
	for key in ["sfx", "music", "haptics", "notif"]:
		t.ok(node.toggle_buttons.has(key), "có nút " + key)
		t.eq(bool(g.s.settings[key]), true, key + " mặc định bật")
		node.toggle_buttons[key].pressed.emit()
		t.eq(bool(g.s.settings[key]), false, key + " tắt")
		t.ok(node.toggle_buttons[key].hit_size().y >= 96, key + " đủ lớn")
		node.toggle_buttons[key].pressed.emit()
		t.eq(bool(g.s.settings[key]), true, key + " bật lại")
	node.toggle_buttons["sfx"].pressed.emit()
	t.eq(_root().get_node("Sfx").sfx_on, false, "Sfx nhận cài đặt")
	node.toggle_buttons["sfx"].pressed.emit()
	node.queue_free()


func test_language(t: T) -> void:
	var g := _game()
	var node := _open([])
	t.eq(node.lang_buttons.size(), 0, "chưa mở popup Language")
	node.language_button.pressed.emit()
	t.ok(node.language_panel != null, "nút Language mở popup")
	t.eq(node.lang_buttons.keys(), g.LANGS, "14 ngôn ngữ theo thứ tự, không có ô theo thiết bị")
	t.eq(g.LANGS.size(), 14, "đủ 14 ngôn ngữ")
	var lit: Array = []
	for code in node.lang_buttons:
		if node.lang_buttons[code].button_pressed:
			lit.append(code)
	t.eq(lit, [g.current_lang()], "chưa chọn: sáng ô ngôn ngữ của máy")
	t.eq(_label_text(node.lang_buttons["ja"]), "日本語", "tên ngôn ngữ viết bằng chính nó")
	t.eq(_label_text(node.lang_buttons["pt_BR"]), "Português (Brasil)", "tên pt_BR")
	node.lang_buttons["vi"].pressed.emit()
	t.ok(node.language_panel != null, "đổi ngôn ngữ vẫn mở popup")
	t.eq(_label_text(node.language_button), "Ngôn ngữ", "chữ đổi theo ngôn ngữ mới")
	t.eq(str(g.s.settings.lang), "vi", "lưu lang vi")
	t.eq(TranslationServer.get_locale().begins_with("vi"), true, "đổi locale")
	node.lang_buttons["pt_BR"].pressed.emit()
	t.eq(str(g.s.settings.lang), "pt_BR", "lưu lang pt_BR")
	t.eq(TranslationServer.get_locale(), "pt_BR", "locale pt_BR")
	t.eq(node.lang_buttons["pt_BR"].button_pressed, true, "ô vừa chọn sáng")
	t.eq(node.lang_buttons["vi"].button_pressed, false, "ô cũ tắt")
	node.lang_buttons["en"].pressed.emit()
	t.eq(str(g.s.settings.lang), "en", "lưu lang en")
	node.language_panel.find_child("LanguageOk", true, false).pressed.emit()
	t.eq(node.language_panel, null, "OK đóng popup Language")
	node.queue_free()
	TranslationServer.set_locale("en")


func test_device_language(t: T) -> void:
	var g := _game()
	t.eq(g.match_lang("vi_VN"), "vi", "vi_VN -> vi")
	t.eq(g.match_lang("pt_BR"), "pt_BR", "pt_BR")
	t.eq(g.match_lang("pt_PT"), "pt_BR", "tiếng Bồ khác vùng -> pt_BR")
	t.eq(g.match_lang("in_ID"), "id", "mã cũ Android in -> id")
	t.eq(g.match_lang("ja_JP"), "ja", "ja_JP -> ja")
	t.eq(g.match_lang("es_MX"), "es", "es_MX -> es")
	t.eq(g.match_lang("zh_CN"), "en", "ngôn ngữ chưa có -> en")
	g.s.settings.lang = "ko"
	t.eq(g.current_lang(), "ko", "mã đã chọn thắng ngôn ngữ máy")
	g.s.settings.lang = "xx"
	t.eq(g.current_lang(), g.match_lang(OS.get_locale()), "mã lạ trong bản lưu -> theo máy")
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
	t.eq(opened.size(), 0, "Support mở popup Help trước, chưa gửi mail")
	var help: Control = node.help_panel
	t.ok(help != null, "popup Help")
	# Pick the purchase topic, write a message, Send.
	(help.find_child("Topic_purchase", true, false).get_node("Pick") as Button).pressed.emit()
	t.eq(str(help.get("topic")), "settings_help_purchase", "chọn chủ đề")
	(help.get("message") as TextEdit).text = "Lost my gold"
	(help.find_child("SaveButton", true, false) as Button).pressed.emit()
	t.eq(opened.size(), 1, "gọi opener một lần")
	t.ok(str(opened[0]).begins_with("mailto:" + str(Config.CONTENT.support_email)), "mailto tới email hỗ trợ")
	t.ok(str(opened[0]).contains("subject="), "có tiêu đề")
	t.ok(str(opened[0]).contains("body=Lost%20my%20gold"), "thân thư có nội dung")
	t.ok(not str(opened[0]).contains(" "), "đã mã hoá")
	t.eq(node.help_panel, null, "Gửi đóng popup Help")
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
	t.ok(_label_text(node.version_button).contains(str(Config.CONTENT.build)), "hiện phiên bản")
	for i in 9:
		node.version_button.pressed.emit()
	t.eq(node.tester_panel, null, "9 lần chưa mở")
	node.version_button.pressed.emit()
	t.ok(node.tester_panel != null, "10 lần mở menu tester")
	node.tester_panel.debugger_button.pressed.emit()
	t.eq(plugin.debugger_calls, 1, "mở mediation debugger")
	node.tester_panel.close()
	t.eq(node.tester_panel, null, "X đóng menu tester, Settings vẫn mở")
	node.queue_free()
	_root().get_node("Platform")._plugin = null


func test_tester_save_closes_settings(t: T) -> void:
	var g := _game()
	Config.account_tool_override = 1
	var node := _open([])
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	node.open_tester()
	node.tester_panel.fields["coins"].text = "777"
	node.tester_panel.save_button.pressed.emit()
	t.eq(int(g.s.coins), 777, "lưu gold")
	t.eq(node.tester_panel, null, "menu tester đóng")
	t.eq(got.size(), 1, "Settings đóng để Main dựng lại Home")
	node.queue_free()


func test_close_signal(t: T) -> void:
	_game()
	var node := _open([])
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	node.close_button.pressed.emit()
	t.eq(got.size(), 1, "closed phát")
	node.queue_free()


func test_prefab_layout_touch_targets(t: T) -> void:
	_game()
	var node := _open([])
	var card: Control = node.find_child("PauseMenu", true, false)
	t.ok(absf(card.size.x - 724.0) < 0.5, "rộng popup theo prefab SettingMainMenuLayer (724)")
	var hits: Array = [node.close_button, node.support_button, node.language_button, node.restore_button, node.version_button]
	hits.append_array(node.toggle_buttons.values())
	for b in hits:
		var s: Vector2 = b.hit_size()
		t.ok(s.x >= 95.9 and s.y >= 95.9, "%s chạm được ít nhất 96 px" % (b as Node).name)
	node.queue_free()


func test_ingame_life_badge(t: T) -> void:
	_game()
	for cost in [false, true]:
		var node := (load("res://scenes/popup_ingame_settings.tscn") as PackedScene).instantiate() as Control
		_root().add_child(node)
		node.setup({"life_cost": cost})
		t.eq(node.home_button.find_child("LifeBadge", true, false) != null, cost, "huy hiệu -1 tim trên Home khi life_cost=%s" % cost)
		t.eq(node.retry_button.find_child("LifeBadge", true, false) != null, cost, "huy hiệu -1 tim trên Retry khi life_cost=%s" % cost)
		node.queue_free()
