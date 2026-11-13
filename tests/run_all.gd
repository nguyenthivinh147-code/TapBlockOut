extends SceneTree
## Chạy mọi tests/test_*.gd. Lọc: `-- test_board` (tên file bắt đầu bằng chuỗi lọc). Thường gọi qua tools/test.sh.
## Lỗi engine hoặc lỗi script ghi ra trong lúc một test chạy làm test đó fail, trừ lỗi test khai bằng
## t.expect_error() và lỗi khớp tests/allow_errors.txt (in dòng ALLOWED). Dòng cuối: "ALL TESTS PASSED (<n>)"
## hoặc "TESTS FAILED <n> of <m>"; thoát 0 nếu đạt, 1 nếu có lỗi (docs/TESTING.md).

const T := preload("res://tests/t.gd")
const TIMEOUT_MSEC := 120000
const ALLOW_PATH := "res://tests/allow_errors.txt"


## Gom lỗi engine và lỗi script (không gom warning). Logger chạy trên nhiều luồng nên có mutex.
class ErrorLog:
	extends Logger
	var errors: PackedStringArray = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var what := rationale if not rationale.is_empty() else code
		mutex.lock()
		errors.append("%s (%s:%d %s)" % [what, file.get_file(), line, function])
		mutex.unlock()

	func take() -> PackedStringArray:
		mutex.lock()
		var e := errors.duplicate()
		errors.clear()
		mutex.unlock()
		return e


var _total_checks := 0
var _failed_files := 0
var _failed_tests := 0
var _passed_tests := 0
var _allowed := 0
var _errlog := ErrorLog.new()
## Mỗi phần tử {"text": chuỗi con, "line": số dòng} của allow_errors.txt.
var _allow: Array[Dictionary] = []
## Per-file limit; TEST_FILE_TIMEOUT=<seconds> raises it (the coverage run is slower).
var _timeout_msec := TIMEOUT_MSEC
## Coverage run (tools/affected.sh --coverage): CANDY_COV_OUT names a JSONL file; after each test file one line
## {test, ms, failed, hits} lists the methods of the instrumented src/**/*.gd it entered (tests/coverage_hits.gd).
var _cov: Object = null
var _cov_out: FileAccess = null


func _initialize() -> void:
	OS.add_logger(_errlog)
	var limit := OS.get_environment("TEST_FILE_TIMEOUT")
	if limit.is_valid_int() and int(limit) > 0:
		_timeout_msec = int(limit) * 1000
	var cov_path := OS.get_environment("CANDY_COV_OUT")
	if not cov_path.is_empty():
		_cov = load("res://tests/coverage_hits.gd")
		_cov_out = FileAccess.open(cov_path, FileAccess.WRITE)
	_run.call_deferred()


func _run() -> void:
	var filters: Array[String] = []
	for a in OS.get_cmdline_user_args():
		filters.append(a)
	if not _load_allow():
		_finish()
		return
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		printerr("Không mở được res://tests")
		_failed_files += 1
		_finish()
		return
	for f in dir.get_files():
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		if not filters.is_empty():
			var hit := false
			for flt in filters:
				if f.begins_with(flt):
					hit = true
			if not hit:
				continue
		files.append(f)
	files.sort()
	if files.is_empty():
		printerr("FAIL không có file test nào khớp %s" % str(filters))
		_failed_files += 1
	for f in files:
		var started := Time.get_ticks_msec()
		var failed_before := _failed_tests + _failed_files
		if _cov_out != null:
			(_cov.get("hits") as Dictionary).clear()
		await _run_file(f)
		if _cov_out != null:
			_cov_write(f, Time.get_ticks_msec() - started, _failed_tests + _failed_files - failed_before)
	await _release_all()
	_report_stray("sau test cuối")
	_finish()


func _finish() -> void:
	OS.remove_logger(_errlog)
	print("---- %d test đạt, %d test lỗi, %d file lỗi, %d kiểm tra ----" % [
		_passed_tests, _failed_tests, _failed_files, _total_checks])
	print("ALLOWED %d" % _allowed)
	var failed := _failed_tests + _failed_files
	if failed == 0:
		print("ALL TESTS PASSED (%d)" % _passed_tests)
	else:
		print("TESTS FAILED %d of %d" % [failed, _passed_tests + _failed_tests])
	quit(1 if failed > 0 else 0)


## Đọc allowlist: mỗi dòng "<chuỗi con> ## <lý do> (YYYY-MM-DD)"; dòng trống và dòng bắt đầu bằng # bỏ qua.
## Dòng thiếu lý do hoặc ngày làm lần chạy fail, để mọi mục miễn đều có lý do.
func _load_allow() -> bool:
	if not FileAccess.file_exists(ALLOW_PATH):
		return true
	var lines := FileAccess.get_file_as_string(ALLOW_PATH).split("\n")
	var date := RegEx.create_from_string("\\(\\d{4}-\\d{2}-\\d{2}\\)\\s*$")
	var good := true
	for i in lines.size():
		var raw := lines[i].strip_edges()
		if raw.is_empty() or raw.begins_with("#"):
			continue
		var parts := raw.split(" ## ", false, 1)
		if parts.size() < 2 or parts[0].strip_edges().is_empty() or date.search(parts[1]) == null:
			printerr("FAIL allow_errors.txt:%d cần dạng \"<chuỗi con> ## <lý do> (YYYY-MM-DD)\"" % (i + 1))
			good = false
			continue
		_allow.append({"text": parts[0].strip_edges(), "line": i + 1})
	if not good:
		_failed_files += 1
	return good


## Dọn cache tĩnh và dừng audio trước khi thoát để không rò tài nguyên.
## Playback audio chỉ được gỡ khi luồng mixer chạy thêm vài bước, nên đợi một chút.
func _release_all() -> void:
	var sfx := root.get_node_or_null("Sfx")
	if sfx != null and sfx.has_method("release_all"):
		sfx.call("release_all")
	var kit := load("res://src/ui/theme_kit.gd") as GDScript
	if kit != null:
		kit.call("clear_cache")
	for i in 6:
		await create_timer(0.05).timeout


func _cov_write(f: String, ms: int, failed: int) -> void:
	var ids := PackedStringArray()
	for k in (_cov.get("hits") as Dictionary):
		ids.append(str(k))
	_cov_out.store_line(JSON.stringify({"test": f.get_basename(), "ms": ms, "failed": failed, "hits": ids}))
	_cov_out.flush()


func _run_file(f: String) -> void:
	_report_stray("trước " + f)
	var path := "res://tests/" + f
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		printerr("FAIL %s: không load được %s" % [f, " | ".join(_errlog.take())])
		_failed_files += 1
		return
	var inst: Object = script.new()
	var init_errors := _unexpected(f, _errlog.take(), [])
	if not init_errors.is_empty():
		for msg in init_errors:
			printerr("FAIL %s: %s" % [f, msg])
		_failed_files += 1
	var deadline := Time.get_ticks_msec() + _timeout_msec
	for m in script.get_script_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		var t := T.new()
		var state := {"done": false}
		_errlog.take()
		_invoke(inst, name, t, state)
		while not state["done"]:
			if Time.get_ticks_msec() > deadline:
				printerr("FAIL %s::%s: quá %d giây" % [f, name, _timeout_msec / 1000])
				_failed_tests += 1
				_failed_files += 1
				return
			await process_frame
		_total_checks += t.checks
		for note in t.allowed_notes:
			_allowed += 1
			print("ALLOWED %s::%s: %s" % [f, name, note])
		var problems: Array[String] = []
		problems.append_array(t.failures)
		problems.append_array(_unexpected("%s::%s" % [f, name], _errlog.take(), t.expected_errors))
		if problems.is_empty():
			_passed_tests += 1
			print("ok   %s::%s" % [f, name])
		else:
			_failed_tests += 1
			for msg in problems:
				printerr("FAIL %s::%s: %s" % [f, name, msg])


## Lỗi engine không được mong đợi trong `errors`. Lỗi khớp allowlist in ALLOWED và không tính; lỗi mong đợi
## (t.expect_error) phải xuất hiện ít nhất một lần.
func _unexpected(id: String, errors: PackedStringArray, expected: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for e in errors:
		var hit := false
		for x in expected:
			if e.contains(x):
				seen[x] = true
				hit = true
		if hit:
			continue
		var allowed := false
		for a in _allow:
			if e.contains(String(a["text"])):
				allowed = true
				_allowed += 1
				print("ALLOWED %s: %s (allow_errors.txt:%d)" % [id, e, int(a["line"])])
				break
		if not allowed:
			out.append("lỗi engine: " + e)
	for x in expected:
		if not seen.has(x):
			out.append("lỗi mong đợi không xuất hiện: " + x)
	return out


## Lỗi ghi ra ngoài lúc một test chạy (giữa hai file, lúc dọn cuối) không gán được cho test nào: vẫn làm lần chạy fail.
func _report_stray(where: String) -> void:
	var stray := _unexpected("(%s)" % where, _errlog.take(), [])
	if stray.is_empty():
		return
	for msg in stray:
		printerr("FAIL (%s): %s" % [where, msg])
	_failed_files += 1


func _invoke(inst: Object, name: String, t: T, state: Dictionary) -> void:
	await inst.call(name, t)
	state["done"] = true
