extends RefCounted
## Test của chính bộ chạy test: Logger trong run_all.gd, t.expect_error, t.eq, luật của test_static_check.gd.

const T := preload("res://tests/t.gd")
const RunAll := preload("res://tests/run_all.gd")
const Static := preload("res://tests/test_static_check.gd")


func test_expect_error_absorbs_push_error(t: T) -> void:
	t.expect_error("runner_selftest_boom")
	push_error("runner_selftest_boom")
	t.ok(true, "lỗi mong đợi không làm test fail")


func test_error_log_captures_errors_not_warnings(t: T) -> void:
	var log := RunAll.ErrorLog.new()
	OS.add_logger(log)
	t.expect_error("runner_selftest_capture")
	push_error("runner_selftest_capture")
	push_warning("runner_selftest_warn")
	OS.remove_logger(log)
	var got := log.take()
	t.eq(got.size(), 1, "chỉ một lỗi được gom")
	t.ok(got.size() == 1 and got[0].contains("runner_selftest_capture"), "dòng lỗi giữ nội dung")
	t.eq(log.take().size(), 0, "take() xoá danh sách")


func test_unexpected_splits_expected_and_missing(t: T) -> void:
	var runner := Engine.get_main_loop()
	if not runner.has_method("_unexpected"):
		t.fail("main loop không phải run_all.gd")
		return
	var none: Array = runner.call("_unexpected", "selftest", PackedStringArray(["selftest boom (x.gd:1 f)"]),
		["selftest boom"] as Array[String])
	t.eq(none.size(), 0, "lỗi khớp expect_error không bị báo")
	var both: Array = runner.call("_unexpected", "selftest", PackedStringArray(["selftest boom (x.gd:1 f)"]),
		["selftest other"] as Array[String])
	t.eq(both.size(), 2, "lỗi lạ và lỗi mong đợi vắng đều bị báo")
	t.ok(both.size() == 2 and String(both[0]).begins_with("lỗi engine: selftest boom"), "báo lỗi lạ")
	t.ok(both.size() == 2 and String(both[1]).contains("selftest other"), "báo lỗi mong đợi vắng")


func test_eq_reports_first_difference(t: T) -> void:
	var inner := T.new()
	inner.eq({"a": [1, 2], "b": 1}, {"a": [1, 2], "b": 1}, "bằng")
	t.eq(inner.failures.size(), 0, "dictionary lồng bằng nhau thì đạt")
	inner.eq({"a": [1, 2]}, {"a": [1, 3]}, "khác")
	t.eq(inner.failures.size(), 1, "dictionary lồng khác nhau thì lỗi")
	t.ok(inner.failures.size() == 1 and inner.failures[0].contains(".a[1]"), "lỗi chỉ ra .a[1]")
	inner.eq(1, 1.0, "khác kiểu")
	t.eq(inner.failures.size(), 2, "int và float ở gốc vẫn khác")


func test_static_class_name_ignores_comments_and_strings(t: T) -> void:
	var hit := Static.check_source("src/ui/x.gd", "extends Node\nclass_name Foo\n")
	t.eq(_rules(hit), ["class_name"], "bắt class_name")
	t.eq(int(hit[0]["line"]) if not hit.is_empty() else 0, 2, "đúng dòng")
	var quiet := Static.check_source("src/ui/x.gd", "extends Node\n# class_name Foo\nvar s := \"class_name Bar\"\n")
	t.eq(quiet.size(), 0, "comment và chuỗi không tính")


func test_static_pure_rules(t: T) -> void:
	t.ok(_rules(Static.check_source("src/core/x.gd", "extends Node\n")).has("pure_extends"), "core phải RefCounted")
	t.eq(_rules(Static.check_source("src/meta/x.gd", "extends RefCounted\nfunc f() -> int:\n\treturn Time.get_ticks_msec()\n")),
		["pure_time"], "meta không đọc giờ")
	t.eq(_rules(Static.check_source("src/meta/x.gd", "extends RefCounted\nfunc f() -> void:\n\tPlatform.haptic(1)\n")),
		["pure_platform"], "meta không gọi Platform")
	t.eq(_rules(Static.check_source("src/meta/x.gd", "extends RefCounted\n## Không dùng Node, Platform, Time.get_x.\n")),
		[], "comment nhắc tên không tính")
	t.eq(_rules(Static.check_source("src/ui/x.gd", "extends Node\nfunc f() -> int:\n\treturn Time.get_ticks_msec()\n")),
		[], "luật thuần chỉ áp cho src/core, src/meta")


func test_static_secrets(t: T) -> void:
	t.ok(Static.secret_path("android/release.keystore"), "keystore")
	t.ok(Static.secret_path("android/config/google-services.json"), "google-services.json")
	t.ok(not Static.secret_path("android/config/platform_config.example.json"), "file mẫu không phải bí mật")
	var d := "-".repeat(5)
	t.eq(Static.secret_line("a\nb\n" + d + "BEGIN RSA PRIVATE KEY" + d + "\nxyz\n"), 3, "private key ở dòng 3")
	t.eq(Static.secret_line("BEGIN PRIVATE KEY"), 0, "không có dấu gạch thì không phải PEM")


func test_static_parse_failure_detected(t: T) -> void:
	var bad := GDScript.new()
	bad.source_code = "extends RefCounted\nfunc f(:\n\tpass\n"
	t.expect_error("Parse Error")
	bad.reload()
	t.ok(not bad.can_instantiate(), "script lỗi parse không instantiate được")
	var good := GDScript.new()
	good.source_code = "extends RefCounted\nfunc f() -> int:\n\treturn 1\n"
	t.eq(good.reload(), OK, "script đúng reload được")
	t.ok(good.can_instantiate(), "script đúng instantiate được")


func _rules(found: Array[Dictionary]) -> Array:
	var out := []
	for v in found:
		out.append(v["rule"])
	return out
