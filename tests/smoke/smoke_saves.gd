extends RefCounted
## Save mẫu cho smoke, dựng bằng code trên Game.s sau Game.reset_for_test và trước khi main boot (smoke.gd
## open_game gọi save_now rồi mới boot). Dựng bằng code, không bằng file JSON, để không lỗi thời khi đổi schema,
## mốc mở tính năng hay sinh lại level (docs/TESTING.md "Tầng 2").

const Config := preload("res://src/config.gd")

## Cơ chế có popup giới thiệu lần đầu (Config.UNLOCK); save dựng sẵn đánh dấu đã xem cơ chế mở trước level đang ở.
const MECHS := ["stone", "ice", "chain", "layer", "fog", "pulse", "frost", "ribbon", "choco", "pop"]


## Cài mới: chưa xem hướng dẫn L1, chưa đánh giá, chưa xem hướng dẫn Leaderboard (reset_for_test bật sẵn các cờ này).
static func fresh(g: Node) -> void:
	g.s.meta["intro_seen"] = false
	g.s.meta["rated"] = false
	g.s.lb["guide"] = false


## Người chơi lâu: L30, gold vừa đủ, mỗi booster 3 cái, đã nhận quà booster. Cơ chế băng (L30) chưa xem nên vào
## level sẽ có popup giới thiệu.
static func veteran(g: Node) -> void:
	_at_level(g, 30, false)
	g.s.coins = 3000
	for k in ["hint", "move", "smash"]:
		g.s.inv[k] = 3


## Nhiều gold để mua mọi thứ trong game bằng gold.
static func rich(g: Node) -> void:
	veteran(g)
	g.s.coins = 100000


## Mọi tính năng đã mở (Config.UNLOCK lớn nhất trong các tính năng ở Home, Chain Offer từ L130), đã xem mọi
## hướng dẫn và giới thiệu cơ chế, nhiều gold và booster.
static func all_unlocked(g: Node) -> void:
	var lvl := 140
	for k in ["daily_gift", "shop", "leaderboard", "road_trip", "special_bomb", "win_streak", "challenge"]:
		lvl = maxi(lvl, int(Config.UNLOCK.get(k, 0)) + 1)
	lvl = maxi(lvl, int(Config.CHAIN.get("level_unlock", 0)) + 1)
	_at_level(g, lvl, true)
	g.s.coins = 50000
	for k in ["hint", "move", "smash"]:
		g.s.inv[k] = 5
	g.s.road_trip["guide"] = true
	g.s.special["guide"] = true
	g.s.special["invited"] = true
	g.s.lb["guide"] = true
	g.s.weekly["tut_seen"] = true


static func _at_level(g: Node, level: int, seen_current: bool) -> void:
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	var seen: Array = []
	for m in MECHS:
		var at := int(Config.UNLOCK.get(m, 1 << 30))
		if at < level or (seen_current and at == level):
			seen.append(m)
	g.s.mech_seen = seen
