extends RefCounted
## Thông báo giả lập: ghi lại lịch để test đọc.

var granted: bool = true
var asked: bool = false
## [{at: int, kind: String, title: String, body: String}]
var scheduled: Array[Dictionary] = []


func ask() -> bool:
	asked = true
	return granted


func enabled() -> bool:
	return granted


func schedule(items: Array) -> void:
	scheduled.clear()
	for it in items:
		if it is Dictionary:
			scheduled.append(it.duplicate())


func cancel_all() -> void:
	scheduled.clear()
