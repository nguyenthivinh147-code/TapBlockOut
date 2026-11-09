extends RefCounted
## So sánh phiên bản app dạng "1.2.3" cho popup cập nhật (design.md mục 8, Config.CONTENT.latest_version,
## min_version). Logic thuần.


## Các số của phiên bản: "v1.2.10" -> [1, 2, 10]; phần không phải số bị bỏ.
static func parts(v: String) -> Array[int]:
	var out: Array[int] = []
	for p in v.strip_edges().trim_prefix("v").split("."):
		var digits := ""
		for ch in p:
			if ch >= "0" and ch <= "9":
				digits += ch
			else:
				break
		out.append(int(digits) if digits != "" else 0)
	return out


## a cũ hơn b. Chuỗi rỗng không cũ hơn gì.
static func older(a: String, b: String) -> bool:
	if a.strip_edges() == "" or b.strip_edges() == "":
		return false
	var pa := parts(a)
	var pb := parts(b)
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i] if i < pa.size() else 0
		var y := pb[i] if i < pb.size() else 0
		if x != y:
			return x < y
	return false


## "" (không cần), "optional" (dưới latest), "force" (dưới min).
static func update_state(current: String, latest: String, minimum: String) -> String:
	if older(current, minimum):
		return "force"
	if older(current, latest):
		return "optional"
	return ""
