extends RefCounted
## Lịch quà 28 ngày. Chỉ tiến lịch, không cộng hàng và không gọi Wallet: Game cộng reward.
## s.daily.idx là ô (0..27) sẽ nhận kế tiếp; claim_day là ngày nhận ô gần nhất; ad_day là ngày xem video nhận trước.

const Config := preload("res://src/config.gd")

const WEEK := 7


static func _total() -> int:
	return maxi(Config.DAILY.size(), 1)


static func _idx(s: Dictionary) -> int:
	return posmod(int(s.daily.get("idx", 0)), _total())


static func _reward(i: int) -> Dictionary:
	if Config.DAILY.is_empty():
		return {}
	return (Config.DAILY[i % Config.DAILY.size()] as Dictionary).duplicate(true)


static func can_claim(s: Dictionary, day: int) -> bool:
	return day > int(s.daily.get("claim_day", -1))


## Đã nhận ô hiện tại hôm nay và chưa xem video hôm nay.
static func can_ad_next(s: Dictionary, day: int) -> bool:
	return day == int(s.daily.get("claim_day", -1)) and day > int(s.daily.get("ad_day", -1))


## cells: 7 ô của tuần đang đi, mỗi ô {index, day (1..28), reward, state: "claimed"|"current"|"next"|"locked"}.
## Đã nhận hôm nay thì tuần hiển thị là tuần của ô vừa nhận để người chơi thấy ô đó.
static func view(s: Dictionary, day: int, level: int) -> Dictionary:
	var total := _total()
	var idx := _idx(s)
	var claimable := can_claim(s, day)
	var has_claimed := int(s.daily.get("claim_day", -1)) >= 0
	var shown := idx
	if not claimable and has_claimed:
		shown = posmod(idx - 1, total)
	@warning_ignore("integer_division")
	var week := shown / WEEK
	var cells: Array = []
	for k in range(WEEK):
		var i := week * WEEK + k
		if i >= total:
			break
		var state := "locked"
		if claimable:
			if i < idx:
				state = "claimed"
			elif i == idx:
				state = "current"
		else:
			if has_claimed and (idx == 0 or i < idx):
				state = "claimed"
			elif i == idx:
				state = "next"
		cells.append({"index": i, "day": i + 1, "reward": _reward(i), "state": state})
	var open := level >= int(Config.UNLOCK.get("daily_gift", 0))
	return {
		"open": open,
		"cells": cells,
		"week": week,
		"idx": idx,
		"can_claim": claimable,
		"can_ad_next": can_ad_next(s, day),
		"badge": open and claimable,
	}


## Nhận ô hiện tại. Mỗi ngày một lần; giờ máy lùi thì không nhận được tới khi vượt mốc.
static func claim(s: Dictionary, day: int) -> Dictionary:
	if not can_claim(s, day):
		return {}
	var i := _idx(s)
	var reward := _reward(i)
	s.daily["idx"] = (i + 1) % _total()
	s.daily["claim_day"] = day
	return reward


## Sau khi đã nhận ô hiện tại: xem video nhận trước ô kế tiếp, 1 lần/ngày. Game gọi sau khi quảng cáo ok.
static func claim_next_ad(s: Dictionary, day: int) -> Dictionary:
	if not can_ad_next(s, day):
		return {}
	var i := _idx(s)
	var reward := _reward(i)
	s.daily["idx"] = (i + 1) % _total()
	s.daily["ad_day"] = day
	return reward
