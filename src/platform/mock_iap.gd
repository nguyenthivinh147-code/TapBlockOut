extends RefCounted
## Mua hàng giả lập. Giá lấy từ Config.SKUS. Có màn hình thật thì hiện overlay Mua / Huỷ;
## headless trả ngay `ok`. Đơn chưa finish và món mua một lần được giữ để giao lại khi mở game
## (ghi ra `persist_path` nếu đặt).

signal overlay_shown
signal overlay_hidden

const Config := preload("res://src/config.gd")
const OVERLAY_NAME := "MockIapOverlay"

var overlay_enabled: bool = DisplayServer.get_name() != "headless"
var persist_path: String = ""
## Nhật ký để test đọc: [{sku, status}]
var calls: Array[Dictionary] = []

var _queue: Array = []
var _busy: bool = false
var _pending: Array[Dictionary] = []
var _owned: Dictionary = {}  # sku -> true, chỉ món không consumable
var _seq: int = 0


func load_state() -> void:
	if persist_path == "" or not FileAccess.file_exists(persist_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(persist_path))
	if not (data is Dictionary):
		return
	_seq = int(data.get("seq", 0))
	_owned.clear()
	for sku in data.get("owned", []):
		_owned[str(sku)] = true
	_pending.clear()
	for p in data.get("pending", []):
		if p is Dictionary:
			_pending.append(p)


func simulate(result: Variant) -> void:
	_queue.append(result)


func price(sku: String) -> String:
	var info: Dictionary = Config.SKUS.get(sku, {})
	if info.is_empty():
		return ""
	return "$%.2f" % float(info.get("usd", 0.0))


func buy(sku: String) -> Dictionary:
	var res: Dictionary
	if not Config.SKUS.has(sku):
		res = {"status": "error", "sku": sku, "token": "", "order_id": ""}
	elif _owned.has(sku):
		res = {"status": "owned", "sku": sku, "token": "", "order_id": ""}
	elif _busy:
		res = {"status": "error", "sku": sku, "token": "", "order_id": ""}
	else:
		var status := "ok"
		if not _queue.is_empty():
			status = _norm(_queue.pop_front())
		elif overlay_enabled:
			_busy = true
			overlay_shown.emit()
			var pick := await _ask("Mua giả lập: %s (%s)" % [sku, price(sku)], ["Mua", "Huỷ"])
			overlay_hidden.emit()
			_busy = false
			status = "ok" if pick == 0 else "cancel"
		res = _make_result(sku, status)
	calls.append({"sku": sku, "status": res["status"]})
	return res


func pending() -> Array:
	return _pending.duplicate(true)


func finish(p: Dictionary, consumable: bool) -> void:
	var token := str(p.get("token", ""))
	for i in range(_pending.size() - 1, -1, -1):
		if str(_pending[i].get("token", "")) == token:
			_pending.remove_at(i)
	var sku := str(p.get("sku", ""))
	if not consumable and sku != "":
		_owned[sku] = true
	_save_state()


## Đưa lại món không consumable đã sở hữu vào hàng đợi (token cố định để game chống giao hai lần).
func restore() -> bool:
	if _owned.is_empty():
		return false
	for sku in _owned:
		var token := "mock_restore_%s" % sku
		var found := false
		for p in _pending:
			if str(p.get("token", "")) == token:
				found = true
		if not found:
			_pending.append({"status": "ok", "sku": sku, "token": token, "order_id": "mock_order_restore"})
	_save_state()
	return true


## Tester menu "delete account": forget owned items and unfinished orders. Tokens keep counting up.
func wipe() -> void:
	_owned.clear()
	_pending.clear()
	_save_state()


func _make_result(sku: String, status: String) -> Dictionary:
	var res := {"status": status, "sku": sku, "token": "", "order_id": ""}
	if status == "ok" or status == "invalid":
		_seq += 1
		res["token"] = "mock_token_%d" % _seq
		res["order_id"] = "mock_order_%d" % _seq
	if status == "ok":
		_pending.append(res.duplicate())
		_save_state()
	return res


func _norm(r: Variant) -> String:
	var s := str(r.get("status", "error")) if r is Dictionary else str(r)
	return s if s in ["ok", "pending", "cancel", "owned", "invalid", "error"] else "error"


func _save_state() -> void:
	if persist_path == "":
		return
	var f := FileAccess.open(persist_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"seq": _seq, "owned": _owned.keys(), "pending": _pending}))


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
