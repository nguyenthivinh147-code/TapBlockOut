extends RefCounted
## Ví gold (`s.coins`) và kho booster (`s.inv`). Logic thuần, không lưu file.

const KINDS := ["hint", "move", "smash"]


static func earn(s: Dictionary, n: int) -> void:
	if n > 0:
		s.coins = int(s.coins) + n


## Trừ gold. Thiếu gold hoặc n âm thì không trừ và trả false.
static func spend(s: Dictionary, n: int) -> bool:
	if n < 0 or n > int(s.coins):
		return false
	s.coins = int(s.coins) - n
	return true


static func inv_count(s: Dictionary, k: String) -> int:
	return int(s.inv.get(k, 0))


## Chỉ nhận loại booster hợp lệ (hint, move, smash).
static func inv_add(s: Dictionary, k: String, n: int) -> void:
	if n > 0 and k in KINDS:
		s.inv[k] = inv_count(s, k) + n


static func inv_use(s: Dictionary, k: String) -> bool:
	var c := inv_count(s, k)
	if c <= 0:
		return false
	s.inv[k] = c - 1
	return true
