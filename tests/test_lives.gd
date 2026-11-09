extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Lives := preload("res://src/meta/lives.gd")

const NOW := 1_000_000
const FROM := 10


func test_full_no_accumulate(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(Lives.count(s, NOW), 10, "đầy")
	t.eq(Lives.seconds_to_next(s, NOW), 0, "đầy thì 0 giây")
	t.eq(Lives.count(s, NOW + 100 * 3600), 10, "đầy lâu vẫn 10")
	t.eq(int(s.lives.next_at), 0, "không tích giờ")


func test_lose_below_from_level(t: T) -> void:
	var s := SaveSchema.defaults()
	Lives.lose(s, NOW, FROM - 1)
	t.eq(Lives.count(s, NOW), 10, "L9 không mất mạng")
	t.eq(int(s.lives.next_at), 0, "L9 không bật đồng hồ")
	Lives.lose(s, NOW, 1)
	t.eq(Lives.count(s, NOW), 10, "L1 không mất mạng")


func test_lose_and_regen(t: T) -> void:
	var s := SaveSchema.defaults()
	var rg: int = Config.LIVES.regen_sec
	t.ok(Lives.lose(s, NOW, FROM), "L10 mất mạng")
	t.eq(Lives.count(s, NOW), 9, "còn 9")
	t.eq(int(s.lives.next_at), NOW + rg, "đồng hồ bắt đầu từ lúc mất")
	t.eq(Lives.seconds_to_next(s, NOW + 100), rg - 100, "đếm ngược")
	t.eq(Lives.count(s, NOW + rg - 1), 9, "chưa tới giờ")
	t.eq(Lives.count(s, NOW + rg), 10, "hồi đúng giờ")
	t.eq(int(s.lives.next_at), 0, "đầy thì dừng đồng hồ")
	t.eq(Lives.seconds_to_next(s, NOW + rg), 0, "đầy thì 0")


func test_lose_keeps_timer_when_not_full(t: T) -> void:
	var s := SaveSchema.defaults()
	var rg: int = Config.LIVES.regen_sec
	Lives.lose(s, NOW, FROM)
	Lives.lose(s, NOW + rg / 3, FROM)
	t.eq(Lives.count(s, NOW + rg / 3), 8, "còn 8")
	t.eq(int(s.lives.next_at), NOW + rg, "mất thêm không dời đồng hồ")
	t.eq(Lives.count(s, NOW + rg), 9, "hồi 1")
	t.eq(Lives.seconds_to_next(s, NOW + rg), rg, "mạng kế tiếp sau một chu kỳ nữa")
	t.eq(Lives.count(s, NOW + 2 * rg), 10, "hồi đủ")


func test_offline_regen_multiple(t: T) -> void:
	var s := SaveSchema.defaults()
	var rg: int = Config.LIVES.regen_sec
	for i in 5:
		Lives.lose(s, NOW, FROM)
	t.eq(Lives.count(s, NOW), 5, "còn 5")
	t.eq(Lives.count(s, NOW + 3 * rg + 10), 8, "offline 3 chu kỳ")
	t.eq(Lives.seconds_to_next(s, NOW + 3 * rg + 10), rg - 10, "phần dư")
	t.eq(Lives.count(s, NOW + 100 * rg), 10, "offline rất lâu: kẹp ở max")


func test_zero_lives(t: T) -> void:
	var s := SaveSchema.defaults()
	for i in 10:
		t.ok(Lives.lose(s, NOW, FROM), "mất mạng %d" % i)
	t.eq(Lives.count(s, NOW), 0, "hết mạng")
	t.ok(not Lives.lose(s, NOW, FROM), "không âm")
	t.eq(Lives.count(s, NOW), 0, "vẫn 0")
	t.ok(Lives.seconds_to_next(s, NOW) > 0, "có đếm ngược")


func test_add(t: T) -> void:
	var s := SaveSchema.defaults()
	var rg: int = Config.LIVES.regen_sec
	for i in 8:
		Lives.lose(s, NOW, FROM)
	Lives.add(s, 1, NOW + 10)
	t.eq(Lives.count(s, NOW + 10), 3, "cộng 1")
	t.eq(int(s.lives.next_at), NOW + rg, "đồng hồ giữ nguyên")
	Lives.add(s, 5, NOW + 10)
	t.eq(Lives.count(s, NOW + 10), 8, "cộng 5")
	Lives.add(s, 5, NOW + 10)
	t.eq(Lives.count(s, NOW + 10), 10, "kẹp ở max")
	t.eq(int(s.lives.next_at), 0, "đầy thì dừng đồng hồ")
	Lives.add(s, 3, NOW + 10)
	t.eq(Lives.count(s, NOW + 10), 10, "đã đầy không vượt")
	Lives.add(s, -2, NOW + 10)
	t.eq(Lives.count(s, NOW + 10), 10, "add âm bị bỏ qua")


func test_refill_coins(t: T) -> void:
	var s := SaveSchema.defaults()
	var price: int = Config.ECON.refill_coins
	var n: int = Config.ECON.refill_lives
	t.ok(not Lives.refill_coins(s, NOW), "đầy mạng thì không đổi")
	t.eq(s.coins, int(Config.ECON.start_coins), "không trừ gold")
	for i in 10:
		Lives.lose(s, NOW, FROM)
	s.coins = price - 1
	t.ok(not Lives.refill_coins(s, NOW), "thiếu gold")
	t.eq(Lives.count(s, NOW), 0, "vẫn 0 mạng")
	t.eq(s.coins, price - 1, "thiếu thì không trừ")
	s.coins = price + 7
	t.ok(Lives.refill_coins(s, NOW), "đủ gold")
	t.eq(s.coins, 7, "trừ 900")
	t.eq(Lives.count(s, NOW), n, "+5 mạng")
	t.ok(Lives.seconds_to_next(s, NOW) > 0, "đồng hồ vẫn chạy")
	s.coins = price * 3
	t.ok(Lives.refill_coins(s, NOW), "đổi lần 2")
	t.eq(Lives.count(s, NOW), 10, "kẹp ở 10")
	t.eq(int(s.lives.next_at), 0, "đầy thì dừng đồng hồ")


func test_clock_rewind_and_corrupt(t: T) -> void:
	var s := SaveSchema.defaults()
	var rg: int = Config.LIVES.regen_sec
	Lives.lose(s, NOW + 10 * rg, FROM)
	t.eq(Lives.count(s, NOW), 9, "giờ lùi không cộng")
	t.ok(Lives.seconds_to_next(s, NOW) <= rg, "giờ lùi: chờ tối đa một chu kỳ")
	var c := SaveSchema.defaults()
	c.lives.count = 4
	c.lives.next_at = 0
	t.eq(Lives.count(c, NOW), 4, "next_at hỏng, vẫn 4")
	t.eq(int(c.lives.next_at), NOW + rg, "dựng lại đồng hồ")
	var o := SaveSchema.defaults()
	o.lives.count = 15
	t.eq(Lives.count(o, NOW), 10, "kẹp vượt max")


func test_remote_config_values(t: T) -> void:
	Config.apply_remote({"lives_max": "5", "lives_regen_sec": "60", "lives_from_level": "3"})
	var s := SaveSchema.defaults()
	s.lives.count = 5
	Lives.lose(s, NOW, 2)
	t.eq(Lives.count(s, NOW), 5, "from_level mới")
	Lives.lose(s, NOW, 3)
	t.eq(Lives.count(s, NOW), 4, "mất mạng từ L3")
	t.eq(Lives.count(s, NOW + 60), 5, "hồi sau 60 giây, max 5")
	Config.reset()


func test_infinite(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(Lives.infinite(s, NOW), false, "mặc định không vô hạn")
	Lives.grant_infinite(s, 900, NOW)
	t.eq(Lives.infinite(s, NOW + 899), true, "còn trong hạn")
	t.eq(Lives.infinite_left(s, NOW + 100), 800, "đếm ngược")
	t.eq(Lives.infinite(s, NOW + 900), false, "hết hạn")
	t.eq(Lives.infinite_left(s, NOW + 5000), 0, "hết hạn thì 0")
	t.eq(Lives.lose(s, NOW, FROM), false, "đang vô hạn thì không mất mạng")
	t.eq(Lives.count(s, NOW), 10, "mạng giữ nguyên")
	Lives.grant_infinite(s, 600, NOW + 300)  # cộng dồn vào hạn hiện tại
	t.eq(Lives.infinite_left(s, NOW + 300), 600 + 600, "cộng dồn")
	t.eq(Lives.lose(s, NOW + 3000, FROM), true, "hết hạn thì mất mạng lại")
	Lives.grant_infinite(s, 0, NOW)
	t.eq(Lives.infinite_left(s, NOW + 3000), 0, "cấp 0 giây không đổi gì")
