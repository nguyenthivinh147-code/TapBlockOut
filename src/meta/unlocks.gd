extends RefCounted
## Mở khoá theo level (Config.UNLOCK) và quà hướng dẫn booster.

const Config := preload("res://src/config.gd")

## Luôn mở, không nằm trong Config.UNLOCK.
const ALWAYS_OPEN := ["rescue", "avatar", "frame"]
## Booster được tặng một lần khi tới level mở, theo thứ tự.
const GIFT_ORDER := ["hint", "move", "smash"]


## `level` là level đang chơi/sắp chơi (người chơi đang ở level này).
static func is_open(feature: String, level: int) -> bool:
	if feature in ALWAYS_OPEN:
		return true
	if not Config.UNLOCK.has(feature):
		return false
	return level >= int(Config.UNLOCK[feature])


## Booster cần tặng ở level này ("" nếu không có). Gọi lặp lại tới khi hết.
static func pending_gift(s: Dictionary, level: int) -> String:
	for k in GIFT_ORDER:
		if level >= int(Config.UNLOCK.get(k, 1 << 30)) and not bool(s.gifted.get(k, false)):
			return k
	return ""


## Chỉ đánh dấu đã tặng. Việc cộng vào kho do người gọi làm (Wallet.inv_add).
static func mark_gifted(s: Dictionary, kind: String) -> void:
	if kind in GIFT_ORDER:
		s.gifted[kind] = true
