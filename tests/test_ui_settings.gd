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


## Distinct font sizes of the language names (Txt of each cell).
func _name_sizes(buttons: Dictionary) -> Array:
	var sizes: Array = []
	for code in buttons:
		var s := (buttons[code].get_node("Txt") as Label).get_theme_font_size("font_size")
		if not sizes.has(s):
			sizes.append(s)
	return sizes


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
	t.eq(_name_sizes(node.lang_buttons).size(), 1, "mọi tên ngôn ngữ cùng một cỡ chữ")
	node.lang_buttons["vi"].pressed.emit()
	t.eq(_name_sizes(node.lang_buttons).size(), 1, "đổi ngôn ngữ: tên vẫn cùng cỡ")
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
	var g := _game()
	g.test_online = 1
	var opened: Array = []
	var node := _open(opened)
	node.support_button.pressed.emit()
	t.eq(opened.size(), 1, "Support mở mail ngay, không qua popup")
	var url := str(opened[0])
	var head := "mailto:%s?subject=" % str(Config.CONTENT.support_email)
	t.ok(url.begins_with(head), "mailto tới email hỗ trợ")
	t.ok(not url.contains(" "), "đã mã hoá")
	var parts := url.trim_prefix(head).split("&body=")
	var subject := "%s - %s - 0 - v0 - USERID: %s" % [ProjectSettings.get_setting("application/config/name"),
		g.app_version(), OS.get_unique_id()]
	t.eq(parts[0].uri_decode(), subject, "tiêu đề như Unity (chạy từ project: version code 0, không ghi Android)")
	var body := parts[1].uri_decode()
	t.ok(body.begins_with("Hi there!. My account is " + g.profile_name()), "thân thư có biệt danh")
	t.eq(body.contains("--- SDK Status ---"), OS.is_debug_build(), "bản debug kèm trạng thái SDK")
	node.queue_free()


func test_support_offline(t: T) -> void:
	var g := _game()
	g.test_online = 0
	var opened: Array = []
	var notices: Array = []
	var on_notice := func(kind: String) -> void: notices.append(kind)
	g.notice.connect(on_notice)
	var node := _open(opened)
	await node._on_support()
	g.notice.disconnect(on_notice)
	t.eq(notices, ["offline"], "mất mạng: Main hiện popup No Internet")
	t.eq(opened.size(), 0, "không mở mail")
	g.test_online = 1
	node.queue_free()


## Label text of a prefab node of a popup's UView.
func _ui_text(pop: Node, path: String) -> String:
	var n: Node = pop.get("ui").call("node", path)
	return (n as Label).text if n is Label else _label_text(n)


## Privacy Policy and Terms of Service like PrivacyPolicyControl (color-cube-match-puzzle): online -> Yes/No popup
## (Notice title, the question), Yes opens the page one frame after the popup closes, No and X only close it.
func test_policy_terms_confirm_then_open(t: T) -> void:
	var g := _game()
	g.test_online = 1
	t.eq(str(Config.CONTENT.get("privacy_url", "")), "https://horusent.com/privacy-policy/", "URL Privacy như Unity")
	t.eq(str(Config.CONTENT.get("terms_url", "")), "https://horusent.com/term-conditions/", "URL Terms như Unity")
	var opened: Array = []
	var node := _open(opened)
	var tree := _root().get_tree()
	var cases := [
		[node.get("policy_button"), "Privacy Policy", "Do you want to read the privacy policy?", "privacy_url"],
		[node.get("terms_button"), "Terms of Service", "Do you want to read the terms of use?", "terms_url"],
	]
	for c in cases:
		var b: Button = c[0]
		t.ok(b != null, "có dòng " + str(c[1]))
		if b == null:
			continue
		t.eq(_label_text(b), str(c[1]), "chữ dòng " + str(c[1]))
		for close in ["Panel/Content/Button/Cancel", "Panel/Top/btnTurnOff"]:
			b.pressed.emit()
			var pop: Node = node.confirm_panel
			t.ok(pop != null, "%s mở popup hỏi" % c[1])
			if pop == null:
				continue
			t.eq(_ui_text(pop, "Panel/Image/txtHeader"), "Notice", "tiêu đề Notice")
			t.eq(_ui_text(pop, "Panel/Content/Description"), str(c[2]), "câu hỏi")
			t.eq(_ui_text(pop, "Panel/Content/Button/Ok"), "Yes", "nút Yes")
			t.eq(_ui_text(pop, "Panel/Content/Button/Cancel"), "No", "nút No")
			t.ok((pop.get("ui").call("node", "Panel/Content/Button/Cancel") as Control).visible, "hiện nút No")
			b.pressed.emit()
			t.eq(node.confirm_panel, pop, "chạm lần nữa không mở popup thứ hai")
			(pop.get("ui").call("node", close) as Button).pressed.emit()
			await tree.process_frame
			await tree.process_frame
			t.eq(opened.size(), 0, "%s: không mở trang" % close.get_file())
			t.eq(node.confirm_panel, null, "%s đóng popup" % close.get_file())
		b.pressed.emit()
		var yes_pop: Node = node.confirm_panel
		if yes_pop == null:
			continue
		(yes_pop.get("ui").call("node", "Panel/Content/Button/Ok") as Button).pressed.emit()
		t.eq(opened.size(), 0, "Yes: đóng popup, chờ một khung rồi mới mở")
		await tree.process_frame
		await tree.process_frame
		t.eq(opened, [str(Config.CONTENT.get(c[3], ""))], "Yes mở trang " + str(c[1]))
		opened.clear()
	node.queue_free()


func test_policy_terms_offline(t: T) -> void:
	var g := _game()
	g.test_online = 0
	var opened: Array = []
	var notices: Array = []
	var on_notice := func(kind: String) -> void: notices.append(kind)
	g.notice.connect(on_notice)
	var node := _open(opened)
	await node.call("_on_link", "policy")
	await node.call("_on_link", "terms")
	g.notice.disconnect(on_notice)
	t.eq(notices, ["offline", "offline"], "mất mạng: Main hiện popup No Internet")
	t.eq(node.get("confirm_panel"), null, "không mở popup hỏi")
	t.eq(opened.size(), 0, "không mở trang")
	g.test_online = 1
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
	var hits: Array = [node.close_button, node.support_button, node.language_button, node.restore_button, node.version_button,
		node.get("policy_button"), node.get("terms_button")]
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
		t.ok(node.find_child("HelpButton", true, false) == null, "cài đặt trong màn không có dòng hỗ trợ")
		node.queue_free()
