extends RefCounted
## Quảng cáo thật (AppLovin MAX qua plugin Kotlin TboPlatform). Cùng hàm với mock_ads.gd.
## Mọi chờ signal đều có hạn: plugin luôn phát kết quả, hạn chỉ là lưới an toàn để game không treo.

signal overlay_shown
signal overlay_hidden

const SHOW_TIMEOUT := 180.0
const CALLS_MAX := 50

## Nhân với mọi hạn chờ (test đặt nhỏ để thử trường hợp treo).
var timeout_scale: float = 1.0
## Placement rewarded còn dở lúc app bị đóng ở phiên trước. Game trao lại rồi gọi lost_done().
var lost: Array = []
## Nhật ký giống mock: [{kind: "rewarded"|"inter", placement, result}]
var calls: Array[Dictionary] = []
## Chỉ có ở mock; Android bỏ qua.
var overlay_enabled: bool = false

var has_privacy: bool:
	get:
		return _has("has_privacy") and bool(_plugin.has_privacy())
var rewarded_loaded: bool:
	get:
		return ready_rewarded()
var inter_loaded: bool:
	get:
		return ready_inter()

var _plugin: Object = null
var _busy: bool = false


func _init(plugin: Object = null) -> void:
	_plugin = plugin
	if _has("lost_rewarded"):
		for pl in _plugin.lost_rewarded():
			lost.append(str(pl))


## Mock dùng để ép kết quả khi test; plugin thật không có.
func simulate(_result: Variant) -> void:
	pass


func set_ready(_rewarded_ok: bool, _inter_ok: bool) -> void:
	pass


func ready_rewarded() -> bool:
	return _has("ready_rewarded") and bool(_plugin.ready_rewarded())


func ready_inter() -> bool:
	return _has("ready_inter") and bool(_plugin.ready_inter())


func load_ads() -> void:
	if _has("load_ads"):
		_plugin.load_ads()


func lost_done() -> void:
	lost = []
	if _has("lost_done"):
		_plugin.lost_done()


func rewarded(placement: String) -> Dictionary:
	var res: Dictionary
	if _busy:
		res = {"ok": false, "reason": "error"}
	elif not ready_rewarded() or not _has("show_rewarded"):
		res = {"ok": false, "reason": "not_ready"}
	else:
		_busy = true
		overlay_shown.emit()
		var w := _arm([Signal(_plugin, &"ad_rewarded_done")],
				func(a: Array) -> bool: return str(a[0]) == placement)
		_plugin.show_rewarded(placement)
		var got := await _until(w, SHOW_TIMEOUT)
		overlay_hidden.emit()
		_busy = false
		res = _norm_rewarded(got)
	_log("rewarded", placement, res)
	return res


func inter(placement: String) -> Dictionary:
	var res: Dictionary
	if _busy or not ready_inter() or not _has("show_inter"):
		res = {"shown": false}
	else:
		_busy = true
		overlay_shown.emit()
		var w := _arm([Signal(_plugin, &"ad_interstitial_done")],
				func(a: Array) -> bool: return str(a[0]) == placement)
		_plugin.show_inter(placement)
		var got := await _until(w, SHOW_TIMEOUT)
		overlay_hidden.emit()
		_busy = false
		res = {"shown": got.size() > 0 and bool(got["args"][1])}
	_log("inter", placement, res)
	return res


## args: (placement, ok, reason). Hết giờ hoặc lạ thì `error`.
func _norm_rewarded(got: Dictionary) -> Dictionary:
	if got.is_empty():
		return {"ok": false, "reason": "error"}
	var a: Array = got["args"]
	if bool(a[1]):
		return {"ok": true, "reason": ""}
	var why := str(a[2])
	return {"ok": false, "reason": why if why in ["closed", "not_ready", "error"] else "error"}


func _log(kind: String, placement: String, res: Dictionary) -> void:
	calls.append({"kind": kind, "placement": placement, "result": res})
	if calls.size() > CALLS_MAX:
		calls.pop_front()


func _has(method: String) -> bool:
	return _plugin != null and _plugin.has_method(method)


## Nối trước khi gọi plugin để không lỡ signal phát đồng bộ.
func _arm(sigs: Array, filter: Callable = Callable()) -> Dictionary:
	var w := {"done": false, "i": -1, "args": [], "cbs": [], "sigs": sigs}
	for i in sigs.size():
		var idx := i
		var cb := func(...args: Array) -> void:
			if bool(w["done"]):
				return
			if filter.is_valid() and not bool(filter.call(args)):
				return
			w["done"] = true
			w["i"] = idx
			w["args"] = args
		(sigs[i] as Signal).connect(cb)
		(w["cbs"] as Array).append(cb)
	return w


## {"i", "args"} khi có signal, {} khi hết giờ. Sau hạn còn đợi thêm một khung hình
## để signal xếp hàng lúc app ở nền kịp được giao.
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
	var sigs: Array = w["sigs"]
	var cbs: Array = w["cbs"]
	for i in sigs.size():
		if (sigs[i] as Signal).is_connected(cbs[i]):
			(sigs[i] as Signal).disconnect(cbs[i])
	w["cbs"] = []  # cắt vòng tham chiếu lambda <-> w
	if not bool(w["done"]):
		return {}
	return {"i": w["i"], "args": w["args"]}
