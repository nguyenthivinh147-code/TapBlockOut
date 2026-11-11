extends RefCounted
## Bộ kiểm tra tối giản cho test_*.gd.

var checks: int = 0
var failures: Array[String] = []
## Chuỗi con của lỗi engine mà test này cố ý gây ra (run_all.gd không tính là lỗi, nhưng đòi phải xuất hiện).
var expected_errors: Array[String] = []
## Mục được miễn theo allowlist của test (run_all.gd in thành dòng ALLOWED và đếm vào tổng ALLOWED).
var allowed_notes: Array[String] = []


## So bằng: cùng kiểu và `==` (Array, Dictionary của Godot so sâu). Khi khác, lỗi chỉ ra đường dẫn phần tử khác
## đầu tiên (ví dụ `[2].coins`).
func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	checks += 1
	if typeof(actual) == typeof(expected) and actual == expected:
		return
	var diff := _diff(actual, expected, "")
	if diff.is_empty() or diff == "<gốc>":
		failures.append("%s: mong đợi %s, nhận %s" % [msg, str(expected), str(actual)])
	else:
		failures.append("%s: khác ở %s; mong đợi %s, nhận %s" % [msg, diff, str(expected), str(actual)])


func ok(cond: bool, msg: String = "") -> void:
	checks += 1
	if not cond:
		failures.append("%s: điều kiện sai" % msg)


func near(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s: mong đợi ~%s, nhận %s" % [msg, str(expected), str(actual)])


func fail(msg: String) -> void:
	checks += 1
	failures.append(msg)


## Khai trước một lỗi engine mà test sẽ gây ra (push_error, lỗi script cố ý). `text` là chuỗi con của dòng lỗi.
func expect_error(text: String) -> void:
	expected_errors.append(text)


## Ghi một vi phạm được miễn (kèm chỗ ghi miễn), để báo cáo hiện là Skipped thay vì ẩn đi.
func allow(note: String) -> void:
	allowed_notes.append(note)


## Chỉ dùng cho thông báo lỗi: "" khi không tìm ra chỗ khác; "<gốc>" khi khác ngay ở gốc; nếu không, đường dẫn tới
## phần tử khác đầu tiên.
func _diff(a: Variant, b: Variant, path: String) -> String:
	var here := path if not path.is_empty() else "<gốc>"
	if typeof(a) != typeof(b):
		return here
	if a is Array:
		var x: Array = a
		var y: Array = b
		if x.size() != y.size():
			return here + " (độ dài %d, mong đợi %d)" % [x.size(), y.size()]
		for i in x.size():
			var d := _diff(x[i], y[i], "%s[%d]" % [path, i])
			if not d.is_empty():
				return d
		return ""
	if a is Dictionary:
		var x: Dictionary = a
		var y: Dictionary = b
		for k in y:
			if not x.has(k):
				return "%s.%s (thiếu khoá)" % [path, str(k)]
		for k in x:
			if not y.has(k):
				return "%s.%s (thừa khoá)" % [path, str(k)]
			var d := _diff(x[k], y[k], "%s.%s" % [path, str(k)])
			if not d.is_empty():
				return d
		return ""
	return "" if a == b else here
