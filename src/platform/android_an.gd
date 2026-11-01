extends RefCounted
## Analytics thật: Firebase Analytics (và Adjust nếu có trong adjust_events) qua plugin TboPlatform.
## Cùng hàm với mock_an.gd. Tham số được ép phẳng: số, bool, chuỗi.

## Chỉ có ở mock (để test đọc); Android không giữ sự kiện trong bộ nhớ.
var events: Array[Dictionary] = []
var user_props: Dictionary = {}

var _plugin: Object = null


func _init(plugin: Object = null) -> void:
	_plugin = plugin


func log_event(event_name: String, params: Dictionary = {}) -> void:
	if _plugin != null and _plugin.has_method("log_event"):
		_plugin.log_event(event_name, JSON.stringify(_flat(params)))


func earn(currency: String, amount: int, source: String) -> void:
	log_event("earn", {"currency": currency, "amount": amount, "source": source})


func spend(currency: String, amount: int, sink: String) -> void:
	log_event("spend", {"currency": currency, "amount": amount, "sink": sink})


func user(props: Dictionary) -> void:
	user_props.merge(props, true)
	if _plugin != null and _plugin.has_method("set_user_props"):
		var out := {}
		for k in props:
			out[str(k)] = str(props[k])
		_plugin.set_user_props(JSON.stringify(out))


## Mock dùng để đọc sự kiện khi test; Android không lưu.
func named(_event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	return out


func count(_event_name: String) -> int:
	return 0


func clear() -> void:
	user_props.clear()


static func _flat(params: Dictionary) -> Dictionary:
	var out := {}
	for k in params:
		var v: Variant = params[k]
		match typeof(v):
			TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING:
				out[str(k)] = v
			TYPE_NIL:
				pass
			_:
				out[str(k)] = str(v)
	return out
