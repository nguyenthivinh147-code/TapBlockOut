extends RefCounted
## Điều kiện hiện gói (Special Pack...). Logic thuần, đọc s.buys và Config.PACKS.
## Gói sale (`<sku>_sale`) tính như gói gốc khi đếm số lần mua.

const Config := preload("res://src/config.gd")

const SALE_SUFFIX := "_sale"


## Số lần đã mua `sku` (cả bản `_sale`).
static func purchases(s: Dictionary, sku: String) -> int:
	var n := 0
	for e in s.get("buys", []):
		if not (e is Dictionary):
			continue
		var b := str(e.get("sku", ""))
		if b == sku or b == sku + SALE_SUFFIX:
			n += 1
	return n


## Gói `pack_id` có được hiện ở level `level` không.
static func can_show(s: Dictionary, pack_id: String, level: int) -> bool:
	var cond: Dictionary = Config.PACKS.get(pack_id, {})
	if cond.is_empty():
		return false
	var sku := str(cond.get("sku", pack_id))
	if level < int(cond.get("level_appear", 1)):
		return false
	var limit := int(cond.get("purchase_limit", 0))
	if limit > 0 and purchases(s, sku) >= limit:
		return false
	for req in cond.get("required", []):
		var rsku := str(Config.PACKS.get(str(req), {}).get("sku", str(req)))
		if purchases(s, rsku) <= 0:
			return false
	for ex in cond.get("exclude", []):
		var xsku := str(Config.PACKS.get(str(ex), {}).get("sku", str(ex)))
		if purchases(s, xsku) > 0:
			return false
	return true


## Gói đầu tiên đủ điều kiện (theo thứ tự khai báo trong Config.PACKS), "" nếu không có.
## Mỗi lần Home chỉ hiện một icon.
static func first_visible(s: Dictionary, level: int) -> String:
	for id in Config.PACKS:
		if can_show(s, str(id), level):
			return str(id)
	return ""
