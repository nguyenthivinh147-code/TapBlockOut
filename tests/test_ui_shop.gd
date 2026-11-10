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
const Offers := preload("res://src/meta/offers.gd")


## A purchase whose store sheet stays open until the test emits `released` (then the player cancels).
class HeldIap extends "res://src/platform/mock_iap.gd":
	signal released
	var started: int = 0

	func buy(sku: String) -> Dictionary:
		started += 1
		await released
		return {"status": "cancel", "sku": sku, "token": "", "order_id": ""}

	func restore() -> bool:
		started += 1
		await released
		return false


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


## The player at `level` with the Starter and Level Pack offers open, as their popups leave them.
func _offers_open(g: Node, level: int = 51) -> void:
	g.s.level = level
	for id in ["starter_pack", "level_pack"]:
		Offers.shown(g.s, id, {"now": int(g.test_now), "day": 0, "runs": 0, "level": level})


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
	_offers_open(g)
	var shop := _open(ShopScene, {"source": "test"})
	for i in range(1, 7):
		t.ok(shop.buy_buttons.has("gold_pack_%d" % i), "gói gold %d" % i)
		t.ok(not shop.buy_buttons.has("gold_pack_%d_sale" % i), "không sale ngày thường")
	t.eq(_text(shop.buy_buttons["gold_pack_1"]), "$1.99", "giá hiển thị")
	for sku in ["starter_pack", "level_pack", "remove_ads", "remove_ads_bundle"]:
		t.ok(shop.buy_buttons.has(sku), "gói " + sku)
	# rescue_pack is switched off in Config.OFFERS (2026-11-10): its BundleSweet card is hidden.
	t.ok(not shop.buy_buttons.has("rescue_pack"), "không bán gói rescue")
	t.ok(not (shop.find_child("BundleSweet", true, false) as Control).visible, "ẩn thẻ rescue")
	t.ok(shop.restore_button != null, "có Restore")
	t.ok(shop.video_button != null and not shop.video_button.disabled, "video bật")
	t.eq(_p().an.named("shop_open").size(), 1, "log shop_open")
	t.eq(_p().an.named("rv_offer").size(), 1, "rv_offer khi hiện nút video")
	for b in shop.buy_buttons.values():
		t.ok(_hit_h(b) >= 96 - 0.01, "nút đủ cao")
	_free(shop)


## Shop.PACK_ART replaces the prefab art of the pack cards (Unity boosters) with the game's boosters.
func test_shop_pack_art(t: T) -> void:
	var g := _g()
	_offers_open(g)
	var shop := _open(ShopScene, {"source": "test"})
	var content: Node = shop.find_child("Content", true, false)
	var cards := {"StarterPack": "art_starter_pack", "SpecialPack": "art_level_pack_shop",
		"Shop_RemoveAdsBundle": "art_no_ads_bundle"}
	for card in cards:
		var art := str(cards[card])
		t.ok(ThemeKit.has_real_icon(art), "có file " + art)
		t.ok(Shop.PACK_ART.values().has(art), "PACK_ART có " + art)
		var tex: Texture2D = content.get_node(str(card) + "/Image (2)").get("tex")
		t.eq(tex, ThemeKit.icon(art), "thẻ %s dùng %s" % [card, art])
	_free(shop)


## Remote Config offers_rescue_pack_enabled switches the rescue pack back on: its card shows and sells it while the
## player has lost the same level 3 times in a row.
func test_shop_rescue_pack_back_on(t: T) -> void:
	var g := _g()
	Config.apply_remote({"offers_rescue_pack_enabled": "true"})
	var calm := _open(ShopScene, {"source": "test"})
	t.ok(not calm.buy_buttons.has("rescue_pack"), "chưa thua liền: chưa bán")
	_free(calm)
	g.s.fail_streak = {"level": 1, "count": 3}
	var shop := _open(ShopScene, {"source": "test"})
	t.ok(shop.buy_buttons.has("rescue_pack"), "bán lại gói rescue")
	t.ok((shop.find_child("BundleSweet", true, false) as Control).visible, "thẻ rescue hiện")
	t.ok((shop.find_child("BundleTitle", true, false) as Control).visible, "tiêu đề gói khác hiện")
	_free(shop)
	Config.reset()


## Pack cards show only while their offer is open (design.md mục 7): none for a new player, Starter and Level Pack
## during their 48 / 72 hour windows; a bought Starter (one-time) or Level Pack hides its card at once, and the title
## goes with the last card (user request 2026-11-10). helper_great is not sold in the Shop at any level: only the
## out-of-moves popup sells it.
func test_shop_packs_follow_offers(t: T) -> void:
	var g := _g()
	g.s.level = 16
	var shop := _open(ShopScene, {"source": "test"})
	for sku in ["starter_pack", "level_pack", "rescue_pack", "helper_great"]:
		t.ok(not shop.buy_buttons.has(sku), "chưa đủ điều kiện: không bán " + sku)
	for card in ["StarterPack", "SpecialPack", "BundleSweet", "BundleTitle"]:
		t.ok(not (shop.find_child(card, true, false) as Control).visible, "ẩn " + card)
	t.ok(shop.find_child("Pack_helper_great", true, false) == null, "L16: không có Helper Pack")
	t.ok(not _has_label(shop, shop.tr("shop_section_helpers")), "L16: không có tiêu đề Helper Packs")
	t.ok(shop.buy_buttons.has("remove_ads") and shop.buy_buttons.has("gold_pack_1"), "No Ads, gold vẫn bán")
	_free(shop)

	g.s.level = 40
	shop = _open(ShopScene, {"source": "test"})
	t.ok(not shop.buy_buttons.has("helper_great"), "L40: Shop vẫn không bán Great Pack")
	t.ok(not _has_label(shop, shop.tr("shop_section_helpers")), "L40: không có tiêu đề Helper Packs")
	_free(shop)

	_offers_open(g)
	shop = _open(ShopScene, {"source": "test"})
	for card in ["StarterPack", "SpecialPack", "BundleTitle"]:
		t.ok((shop.find_child(card, true, false) as Control).visible, "offer mở: hiện " + card)
	await shop.buy("starter_pack")
	t.ok(not (shop.find_child("StarterPack", true, false) as Control).visible, "Starter vừa mua: ẩn thẻ")
	t.ok((shop.find_child("BundleTitle", true, false) as Control).visible, "còn Level Pack: giữ tiêu đề")
	await shop.buy("level_pack")
	t.ok(not (shop.find_child("SpecialPack", true, false) as Control).visible, "Level Pack mua xong: ẩn")
	t.ok(not (shop.find_child("BundleTitle", true, false) as Control).visible, "hết thẻ: ẩn tiêu đề")
	_free(shop)

	shop = _open(ShopScene, {"source": "test"})
	t.ok(not shop.buy_buttons.has("starter_pack"), "mở lại: Starter đã mua thì ẩn")
	t.ok(not (shop.find_child("BundleTitle", true, false) as Control).visible, "mở lại: không còn gói, ẩn tiêu đề")
	_free(shop)

	# Expired window: a new save with the offers opened 72 hours ago.
	g.reset_for_test(DIR + "/save3.json")
	g.test_now = MONDAY - 72 * 3600
	_offers_open(g)
	g.test_now = MONDAY
	shop = _open(ShopScene, {"source": "test"})
	t.ok(not shop.buy_buttons.has("starter_pack"), "Starter hết hạn: ẩn")
	t.ok(not shop.buy_buttons.has("level_pack"), "Level Pack hết hạn: ẩn")
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


## While one pack's purchase is open only its button greys out; the other packs, the video and Restore keep their
## look (Unity StoreItem locks nothing else), and a second purchase waits for the first.
func test_shop_buy_dims_only_pressed_button(t: T) -> void:
	_g()
	var iap := HeldIap.new()
	_p().iap = iap
	var shop := _open(ShopScene)
	var held: Button = shop.buy_buttons["gold_pack_1"]
	shop.buy("gold_pack_1")
	t.ok(held.disabled, "nút vừa bấm khoá trong lúc mua")
	_check_others_live(t, shop.buy_buttons, "gold_pack_1", shop)
	t.ok(not shop.video_button.disabled, "video không khoá theo")
	t.ok(not shop.restore_button.disabled, "Restore không khoá theo")
	shop.buy("gold_pack_2")
	t.eq(iap.started, 1, "gói khác chờ giao dịch đang mở")
	iap.released.emit()
	await _root().get_tree().process_frame
	t.ok(not held.disabled, "xong thì nút mở lại")
	shop.restore()
	t.ok(shop.restore_button.disabled, "Restore khoá chính nó")
	_check_others_live(t, shop.buy_buttons, "", shop)
	iap.released.emit()
	await _root().get_tree().process_frame
	t.ok(not shop.restore_button.disabled, "Restore mở lại")
	_free(shop)


func _check_others_live(t: T, buttons: Dictionary, held_sku: String, shop: Node = null) -> void:
	for sku in buttons:
		if sku == held_sku or (shop != null and shop.is_owned(sku)):
			continue
		var b: Button = buttons[sku]
		t.ok(not b.disabled, sku + " không khoá theo")
		var tint: CanvasItem = b.get("tint_target")
		if tint != null:
			t.eq(tint.self_modulate, (b.get("tint_colors") as Array)[0], sku + " giữ màu thường")


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


## Pack names, buy buttons and prices stay inside their cards, and the ADS Daily progress inside its pill, in the
## language with the longest strings here (scenes/shop.tscn once saved these nodes snapped to the card corners).
func test_shop_cards_hold_their_text(t: T) -> void:
	_offers_open(_g())
	TranslationServer.set_locale("vi")
	var shop := _open(ShopScene, {"source": "test"})
	var content: Node = shop.find_child("Content", true, false)
	for card in ["Shop_RemoveAdsBundle", "Shop_RemoveAds", "StarterPack", "SpecialPack"]:
		var c: Control = content.get_node(card)
		# Inset like the prefab (26 units at least), not flush with the frame.
		var box := c.get_global_rect().grow(-20.0)
		for part in ["PackName", "Button_Purchase"]:
			t.ok(box.encloses((c.get_node(part) as Control).get_global_rect()), "%s/%s trong thẻ" % [card, part])
	for sku in shop.price_labels:
		var l: Label = shop.price_labels[sku]
		t.eq(l.get_line_count(), 1, "giá %s một dòng" % sku)
		t.ok(l.get_parent().get_global_rect().grow(1.0).encloses(l.get_global_rect()), "giá %s trong nút" % sku)
	var pill: Rect2 = (shop.find_child("AdsDaily", true, false).get_node("Image") as Control).get_global_rect()
	# The prefab's text rect pokes a little past the pill; its margins keep the text inside.
	var vl: Label = shop._video_text
	var box: StyleBox = vl.get_theme_stylebox("normal")
	var k := vl.get_global_transform().get_scale().x
	var text: Rect2 = vl.get_global_rect()
	t.ok(text.position.x + box.get_margin(SIDE_LEFT) * k >= pill.position.x
		and text.end.x - box.get_margin(SIDE_RIGHT) * k <= pill.end.x, "chữ ADS Daily trong viên nền")
	_free(shop)
	TranslationServer.set_locale("en")


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
	# The gold flies from the pack's tile to the chip (RewardFly), which counts on as the coins land.
	t.eq(coins.text, Shop.fmt_n0(1000), "khung giữ số cũ lúc gold bay")
	var fx := mini.find_children("RewardGoldFx", "", false, false)
	t.eq(fx.size(), 1, "gold bay lên khung gold của popup")
	for i in 40:
		if not fx.is_empty() and is_instance_valid(fx[0]):
			fx[0].call("_process", 0.05)
	t.eq(coins.text, Shop.fmt_n0(2000), "khung gold cập nhật sau khi gold bay tới")
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


func test_shop_mini_buy_dims_only_pressed_button(t: T) -> void:
	_g()
	var iap := HeldIap.new()
	_p().iap = iap
	var mini := _open(MiniScene, {"source": "rescue"})
	var held: Button = mini.buy_buttons["gold_pack_1"]
	mini.buy("gold_pack_1")
	t.ok(held.disabled, "nút vừa bấm khoá trong lúc mua")
	_check_others_live(t, mini.buy_buttons, "gold_pack_1")
	mini.buy("gold_pack_2")
	t.eq(iap.started, 1, "gói khác chờ giao dịch đang mở")
	iap.released.emit()
	await _root().get_tree().process_frame
	t.ok(not held.disabled, "xong thì nút mở lại")
	_free(mini)


func test_offer_popup(t: T) -> void:
	var g := _g()
	g.s.level = 11
	var id: String = g.check_offer(false)
	t.eq(id, "starter_pack", "starter mở")
	var pop := _open(OfferScene, {"id": id})
	t.eq(pop.sku, "starter_pack", "sku")
	t.eq(pop.contents().size(), 5, "gold + mạng vô hạn + 3 booster")
	var heart: Control = pop.ui.node(pop.GROUP + "/" + str(pop.SLOTS.heart))
	t.ok(heart.visible, "ô mạng vô hạn hiện")
	t.eq((heart.get_node("Text (TMP)") as Label).text, pop.tr("shop_heart_forever"), "chữ Vĩnh viễn")
	t.ok(pop.contents().has(pop.tr("shop_lives_forever")), "dòng mạng vô hạn vĩnh viễn")
	t.eq(_text(pop.buy_button), "$6.99", "chỉ giá trên nút")
	t.ok(pop.time_label.visible, "đếm ngược khi có hạn")
	t.eq(pop.time_label.text, pop.tr("offer_time_left") % "48:00:00", "còn 48 giờ")
	var res: Array = []
	pop.closed.connect(func(r: Variant) -> void: res.append(r))
	pop.buy_button.pressed.emit()
	await _root().get_tree().process_frame
	t.eq(int(g.s.coins), 7000, "6.000 gold")
	t.eq(int(g.s.inv.hint), 1, "booster")
	t.ok(bool(g.lives_view().infinite_forever), "mạng vô hạn vĩnh viễn")
	t.eq(g.lives_view().infinite, true, "đang vô hạn")
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
