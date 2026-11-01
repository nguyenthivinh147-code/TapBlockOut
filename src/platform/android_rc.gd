extends RefCounted
## Remote Config thật (Firebase) qua plugin TboPlatform. Giá trị luôn là chuỗi.
## `values` có ngay từ đầu (mặc định rc_defaults + bản đã activate lần trước), fetch() làm mới.

const FETCH_TIMEOUT := 6.0

var values: Dictionary = {}
var fetch_count: int = 0
## Nhân với mọi hạn chờ (test đặt nhỏ).
var timeout_scale: float = 1.0

var _plugin: Object = null


func _init(plugin: Object = null) -> void:
	_plugin = plugin
	_read_current()


## Mock dùng để đặt giá trị khi test.
func set_values(d: Dictionary) -> void:
	values = _stringify(d)


## Không bao giờ treo: hết giờ thì giữ giá trị đang hiệu lực.
func fetch() -> void:
	fetch_count += 1
	if _plugin == null or not _plugin.has_method("rc_fetch"):
		return
	var w := _arm(Signal(_plugin, &"rc_fetched"))
	_plugin.rc_fetch()
	var got := await _until(w, FETCH_TIMEOUT)
	if got.is_empty():
		_read_current()
		return
	var j := JSON.new()
	if j.parse(str(got["args"][0])) == OK and j.data is Dictionary \
			and (j.data as Dictionary).get("values") is Dictionary:
		values = _stringify(j.data["values"])
	else:
		_read_current()


func _read_current() -> void:
	if _plugin == null or not _plugin.has_method("rc_get_all"):
		return
	var j := JSON.new()
	if j.parse(str(_plugin.rc_get_all())) == OK and j.data is Dictionary:
		values = _stringify(j.data)


static func _stringify(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v: Variant = d[k]
		# JSON đọc số thành float: 5 không được thành "5.0".
		out[str(k)] = str(int(v)) if v is float and is_equal_approx(v, floorf(v)) else str(v)
	return out


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
