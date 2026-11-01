extends RefCounted
## Bộ kiểm tra tối giản cho test_*.gd.

var checks: int = 0
var failures: Array[String] = []


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	checks += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: mong đợi %s, nhận %s" % [msg, str(expected), str(actual)])


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
