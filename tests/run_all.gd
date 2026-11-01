extends SceneTree
## Chạy mọi tests/test_*.gd. Lọc: `-- test_board`. Thoát 0 nếu đạt, 1 nếu có lỗi.

const T := preload("res://tests/t.gd")
const TIMEOUT_MSEC := 120000

var _total_checks := 0
var _failed_files := 0
var _failed_tests := 0
var _passed_tests := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filters: Array[String] = []
	for a in OS.get_cmdline_user_args():
		filters.append(a)
	var files: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		printerr("Không mở được res://tests")
		quit(1)
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
	for f in files:
		await _run_file(f)
	await _release_all()
	print("---- %d test đạt, %d test lỗi, %d file lỗi, %d kiểm tra ----" % [
		_passed_tests, _failed_tests, _failed_files, _total_checks])
	quit(1 if (_failed_tests > 0 or _failed_files > 0) else 0)


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


func _run_file(f: String) -> void:
	var path := "res://tests/" + f
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		printerr("FAIL %s: không load được" % f)
		_failed_files += 1
		return
	var inst: Object = script.new()
	var deadline := Time.get_ticks_msec() + TIMEOUT_MSEC
	for m in script.get_script_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		var t := T.new()
		var state := {"done": false}
		_invoke(inst, name, t, state)
		while not state["done"]:
			if Time.get_ticks_msec() > deadline:
				printerr("FAIL %s::%s: quá 120 giây" % [f, name])
				_failed_tests += 1
				_failed_files += 1
				return
			await process_frame
		_total_checks += t.checks
		if t.failures.is_empty():
			_passed_tests += 1
			print("ok   %s::%s" % [f, name])
		else:
			_failed_tests += 1
			for msg in t.failures:
				printerr("FAIL %s::%s: %s" % [f, name, msg])


func _invoke(inst: Object, name: String, t: T, state: Dictionary) -> void:
	await inst.call(name, t)
	state["done"] = true
