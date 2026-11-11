extends RefCounted
## Kiểm tra tĩnh toàn project (docs/TESTING.md "Kiểm tra tĩnh"): mọi script parse được, luật code máy kiểm được,
## không có bí mật trong file git theo dõi. Ngoại lệ ghi trong tests/static_allow.txt, mỗi dòng
## "<đường dẫn>:<luật> ## <lý do> (YYYY-MM-DD)"; mục được miễn hiện thành dòng ALLOWED.
## Luật: parse, class_name, pure_extends, pure_node, pure_platform, pure_time, secret.

const T := preload("res://tests/t.gd")

const ALLOW_PATH := "res://tests/static_allow.txt"
## Thư mục không quét script. tools/ có .gdignore nhưng script trong đó chạy bằng -s nên vẫn quét.
const SKIP_DIRS := ["res://addons", "res://art", "res://reference", "res://plans", "res://output", "res://android",
	"res://build", "res://docs"]
const PURE_DIRS := ["src/core/", "src/meta/"]
## Luật cho src/core, src/meta (CLAUDE.md "Quy ước chính"), chạy trên code đã bỏ comment và chuỗi.
const PURE_RULES := {
	"pure_node": "\\bNode\\b|\\bSceneTree\\b|\\bget_tree\\s*\\(|\\bEngine\\.get_main_loop\\b",
	"pure_platform": "\\bPlatform\\b",
	"pure_time": "\\bTime\\.get_\\w+|\\bOS\\.get_ticks_\\w+",
}
const SECRET_EXT := ["jks", "keystore", "p12"]
const SECRET_FILES := ["google-services.json", "android_config.json"]
## Chỉ file chữ mới quét nội dung tìm private key.
const TEXT_EXT := ["gd", "gdshader", "gdshaderinc", "json", "cfg", "md", "txt", "csv", "tscn", "tres", "kts", "kt",
	"java", "gradle", "xml", "properties", "sh", "mjs", "js", "py", "yml", "yaml", "pem", "key", "env", "ini",
	"toml", "html"]
const MAX_SCAN_BYTES := 2 * 1024 * 1024

## Vi phạm parse do test_scripts_parse ghi lại, dùng cho kiểm dòng allowlist thừa ở test cuối.
var _parse_found: Array[Dictionary] = []
var _allow_used: Dictionary = {}
var _allow: Dictionary = {}
var _allow_errors: Array[String] = []
var _allow_loaded := false


func test_scripts_parse(t: T) -> void:
	_load_allow_once(t)
	# load() thường (dùng cache): nạp bản thứ hai của script đang chạy (run_all.gd, file này) bằng CACHE_MODE_IGNORE
	# làm Godot 4.7.2 crash khi bản đó được giải phóng. Mỗi lần chạy test là một tiến trình mới nên cache là bản
	# vừa đọc từ đĩa.
	for path in list_scripts():
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			_parse_found.append(_v(path.trim_prefix("res://"), "parse", 0, "không parse được"))
	t.ok(not list_scripts().is_empty(), "tìm thấy script")
	_report(t, _parse_found)


func test_code_rules(t: T) -> void:
	_load_allow_once(t)
	var found: Array[Dictionary] = []
	for path in list_scripts():
		found.append_array(check_source(path.trim_prefix("res://"), FileAccess.get_file_as_string(path)))
	_report(t, found)


func test_no_secrets_tracked(t: T) -> void:
	_load_allow_once(t)
	var root := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var code := OS.execute("git", ["-C", root, "-c", "core.quotepath=off", "ls-files"], output, true)
	if code != 0 or output.is_empty():
		t.fail("git ls-files lỗi (mã %d): %s" % [code, str(output)])
		return
	var files := String(output[0]).replace("\r", "").split("\n", false)
	t.ok(files.size() > 100, "git ls-files trả danh sách file")
	var found: Array[Dictionary] = []
	for rel in files:
		if secret_path(rel):
			found.append(_v(rel, "secret", 0, "file bí mật bị git theo dõi"))
			continue
		if not TEXT_EXT.has(rel.get_extension().to_lower()):
			continue
		var f := FileAccess.open(root.path_join(rel), FileAccess.READ)
		if f == null or f.get_length() > MAX_SCAN_BYTES:
			continue
		var line := secret_line(f.get_as_text())
		if line > 0:
			found.append(_v(rel, "secret", line, "có private key"))
	_report(t, found)


## Chạy sau các test trên (cùng một instance): dòng allowlist không còn khớp vi phạm nào thì phải xoá.
func test_allow_entries_still_needed(t: T) -> void:
	_load_allow_once(t)
	for key in _allow:
		t.ok(_allow_used.has(key), "static_allow.txt:%d (%s) không còn vi phạm nào, xoá dòng này" % [_allow[key], key])


## Mọi script cần quét, đường dẫn res://.
static func list_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	_walk("res://", out)
	out.sort()
	return out


static func _walk(dir: String, out: PackedStringArray) -> void:
	for d in DirAccess.get_directories_at(dir):
		var sub := dir.path_join(d)
		if SKIP_DIRS.has(sub) or d.begins_with("."):
			continue
		if sub != "res://tools" and FileAccess.file_exists(sub.path_join(".gdignore")):
			continue
		_walk(sub, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))


## Vi phạm luật code của một file (đường dẫn tương đối gốc repo).
static func check_source(rel: String, text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lines := strip_code(text).split("\n")
	var class_re := RegEx.create_from_string("^\\s*class_name\\s+\\w")
	for i in lines.size():
		if class_re.search(lines[i]) != null:
			out.append(_v(rel, "class_name", i + 1, "dùng class_name; dùng preload (CLAUDE.md)"))
	var pure := false
	for d in PURE_DIRS:
		if rel.begins_with(d):
			pure = true
	if not pure:
		return out
	var ext_re := RegEx.create_from_string("(?m)^extends\\s+(.+)$")
	var ext := ext_re.search(text)
	var base := ext.get_string(1).strip_edges() if ext != null else ""
	if base != "RefCounted" and not (base.begins_with("\"res://src/core/") or base.begins_with("\"res://src/meta/")):
		out.append(_v(rel, "pure_extends", 0, "src/core, src/meta phải extends RefCounted, đang là '%s'" % base))
	for rule in PURE_RULES:
		var re := RegEx.create_from_string(PURE_RULES[rule])
		for i in lines.size():
			var m := re.search(lines[i])
			if m != null:
				out.append(_v(rel, rule, i + 1, "logic thuần không dùng '%s'" % m.get_string()))
	return out


## Bỏ comment và nội dung chuỗi (giữ dấu xuống dòng để số dòng không đổi).
static func strip_code(text: String) -> String:
	var re := RegEx.create_from_string(
		"\"\"\"[\\s\\S]*?\"\"\"|'''[\\s\\S]*?'''|\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'|#[^\\n]*")
	var out := PackedStringArray()
	var at := 0
	for m in re.search_all(text):
		out.append(text.substr(at, m.get_start() - at))
		var gone := m.get_string()
		out.append("\"\"" if gone.begins_with("\"") or gone.begins_with("'") else "")
		out.append("\n".repeat(gone.count("\n")))
		at = m.get_end()
	out.append(text.substr(at))
	return "".join(out)


static func secret_path(rel: String) -> bool:
	return SECRET_EXT.has(rel.get_extension().to_lower()) or SECRET_FILES.has(rel.get_file())


## Số dòng (từ 1) có private key dạng PEM, 0 nếu không có. Mẫu ghép từ nhiều mảnh để chính file này không khớp.
static func secret_line(text: String) -> int:
	var dashes := "-".repeat(5)
	var re := RegEx.create_from_string(dashes + "BEGIN [A-Z ]*PRIVATE KEY" + dashes)
	var m := re.search(text)
	if m == null:
		return 0
	return text.substr(0, m.get_start()).count("\n") + 1


static func _v(rel: String, rule: String, line: int, msg: String) -> Dictionary:
	return {"path": rel, "rule": rule, "line": line, "msg": msg}


func _report(t: T, found: Array[Dictionary]) -> void:
	for err in _allow_errors:
		t.fail(err)
	_allow_errors.clear()
	for v in found:
		var key := "%s:%s" % [v["path"], v["rule"]]
		var where := "%s:%d" % [v["path"], int(v["line"])] if int(v["line"]) > 0 else String(v["path"])
		if _allow.has(key):
			_allow_used[key] = true
			t.allow("%s %s: %s (static_allow.txt:%d)" % [where, v["rule"], v["msg"], _allow[key]])
		else:
			t.fail("%s %s: %s" % [where, v["rule"], v["msg"]])


func _load_allow_once(_t: T) -> void:
	if _allow_loaded:
		return
	_allow_loaded = true
	if not FileAccess.file_exists(ALLOW_PATH):
		return
	var date := RegEx.create_from_string("\\(\\d{4}-\\d{2}-\\d{2}\\)\\s*$")
	var lines := FileAccess.get_file_as_string(ALLOW_PATH).split("\n")
	for i in lines.size():
		var raw := lines[i].strip_edges()
		if raw.is_empty() or raw.begins_with("#"):
			continue
		var parts := raw.split(" ## ", false, 1)
		if parts.size() < 2 or not parts[0].contains(":") or date.search(parts[1]) == null:
			_allow_errors.append("static_allow.txt:%d cần dạng \"<đường dẫn>:<luật> ## <lý do> (YYYY-MM-DD)\"" % (i + 1))
			continue
		_allow[parts[0].strip_edges()] = i + 1
