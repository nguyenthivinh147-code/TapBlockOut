extends RefCounted
## UI motion (ui_motion.gd): glow pulse, ad icon hop, attached by sprite in Unity layers (not while baking);
## HubNav's highlight slides from the previous tab and the icons trade sizes, a pressed tab dips; main slides the hub
## screens with their bars held in place.
const T := preload("res://tests/t.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const Main := preload("res://src/ui/main.gd")

const AD_ICON := "Panel/Content/GameObject/WatchAdsBtn/Image"
const LIGHT := "Panel/LightRotate/Image"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _box(pos: Vector2, scale: Vector2 = Vector2.ONE) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(80, 80)
	c.pivot_offset_ratio = Vector2(0.5, 0.5)
	c.scale = scale
	_tree().root.add_child(c)
	return c


func _owner() -> Control:
	var c := Control.new()
	c.size = Vector2(720, 1280)
	_tree().root.add_child(c)
	return c


func test_pulse_breathes_on_the_own_scale(t: T) -> void:
	var c := _box(Vector2(10, 10), Vector2(-1, 1))
	var m := UiMotion.attach(c, UiMotion.PULSE)
	t.eq(UiMotion.attach(c, UiMotion.AD_HOP), m, "một motion mỗi node")
	m.call("_process", UiMotion.PULSE_SEC * 0.5)
	t.near(c.scale.x, -(1.0 + UiMotion.PULSE_SCALE), 0.0001, "đỉnh phồng giữ dấu lật")
	t.near(c.scale.y, 1.0 + UiMotion.PULSE_SCALE, 0.0001, "đỉnh phồng")
	# Someone else's scale (a reveal) becomes the base.
	c.scale = Vector2(2, 2)
	m.call("_process", UiMotion.PULSE_SEC * 0.5)
	t.near(c.scale.x, 2.0, 0.0001, "hết chu kỳ về đúng base mới")
	t.eq(c.position, Vector2(10, 10), "pulse không dời chỗ")
	c.free()


func test_hop_pose_is_continuous_and_rests(t: T) -> void:
	t.eq(UiMotion.hop_pose(0.0), [0.0, 0.0, 0.0], "bắt đầu đứng yên")
	t.eq(UiMotion.hop_pose(UiMotion.HOP_PERIOD - 0.01), [0.0, 0.0, 0.0], "cuối chu kỳ đứng yên")
	for edge in [UiMotion.HOP_CROUCH, UiMotion.HOP_AIR, UiMotion.HOP_LAND, UiMotion.HOP_WIGGLE]:
		var a: Array = UiMotion.hop_pose(edge - 0.0001)
		var b: Array = UiMotion.hop_pose(edge + 0.0001)
		# lift and squash in shares, tilt in degrees (steep while wiggling)
		for i in 3:
			t.near(float(a[i]), float(b[i]), 0.1 if i == 2 else 0.01, "liền mạch ở %.2f [%d]" % [edge, i])
	var apex: Array = UiMotion.hop_pose((UiMotion.HOP_CROUCH + UiMotion.HOP_AIR) * 0.5)
	t.near(float(apex[0]), UiMotion.HOP_HEIGHT, 0.0001, "đỉnh nhảy")
	t.ok(float(apex[1]) < 0.0, "trên không thì giãn dọc")


func test_sob_stretch_is_gentle_upward_and_rests(t: T) -> void:
	t.eq(UiMotion.sob_stretch(0.0), 0.0, "bắt đầu đứng yên")
	t.near(UiMotion.sob_stretch(UiMotion.SOB_PERIOD - 0.0001), 0.0, 0.0001, "cuối chu kỳ đứng yên")
	t.eq(UiMotion.sob_stretch((UiMotion.SOB_BURST + UiMotion.SOB_PERIOD) * 0.5), 0.0, "sau tiếng nấc thì nghỉ, không co xuống")
	for b in range(1, int(UiMotion.SOB_BOBS) + 1):
		var edge := UiMotion.SOB_BURST * b / UiMotion.SOB_BOBS
		t.near(UiMotion.sob_stretch(edge - 0.0001), UiMotion.sob_stretch(edge + 0.0001), 0.001, "liền mạch ở %.2f" % edge)
	t.near(UiMotion.sob_stretch(UiMotion.SOB_BURST / UiMotion.SOB_BOBS * 0.5), UiMotion.SOB_STRETCH, 0.0001, "nấc đầu dài nhất")
	var low := 1.0
	var high := 0.0
	for i in 200:
		var st := UiMotion.sob_stretch(UiMotion.SOB_PERIOD * i / 200.0)
		low = minf(low, st)
		high = maxf(high, st)
	t.ok(low >= 0.0, "chỉ kéo dài, không co")
	t.ok(high <= UiMotion.SOB_STRETCH + 0.0001, "kéo dài nhẹ")


func test_sob_keeps_its_feet_and_grows_up(t: T) -> void:
	var c := _box(Vector2(100, 200))
	var m := UiMotion.attach(c, UiMotion.SOB)
	m.call("_process", UiMotion.SOB_DELAY * 0.5)
	t.eq(c.position, Vector2(100, 200), "chờ SOB_DELAY trước nấc đầu")
	m.call("_process", UiMotion.SOB_DELAY * 0.5 + UiMotion.SOB_BURST / UiMotion.SOB_BOBS * 0.5)
	t.ok(c.scale.y > 1.0 and c.scale.x < 1.0, "kéo dài lên")
	# Box 80 px, pivot at its centre: feet line at SOB_FOOT * 80 below the top.
	var feet := c.position.y + 40.0 + (UiMotion.SOB_FOOT * 80.0 - 40.0) * c.scale.y
	t.near(feet, 200.0 + UiMotion.SOB_FOOT * 80.0, 0.0001, "chân đứng yên")
	t.ok(c.position.y + 40.0 - 40.0 * c.scale.y < 200.0, "đỉnh cao lên")
	t.near(c.position.x, 100.0, 0.0001, "không dời ngang")
	t.eq(c.rotation, 0.0, "không nghiêng")
	m.call("_process", UiMotion.SOB_PERIOD - UiMotion.SOB_BURST / UiMotion.SOB_BOBS * 0.5)
	t.ok(c.position.is_equal_approx(Vector2(100, 200)), "hết chu kỳ về chỗ")
	t.ok(c.scale.is_equal_approx(Vector2.ONE), "hết co giãn")
	c.free()


func test_tear_pose_wells_runs_and_fades(t: T) -> void:
	t.eq(UiMotion.TEAR_PERIOD, UiMotion.SOB_PERIOD, "mỗi tiếng nấc một giọt lệ")
	var start: Array = UiMotion.tear_pose(0.0)
	t.near(float(start[3]), 0.0, 0.0001, "chưa ứa thì ẩn")
	t.near(float(start[1]), UiMotion.TEAR_START, 0.0001, "ứa ra từ nhỏ")
	var full: Array = UiMotion.tear_pose((UiMotion.TEAR_WELL + UiMotion.TEAR_CLING) * 0.5)
	t.eq(full, [0.0, 1.0, 1.0, 1.0], "đọng đủ cỡ dưới mắt, đúng chỗ vẽ")
	var run: Array = UiMotion.tear_pose((UiMotion.TEAR_CLING + UiMotion.TEAR_RUN) * 0.5)
	t.ok(float(run[0]) > 0.0 and float(run[0]) < UiMotion.TEAR_DROP, "đang chảy xuống má")
	t.ok(float(run[2]) > 1.0 and float(run[1]) < 1.0, "chảy thì dài ra")
	t.near(float(run[3]), 1.0, 0.0001, "chưa mờ khi đang chảy")
	var late: Array = UiMotion.tear_pose((UiMotion.TEAR_RUN + UiMotion.TEAR_FADE) * 0.5)
	t.ok(float(late[0]) > float(run[0]) and float(late[3]) < 1.0 and float(late[3]) > 0.0, "chảy tiếp và mờ dần")
	t.near(float(UiMotion.tear_pose(UiMotion.TEAR_FADE + 0.01)[3]), 0.0, 0.0001, "hết giọt thì ẩn tới chu kỳ sau")
	# Continuous while it shows: wells, clings, runs (alpha, down, scale).
	for edge in [UiMotion.TEAR_WELL, UiMotion.TEAR_CLING, UiMotion.TEAR_RUN]:
		var a: Array = UiMotion.tear_pose(edge - 0.0001)
		var b: Array = UiMotion.tear_pose(edge + 0.0001)
		for i in 4:
			t.near(float(a[i]), float(b[i]), 0.01, "liền mạch ở %.2f [%d]" % [edge, i])
	var last := 0.0
	var falls := true
	for i in 101:
		var d := float(UiMotion.tear_pose(lerpf(UiMotion.TEAR_CLING, UiMotion.TEAR_FADE - 0.0001, i / 100.0))[0])
		falls = falls and d >= last
		last = d
	t.ok(falls, "chỉ chảy xuống, không ngược lên")


func test_tear_runs_down_from_its_place_and_hides(t: T) -> void:
	var c := _box(Vector2(40, 50))
	var m := UiMotion.attach(c, UiMotion.TEAR)
	t.near(c.modulate.a, 0.0, 0.0001, "ẩn ngay khi gắn")
	m.call("_process", UiMotion.TEAR_DELAY + (UiMotion.TEAR_WELL + UiMotion.TEAR_CLING) * 0.5)
	t.near(c.modulate.a, 1.0, 0.0001, "đọng dưới mắt")
	t.ok(c.position.is_equal_approx(Vector2(40, 50)), "đọng đúng chỗ vẽ")
	m.call("_process", UiMotion.TEAR_RUN - (UiMotion.TEAR_WELL + UiMotion.TEAR_CLING) * 0.5)
	t.ok(c.position.y > 50.0, "chảy xuống")
	t.near(c.position.x, 40.0, 0.0001, "chảy thẳng xuống")
	# Past the fade, before the next tear wells up.
	m.call("_process", (UiMotion.TEAR_FADE + UiMotion.TEAR_PERIOD) * 0.5 - UiMotion.TEAR_RUN)
	t.near(c.modulate.a, 0.0, 0.0001, "hết giọt thì ẩn")
	t.ok(c.position.is_equal_approx(Vector2(40, 50)), "về chỗ cũ cho giọt sau")
	t.ok(c.scale.is_equal_approx(Vector2.ONE), "về cỡ cũ")
	c.free()


func test_ad_hop_moves_then_returns_to_its_layout(t: T) -> void:
	var c := _box(Vector2(100, 200))
	var m := UiMotion.attach(c, UiMotion.AD_HOP)
	m.call("_process", UiMotion.HOP_DELAY * 0.5)
	t.eq(c.position, Vector2(100, 200), "chờ HOP_DELAY trước lần nhảy đầu")
	m.call("_process", UiMotion.HOP_DELAY * 0.5 + (UiMotion.HOP_CROUCH + UiMotion.HOP_AIR) * 0.5)
	t.ok(c.position.y < 200.0 - UiMotion.HOP_HEIGHT * 80.0 * 0.5, "đang bay lên")
	t.near(c.position.x, 100.0, 0.0001, "nhảy thẳng đứng")
	# Layout moves the icon mid-hop: the new place is the base.
	c.position = Vector2(300, 400)
	m.call("_process", UiMotion.HOP_LAND - UiMotion.HOP_AIR * 0.5 + (UiMotion.HOP_WIGGLE - UiMotion.HOP_LAND) * 0.3)
	t.ok(absf(c.rotation) > 0.01, "lắc sau khi tiếp đất")
	m.call("_process", UiMotion.HOP_PERIOD - UiMotion.HOP_WIGGLE)
	t.ok(c.position.is_equal_approx(Vector2(300, 400)), "về đúng chỗ layout mới")
	t.near(c.rotation, 0.0, 0.0001, "hết lắc")
	t.ok(c.scale.is_equal_approx(Vector2.ONE), "hết co giãn")
	c.free()


func test_hidden_icon_rests_on_its_base(t: T) -> void:
	var c := _box(Vector2(50, 60))
	var m := UiMotion.attach(c, UiMotion.AD_HOP)
	m.call("_process", UiMotion.HOP_DELAY + (UiMotion.HOP_CROUCH + UiMotion.HOP_AIR) * 0.5)
	t.ok(not c.position.is_equal_approx(Vector2(50, 60)), "đang nhảy")
	c.visible = false
	m.call("_process", 0.016)
	t.ok(c.position.is_equal_approx(Vector2(50, 60)), "ẩn thì về chỗ")
	t.ok(c.scale.is_equal_approx(Vector2.ONE), "ẩn thì hết co giãn")
	c.free()


func test_layers_attach_by_sprite(t: T) -> void:
	t.eq(UiMotion.kind_for_sprite("Resources_moved_UI_Maincenter:UI_Maincenter_7"), -1, "đồng hồ không phải icon ads")
	t.eq(UiMotion.kind_for_sprite(null), -1, "không sprite")
	var o := _owner()
	var v := UnityUI.build(o, "DailyRewardAdLayer", {"reveal": false})
	var ad: Control = v.node(AD_ICON)
	var light: Control = v.node(LIGHT)
	t.ok(ad != null and light != null, "có node")
	if ad != null and light != null:
		var am := ad.get_node_or_null(UiMotion.NODE_NAME)
		var lm := light.get_node_or_null(UiMotion.NODE_NAME)
		t.ok(am != null and int(am.get("kind")) == UiMotion.AD_HOP, "icon ads nhảy")
		t.ok(lm != null and int(lm.get("kind")) == UiMotion.PULSE, "tia sáng phập phồng")
		var copy := UnityUI.strip_runtime(ad.duplicate())
		t.ok(copy.get_node_or_null(UiMotion.NODE_NAME) == null, "bản sao bỏ motion")
		copy.free()
	o.free()
	var b := _owner()
	UnityUI.baking = true
	var vb := UnityUI.build(b, "DailyRewardAdLayer", {"reveal": false})
	UnityUI.baking = false
	var baked: Control = vb.node(AD_ICON)
	t.ok(baked != null and baked.get_node_or_null(UiMotion.NODE_NAME) == null, "bake không gắn motion")
	b.free()


func test_nav_slides_the_highlight_then_trades_icons(t: T) -> void:
	HubNav.last_tab = "road_trip"
	var nav: Control = HubNav.create("shop")
	_tree().root.add_child(nav)
	nav.size = Vector2(HubNav.DESIGN_W, HubNav.DESIGN_H)
	t.eq(HubNav.last_tab, "shop", "nhớ tab vừa mở")
	t.eq(nav.get("_morph_from"), "road_trip", "trượt từ tab Road Trip")
	var hl: Control = nav.get_node("Highlight")
	var shop: Button = nav.get("shop_btn")
	var rank: Button = nav.get("road_trip_btn")
	var shop_icon: Control = shop.get_node("Icon")
	var rank_icon: Control = rank.get_node("Icon")
	var panels: Array = ["ShopPanel", "HomePanel", "RoadTripPanel"].map(func(n: String) -> Rect2: return (nav.get_node(n) as Control).get_rect())
	# The deferred call from _ready() finds the switch already started and does nothing.
	nav.call("_morph")
	t.near(hl.position.x, HubNav.SLOT_W * 2 + HubNav.SLOT_INSET, 0.01, "khung đầu: ô sáng ở Road Trip")
	t.near(rank_icon.size.x, 168.0, 0.01, "khung đầu: icon Road Trip còn to")
	t.near(shop_icon.size.x, 96.0, 0.01, "khung đầu: icon Shop còn nhỏ")
	var from: Dictionary = nav.call("_layout", "road_trip")
	var to: Dictionary = nav.call("_layout", "shop")
	nav.call("_morph_step", HubNav.ICON_DELAY * 0.5, from, to)
	t.ok(hl.position.x < HubNav.SLOT_W * 1.5 and hl.position.x > HubNav.SLOT_INSET, "ô sáng đang lướt qua ô giữa")
	t.near(rank_icon.size.x, 168.0, 0.01, "icon chưa đổi khi ô sáng còn trượt")
	t.near((shop.get_node("Caption") as Control).modulate.a, 0.0, 0.001, "chữ Shop chưa hiện")
	await _tree().create_timer(HubNav.ICON_DELAY + HubNav.ICON_SEC + 0.15).timeout
	t.near(hl.position.x, HubNav.SLOT_INSET, 0.01, "ô sáng tới Shop")
	t.near(hl.size.x, HubNav.SLOT_W - HubNav.SLOT_INSET * 2, 0.01, "ô sáng giữ bề rộng")
	t.near(shop.position.y, 0.0, 0.01, "Shop nhô lên")
	t.near(rank.position.y, 102.0, 0.01, "Road Trip hạ xuống")
	t.near(rank.position.x, HubNav.SLOT_W * 2, 0.01, "các ô không đổi chỗ")
	t.near(shop_icon.size.x, 168.0, 0.01, "icon Shop to hẳn")
	t.near(rank_icon.size.x, 96.0, 0.01, "icon Road Trip nhỏ lại")
	t.near((shop.get_node("Caption") as Control).modulate.a, 1.0, 0.001, "chữ Shop hiện hẳn")
	for i in 3:
		t.eq((nav.get_node(["ShopPanel", "HomePanel", "RoadTripPanel"][i]) as Control).get_rect(), panels[i], "nền tím đứng yên %d" % i)
	nav.free()
	HubNav.last_tab = ""


func test_nav_same_tab_does_not_slide_and_press_dips(t: T) -> void:
	HubNav.last_tab = "home"
	var nav: Control = HubNav.create("home")
	_tree().root.add_child(nav)
	nav.size = Vector2(HubNav.DESIGN_W, HubNav.DESIGN_H)
	t.eq(nav.get("_morph_from"), "", "cùng tab thì không trượt")
	await _tree().process_frame
	var home: Button = nav.get("home_btn")
	t.near(home.size.x, HubNav.SLOT_W, 0.01, "ba ô bằng nhau")
	t.near(home.position.y, 0.0, 0.01, "cùng tab: hiện bố cục cuối ngay")
	t.near((nav.get_node("Highlight") as Control).position.x, HubNav.SLOT_W + HubNav.SLOT_INSET, 0.01, "ô sáng ở Home")
	home.button_down.emit()
	await _tree().create_timer(HubNav.PRESS_SEC + 0.1).timeout
	t.near(home.scale.x, HubNav.PRESS_SCALE, 0.001, "bấm thì lún")
	home.button_up.emit()
	await _tree().create_timer(HubNav.PRESS_SEC + 0.1).timeout
	t.near(home.scale.x, 1.0, 0.001, "thả thì bật lại")
	nav.free()
	HubNav.last_tab = ""


func test_main_slides_hub_screens(t: T) -> void:
	t.eq(Main.slide_dir("home", "shop"), -1, "Shop vào từ trái")
	t.eq(Main.slide_dir("home", "road_trip"), 1, "Road Trip vào từ phải")
	t.eq(Main.slide_dir("road_trip", "shop"), -1, "Road Trip sang Shop")
	t.eq(Main.slide_dir("home", "leaderboard"), 0, "Bảng xếp hạng (icon ở Home) không trượt")
	t.eq(Main.slide_dir("level", "home"), 0, "từ level không trượt")
	t.eq(Main.slide_dir("home", "home"), 0, "dựng lại Home không trượt")
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test("user://test_ui_motion/save.json")
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	var deadline := Time.get_ticks_msec() + 6000
	while not m.is_booted and Time.get_ticks_msec() < deadline:
		await _tree().process_frame
	t.ok(m.is_booted, "boot xong")
	g.s.level = 30
	m.go("home")
	var home: Control = m.current_screen
	m.go("shop")
	var shop: Control = m.current_screen
	t.ok(is_instance_valid(home) and not home.is_queued_for_deletion(), "Home còn lại trong lúc trượt")
	t.near(shop.position.x, -m.size.x, 0.5, "Shop bắt đầu ngoài mép trái")
	t.ok(m.get_node_or_null("SlideBlock") != null, "chặn chạm ngay")
	# The slide starts next frame, once the Shop's containers placed its bars.
	await _tree().process_frame
	t.ok(shop.position.x < 0.0, "Shop đang trượt vào")
	var nav: Control = shop.find_child("NavBar", true, false)
	t.near(nav.get_global_rect().position.x, 0.0, 0.5, "thanh dưới của Shop đứng yên")
	t.near(nav.get_global_rect().end.y, m.size.y, 0.5, "thanh dưới của Shop ở đáy")
	t.ok(not (home.find_child("NavBar", true, false) as Control).visible, "thanh dưới của Home ẩn")
	# A switch during the slide ends it at once.
	m.go("road_trip")
	t.ok(not is_instance_valid(home) or home.is_queued_for_deletion(), "Home bỏ khi có lần chuyển mới")
	t.near(shop.position.x, 0.0, 0.5, "Shop về chỗ trước khi trượt ra")
	var lb: Control = m.current_screen
	await _tree().create_timer(HubNav.SLIDE_SEC + 0.15).timeout
	t.near(lb.position.x, 0.0, 0.01, "Road Trip vào hẳn")
	t.ok(not is_instance_valid(shop) or shop.is_queued_for_deletion(), "Shop bỏ sau khi trượt")
	t.ok(m.get_node_or_null("SlideBlock") == null, "hết chặn chạm")
	var lb_nav: Control = lb.find_child("NavBar", true, false)
	t.near(lb_nav.get_global_rect().end.y, m.size.y, 0.5, "thanh dưới về đúng đáy")
	m.free()
	HubNav.last_tab = ""
