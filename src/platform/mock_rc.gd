extends RefCounted
## Remote Config giả lập: giá trị luôn là chuỗi. Test đặt qua set_values().

var values: Dictionary = {}
var fetch_count: int = 0


func fetch() -> void:
	fetch_count += 1


func set_values(d: Dictionary) -> void:
	values = {}
	for k in d:
		values[str(k)] = str(d[k])
