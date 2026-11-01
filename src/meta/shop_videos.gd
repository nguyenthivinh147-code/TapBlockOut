extends RefCounted
## Video gold trong shop, tối đa Config.ECON.shop_video_max mỗi ngày theo giờ máy.
## Chỉ đọc và ghi s.shop. Không cộng gold: Game cộng số trả về qua Wallet.earn.
## Video cosmetic (cosmetic_unlock) không tính ở đây.

const Config := preload("res://src/config.gd")


## Sang ngày mới thì đặt lại. Giờ máy lùi (day < shop.day) thì giữ nguyên, không đặt lại.
static func _roll(s: Dictionary, day: int) -> void:
	if day > int(s.shop.day):
		s.shop.day = day
		s.shop.videos = 0


## Số video còn xem được trong ngày `day`.
static func remaining(s: Dictionary, day: int) -> int:
	var used := int(s.shop.videos) if day <= int(s.shop.day) else 0
	return maxi(0, int(Config.ECON.shop_video_max) - used)


## Ghi một lượt xem xong; trả gold được nhận (0 nếu hết lượt).
static func note_watch(s: Dictionary, day: int) -> int:
	_roll(s, day)
	if remaining(s, day) <= 0:
		return 0
	s.shop.videos = int(s.shop.videos) + 1
	return int(Config.ECON.shop_video_coins)
