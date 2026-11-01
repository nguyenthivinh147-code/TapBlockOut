extends RefCounted
## Analytics giả lập: giữ danh sách sự kiện trong bộ nhớ để test đọc.

## [{name: String, params: Dictionary}]
var events: Array[Dictionary] = []
var user_props: Dictionary = {}


func log_event(event_name: String, params: Dictionary = {}) -> void:
	events.append({"name": event_name, "params": params.duplicate()})


func earn(currency: String, amount: int, source: String) -> void:
	log_event("earn", {"currency": currency, "amount": amount, "source": source})


func spend(currency: String, amount: int, sink: String) -> void:
	log_event("spend", {"currency": currency, "amount": amount, "sink": sink})


func user(props: Dictionary) -> void:
	user_props.merge(props, true)


## Các sự kiện cùng tên, theo thứ tự.
func named(event_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if e["name"] == event_name:
			out.append(e)
	return out


func count(event_name: String) -> int:
	return named(event_name).size()


func clear() -> void:
	events.clear()
	user_props.clear()
