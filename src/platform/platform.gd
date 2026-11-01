extends Node
## Autoload Platform (kế hoạch mục 1.9). Có singleton Android "TboPlatform" thì dùng backend
## android_*.gd, còn lại (hoặc thiếu file) dùng mock_*.gd. UI và Game chỉ gọi lớp này.

signal paused
signal resumed

const ANDROID_SINGLETON := "TboPlatform"
const MOCK_IAP_STATE := "user://mock_iap.json"
const ANDROID_CONFIG := "res://android_config.json"

var ads: Object
var iap: Object
var an: Object
var rc: Object
var save: Object
var notif: Object

var is_android: bool = false
var has_privacy: bool:
	get:
		return ads != null and ads.get("has_privacy") == true
var values: Dictionary:
	get:
		return rc.values if rc != null else {}

var _plugin: Object = null
var _overlay_depth: int = 0


func _init() -> void:
	if Engine.has_singleton(ANDROID_SINGLETON):
		_plugin = Engine.get_singleton(ANDROID_SINGLETON)
		is_android = true
	ads = _make("ads")
	iap = _make("iap")
	an = _make("an")
	rc = _make("rc")
	save = _make("save")
	notif = _make("notif")
	for o in [ads, iap]:
		if o.has_signal("overlay_shown"):
			o.connect("overlay_shown", _on_overlay_shown)
			o.connect("overlay_hidden", _on_overlay_hidden)
	if not is_android and iap.get("persist_path") != null and DisplayServer.get_name() != "headless":
		iap.persist_path = MOCK_IAP_STATE
		iap.load_state()
	if is_android:
		_init_plugin()


func _make(part: String) -> Object:
	if is_android:
		var path := "res://src/platform/android_%s.gd" % part
		if ResourceLoader.exists(path):
			var script := load(path) as GDScript
			if script != null and script.can_instantiate():
				return script.new(_plugin)
	return (load("res://src/platform/mock_%s.gd" % part) as GDScript).new()


## Sau khi các backend đã nối signal: nạp cấu hình (res:// nằm trong PCK nên Java không đọc
## được) rồi khởi tạo SDK. Thiếu file thì bỏ qua set_config, plugin tự tắt mô-đun thiếu khoá.
func _init_plugin() -> void:
	if _plugin == null:
		return
	if FileAccess.file_exists(ANDROID_CONFIG) and _plugin.has_method("set_config"):
		_plugin.call("set_config", FileAccess.get_file_as_string(ANDROID_CONFIG))
	if _plugin.has_method("init_sdks"):
		_plugin.call("init_sdks")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		paused.emit()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		resumed.emit()
		if iap != null and iap.has_method("on_resume"):
			iap.call("on_resume")


func _on_overlay_shown() -> void:
	_overlay_depth += 1
	if _overlay_depth == 1:
		paused.emit()


func _on_overlay_hidden() -> void:
	_overlay_depth = maxi(_overlay_depth - 1, 0)
	if _overlay_depth == 0:
		resumed.emit()


# --- chung ---

func haptic(ms: int) -> void:
	Input.vibrate_handheld(ms)


func review() -> void:
	_call_plugin("review")


func open_privacy() -> void:
	_call_plugin("open_privacy")


func open_debugger() -> void:
	_call_plugin("open_debugger")


func _call_plugin(method: String) -> void:
	if _plugin != null and _plugin.has_method(method):
		_plugin.call(method)


# --- ads ---

func ready_rewarded() -> bool:
	return ads.ready_rewarded()


func ready_inter() -> bool:
	return ads.ready_inter()


func load_ads() -> void:
	ads.load_ads()


func rewarded(placement: String) -> Dictionary:
	return await ads.rewarded(placement)


func inter(placement: String) -> Dictionary:
	return await ads.inter(placement)


# --- iap ---

func price(sku: String) -> String:
	return iap.price(sku)


func buy(sku: String) -> Dictionary:
	return await iap.buy(sku)


func pending() -> Array:
	return iap.pending()


func finish(p: Dictionary, consumable: bool) -> void:
	iap.finish(p, consumable)


func restore() -> bool:
	return await iap.restore()


# --- an ---

func log_event(event_name: String, params: Dictionary = {}) -> void:
	an.log_event(event_name, params)


func earn(currency: String, amount: int, source: String) -> void:
	an.earn(currency, amount, source)


func spend(currency: String, amount: int, sink: String) -> void:
	an.spend(currency, amount, sink)


func user(props: Dictionary) -> void:
	an.user(props)


# --- rc ---

func fetch() -> void:
	await rc.fetch()


# --- save ---

func mirror(json: String) -> void:
	save.mirror(json)


func backup() -> String:
	return save.backup()


func flush() -> void:
	save.flush()


func sync_cloud() -> void:
	save.sync_cloud()


# --- notif ---

func ask() -> bool:
	return await notif.ask()


func enabled() -> bool:
	return notif.enabled()


func schedule(items: Array) -> void:
	notif.schedule(items)


func cancel_all() -> void:
	notif.cancel_all()
