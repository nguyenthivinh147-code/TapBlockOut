extends RefCounted
const T := preload("res://tests/t.gd")
const Offers := preload("res://src/meta/offers.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const Config := preload("res://src/config.gd")

const T0 := 1700000000  # 2023-11-14 22:13 UTC, thứ Ba
const H := 3600
const D := 86400


func _ctx(over: Dictionary = {}) -> Dictionary:
	var c := {"now": T0, "day": T0 / D, "level": 5, "runs": 5, "session_start": T0 - 1000,
		"first_session": false, "inter_today": 0}
	c.merge(over, true)
	return c


func test_sale(t: T) -> void:
	# 1700000000 là thứ Ba; thứ Bảy = +4 ngày, Chủ nhật = +5, Thứ Hai = +6
	t.eq(Offers.is_sale(T0, 0), false, "thứ Ba")
	t.eq(Offers.is_sale(T0 + 4 * D, 0), true, "thứ Bảy")
	t.eq(Offers.is_sale(T0 + 5 * D, 0), true, "Chủ nhật")
	t.eq(Offers.is_sale(T0 + 6 * D, 0), false, "thứ Hai")
	# múi giờ đẩy qua ngày: thứ Năm 22:13 UTC, +7h thành thứ Sáu
	t.eq(Offers.is_sale(T0 + 2 * D, 0), false, "thứ Năm UTC")
	t.eq(Offers.is_sale(T0 + 2 * D, 7 * H), true, "thứ Sáu theo giờ máy")


func test_sale_friday(t: T) -> void:
	Config.reset()
	t.eq(Offers.is_sale(T0 + 3 * D, 0), true, "thứ Sáu")
	t.eq(Offers.is_sale(T0 + 2 * D, 0), false, "thứ Năm")


func test_sale_mode(t: T) -> void:
	var sat := T0 + 4 * D
	Config.reset()
	t.eq(Offers.is_sale(sat, 0, true), true, "mode 1: đã mua vẫn sale")
	Config.SALE_MODE = 2
	t.eq(Offers.is_sale(sat, 0, false), true, "mode 2: chưa mua")
	t.eq(Offers.is_sale(sat, 0, true), false, "mode 2: đã mua")
	t.eq(Offers.is_sale(T0, 0, false), false, "mode 2: ngoài ngày sale")
	Config.SALE_MODE = 3
	t.eq(Offers.is_sale(sat, 0, false), false, "mode 3: tắt")
	t.eq(Offers.catalog(sat, 0, false)[0].sku, "gold_pack_1", "mode 3: gói thường")
	Config.reset()


func test_catalog_base(t: T) -> void:
	Config.reset()
	var sale := Offers.catalog(T0 + 4 * D, 0)
	t.eq(sale[0].base_sku, "gold_pack_1", "base_sku")
	t.near(sale[0].base_usd, 1.99, 0.001, "base_usd")


func test_catalog(t: T) -> void:
	var normal := Offers.catalog(T0, 0)
	t.eq(normal.size(), 6, "6 gói")
	t.eq(normal[0].sku, "gold_pack_1", "sku thường")
	t.eq(normal[0].gold, 1000, "gold thường")
	t.near(normal[0].usd, 1.99, 0.001, "giá thường")
	t.eq(normal[5].sku, "gold_pack_6", "gói 6")
	var sale := Offers.catalog(T0 + 4 * D, 0)
	t.eq(sale.size(), 6, "6 gói sale")
	t.eq(sale[0].sku, "gold_pack_1_sale", "sku sale")
	t.eq(sale[0].gold, 2000, "gold sale")
	t.near(sale[0].usd, 1.99, 0.001, "gói 1 sale giữ giá")
	t.eq(sale[0].base_gold, 1000, "base_gold")
	t.near(sale[1].usd, 3.99, 0.001, "gói 2 sale giảm giá")
	t.eq(sale[0].id, "gold_pack_1", "id giữ nguyên")
	t.eq(sale[0].sale, true, "cờ sale")
	t.eq(normal[0].sale, false, "cờ thường")


func test_starter(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(Offers.due(s, _ctx({"level": 10, "runs": 11})), "", "chưa qua L10, chưa lượt 12")
	t.eq(Offers.due(s, _ctx({"level": 11, "runs": 11})), "starter_pack", "qua L10")
	t.eq(Offers.due(s, _ctx({"level": 5, "runs": 12})), "starter_pack", "lượt 12")
	Offers.shown(s, "starter_pack", _ctx({"level": 11}))
	t.eq(Offers.due(s, _ctx({"level": 11, "runs": 40})), "", "đang mở không hiện lại, level_pack chờ")
	var open := Offers.open_offers(s, T0 + 47 * H)
	t.eq(open.size(), 1, "mở 47 giờ sau")
	t.eq(open[0].id, "starter_pack", "id")
	t.eq(open[0].sku, "starter_pack", "sku")
	t.eq(open[0].until, T0 + 48 * H, "hạn 48 giờ")
	t.eq(Offers.open_offers(s, T0 + 48 * H).size(), 0, "hết hạn")
	t.eq(Offers.due(s, _ctx({"now": T0 + 100 * H, "level": 10, "runs": 99, "inter_today": 0})), "", "một lần, không hiện lại")
	# mua thì đóng
	var s2 := SaveSchema.defaults()
	Offers.shown(s2, "starter_pack", _ctx({"level": 11}))
	Offers.bought(s2, "starter_pack", T0 + H)
	t.eq(Offers.open_offers(s2, T0 + 2 * H).size(), 0, "mua xong đóng")


func test_remove_ads(t: T) -> void:
	var s := SaveSchema.defaults()
	Offers.bought(s, "starter_pack", T0 - D)  # tách riêng: starter đã xong
	t.eq(Offers.due(s, _ctx({"inter_today": 2})), "", "mới 2 interstitial")
	t.eq(Offers.due(s, _ctx({"inter_today": 3})), "remove_ads", "sau interstitial thứ 3")
	Offers.shown(s, "remove_ads", _ctx({"runs": 30}))
	t.eq(Offers.due(s, _ctx({"inter_today": 4, "runs": 40})), "", "1 lần/ngày")
	t.eq(Offers.due(s, _ctx({"inter_today": 3, "runs": 40, "day": T0 / D + 1})), "remove_ads", "ngày sau lại hiện")
	Offers.shown(s, "remove_ads", _ctx({"runs": 40, "day": T0 / D + 1}))
	Offers.shown(s, "remove_ads", _ctx({"runs": 50, "day": T0 / D + 2}))
	t.eq(Offers.due(s, _ctx({"inter_today": 3, "runs": 60, "day": T0 / D + 3})), "", "tối đa 3 lần tổng")
	var s2 := SaveSchema.defaults()
	s2.no_ads = true
	t.eq(Offers.due(s2, _ctx({"inter_today": 5})), "", "đã bỏ quảng cáo")
	var s3 := SaveSchema.defaults()
	Offers.bought(s3, "remove_ads", T0)
	t.eq(Offers.due(s3, _ctx({"inter_today": 5})), "", "đã mua")


## rescue_pack is off by default (Config.OFFERS.rescue_pack.enabled, 2026-11-10): no offer after any fail streak.
func test_rescue_off_by_default(t: T) -> void:
	var s := SaveSchema.defaults()
	for i in 5:
		Offers.note_fail(s, 7)
	t.eq(Offers.enabled("rescue_pack"), false, "rescue tắt")
	t.eq(Offers.due(s, _ctx({"on_lose": true})), "", "thua 5 lần liền vẫn không hiện")
	t.eq(Offers.due(s, _ctx({"on_lose": true, "level": 11})), "", "màn thua không xét gói khác")
	t.eq(Offers.enabled("starter_pack"), true, "offer không có cờ là bật")
	t.eq(Offers.enabled("no_such_offer"), false, "id lạ")
	Config.apply_remote({"offers_rescue_pack_enabled": "true"})
	t.eq(Offers.due(s, _ctx({"on_lose": true})), "rescue_pack", "Remote Config bật lại")
	Config.reset()


func test_rescue(t: T) -> void:
	Config.OFFERS.rescue_pack.enabled = true
	var s := SaveSchema.defaults()
	Offers.note_fail(s, 7)
	Offers.note_fail(s, 7)
	t.eq(Offers.due(s, _ctx({"on_lose": true})), "", "mới thua 2 lần")
	Offers.note_fail(s, 7)
	t.eq(s.fail_streak.count, 3, "chuỗi 3")
	t.eq(Offers.due(s, _ctx({"on_lose": true})), "rescue_pack", "thua 3 lần liền")
	t.eq(Offers.due(s, _ctx({"on_lose": false})), "", "không hiện ngoài màn thua")
	Offers.shown(s, "rescue_pack", _ctx({"runs": 30}))
	Offers.note_fail(s, 7)
	t.eq(Offers.due(s, _ctx({"on_lose": true, "runs": 40, "now": T0 + 23 * H})), "", "chưa đủ 24 giờ")
	t.eq(Offers.due(s, _ctx({"on_lose": true, "runs": 40, "now": T0 + 24 * H})), "rescue_pack", "đủ 24 giờ")
	# thua level khác thì chuỗi bắt đầu lại
	Offers.note_fail(s, 8)
	t.eq(s.fail_streak.level, 8, "level mới")
	t.eq(s.fail_streak.count, 1, "đếm lại")
	Offers.note_win(s, 8)
	t.eq(s.fail_streak.count, 0, "thắng xoá chuỗi")
	t.eq(Offers.due(s, _ctx({"on_lose": true, "runs": 99, "now": T0 + 99 * H})), "", "sau thắng")
	Config.reset()


func test_level_pack(t: T) -> void:
	var s := SaveSchema.defaults()
	t.eq(Offers.due(s, _ctx({"level": 10, "runs": 5})), "", "mới qua 9 level")
	# đánh dấu starter đã hiện để tách riêng level_pack
	Offers.shown(s, "starter_pack", _ctx({"level": 11, "runs": 1}))
	Offers.bought(s, "starter_pack", T0)
	t.eq(Offers.due(s, _ctx({"level": 11, "runs": 10})), "", "qua 10 level chưa có")
	# Mốc đầu ở L60 (first_level), rồi mỗi 50 level: L110, L160 (2026-11-10).
	t.eq(Offers.due(s, _ctx({"level": 51, "runs": 10})), "", "L51 chưa tới mốc đầu")
	t.eq(Offers.due(s, _ctx({"level": 59, "runs": 10})), "", "L59 chưa tới mốc đầu")
	t.eq(Offers.due(s, _ctx({"level": 60, "runs": 10})), "level_pack", "mốc đầu L60")
	Offers.shown(s, "level_pack", _ctx({"level": 60, "runs": 10}))
	t.eq(Offers.due(s, _ctx({"level": 85, "runs": 20})), "", "đang mở / cùng mốc")
	t.eq(Offers.open_offers(s, T0 + 71 * H).size(), 1, "mở 72 giờ")
	t.eq(Offers.open_offers(s, T0 + 72 * H).size(), 0, "hết hạn")
	t.eq(Offers.due(s, _ctx({"level": 109, "runs": 30, "now": T0 + 80 * H})), "", "hết hạn vẫn cùng mốc")
	t.eq(Offers.due(s, _ctx({"level": 110, "runs": 30, "now": T0 + 80 * H})), "level_pack", "mốc L110")
	Offers.shown(s, "level_pack", _ctx({"level": 110, "runs": 30, "now": T0 + 80 * H}))
	Offers.bought(s, "level_pack", T0 + 81 * H)
	t.eq(Offers.open_offers(s, T0 + 82 * H).size(), 0, "mua xong đóng")
	t.eq(Offers.due(s, _ctx({"level": 159, "runs": 40, "now": T0 + 90 * H})), "", "chưa tới mốc L160")
	t.eq(Offers.due(s, _ctx({"level": 160, "runs": 40, "now": T0 + 90 * H})), "level_pack", "mua rồi vẫn có mốc sau")
	Config.apply_remote({"offers_level_pack_first_level": "30"})
	var s2 := SaveSchema.defaults()
	Offers.bought(s2, "starter_pack", T0)
	t.eq(Offers.due(s2, _ctx({"level": 30, "runs": 10})), "level_pack", "Remote Config offers_level_pack_first_level")
	Config.reset()


## Shop pack cards follow their offer: Starter, Level Pack only while open; Rescue while the lose streak holds.
func test_in_shop(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	for id in ["starter_pack", "level_pack", "rescue_pack"]:
		t.eq(Offers.in_shop(s, id, T0), false, "người chơi mới: không bán " + id)
	t.eq(Offers.in_shop(s, "unknown", T0), false, "id lạ")
	Offers.shown(s, "starter_pack", _ctx({"level": 11}))
	t.eq(Offers.in_shop(s, "starter_pack", T0 + 47 * H), true, "starter đang mở")
	t.eq(Offers.in_shop(s, "starter_pack", T0 + 48 * H), false, "starter hết hạn")
	Offers.shown(s, "level_pack", _ctx({"level": 60}))
	t.eq(Offers.in_shop(s, "level_pack", T0 + 71 * H), true, "level pack đang mở")
	Offers.bought(s, "level_pack", T0 + H)
	t.eq(Offers.in_shop(s, "level_pack", T0 + 2 * H), false, "level pack mua xong")
	var s2 := SaveSchema.defaults()
	Offers.shown(s2, "starter_pack", _ctx({"level": 11}))
	Offers.bought(s2, "starter_pack", T0 + H)
	t.eq(Offers.in_shop(s2, "starter_pack", T0 + 2 * H), false, "starter mua một lần")
	for i in 3:
		Offers.note_fail(s2, 7)
	t.eq(Offers.in_shop(s2, "rescue_pack", T0), false, "rescue tắt trong Config")
	Config.OFFERS.rescue_pack.enabled = true
	t.eq(Offers.in_shop(s2, "rescue_pack", T0), true, "thua liền 3 lần")
	Offers.note_win(s2, 7)
	t.eq(Offers.in_shop(s2, "rescue_pack", T0), false, "thắng thì thôi")
	var s3: Dictionary = JSON.parse_string(JSON.stringify(s))
	t.eq(Offers.in_shop(s3, "starter_pack", T0 + H), true, "sau JSON")
	Config.reset()


func test_gates(t: T) -> void:
	var s := SaveSchema.defaults()
	var c := _ctx({"level": 11, "runs": 11, "first_session": true, "session_start": T0 - 299})
	t.eq(Offers.due(s, c), "", "trong 5 phút đầu phiên đầu")
	c.session_start = T0 - 300
	t.eq(Offers.due(s, c), "starter_pack", "đủ 5 phút")
	c.session_start = T0 - 10
	c.first_session = false
	t.eq(Offers.due(s, c), "starter_pack", "không phải phiên đầu")
	# cách nhau ít nhất 3 lượt
	Offers.shown(s, "starter_pack", _ctx({"level": 11, "runs": 11}))
	Offers.bought(s, "starter_pack", T0)
	var c2 := _ctx({"level": 11, "inter_today": 3, "runs": 13})
	t.eq(Offers.due(s, c2), "", "mới cách 2 lượt")
	c2.runs = 14
	t.eq(Offers.due(s, c2), "remove_ads", "cách 3 lượt")
	t.eq(s.offers.last_run, 11, "last_run ghi lúc hiện")


func test_priority_and_roundtrip(t: T) -> void:
	Config.OFFERS.rescue_pack.enabled = true
	var s := SaveSchema.defaults()
	Offers.note_fail(s, 3)
	Offers.note_fail(s, 3)
	Offers.note_fail(s, 3)
	var c := _ctx({"level": 11, "inter_today": 3})
	t.eq(Offers.due(s, c), "starter_pack", "starter ưu tiên")
	c.on_lose = true
	t.eq(Offers.due(s, c), "rescue_pack", "màn thua chỉ xét rescue")
	# lưu rồi nạp lại qua JSON (số thành float) vẫn chạy đúng
	Offers.shown(s, "starter_pack", _ctx({"level": 11, "runs": 12}))
	var s2: Dictionary = JSON.parse_string(JSON.stringify(s))
	t.eq(Offers.due(s2, _ctx({"level": 11, "runs": 40})), "rescue_pack", "starter đang mở, còn rescue")
	t.eq(Offers.open_offers(s2, T0 + H).size(), 1, "open sau JSON")
	Offers.bought(s2, "starter_pack", T0 + H)
	t.eq(Offers.open_offers(s2, T0 + 2 * H).size(), 0, "bought sau JSON")
	Config.reset()


func test_remote_config(t: T) -> void:
	var s := SaveSchema.defaults()
	Config.apply_remote({"offers_starter_pack_after_level": "20"})
	t.eq(Offers.due(s, _ctx({"level": 8, "runs": 5})), "", "ghi đè after_level")
	t.eq(Offers.due(s, _ctx({"level": 21, "runs": 5})), "starter_pack", "qua mốc mới")
	Config.reset()
