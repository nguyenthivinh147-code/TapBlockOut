extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const ShopVideos := preload("res://src/meta/shop_videos.gd")


func test_fresh(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(ShopVideos.remaining(s, 100), Config.ECON.shop_video_max, "đủ lượt")
	t.eq(ShopVideos.remaining(s, 0), 5, "ngày 0")


func test_watch_to_limit(t: T) -> void:
	var s := SaveSchema.defaults()
	for i in 5:
		t.eq(ShopVideos.remaining(s, 10), 5 - i, "còn lại %d" % i)
		t.eq(ShopVideos.note_watch(s, 10), 200, "nhận 200 lần %d" % i)
	t.eq(ShopVideos.remaining(s, 10), 0, "hết lượt")
	t.eq(ShopVideos.note_watch(s, 10), 0, "lần 6 không có gold")
	t.eq(s.shop.videos, 5, "không vượt trần")


func test_note_watch_does_not_touch_coins(t: T) -> void:
	var s := SaveSchema.defaults()
	var c0: int = s.coins
	ShopVideos.note_watch(s, 3)
	t.eq(s.coins, c0, "Game cộng gold, không phải module")


func test_next_day_resets(t: T) -> void:
	var s := SaveSchema.defaults()
	for i in 5:
		ShopVideos.note_watch(s, 10)
	t.eq(ShopVideos.remaining(s, 10), 0, "hết")
	t.eq(ShopVideos.remaining(s, 11), 5, "ngày mới thấy đủ trước khi ghi")
	t.eq(ShopVideos.note_watch(s, 11), 200, "ngày mới xem được")
	t.eq(s.shop.day, 11, "ghi ngày")
	t.eq(ShopVideos.remaining(s, 11), 4, "còn 4")


func test_clock_goes_back(t: T) -> void:
	var s := SaveSchema.defaults()
	for i in 5:
		ShopVideos.note_watch(s, 10)
	t.eq(ShopVideos.remaining(s, 9), 0, "giờ lùi không có thêm lượt")
	t.eq(ShopVideos.note_watch(s, 9), 0, "giờ lùi không nhận")
	t.eq(s.shop.day, 10, "giữ mốc")
	t.eq(ShopVideos.remaining(s, 10), 0, "vẫn hết")


func test_config_max(t: T) -> void:
	Config.reset()
	Config.ECON.shop_video_max = 2
	var s := SaveSchema.defaults()
	ShopVideos.note_watch(s, 1)
	ShopVideos.note_watch(s, 1)
	t.eq(ShopVideos.remaining(s, 1), 0, "trần theo Config")
	t.eq(ShopVideos.note_watch(s, 1), 0, "quá trần")
	Config.reset()
