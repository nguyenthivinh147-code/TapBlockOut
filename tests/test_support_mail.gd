extends RefCounted
const T := preload("res://tests/t.gd")
const SupportMail := preload("res://src/meta/support_mail.gd")


class FakePlugin extends RefCounted:
	var status: String = "{}"

	func module_status() -> String:
		return status


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_subject_like_unity(t: T) -> void:
	var info := {"product": "Candy Away", "version": "0.1.0", "version_code": "7", "os": "Android", "device_id": " ab12 "}
	t.eq(SupportMail.subject(info), "Candy Away - 0.1.0 - 7 - v0 - Android - USERID: ab12", "Android, id bỏ khoảng trắng")
	info.os = "iOS"
	t.eq(SupportMail.subject(info), "Candy Away - 0.1.0 - 7 - v0 - IOS - USERID: ab12", "iOS ghi IOS")
	info.os = "Windows"
	t.eq(SupportMail.subject(info), "Candy Away - 0.1.0 - 7 - v0 - USERID: ab12", "máy khác không ghi hệ điều hành")


func test_body(t: T) -> void:
	t.eq(SupportMail.body("CD_123456"), "Hi there!. My account is CD_123456", "người chơi: một câu")
	var sdk := {"max": true, "interstitial": "inter_1", "rewarded": "rv_1", "firebase": false, "adjust": true,
		"adjust_env": "sandbox", "adjust_token": "tok"}
	t.eq(SupportMail.body("Mint", sdk), "Hi there!. My account is Mint\n--- SDK Status ---\n"
		+ "Max SDK Initialized: True\nInterstitial: inter_1\nRewarded: rv_1\nFirebase Initialized: False\n"
		+ "Adjust SDK Initialized: True\nAdjust Environment: sandbox\nAdjust Token: tok\n", "tester: thêm trạng thái SDK")


func test_is_tester(t: T) -> void:
	t.eq(SupportMail.is_tester(false, "abc", []), false, "bản phát hành, máy thường")
	t.eq(SupportMail.is_tester(true, "abc", []), true, "bản debug")
	t.eq(SupportMail.is_tester(false, " abc ", ["abc"]), true, "máy tester")
	t.eq(SupportMail.is_tester(false, "", [""]), false, "id trống không phải tester")


func test_url_encoded(t: T) -> void:
	t.eq(SupportMail.url("a@b.c", "A - B: 1", "x!\ny&z"), "mailto:a@b.c?subject=A%20-%20B%3A%201&body=x%21%0Ay%26z",
		"mã hoá như Uri.EscapeDataString")


func test_platform_status(t: T) -> void:
	var p: Node = _root().get_node("Platform")
	var old: Object = p._plugin
	p._plugin = null
	var st: Dictionary = p.support_status()
	t.eq([st.max, st.firebase, st.adjust], [false, false, false], "không có plugin: chưa khởi tạo")
	var fake := FakePlugin.new()
	fake.status = '{"ads": true, "ads_ready": true, "firebase": true, "adjust": false}'
	p._plugin = fake
	st = p.support_status()
	t.eq([st.max, st.firebase, st.adjust], [true, true, false], "đọc module_status của plugin")
	fake.status = "not json"
	t.eq(bool(p.support_status().max), false, "module_status hỏng")
	p._plugin = old


func test_version_code_without_export(t: T) -> void:
	var g: Node = _root().get_node("Game")
	t.ok(not FileAccess.file_exists("res://build_info.json"), "build_info.json chỉ có trong bản xuất")
	t.eq(g.version_code(), "0", "chạy từ project: 0")
