extends RefCounted
## Sao lưu cloud thật (Play Games Saved Games qua plugin TboPlatform). Cùng hàm với mock_save.gd.
## File save chính vẫn do SaveStore ghi ở user:// (Android Auto Backup phủ thư mục này).
## Ở đây: đẩy bản mirror lên cloud (gộp lần, không ghi đè bản cloud đang đi trước), giữ bản cloud
## ở `cache_path` để `backup()` trả cho SaveStore làm dự phòng, gộp `buys` khi có xung đột.

const SaveStore := preload("res://src/meta/save_store.gd")

## Cloud_load có thể hiện giao diện đăng nhập nên hạn dài.
const LOAD_TIMEOUT := 60.0
const SAVE_TIMEOUT := 30.0
## Hai lần đẩy cloud tối thiểu cách nhau (giây); flush() bỏ qua giới hạn này.
const PUSH_GAP_SEC := 90
## Sau khi đồng bộ lỗi, thử lại ở flush() không sớm hơn (giây).
const RETRY_GAP_SEC := 300

signal cloud_synced(json: String)

var last_json: String = ""
var mirror_count: int = 0
var flush_count: int = 0
var sync_count: int = 0
## Bản cloud thắng ở lần đồng bộ gần nhất ("" nếu chưa có). Game có thể đọc để khôi phục.
var cloud_json: String = ""
var cache_path: String = "user://cloud_backup.json"
## Nhân với mọi hạn chờ và khoảng cách (test đặt nhỏ).
var timeout_scale: float = 1.0

var _plugin: Object = null
var _backup: String = ""
var _loser: String = ""
var _synced: bool = false
var _syncing: bool = false
var _pushing: bool = false
var _trailing: bool = false
var _dirty: bool = false
## Account deleted from the tester menu: the cloud copy loaded later is ignored and overwritten by the next push.
var _wiped: bool = false
var _last_push_at: int = -1000000
var _last_sync_try: int = -1000000


func _init(plugin: Object = null, p_cache_path: String = "") -> void:
	_plugin = plugin
	if p_cache_path != "":
		cache_path = p_cache_path
	if FileAccess.file_exists(cache_path):
		_backup = FileAccess.get_file_as_string(cache_path)
	if _plugin != null and _plugin.has_signal("cloud_conflict"):
		_plugin.connect("cloud_conflict", _on_conflict)


func _on_conflict(loser_json: String) -> void:
	_loser = loser_json


func mirror(json: String) -> void:
	last_json = json
	mirror_count += 1
	_dirty = true
	_maybe_push(false)


func backup() -> String:
	return _backup


func flush() -> void:
	flush_count += 1
	if not _synced:
		if _now() - _last_sync_try >= int(RETRY_GAP_SEC * timeout_scale):
			sync_cloud()
		return
	_maybe_push(true)


## Chạy nền (Game không await). Đọc cloud, gộp xung đột, rồi cho phép đẩy bản local.
func sync_cloud() -> void:
	sync_count += 1
	if _syncing or _synced or _plugin == null or not _plugin.has_method("cloud_load"):
		return
	_syncing = true
	_last_sync_try = _now()
	_loser = ""
	var w := _arm(Signal(_plugin, &"cloud_loaded"))
	_plugin.cloud_load()
	var got := await _until(w, LOAD_TIMEOUT)
	_syncing = false
	if got.is_empty() or not bool(got["args"][1]):
		return
	var raw := str(got["args"][0])
	if _wiped:
		raw = ""
		_loser = ""
	var win := _parse(raw)
	var write_back := false
	if _loser != "":
		var lose := _parse(_loser)
		if not lose.is_empty():
			SaveStore.merge_purchases(win, lose)
			write_back = true
		_loser = ""
	_synced = true
	cloud_json = JSON.stringify(win) if write_back else (raw if not win.is_empty() else "")
	if cloud_json != "":
		_store_backup(cloud_json)
	if write_back:
		await _cloud_save(cloud_json)
	cloud_synced.emit(cloud_json)
	_maybe_push(false)


## Tester menu "delete account": forget the cloud copy here and in the cache file, so backup() is empty and
## the next push (the fresh save) is not held back by an older cloud copy that played further.
func wipe() -> void:
	_wiped = true
	_backup = ""
	_loser = ""
	cloud_json = ""
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(cache_path)


func _maybe_push(force: bool) -> void:
	if not _synced or not _dirty or _pushing or _plugin == null:
		return
	var wait_s := int(PUSH_GAP_SEC * timeout_scale) - (_now() - _last_push_at)
	if force or wait_s <= 0:
		_push()
	elif not _trailing:
		_trailing = true
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.create_timer(float(wait_s)).timeout
		_trailing = false
		_maybe_push(true)


func _push() -> void:
	_pushing = true
	var json := last_json
	var local := _parse(json)
	var cloud := _parse(cloud_json)
	# Bản local còn thua cloud (cài lại, chưa khôi phục): không ghi đè bản tốt hơn.
	if local.is_empty() or _cloud_ahead(local, cloud):
		_pushing = false
		return
	var ok := await _cloud_save(json)
	_pushing = false
	_last_push_at = _now()
	if ok:
		if last_json == json:
			_dirty = false
		cloud_json = json
		_store_backup(json)


func _cloud_save(json: String) -> bool:
	if _plugin == null or not _plugin.has_method("cloud_save"):
		return false
	var w := _arm(Signal(_plugin, &"cloud_saved"))
	_plugin.cloud_save(json)
	var got := await _until(w, SAVE_TIMEOUT)
	return not got.is_empty() and bool(got["args"][0])


## Cùng thứ tự với SaveStore.further: runs, rồi play_ms.
static func _cloud_ahead(local: Dictionary, cloud: Dictionary) -> bool:
	if cloud.is_empty():
		return false
	var rl := int(local.get("runs", 0))
	var rc := int(cloud.get("runs", 0))
	if rl != rc:
		return rc > rl
	return int(cloud.get("play_ms", 0)) > int(local.get("play_ms", 0))


func _store_backup(json: String) -> void:
	_backup = json
	var f := FileAccess.open(cache_path, FileAccess.WRITE)
	if f != null:
		f.store_string(json)


func _parse(json: String) -> Dictionary:
	if json.strip_edges().is_empty():
		return {}
	var j := JSON.new()
	if j.parse(json) == OK and j.data is Dictionary:
		return j.data
	return {}


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _arm(sig: Signal) -> Dictionary:
	var w := {"done": false, "args": [], "cb": Callable(), "sig": sig}
	var cb := func(...args: Array) -> void:
		if not bool(w["done"]):
			w["done"] = true
			w["args"] = args
	w["cb"] = cb
	sig.connect(cb)
	return w


func _until(w: Dictionary, timeout_s: float) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var limit := Time.get_ticks_msec() + int(timeout_s * timeout_scale * 1000.0)
	var late := false
	while tree != null and not bool(w["done"]):
		if Time.get_ticks_msec() >= limit:
			if late:
				break
			late = true
		await tree.process_frame
	var sig: Signal = w["sig"]
	if sig.is_connected(w["cb"]):
		sig.disconnect(w["cb"])
	w["cb"] = Callable()  # cắt vòng tham chiếu lambda <-> w
	return {"args": w["args"]} if bool(w["done"]) else {}
