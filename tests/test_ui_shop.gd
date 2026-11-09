extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const MockAds := preload("res://src/platform/mock_ads.gd")

const DIR := "user://test_test_ui_shop"
const SATURDAY := 1704542400  # 2024-01-06 12:00 UTC
const MONDAY := 1704715200  # 2024-01-08 12:00 UTC

const ShopScene := preload("res://scenes/shop.tscn")
const MiniScene := preload("res://scenes/shop_mini.tscn")
const OfferScene := preload("res://scenes/popup_offer.tscn")
const Shop := preload("res://src/ui/shop.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g(now: int = MONDAY) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = now
	g.test_tz = 0
	var p: Node = _root().get_node("Platform")
	p.ads = MockAds.new()
	p.iap = MockIap.new()
	return g


func _p() -> Node:
	return _root().get_node("Platform")


func _open(scene: PackedScene, args: Dictionary = {}) -> Node:
	var n: Node = scene.instantiate()
	_root().add_child(n)
	n.call("setup", args)
	return n


func _free(n: Node) -> void:
	_root().remove_child(n)
	n.free()


func test_shop_lists_gold_packs_and_others(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene, {"source": "test"})
	for i in range(1, 7):
		t.ok(shop.buy_buttons.has("gold_pack_%d" % i), "gói gold %d" % i)
		t.ok(not shop.buy_buttons.has("gold_pack_%d_sale" % i), "không sale ngày thường")
	t.eq(_text(shop.buy_buttons["gold_pack_1"]), "$1.99", "giá hiển thị")
	for sku in ["starter_pack", "level_pack", "rescue_pack", "remove_ads", "remove_ads_bundle"]:
		t.ok(shop.buy_buttons.has(sku), "gói " + sku)
	t.ok(shop.restore_button != null, "có Restore")
	t.ok(shop.video_button != null and not shop.video_button.disabled, "video bật")
	t.eq(_p().an.named("shop_open").size(), 1, "log shop_open")
	t.eq(_p().an.named("rv_offer").size(), 1, "rv_offer khi hiện nút video")
	for b in shop.buy_buttons.values():
		t.ok(_hit_h(b) >= 96 - 0.01, "nút đủ cao")
	_free(shop)


func test_shop_weekend_sale(t: T) -> void:
	var g := _g(SATURDAY)
	var shop := _open(ShopScene)
	for i in range(1, 7):
		t.ok(shop.buy_buttons.has("gold_pack_%d_sale" % i), "SKU sale %d" % i)
	t.eq(_text(shop.buy_buttons["gold_pack_1_sale"]), "$1.99", "gói 1: giá giữ nguyên")
	t.eq(_text(shop.buy_buttons["gold_pack_2_sale"]), "$3.99", "gói 2: giá sale")
	var cat: Array = g.shop_catalog()
	t.eq(cat[0].has("sale_percent"), false, "gói 1 không giảm giá")
	t.eq(shop.sale_tag(cat[0]), "x2", "gói 1: nhãn x2")
	t.eq(shop.sale_tag(cat[1]), "-50%", "gói 2: nhãn -50%")
	_free(shop)


func test_shop_sale_tag(t: T) -> void:
	var shop := _open(ShopScene)
	t.eq(shop.sale_tag({"sale": false, "gold": 2000, "base_gold": 1000}), "", "không sale")
	t.eq(shop.sale_tag({"sale": true, "sale_percent": 40, "gold": 2000, "base_gold": 1000}), "-40%", "giảm giá trước")
	t.eq(shop.sale_tag({"sale": true, "gold": 3000, "base_gold": 1000}), "x3", "gấp gold")
	t.eq(shop.sale_tag({"sale": true, "gold": 1500, "base_gold": 1000}), "+50%", "thêm gold lẻ")
	t.eq(shop.sale_tag({"sale": true, "gold": 1000, "base_gold": 1000}), "", "không hơn gì")
	_free(shop)


func test_shop_buy_gold_pack(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	var closed_log: Array = []
	shop.closed.connect(func(r: Variant) -> void: closed_log.append(r))
	(shop.buy_buttons["gold_pack_1"] as Button).pressed.emit()
	await _root().get_tree().process_frame
	t.eq(int(g.s.coins), 1000 + 1000, "cộng gold")
	t.eq(g.s.buys.size(), 1, "ghi buys")
	t.eq(_p().iap.pending().size(), 0, "đã finish")
	t.eq(shop.last_toast, shop.tr("shop_buy_ok"), "toast cảm ơn")
	shop.close_button.pressed.emit()
	t.eq(closed_log.size(), 1, "đóng một lần")
	t.eq(closed_log[0].bought, true, "kết quả bought")
	_free(shop)


## The hearts' + opens a popup over the Shop (main.gd): the Shop must still leave by its tabs afterwards.
func test_shop_lives_popup_keeps_tabs(t: T) -> void:
	_g()
	var shop := _open(ShopScene)
	var closed_log: Array = []
	shop.closed.connect(func(r: Variant) -> void: closed_log.append(r))
	(shop.find_child("LivesPlus", true, false) as Button).pressed.emit()
	t.eq(closed_log.size(), 1, "lives báo main")
	t.eq(str(closed_log[0].get("action", "")), "lives", "action lives")
	shop.close_button.pressed.emit()
	t.eq(closed_log.size(), 2, "tab Home vẫn rời Shop sau popup mạng")
	shop.close_button.pressed.emit()
	t.eq(closed_log.size(), 2, "rời Shop một lần")
	_free(shop)


func test_shop_buy_cancel_and_invalid(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	_p().iap.simulate("cancel")
	await shop.buy("gold_pack_1")
	t.eq(int(g.s.coins), 1000, "huỷ không thưởng")
	t.eq(shop.last_toast, "", "huỷ không báo")
	_p().iap.simulate("invalid")
	await shop.buy("gold_pack_1")
	t.eq(int(g.s.coins), 1000, "đơn giả không thưởng")
	t.eq(shop.last_toast, shop.tr("shop_buy_failed"), "báo lỗi")
	_p().iap.simulate("pending")
	await shop.buy("gold_pack_2")
	t.eq(int(g.s.coins), 1000, "pending không thưởng")
	t.eq(shop.last_toast, shop.tr("shop_buy_pending"), "báo pending")
	t.eq(g.s.buys.size(), 0, "không ghi buys")
	_free(shop)


func test_shop_remove_ads_owned_and_restore(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	t.ok(_no_ads_shown(shop), "chưa mua: mục No Ads hiện")
	await shop.buy("remove_ads")
	t.eq(bool(g.s.no_ads), true, "no_ads")
	t.eq(int(g.s.coins), 1000, "gói thường không kèm gold")
	t.ok((shop.buy_buttons["remove_ads"] as Button).disabled, "nút khoá khi đã sở hữu")
	t.ok((shop.buy_buttons["remove_ads_bundle"] as Button).disabled, "bundle cũng khoá")
	t.ok(_no_ads_hidden(shop), "mua xong: ẩn cả mục No Ads")
	# Restore không giao lần hai.
	shop.restore_button.pressed.emit()
	await _root().get_tree().process_frame
	t.eq(int(g.s.coins), 1000, "restore không giao hai lần")
	t.eq(g.s.buys.size(), 1, "buys giữ nguyên")
	t.eq(shop.last_toast, shop.tr("shop_restore_ok"), "báo đã khôi phục")
	_free(shop)
	# Mở lại Shop: mục vẫn ẩn.
	var again := _open(ShopScene)
	t.ok(_no_ads_hidden(again), "mở lại: mục No Ads ẩn")
	_free(again)
	# Cài lại: bản lưu mới, đơn sở hữu còn ở store.
	g.reset_for_test(DIR + "/save2.json")
	g.test_now = MONDAY
	var shop2 := _open(ShopScene)
	t.ok(not (shop2.buy_buttons["remove_ads"] as Button).disabled, "bản lưu mới: chưa sở hữu")
	t.ok(_no_ads_shown(shop2), "bản lưu mới: mục No Ads hiện")
	await shop2.restore()
	t.eq(bool(g.s.no_ads), true, "restore trả Remove Ads")
	t.ok((shop2.buy_buttons["remove_ads"] as Button).disabled, "Owned sau restore")
	t.ok(_no_ads_hidden(shop2), "restore xong: ẩn cả mục No Ads")
	_free(shop2)


func test_shop_no_ads_bundle(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	var info: Dictionary = Config.SKUS.remove_ads_bundle
	t.eq(_text(shop.buy_buttons["remove_ads_bundle"]), "$9.99", "giá bundle")
	var card := Shop.C + "/Shop_RemoveAdsBundle"
	var gold := shop.ui.label(card + "/ItemContainer/Row(Clone)/ShopRewardItem(Clone) (1)/Text (TMP)") as Label
	t.eq(gold.text, Shop.fmt_n0(int(info.gold)), "thẻ ghi gold của bundle")
	t.ok(gold.is_visible_in_tree(), "ô gold hiện")
	for k in Shop.NO_ADS_BOOSTERS:
		var slot: Control = shop.ui.node(card + "/ItemContainer/" + str(Shop.NO_ADS_BOOSTERS[k][0]))
		t.ok(slot.is_visible_in_tree(), "ô booster " + str(k))
	t.ok(not shop.ui.node(card + "/SellBadge").visible, "không có nhãn giảm giá")
	var inv_before: Dictionary = (g.s.inv as Dictionary).duplicate()
	await shop.buy("remove_ads_bundle")
	t.eq(bool(g.s.no_ads), true, "bundle bỏ quảng cáo")
	t.eq(int(g.s.coins), 1000 + int(info.gold), "cộng gold của bundle")
	for k in ["hint", "move", "smash"]:
		t.eq(int(g.s.inv[k]), int(inv_before.get(k, 0)) + int(info.inv[k]), "booster " + k)
	t.ok(_no_ads_hidden(shop), "mua bundle: ẩn cả mục No Ads")
	t.ok((shop.buy_buttons["remove_ads"] as Button).disabled, "không mua thêm gói thường")
	_free(shop)


func _no_ads_shown(shop: Node) -> bool:
	for n in Shop.NO_ADS_NODES:
		if not shop.ui.node(Shop.C + "/" + str(n)).visible:
			return false
	return true


func _no_ads_hidden(shop: Node) -> bool:
	for n in Shop.NO_ADS_NODES:
		if shop.ui.node(Shop.C + "/" + str(n)).visible:
			return false
	return true


func test_shop_restore_none(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	await shop.restore()
	t.eq(shop.last_toast, shop.tr("shop_restore_none"), "không có gì để khôi phục")
	_free(shop)


func test_shop_video(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	_p().ads.simulate("closed")
	await shop.watch_video()
	t.eq(int(g.s.coins), 1000, "đóng sớm không thưởng")
	t.eq(g.shop_videos_left(), 5, "chưa trừ lượt")
	await shop.watch_video()
	t.eq(int(g.s.coins), 1200, "+200 gold")
	t.eq(g.shop_videos_left(), 4, "còn 4")
	for i in 4:
		await shop.watch_video()
	t.eq(int(g.s.coins), 2000, "đủ 5 video = 1000 gold")
	t.eq(g.shop_videos_left(), 0, "hết lượt")
	t.ok(shop.video_button.disabled, "nút video khoá khi hết")
	await shop.watch_video()
	t.eq(int(g.s.coins), 2000, "không quá 5 video")
	_free(shop)


func test_shop_ads_daily(t: T) -> void:
	var g := _g()
	var shop := _open(ShopScene)
	t.ok(shop.find_child("AdsDaily", true, false) != null, "ADS Daily nằm trong Shop")
	t.ok(_has_label(shop, shop.tr("ads_daily_progress") % [0, 5]), "0 / 5")
	await shop.watch_video()
	t.eq(int(g.s.coins), 1200, "+200 gold")
	t.ok(_has_label(shop, shop.tr("ads_daily_progress") % [1, 5]), "dựng lại: 1 / 5")
	_free(shop)
	g.test_now = MONDAY + 86400
	shop = _open(ShopScene)
	t.ok(_has_label(shop, shop.tr("ads_daily_progress") % [0, 5]), "ngày mới làm mới")
	t.ok(not shop.video_button.disabled, "ngày mới xem được")
	_free(shop)


## Prefab buttons (unity_ui.gd) draw their text in a child TMP label.
func _text(b: Node) -> String:
	if b is Button and (b as Button).text != "":
		return (b as Button).text
	for l in b.find_children("*", "Label", true, false):
		if (l as Label).visible:
			return (l as Label).text
	return ""


## Prefab buttons keep the Unity art size and grow only their hit area.
func _hit_h(b: Node) -> float:
	return (b.call("hit_size") as Vector2).y if b.has_method("hit_size") else (b as Control).custom_minimum_size.y


func _has_label(n: Node, needle: String) -> bool:
	if n is Label and not n.is_queued_for_deletion() and (n as Label).text.contains(needle):
		return true
	for c in n.get_children():
		if _has_label(c, needle):
			return true
	return false


func test_shop_mini(t: T) -> void:
	var g := _g()
	var mini := _open(MiniScene, {"source": "rescue"})
	t.eq(mini.buy_buttons.size(), 6, "chỉ 6 gói gold")
	t.ok(mini.close_button != null, "có nút đóng")
	# Title inside the ribbon's oval, not as wide as the ribbon.
	var hdr: Label = mini.ui.label("Panel/Image/txtHeader")
	t.ok(hdr.size.x <= mini.ui.node("Panel/Image").size.x * 0.85, "tiêu đề gọn trong dải tím")
	# Gold balance in a chip like HubTop's GoldPanel.
	var coins: Label = mini.coins_label
	var chip := coins.get_parent()
	t.eq(str(chip.name), "GoldChip", "số gold nằm trong khung")
	t.ok(chip.get_node_or_null("Bar") is Panel and chip.get_node_or_null("Icon") is TextureRect, "khung có nền và đồng gold")
	t.eq(coins.text, Shop.fmt_n0(int(g.s.coins)), "số gold trong ví")
	var font := coins.get_theme_font_size("font_size")
	mini._on_coins_changed(123456789)
	t.ok(ThemeKit.FONT.get_string_size(coins.text, HORIZONTAL_ALIGNMENT_LEFT, -1, coins.get_theme_font_size("font_size")).x <= coins.size.x, "số dài co cho vừa khung")
	mini._on_coins_changed(int(g.s.coins))
	t.eq(coins.get_theme_font_size("font_size"), font, "số ngắn về cỡ cũ")
	var res: Array = []
	mini.closed.connect(func(r: Variant) -> void: res.append(r))
	await mini.buy("gold_pack_1")
	t.eq(int(g.s.coins), 2000, "mua trong shop mini")
	t.eq(coins.text, Shop.fmt_n0(2000), "khung gold cập nhật sau khi mua")
	mini.close_button.pressed.emit()
	mini.close()
	t.eq(res.size(), 1, "đóng một lần")
	t.eq(res[0].bought, true, "bought")
	_free(mini)
	var mini2 := _open(MiniScene)
	var res2: Array = []
	mini2.closed.connect(func(r: Variant) -> void: res2.append(r))
	mini2.close_button.pressed.emit()
	t.eq(res2[0].bought, false, "đóng không mua")
	_free(mini2)


func test_offer_popup(t: T) -> void:
	var g := _g()
	g.s.level = 11
	var id: String = g.check_offer(false)
	t.eq(id, "starter_pack", "starter mở")
	var pop := _open(OfferScene, {"id": id})
	t.eq(pop.sku, "starter_pack", "sku")
	t.eq(pop.contents().size(), 4, "gold + 3 booster")
	t.eq(_text(pop.buy_button), "$6.99", "chỉ giá trên nút")
	t.ok(pop.time_label.visible, "đếm ngược khi có hạn")
	t.eq(pop.time_label.text, pop.tr("offer_time_left") % "48:00:00", "còn 48 giờ")
	var res: Array = []
	pop.closed.connect(func(r: Variant) -> void: res.append(r))
	pop.buy_button.pressed.emit()
	await _root().get_tree().process_frame
	t.eq(int(g.s.coins), 7000, "6.000 gold")
	t.eq(int(g.s.inv.hint), 1, "booster")
	t.eq(res.size(), 1, "đóng sau mua")
	t.eq(res[0].bought, true, "bought")
	t.eq(res[0].id, "starter_pack", "id")
	t.eq(g.offers_open().size(), 0, "offer hết mở")
	_free(pop)


func test_offer_popup_later_and_variants(t: T) -> void:
	var g := _g()
	for id in ["starter_pack", "remove_ads", "rescue_pack", "level_pack"]:
		var pop := _open(OfferScene, {"id": id})
		t.ok(pop._title() != "", "tiêu đề " + id)
		t.ok(pop._body() != "", "nội dung " + id)
		t.ok(pop.contents().size() >= 1, "có nội dung " + id)
		var res: Array = []
		pop.closed.connect(func(r: Variant) -> void: res.append(r))
		pop.later_button.pressed.emit()
		pop.later_button.pressed.emit()
		t.eq(res.size(), 1, "đóng một lần " + id)
		t.eq(res[0].bought, false, "để sau " + id)
		_free(pop)
	t.eq(int(g.s.coins), 1000, "không mua thì không đổi")
	var pop2 := _open(OfferScene, {"id": "rescue_pack"})
	_p().iap.simulate("invalid")
	await pop2.buy()
	t.eq(pop2.last_toast, pop2.tr("shop_buy_failed"), "đơn giả báo lỗi")
	t.eq(int(g.s.inv.move), 0, "đơn giả không thưởng")
	_free(pop2)
