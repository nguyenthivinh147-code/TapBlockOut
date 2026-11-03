extends RefCounted
## Luồng hết MOVES của một lượt chơi (design.md mục "Khi hết MOVES").
## Mỗi lần hết MOVES hiện một popup +3 Move, tối đa len(rescue_prices) lần; hết lần hoặc bỏ qua là thua.
## Không trừ tiền, không đọc save: Game trừ theo kết quả accept().

const Config := preload("res://src/config.gd")

var _used: int = 0
var _lost: bool = false
var _cur: Dictionary = {}
var _coins: int = 0


## Gọi mỗi lần moves_left về 0. index -1 nghĩa là hết đường cứu (đánh dấu thua).
func offer(inv_move: int, coins: int, remaining: int, level: int) -> Dictionary:
	var res := {
		"index": -1, "price": 0, "use_inventory": false, "video": false,
		"affordable": false, "remaining": remaining, "warn_life": false,
	}
	_cur = res
	_coins = coins
	if _lost:
		return res
	var prices: Array = Config.ECON.rescue_prices
	if _used >= prices.size():
		_lost = true
		return res
	res.index = _used
	res.price = int(prices[_used])
	res.use_inventory = inv_move > 0
	res.video = _used < int(Config.ECON.rescue_video_max)
	res.affordable = res.use_inventory or coins >= int(res.price)
	res.warn_life = level >= int(Config.LIVES.from_level)
	return res


## method: "inventory" | "gold" | "video". Trả {} nếu không hợp lệ theo offer gần nhất.
func accept(method: String) -> Dictionary:
	if _cur.is_empty() or _lost or int(_cur.index) < 0:
		return {}
	var price := 0
	match method:
		"inventory":
			if not _cur.use_inventory:
				return {}
		"gold":
			if _coins < int(_cur.price):
				return {}
			price = int(_cur.price)
		"video":
			if not _cur.video:
				return {}
		_:
			return {}
	_used += 1
	_cur = {}
	return {"moves": int(Config.ECON.rescue_moves), "price": price}


## Bỏ qua popup là thua.
func skip() -> void:
	if _cur.is_empty() or _lost:
		return
	_lost = true
	_cur = {}


func is_lost() -> bool:
	return _lost


## Số lần đã cứu thành công trong lượt này.
func used() -> int:
	return _used
