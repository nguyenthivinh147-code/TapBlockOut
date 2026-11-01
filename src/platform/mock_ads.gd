extends RefCounted
## Quảng cáo giả lập. Có màn hình thật thì hiện overlay Xem hết / Đóng; headless trả ngay `ok`.
## Test dùng simulate() để ép kết quả của lần gọi kế tiếp.

signal overlay_shown
signal overlay_hidden

const OVERLAY_NAME := "MockAdOverlay"

var has_privacy: bool = false
var overlay_enabled: bool = DisplayServer.get_name() != "headless"
var rewarded_loaded: bool = true
var inter_loaded: bool = true
## Nhật ký để test đọc: [{kind: "rewarded"|"inter", placement, result}]
var calls: Array[Dictionary] = []

var _queue: Array = []
var _busy: bool = false


func simulate(result: Variant) -> void:
	_queue.append(result)


func set_ready(rewarded_ok: bool, inter_ok: bool) -> void:
	rewarded_loaded = rewarded_ok
	inter_loaded = inter_ok


func ready_rewarded() -> bool:
	return rewarded_loaded


func ready_inter() -> bool:
	return inter_loaded


func load_ads() -> void:
	rewarded_loaded = true
	inter_loaded = true


func rewarded(placement: String) -> Dictionary:
	var res: Dictionary
	if _busy or not rewarded_loaded:
		res = {"ok": false, "reason": "not_ready"}
	elif not _queue.is_empty():
		res = _norm_rewarded(_queue.pop_front())
	elif overlay_enabled:
		_busy = true
		overlay_shown.emit()
		var pick := await _ask("Quảng cáo giả lập (%s)" % placement, ["Xem hết", "Đóng"])
		overlay_hidden.emit()
		_busy = false
		res = {"ok": true, "reason": ""} if pick == 0 else {"ok": false, "reason": "closed"}
	else:
		res = {"ok": true, "reason": ""}
	calls.append({"kind": "rewarded", "placement": placement, "result": res})
	return res


func inter(placement: String) -> Dictionary:
	var res: Dictionary
	if _busy or not inter_loaded:
		res = {"shown": false}
	elif not _queue.is_empty():
		res = _norm_inter(_queue.pop_front())
	elif overlay_enabled:
		_busy = true
		overlay_shown.emit()
		await _ask("Quảng cáo xen kẽ giả lập (%s)" % placement, ["Đóng"])
		overlay_hidden.emit()
		_busy = false
		res = {"shown": true}
	else:
		res = {"shown": true}
	calls.append({"kind": "inter", "placement": placement, "result": res})
	return res


func _norm_rewarded(r: Variant) -> Dictionary:
	if r is Dictionary:
		return {"ok": bool(r.get("ok", false)), "reason": str(r.get("reason", ""))}
	if r is bool:
		return {"ok": r, "reason": "" if r else "closed"}
	var s := str(r)
	return {"ok": true, "reason": ""} if s == "ok" else {"ok": false, "reason": s}


func _norm_inter(r: Variant) -> Dictionary:
	if r is Dictionary:
		return {"shown": bool(r.get("shown", false))}
	if r is bool:
		return {"shown": r}
	var s := str(r)
	return {"shown": s == "ok" or s == "shown"}


## Trả chỉ số nút được bấm.
func _ask(title: String, labels: Array[String]) -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := CanvasLayer.new()
	layer.name = OVERLAY_NAME
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 36)
	box.add_child(lbl)
	var state := {"pick": -1}
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.custom_minimum_size = Vector2(420, 96)
		b.add_theme_font_size_override("font_size", 36)
		b.pressed.connect(func() -> void: state["pick"] = i)
		box.add_child(b)
	tree.root.add_child.call_deferred(layer)
	while state["pick"] < 0:
		await tree.process_frame
	layer.get_parent().remove_child(layer)
	layer.free()
	return state["pick"]
