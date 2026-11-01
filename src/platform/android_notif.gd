extends RefCounted
## Thông báo local thật (AlarmManager) qua plugin TboPlatform. Cùng hàm với mock_notif.gd.

const ASK_TIMEOUT := 120.0

## Nhân với mọi hạn chờ (test đặt nhỏ).
var timeout_scale: float = 1.0
var asked: bool = false
## Bản sao kế hoạch vừa gửi cho plugin: [{at, kind, title, body}]
var scheduled: Array[Dictionary] = []
## Quyền thông báo hiện tại (giống `granted` của mock).
var granted: bool:
	get:
		return enabled()

var _plugin: Object = null


func _init(plugin: Object = null) -> void:
	_plugin = plugin


## Xin quyền (Android 13+). Hết giờ coi như chưa được cấp.
func ask() -> bool:
	asked = true
	if _plugin == null or not _plugin.has_method("notif_ask"):
		return false
	var w := _arm(Signal(_plugin, &"notif_permission"))
	_plugin.notif_ask()
	var got := await _until(w, ASK_TIMEOUT)
	if got.is_empty():
		return enabled()
	return bool(got["args"][0])


func enabled() -> bool:
	return _plugin != null and _plugin.has_method("notif_enabled") and bool(_plugin.notif_enabled())


func schedule(items: Array) -> void:
	scheduled.clear()
	var out: Array = []
	for it in items:
		if not (it is Dictionary):
			continue
		scheduled.append(it.duplicate())
		out.append({"at": int(it.get("at", 0)), "kind": str(it.get("kind", "")),
			"title": str(it.get("title", "")), "body": str(it.get("body", ""))})
	if _plugin != null and _plugin.has_method("notif_schedule"):
		_plugin.notif_schedule(JSON.stringify(out))


func cancel_all() -> void:
	scheduled.clear()
	if _plugin != null and _plugin.has_method("notif_cancel_all"):
		_plugin.notif_cancel_all()


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
