extends RefCounted
## Thông báo local thật (AlarmManager) qua plugin TboPlatform. Cùng hàm với mock_notif.gd.

const ASK_TIMEOUT := 120.0
## Icon lớn của thông báo: ảnh `res://` chép thành PNG vuông cạnh ICON_PX ở đây, plugin đọc theo đường dẫn tuyệt đối
## (receiver chạy cả khi game đã tắt nên không đọc được PCK).
const ICON_DIR := "user://notif_icons"
const ICON_PX := 192

## Nhân với mọi hạn chờ (test đặt nhỏ).
var timeout_scale: float = 1.0
var asked: bool = false
## Bản sao kế hoạch vừa gửi cho plugin: [{at, kind, title, body, icon}]
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
			"title": str(it.get("title", "")), "body": str(it.get("body", "")),
			"icon": icon_file(str(it.get("icon", "")))})
	if _plugin != null and _plugin.has_method("notif_schedule"):
		_plugin.notif_schedule(JSON.stringify(out))


## Đường dẫn tuyệt đối của bản PNG cho ảnh `res_path` (chép lần đầu, lần sau dùng lại). Rỗng nếu không có ảnh.
func icon_file(res_path: String) -> String:
	if res_path == "":
		return ""
	var dst := "%s/%s.png" % [ICON_DIR, res_path.get_file().get_basename()]
	if not FileAccess.file_exists(dst):
		var tex := load(res_path) as Texture2D
		if tex == null:
			return ""
		var img := tex.get_image()
		if img == null or img.is_empty():
			return ""
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var k := float(ICON_PX) / float(maxi(img.get_width(), img.get_height()))
		img.resize(maxi(roundi(img.get_width() * k), 1), maxi(roundi(img.get_height() * k), 1), Image.INTERPOLATE_LANCZOS)
		var sq := Image.create_empty(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
		@warning_ignore("integer_division")
		sq.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), (Vector2i(ICON_PX, ICON_PX) - img.get_size()) / 2)
		DirAccess.make_dir_recursive_absolute(ICON_DIR)
		if sq.save_png(dst) != OK:
			return ""
	return ProjectSettings.globalize_path(dst)


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
