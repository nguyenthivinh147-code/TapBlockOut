extends RefCounted
## Đọc ghi bản lưu: ghi file tạm rồi đổi tên, giữ `.bak`, gọi `mirror` sau mỗi lần lưu.

const SaveSchema := preload("res://src/meta/save_schema.gd")

var path: String
var mirror: Callable
var _pending: Dictionary = {}
var _dirty: bool = false


func _init(p_path: String, p_mirror: Callable = Callable()) -> void:
	path = p_path
	mirror = p_mirror


## Thứ tự thử: file chính, `.bak`, `backup_json` truyền vào, rồi mặc định.
func load_state(backup_json: String = "") -> Dictionary:
	for src in [_read_file(path), _read_file(path + ".bak"), _parse(backup_json)]:
		if not src.is_empty():
			return SaveSchema.merge_defaults(src)
	return SaveSchema.defaults()


## Đánh dấu có thay đổi cần ghi. Nhiều lần `queue` chỉ ghi một lần ở `flush`.
func queue(s: Dictionary) -> void:
	_pending = s
	_dirty = true


func has_pending() -> bool:
	return _dirty


func flush() -> void:
	if _dirty:
		save_now(_pending)


## Ghi ngay. Trả true nếu ghi file thành công; `mirror` vẫn được gọi khi ghi file lỗi.
func save_now(s: Dictionary) -> bool:
	var json := JSON.stringify(s)
	_pending = {}
	_dirty = false
	var ok := _write_atomic(json)
	if mirror.is_valid():
		mirror.call(json)
	return ok


func _write_atomic(json: String) -> bool:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(json)
	f.flush()
	f.close()
	# Chỉ giữ làm .bak khi file hiện tại còn đọc được, để không ghi đè bản tốt bằng bản hỏng.
	if not _read_file(path).is_empty():
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


func _read_file(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	return _parse(FileAccess.get_file_as_string(p))


func _parse(json: String) -> Dictionary:
	if json.strip_edges().is_empty():
		return {}
	var j := JSON.new() # parse() không in ERROR ra log như parse_string
	if j.parse(json) != OK:
		return {}
	var v: Variant = j.data
	if v is Dictionary and not (v as Dictionary).is_empty():
		return v
	return {}


## Chọn bản chơi nhiều hơn: `runs` cao hơn, bằng nhau thì `play_ms` cao hơn, vẫn bằng thì `a`.
static func further(a: Dictionary, b: Dictionary) -> Dictionary:
	var ra := int(a.get("runs", 0))
	var rb := int(b.get("runs", 0))
	if ra != rb:
		return a if ra > rb else b
	return b if int(b.get("play_ms", 0)) > int(a.get("play_ms", 0)) else a


## Gộp `from.buys` vào `into.buys` theo `token` (mỗi phần tử là Dictionary có khoá `token`).
## Đơn chưa có ở `into` được thêm vào và gọi `grant.call(entry)` để cấp lại hàng.
## `no_ads` giữ true nếu một bên có. Trả danh sách đơn vừa cấp lại.
static func merge_purchases(into: Dictionary, from: Dictionary, grant: Callable = Callable()) -> Array:
	var buys: Array = into.get("buys", [])
	var seen := {}
	for e in buys:
		if e is Dictionary and str(e.get("token", "")) != "":
			seen[str(e["token"])] = true
	var granted: Array = []
	for e in from.get("buys", []):
		if not (e is Dictionary):
			continue
		var tok := str(e.get("token", ""))
		if tok == "" or seen.has(tok):
			continue
		seen[tok] = true
		var entry: Dictionary = (e as Dictionary).duplicate(true)
		buys.append(entry)
		granted.append(entry)
		if grant.is_valid():
			grant.call(entry)
	into["buys"] = buys
	into["no_ads"] = bool(into.get("no_ads", false)) or bool(from.get("no_ads", false))
	return granted
