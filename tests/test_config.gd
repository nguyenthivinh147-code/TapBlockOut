extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")


func test_daily_totals(t: T) -> void:
	Config.reset()
	t.eq(Config.DAILY.size(), 28, "28 ô")
	var coins := 0
	var items := {"hint": 0, "move": 0, "smash": 0}
	for cell in Config.DAILY:
		coins += int(cell.coins)
		for k in cell.items:
			items[k] += int(cell.items[k])
	t.eq(coins, 6650, "tổng gold")
	t.eq(items.hint, 5, "hint")
	t.eq(items.move, 5, "move")
	t.eq(items.smash, 4, "smash")
	# tuần 1 theo bảng
	t.eq(Config.DAILY[0].coins, 50, "ô 1")
	t.eq(Config.DAILY[6].coins, 500, "ô 7 gold")
	t.eq(Config.DAILY[6].items.smash, 1, "ô 7 smash")
	t.eq(Config.DAILY[27].coins, 1000, "ô 28 gold")


func test_defaults(t: T) -> void:
	Config.reset()
	t.eq(Config.ECON.start_coins, 1000, "start")
	t.eq(Config.ECON.win_coins, 40, "win")
	t.eq(Config.ECON.booster_price.hint, 900, "hint")
	t.eq(Config.ECON.booster_price.move, 1900, "move")
	t.eq(Config.ECON.booster_price.smash, 2900, "smash")
	t.eq(Config.ECON.rescue_prices, [1900, 2200, 2500, 2800], "giá cứu")
	t.eq(Config.ECON.rescue_video_max, 4, "video cả 4 lần")
	t.eq(Config.LIVES.max, 10, "mạng")
	t.eq(Config.LIVES.regen_sec, 900, "hồi mạng")
	t.eq(Config.UNLOCK.pulse, 90, "pulse")
	t.eq(Config.CONTENT.demo_max_level, 20, "demo")
	t.eq(Config.CONTENT.ftue_steps.size(), 8, "ftue")
	t.eq(Config.SALE_WEEKDAYS, [6, 0], "sale")
	t.eq(Config.is_demo(), OS.has_feature("demo"), "is_demo")
	t.eq(Config.demo_override, -1, "demo_override mặc định")


func test_demo_override(t: T) -> void:
	Config.reset()
	Config.demo_override = 1
	t.ok(Config.is_demo(), "1 bật")
	Config.demo_override = 0
	t.ok(not Config.is_demo(), "0 tắt")
	Config.demo_override = -1
	t.eq(Config.is_demo(), OS.has_feature("demo"), "-1 theo feature")
	Config.demo_override = 1
	Config.reset()
	t.eq(Config.demo_override, -1, "reset trả -1")


func test_skus(t: T) -> void:
	Config.reset()
	t.eq(Config.SKUS.size(), 16, "16 SKU")
	for i in range(1, 7):
		var base := "gold_pack_%d" % i
		t.ok(Config.SKUS.has(base), base)
		t.ok(Config.SKUS.has(base + "_sale"), base + "_sale")
		t.ok(Config.SKUS[base + "_sale"].usd < Config.SKUS[base].usd, "giá sale thấp hơn " + base)
		t.eq(Config.SKUS[base].consumable, true, "consumable " + base)
	t.near(Config.SKUS.gold_pack_1.usd, 1.99, 0.0001, "usd 1")
	t.eq(Config.SKUS.gold_pack_1_sale.gold, 2000, "sale 1 gold")
	t.eq(Config.SKUS.remove_ads.consumable, false, "remove_ads một lần")
	t.eq(Config.SKUS.starter_pack.consumable, false, "starter một lần")
	t.eq(Config.SKUS.rescue_pack.consumable, true, "rescue dùng hết")


func test_cosmetics(t: T) -> void:
	Config.reset()
	t.eq(Config.cosmetic_ids("avatar").size(), 13, "avatar 00-12")
	t.eq(Config.cosmetic_ids("frame")[12], "frame_12", "frame_12")
	t.eq(Config.cosmetic_price("avatar_00"), 0, "mặc định miễn phí")
	t.eq(Config.cosmetic_price("avatar_01"), 50, "50")
	t.eq(Config.cosmetic_price("avatar_02"), 75, "75")
	t.eq(Config.cosmetic_price("frame_03"), 100, "100")
	t.eq(Config.cosmetic_price("frame_04"), 50, "xoay lại")
	t.eq(Config.cosmetic_price("lạ"), 0, "id lạ")
	var total := 0
	for kind in ["avatar", "frame"]:
		for id in Config.cosmetic_ids(kind):
			total += Config.cosmetic_price(id)
	t.eq(total, 1800, "mua hết 1.800")


func test_apply_remote(t: T) -> void:
	Config.reset()
	Config.apply_remote({
		"econ_win_coins": "55",
		"econ_booster_price_hint": "800",
		"econ_rescue_prices": "100, 200,300",
		"ads_inter_every": "3",
		"lives_regen_sec": "600",
		"content_build": "v2",
		"content_ftue_steps": "a,b",
		"skus_gold_pack_1_sale_usd": "0.49",
		"skus_gold_pack_1_usd": "2.49",
		"skus_starter_pack_inv_hint": "2",
		"offers_min_secs": "60",
		"sale_weekdays": "5,6",
	})
	t.eq(Config.ECON.win_coins, 55, "int")
	t.eq(Config.ECON.booster_price.hint, 800, "dict lồng")
	t.eq(Config.ECON.booster_price.move, 1900, "move giữ nguyên")
	t.eq(Config.ECON.rescue_prices, [100, 200, 300], "mảng")
	t.eq(Config.ADS.inter_every, 3, "ads")
	t.eq(Config.LIVES.regen_sec, 600, "lives")
	t.eq(Config.CONTENT.build, "v2", "chuỗi")
	t.eq(Config.CONTENT.ftue_steps, ["a", "b"], "mảng chuỗi")
	t.near(Config.SKUS.gold_pack_1_sale.usd, 0.49, 0.0001, "float lồng sale")
	t.near(Config.SKUS.gold_pack_1.usd, 2.49, 0.0001, "float lồng thường")
	t.eq(Config.SKUS.starter_pack.inv.hint, 2, "inv lồng")
	t.eq(Config.OFFERS.min_secs, 60, "offers")
	t.eq(Config.SALE_WEEKDAYS, [5, 6], "sale_weekdays")
	Config.reset()
	t.eq(Config.ECON.win_coins, 40, "reset")


func test_apply_remote_bad_values(t: T) -> void:
	Config.reset()
	Config.apply_remote({
		"econ_win_coins": "abc",
		"econ_start_coins": "",
		"econ_refill_coins": "-5",
		"econ_unknown_key": "1",
		"nogroup_x": "1",
		"ads_inter_every": "1.5",
		"econ_rescue_prices": "100,xyz",
		"econ_booster_price": "5",
		"econ_challenge_coins": 7,
		"content_build": "",
		"lives_max": "  12 ",
	})
	t.eq(Config.ECON.win_coins, 40, "chữ không phải số")
	t.eq(Config.ECON.start_coins, 1000, "rỗng")
	t.eq(Config.ECON.refill_coins, 900, "số âm")
	t.eq(Config.ECON.has("unknown_key"), false, "khoá lạ không thêm")
	t.eq(Config.ADS.inter_every, 2, "float vào int")
	t.eq(Config.ECON.rescue_prices, [1900, 2200, 2500, 2800], "mảng hỏng giữ nguyên")
	t.eq(Config.ECON.booster_price, {"hint": 900, "move": 1900, "smash": 2900}, "dict không bị thay")
	t.eq(Config.ECON.challenge_coins, 100, "giá trị không phải chuỗi bị bỏ")
	t.eq(Config.CONTENT.build, "v1", "chuỗi rỗng")
	t.eq(Config.LIVES.max, 12, "cắt khoảng trắng")
	Config.reset()


func test_bool_coercion(t: T) -> void:
	Config.reset()
	var v: Variant = Config._coerce(true, "0")
	t.eq(v, false, "bool 0")
	t.eq(Config._coerce(false, "TRUE"), true, "bool TRUE")
	t.eq(Config._coerce(true, "maybe"), null, "bool hỏng")
