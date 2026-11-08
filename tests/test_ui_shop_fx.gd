extends RefCounted
## Shop animation (shop_fx.gd): cards pop in, loops (UiMotion FLOAT, WOBBLE, SHINE) on tiles, badges and buttons,
## bought gold flies to the top bar's chip that counts up, Owned pops; nothing while baking.
const T := preload("res://tests/t.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const ShopFx := preload("res://src/ui/shop_fx.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const MockAds := preload("res://src/platform/mock_ads.gd")
const ShopScene := preload("res://scenes/shop.tscn")

const DIR := "user://test_test_ui_shop_fx"
const SATURDAY := 1704542400  # 2024-01-06 12:00 UTC, weekend sale
const MONDAY := 1704715200  # 2024-01-08 12:00 UTC


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


func _open() -> Node:
	var n: Node = ShopScene.instantiate()
	_root().add_child(n)
	n.call("setup", {"source": "test"})
	return n


func _free(n: Node) -> void:
	_root().remove_child(n)
	n.free()


func _motions(shop: Node, kind: int) -> Array:
	var out: Array = []
	for m in shop.find_children(UiMotion.NODE_NAME, "", true, false):
		if int(m.get("kind")) == kind:
			out.append(m)
	return out


func _cards(shop: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in shop.ui.node(shop.C).get_children():
		if c is Control and (c as Control).visible:
			out.append(c)
	return out


func test_float_wobble_shine_poses(t: T) -> void:
	t.eq(UiMotion.float_lift(0.0), 0.0, "nổi: bắt đầu tại chỗ")
	t.near(UiMotion.float_lift(UiMotion.FLOAT_SEC * 0.5), UiMotion.FLOAT_LIFT, 0.0001, "nổi: đỉnh giữa chu kỳ")
	for i in 24:
		t.ok(UiMotion.float_lift(i * 0.1) >= 0.0, "nổi không chìm dưới chỗ cũ")
	t.eq(UiMotion.wobble_pose(0.0), [0.0, 0.0], "lắc: bắt đầu đứng yên")
	var a: Array = UiMotion.wobble_pose(UiMotion.WOBBLE_BURST - 0.0001)
	var b: Array = UiMotion.wobble_pose(UiMotion.WOBBLE_BURST + 0.0001)
	t.near(float(a[0]), float(b[0]), 0.1, "lắc: hết đợt liền mạch (góc)")
	t.near(float(a[1]), float(b[1]), 0.01, "lắc: hết đợt liền mạch (phồng)")
	t.eq(UiMotion.wobble_pose(UiMotion.WOBBLE_PERIOD - 0.01), [0.0, 0.0], "lắc: nghỉ tới đợt sau")
	t.near(float(UiMotion.wobble_pose(UiMotion.WOBBLE_BURST * 0.5)[1]), UiMotion.WOBBLE_POP, 0.0001, "lắc: phồng nhất giữa đợt")
	t.eq(UiMotion.shine_progress(0.0), 0.0, "loé: vào từ mép trái")
	t.near(UiMotion.shine_progress(UiMotion.SHINE_SWEEP * 0.5), 0.5, 0.0001, "loé: giữa đợt ở giữa")
	t.eq(UiMotion.shine_progress(UiMotion.SHINE_SWEEP + 0.01), -1.0, "loé: nghỉ sau đợt")
	var last := -1.0
	for i in 10:
		var p := UiMotion.shine_progress(UiMotion.SHINE_SWEEP * i / 10.0)
		t.ok(p > last, "loé đi một chiều")
		last = p


func test_motion_delay_and_hosts(t: T) -> void:
	var c := Control.new()
	c.position = Vector2(10, 20)
	c.size = Vector2(100, 100)
	_root().add_child(c)
	var m := UiMotion.attach(c, UiMotion.FLOAT, 0.5)
	t.near(float(m.get("time")), -0.5, 0.0001, "delay lùi chu kỳ đầu")
	m.call("_process", 0.4)
	t.eq(c.position, Vector2(10, 20), "chưa tới lượt thì đứng yên")
	m.call("_process", 0.1 + UiMotion.FLOAT_SEC * 0.5)
	t.near(c.position.y, 20.0 - UiMotion.FLOAT_LIFT * 100.0, 0.001, "nổi lên theo chiều cao icon")
	t.eq(c.position.x, 10.0, "chỉ nổi dọc")
	c.free()

	var badge := Control.new()
	badge.size = Vector2(80, 80)
	_root().add_child(badge)
	var w := UiMotion.attach(badge, UiMotion.WOBBLE, 0.0)
	w.call("_process", UiMotion.WOBBLE_BURST * 0.5)
	t.near(badge.scale.x, 1.0 + UiMotion.WOBBLE_POP, 0.0001, "lắc: phồng")
	t.ok(absf(badge.rotation) > 0.01, "lắc: nghiêng")
	w.call("_process", UiMotion.WOBBLE_BURST)
	t.near(badge.rotation, 0.0, 0.0001, "lắc: về góc cũ")
	badge.free()

	var btn := Button.new()
	var img := Control.new()
	img.size = Vector2(200, 80)
	btn.add_child(img)
	_root().add_child(btn)
	var s := UiMotion.attach(img, UiMotion.SHINE, 0.0)
	var mat := img.material as ShaderMaterial
	t.ok(mat != null and mat.shader.resource_path == UiMotion.SHINE_SHADER, "loé: gắn shine.gdshader")
	s.call("_process", UiMotion.SHINE_SWEEP * 0.5)
	t.near(float(mat.get_shader_parameter("progress")), 0.5, 0.0001, "loé: vệt giữa nút")
	t.eq(mat.get_shader_parameter("box_size"), Vector2(200, 80), "loé: theo cỡ node")
	btn.disabled = true
	s.call("_process", 0.0)
	t.eq(float(mat.get_shader_parameter("progress")), -1.0, "nút khoá không loé")
	btn.free()

	# host là chính nút (nút Chơi ở Home)
	var self_btn := Button.new()
	self_btn.size = Vector2(300, 120)
	_root().add_child(self_btn)
	var sb := UiMotion.attach(self_btn, UiMotion.SHINE, 0.0)
	var smat := self_btn.material as ShaderMaterial
	sb.call("_process", UiMotion.SHINE_SWEEP * 0.5)
	t.near(float(smat.get_shader_parameter("progress")), 0.5, 0.0001, "loé trên chính nút")
	self_btn.disabled = true
	sb.call("_process", 0.0)
	t.eq(float(smat.get_shader_parameter("progress")), -1.0, "chính nút tắt thì không loé")
	self_btn.free()

	var own := Control.new()
	var keep := CanvasItemMaterial.new()
	own.material = keep
	_root().add_child(own)
	UiMotion.attach(own, UiMotion.SHINE)
	t.eq(own.material, keep, "node có material riêng giữ nguyên")
	own.free()


func test_shop_cards_pop_in(t: T) -> void:
	_g()
	var shop := _open()
	var fx: Control = shop.fx
	t.ok(fx != null and fx.get_parent() == shop, "ShopFx là con của Shop")
	t.eq(fx.get_index(), shop.get_child_count() - 1, "ShopFx nằm trên cùng (xu bay qua thanh)")
	t.ok(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ShopFx không bắt chạm")
	var cards := _cards(shop)
	t.ok(cards.size() >= 6, "có các thẻ để hiện lần lượt")
	t.eq(cards[0].modulate.a, 0.0, "thẻ đầu chưa hiện")
	t.near(cards[0].scale.x, ShopFx.ENTER_SCALE, 0.0001, "thẻ đầu nhỏ lại")
	var tw: Tween = fx.enter_tween
	t.ok(tw != null and tw.is_valid(), "có tween hiện thẻ")
	tw.custom_step(ShopFx.ENTER_DELAY + ShopFx.ENTER_STEP)
	t.ok(cards[0].modulate.a > 0.0, "thẻ đầu đang hiện")
	t.eq(cards[cards.size() - 1].modulate.a, 0.0, "thẻ cuối còn chờ")
	tw.custom_step(ShopFx.ENTER_DELAY + ShopFx.ENTER_STEPS * ShopFx.ENTER_STEP + ShopFx.ENTER_GROW)
	for c in cards:
		t.eq(c.modulate.a, 1.0, "hiện đủ: " + c.name)
		t.eq(c.scale, Vector2.ONE, "đủ cỡ: " + c.name)
	_free(shop)


func test_shop_idle_loops(t: T) -> void:
	_g(SATURDAY)
	var shop := _open()
	var floats := _motions(shop, UiMotion.FLOAT)
	# 5 gold tiles + ADS Daily (+ preview heart tiles).
	t.ok(floats.size() >= 6, "icon gold các ô nổi: %d" % floats.size())
	for m in floats:
		t.eq(str(m.get_parent().name), "Icon", "nổi trên icon")
	var badges := 0
	for b in shop.find_children("SellBadge", "", true, false):
		if ShopFx._shown_under(b, shop.ui.node(shop.C)):
			badges += 1
			t.ok(b.get_node_or_null(UiMotion.NODE_NAME) != null, "nhãn sale lắc: " + str(b.get_path()))
	t.ok(badges >= 6, "cuối tuần có nhãn -50%%: %d" % badges)
	t.eq(_motions(shop, UiMotion.WOBBLE).size(), badges, "chỉ nhãn đang hiện mới lắc")
	for sku in shop.buy_buttons:
		var img: Node = (shop.buy_buttons[sku] as Node).get_node("image")
		t.ok(img.get_node_or_null(UiMotion.NODE_NAME) != null, "nút mua loé: " + str(sku))
	t.ok(shop.video_button.get_node("image").get_node_or_null(UiMotion.NODE_NAME) != null, "nút video loé")
	var big: Node = shop.ui.node(shop.C + "/Shop_GoldBigPack/BG")
	t.ok(big.get_node_or_null(UiMotion.NODE_NAME) != null, "gói gold lớn loé")
	# Ripple: the same kind starts later further down.
	var shines := _motions(shop, UiMotion.SHINE)
	var first: Node = shines[0]
	var last: Node = shines[0]
	for m in shines:
		if (m.get_parent() as Control).get_global_rect().position.y < (first.get_parent() as Control).get_global_rect().position.y:
			first = m
		if (m.get_parent() as Control).get_global_rect().position.y > (last.get_parent() as Control).get_global_rect().position.y:
			last = m
	t.ok(float(first.get("time")) > float(last.get("time")), "vệt sáng lan từ trên xuống")
	t.near(float(first.get("time")), -ShopFx.IDLE_DELAY, 0.0001, "vòng đầu sau khi thẻ đã hiện")
	_free(shop)
	_g()
	shop = _open()
	t.eq(_motions(shop, UiMotion.WOBBLE).size(), 0, "ngày thường không có nhãn sale để lắc")
	_free(shop)


func test_shop_gold_flies_to_chip(t: T) -> void:
	var g := _g()
	var shop := _open()
	var fx: Control = shop.fx
	var top: Control = fx.top
	var before := int(g.s.coins)
	await shop.buy("gold_pack_1")
	var wallet := int(g.s.coins)
	t.eq(wallet, before + 1000, "gold vào ví ngay")
	t.ok(fx.flying(), "gold đang bay")
	var coin_fx: Node = fx.get_node_or_null("GoldFx")
	t.ok(coin_fx != null, "CoinFx trên ShopFx")
	t.eq(int(top.gold_shown), before, "chip bắt đầu từ ví trước khi mua")
	t.eq(shop.coins_label.text, str(before), "chip chưa nhảy số")
	# coins_changed during the flight does not jump the chip.
	g.coins_changed.emit(wallet)
	t.eq(shop.coins_label.text, str(before), "chip vẫn đếm theo xu bay")
	var seen: Array = []
	for i in 40:
		if not is_instance_valid(coin_fx):
			break
		coin_fx.call("_process", 0.05)
		var v := int(shop.coins_label.text)
		if seen.is_empty() or v != int(seen[seen.size() - 1]):
			seen.append(v)
	t.ok(seen.size() >= 3, "chip đếm dần: %s" % str(seen))
	for i in range(1, seen.size()):
		t.ok(int(seen[i]) > int(seen[i - 1]), "số chỉ tăng")
	t.ok(not fx.flying(), "bay xong")
	t.eq(int(top.gold_shown), -1, "chip về số trong ví")
	t.eq(shop.coins_label.text, str(wallet), "chip đúng số trong ví")
	t.eq(int(g.s.coins), wallet, "bay không đổi ví")

	# Video gold flies from the ADS Daily tile's coin.
	await shop.watch_video()
	t.eq(int(g.s.coins), wallet + 200, "+200 gold")
	t.ok(fx.flying(), "gold video bay")
	t.eq(int(top.gold_shown), wallet, "chip từ ví trước video")
	_free(shop)


func test_shop_owned_pops(t: T) -> void:
	_g()
	var shop := _open()
	var label: Label = shop.price_labels["remove_ads"]
	t.eq(label.scale, Vector2.ONE, "giá đứng yên trước khi mua")
	await shop.buy("remove_ads")
	t.ok(label.scale.x > 1.0, "Owned nảy lên")
	t.ok(shop.fx.flying(), "500 gold tặng kèm bay lên chip")
	var price: Label = shop.price_labels["gold_pack_1"]
	t.eq(price.scale, Vector2.ONE, "gói khác không nảy")
	_free(shop)


func test_shop_fx_off_while_baking(t: T) -> void:
	_g(SATURDAY)
	UnityUI.baking = true
	var shop := _open()
	UnityUI.baking = false
	t.eq(shop.fx.enter_tween, null, "bake: không tween hiện thẻ")
	for c in _cards(shop):
		t.eq(c.modulate.a, 1.0, "bake: thẻ giữ alpha")
		t.eq(c.scale, Vector2.ONE, "bake: thẻ giữ cỡ")
	for k in [UiMotion.FLOAT, UiMotion.WOBBLE, UiMotion.SHINE]:
		t.eq(_motions(shop, k).size(), 0, "bake: không motion %d" % k)
	_free(shop)
