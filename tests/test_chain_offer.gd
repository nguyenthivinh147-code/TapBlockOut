extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const ChainOffer := preload("res://src/meta/chain_offer.gd")
const PackConditions := preload("res://src/meta/pack_conditions.gd")

const T0 := 1700000000
const D := 86400


func test_activate_conditions(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(ChainOffer.try_activate(s, T0, 99), false, "chưa tới level 100")
	t.eq(ChainOffer.try_activate(s, T0, 100), true, "level 100 bật")
	t.eq(s.chain.id, "chain_a", "chuỗi đầu")
	t.eq(s.chain.expires, T0 + D, "sống 1 ngày")
	t.eq(s.chain.shown, false, "chưa hiện")
	t.eq(ChainOffer.try_activate(s, T0 + 10, 160), false, "đang chạy thì không bật thêm")


func test_expire_cooldown_rotation(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	ChainOffer.try_activate(s, T0, 150)
	t.eq(ChainOffer.update(s, T0 + D - 1), false, "chưa hết hạn")
	t.eq(ChainOffer.update(s, T0 + D + 500), true, "hết hạn")
	t.eq(s.chain.active, false, "tắt")
	t.eq(s.chain.cooldown_until, T0 + 4 * D, "nghỉ 3 ngày tính từ lúc hết hạn")
	t.eq(ChainOffer.try_activate(s, T0 + 3 * D, 160), false, "đang cooldown")
	t.eq(ChainOffer.try_activate(s, T0 + 4 * D, 160), true, "hết cooldown")
	t.eq(s.chain.id, "chain_b", "xoay sang chuỗi kế")
	ChainOffer.update(s, T0 + 6 * D)
	ChainOffer.try_activate(s, T0 + 10 * D, 160)
	t.eq(s.chain.id, "chain_a", "xoay vòng")


func test_trigger_rule(t: T) -> void:
	Config.reset()
	t.eq(ChainOffer.should_trigger(false, true), true, "-1: cả ván thắng, level HARD")
	t.eq(ChainOffer.should_trigger(true, true), true, "-1: thua HARD")
	Config.CHAIN["require_lose"] = 1
	t.eq(ChainOffer.should_trigger(true, false), true, "thua ở level thường")
	t.eq(ChainOffer.should_trigger(true, true), false, "thua ở HARD")
	t.eq(ChainOffer.should_trigger(false, false), false, "thắng")
	Config.reset()


func test_steps(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(ChainOffer.advance(s, T0), {}, "không có chuỗi")
	ChainOffer.try_activate(s, T0, 150)
	var cur := ChainOffer.current(s, T0 + 100)
	t.eq(cur.count, 8, "8 bước")
	t.eq(cur.step, 0, "bước đầu")
	t.eq(cur.seconds_left, D - 100, "đếm ngược")
	var a := ChainOffer.advance(s, T0 + 100)
	t.eq(a.type, "free", "bước free")
	t.eq(a.reward.coins, 300, "thưởng bước 0")
	t.eq(ChainOffer.advance(s, T0 + 100).type, "ad", "bước ad")
	ChainOffer.advance(s, T0)
	var pay := ChainOffer.advance(s, T0)
	t.eq(pay.type, "pay", "bước pay")
	t.eq(pay.reward.coins, 0, "pay không cộng thêm")
	for i in 4:
		ChainOffer.advance(s, T0)
	t.eq(ChainOffer.current_step(s, T0), {}, "hết bước")
	t.eq(ChainOffer.advance(s, T0), {}, "hết bước không tiến thêm")
	t.eq(s.chain.active, true, "làm hết bước không tắt chuỗi")


func test_autoshow_once(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(ChainOffer.should_autoshow(s, T0), false, "chưa có chuỗi")
	ChainOffer.try_activate(s, T0, 150)
	t.eq(ChainOffer.should_autoshow(s, T0), true, "chuỗi mới")
	ChainOffer.mark_shown(s)
	t.eq(ChainOffer.should_autoshow(s, T0), false, "chỉ một lần")
	ChainOffer.update(s, T0 + 2 * D)
	ChainOffer.try_activate(s, T0 + 5 * D, 160)
	t.eq(ChainOffer.should_autoshow(s, T0 + 5 * D), true, "chuỗi mới được hiện lại")


func test_save_survives_json(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	ChainOffer.try_activate(s, T0, 150)
	var back: Dictionary = SaveSchema.merge_defaults(JSON.parse_string(JSON.stringify(s)))
	t.eq(ChainOffer.current(back, T0).id, "chain_a", "đọc lại sau JSON")
	t.eq(back.chain.expires, T0 + D, "expires giữ kiểu int")
	t.eq(back.weekly.points, 0, "weekly có mặc định")


func test_pack_conditions(t: T) -> void:
	Config.reset()
	var s := SaveSchema.defaults()
	t.eq(PackConditions.can_show(s, "special_pack", 16), false, "chưa mua Starter")
	s.buys.append({"token": "a", "sku": "starter_pack"})
	t.eq(PackConditions.can_show(s, "special_pack", 15), false, "chưa tới level 16")
	t.eq(PackConditions.can_show(s, "special_pack", 16), true, "đủ điều kiện")
	t.eq(PackConditions.first_visible(s, 16), "special_pack", "gói đầu tiên")
	t.eq(PackConditions.first_visible(s, 10), "", "level thấp")
	s.buys.append({"token": "b", "sku": "special_pack"})
	t.eq(PackConditions.can_show(s, "special_pack", 40), true, "không giới hạn số lần mua")
	Config.PACKS["special_pack"]["purchase_limit"] = 2
	s.buys.append({"token": "c", "sku": "special_pack_sale"})
	t.eq(PackConditions.purchases(s, "special_pack"), 2, "bản sale tính như gói gốc")
	t.eq(PackConditions.can_show(s, "special_pack", 40), false, "chạm giới hạn")
	Config.PACKS["special_pack"]["purchase_limit"] = 0
	Config.PACKS["special_pack"]["exclude"] = ["starter_pack"]
	t.eq(PackConditions.can_show(s, "special_pack", 40), false, "đã sở hữu gói bị loại")
	t.eq(PackConditions.can_show(s, "khong_co", 40), false, "gói lạ")
	Config.reset()
