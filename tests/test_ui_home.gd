extends RefCounted
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const HomeScript := preload("res://src/ui/home.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")

const DIR := "user://test_ui_home"
const SCENE := "res://scenes/home.tscn"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g(level: int = 1) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = level
	g.test_now = 1_800_000_000
	return g


func _home() -> Control:
	var h := (load(SCENE) as PackedScene).instantiate() as Control
	_root().add_child(h)
	h.setup({})
	return h


## Bấm nút và trả kết quả closed ({} nếu không phát).
func _press(h: Control, btn: Button) -> Dictionary:
	var got := {"r": {}}
	h.closed.connect(func(r: Variant) -> void: got["r"] = r)
	btn.pressed.emit()
	return got["r"]


func test_play_shows_level(t: T) -> void:
	var g := _g(7)
	g.s.coins = 1234
	var h := _home()
	t.eq(h.path_nodes[1].num.text, "7", "mốc hiện tại ghi số level")
	t.eq(h.play_label.text, "PLAY", "nút Chơi ghi PLAY")
	var shine: Node = h.play_btn.get_node_or_null("Motion")
	t.ok(shine != null and int(shine.get("kind")) == HomeScript.UiMotion.SHINE, "nút Chơi có dải sáng quét dọc")
	t.ok(not h.hard_tag.visible, "level thường không ghi độ khó")
	t.eq(h.gold_label.text, "1234", "gold")
	t.ok(not h.play_btn.disabled, "nút Chơi bấm được")
	t.ok(not h.coming_soon_label.visible, "không hiện sắp có level mới")
	t.eq(_press(h, h.play_btn).get("action", ""), "play", "bấm Chơi")
	h.queue_free()


func test_early_levels_hide_lives_gift_shop(t: T) -> void:
	_g(1)
	var h := _home()
	t.ok(not h.lives_panel.visible, "L1 không hiện mạng")
	t.ok(not h.gift_btn.get_parent().visible, "L1 ẩn quà")
	t.ok(h.shop_btn.disabled, "L1 shop khoá")
	t.ok(h.shop_caption.text.contains("11"), "shop khoá ghi Level 11")
	t.ok(not h.challenge_btn.get_parent().visible, "Daily Challenge tắt (Config.FEATURES) thì ẩn icon")
	t.ok(h.leaderboard_btn.get_parent().visible, "Bảng xếp hạng vẫn hiện")
	t.ok(not h.offer_chip.get_parent().visible, "không có offer thì không hiện icon offer")
	h.queue_free()
	Config.FEATURES.challenge = true
	h = _home()
	t.ok(h.challenge_btn.disabled, "challenge khoá")
	t.eq(h.challenge_caption.text, "Level 50", "challenge ghi Level 50")
	h.queue_free()


func test_shop_unlock_and_gift_badge(t: T) -> void:
	var g := _g(11)
	var h := _home()
	t.ok(not h.shop_btn.disabled, "L11 shop mở")
	t.ok(not h.gift_btn.get_parent().visible, "L11 chưa có icon quà")
	h.queue_free()
	g.s.level = 14
	h = _home()
	t.ok(h.gift_btn.get_parent().visible, "L14 có icon quà")
	t.ok(h.gift_badge.visible, "chưa nhận quà thì có chấm đỏ")
	t.eq(_press(h, h.shop_btn).get("action", ""), "shop", "bấm shop")
	t.eq(_press(h, h.gift_btn).get("action", ""), "gift", "bấm quà")
	t.eq(_press(h, h.settings_btn).get("action", ""), "settings", "bấm settings")
	t.eq(_press(h, h.profile_btn).get("action", ""), "profile", "bấm avatar")
	h.queue_free()
	# nhận quà thì mất chấm đỏ và Home tự cập nhật
	var h2 := _home()
	t.ok(h2.gift_badge.visible, "chấm đỏ trước khi nhận")
	var reward: Dictionary = g.daily_claim()
	t.ok(not reward.is_empty(), "nhận quà")
	g.coins_changed.emit(int(g.s.coins))
	t.ok(not h2.gift_badge.visible, "hết chấm đỏ sau khi nhận")
	h2.queue_free()


func test_lives_and_countdown(t: T) -> void:
	var g := _g(10)
	var h := _home()
	t.ok(h.lives_panel.visible, "L10 hiện mạng")
	t.eq(h.lives_timer_label.text, "Full", "mạng đầy")
	t.ok(h.lives_label.text.contains("10"), "10 mạng")
	# mất 2 mạng, đếm hồi
	g.s.lives.count = 8
	g.s.lives.next_at = g.now() + 125
	g.lives_changed.emit()
	t.ok(h.lives_label.text.contains("8"), "còn 8 mạng")
	t.eq(h.lives_timer_label.text, "2:05", "đếm hồi")
	h.queue_free()


func test_no_lives_goes_to_no_lives(t: T) -> void:
	var g := _g(12)
	g.s.lives.count = 0
	g.s.lives.next_at = g.now() + 600
	var h := _home()
	t.eq(_press(h, h.play_btn).get("action", ""), "no_lives", "hết mạng thì không vào level")
	h.queue_free()


func test_offer_chip(t: T) -> void:
	var g := _g(11)
	g.s.offers.items["starter_pack"] = {"shown": 1, "at": g.now(), "until": g.now() + 3700,
		"bought": 0, "bought_at": 0, "day": 0, "day_n": 1, "key": 0}
	var h := _home()
	t.ok(h.offer_chip.get_parent().visible, "có offer mở thì hiện icon offer")
	t.eq(h.offer_chip.tooltip_text, "Starter Pack", "tên offer")
	t.eq(h.offer_caption.text, "1:01:40", "ribbon ghi thời gian còn")
	var r := _press(h, h.offer_chip)
	t.eq(r.get("action", ""), "offer", "bấm chip")
	t.eq(r.get("id", ""), "starter_pack", "id offer")
	h.queue_free()


func test_demo_end(t: T) -> void:
	var g := _g(21)
	# demo: sau L20 hiện Sắp có level mới, nút Chơi tắt
	Config.demo_override = 1
	var h := _home()
	t.ok(h.coming_soon_label.visible, "demo hết level thì hiện Sắp có level mới")
	t.ok(h.play_btn.disabled, "nút Chơi tắt")
	t.eq(h.coming_soon_label.text, "New levels coming soon", "chữ")
	h.queue_free()
	# phát hành: L21 có data, và sau L300 lặp lại nội dung nên không bao giờ hết
	Config.demo_override = 0
	var h2 := _home()
	t.ok(not h2.coming_soon_label.visible, "phát hành: L21 chơi được")
	t.ok(not h2.play_btn.disabled, "phát hành: nút Chơi mở")
	g.s.level = 99999
	h2.refresh()
	t.ok(not h2.play_btn.disabled, "phát hành: level sinh trong game")
	h2.queue_free()
	Config.demo_override = -1


func test_fmt_time(t: T) -> void:
	t.eq(HomeScript.fmt_time(0), "0:00", "0")
	t.eq(HomeScript.fmt_time(75), "1:15", "75")
	t.eq(HomeScript.fmt_time(3725), "1:02:05", "3725")
	t.eq(HomeScript.fmt_time(90000), "1d 1h", "1 ngày")
	t.eq(HomeScript.fmt_time(-5), "0:00", "âm")


func test_equipped_avatar_shown(t: T) -> void:
	var g := _g(1)
	g.s.cos.owned.append("avatar_03")
	g.cos_equip("avatar_03")
	var h := _home()
	var av: Control = h.profile_btn.get_node("AvatarView")
	t.ok(av != null, "có avatar view")
	t.ok(av.get_node("Avatar").texture != null, "avatar có texture")
	h.queue_free()


func test_challenge_button_emits_action(t: T) -> void:
	var g := _g(60)
	Config.FEATURES.challenge = true
	var h := _home()
	t.ok(not h.challenge_btn.disabled, "challenge mở ở L60")
	t.eq(_press(h, h.challenge_btn).get("action", ""), "challenge", "Home chỉ phát closed(challenge)")
	h.queue_free()
	g.reset_for_test(DIR + "/save.json")
	Config.FEATURES.challenge = true
	Config.demo_override = 1
	h = _home()
	t.ok(h.challenge_btn.disabled, "demo khoá challenge")
	h.queue_free()
	Config.demo_override = -1


## Ba khung Figma "main menu": thường (kim cương xanh, PLAY xanh), Hard (lục giác đỏ, đầu lâu), Super Hard (tím).
func test_difficulty_tiers(t: T) -> void:
	var g := _g(1)
	var h := _home()
	t.eq(h.path_nodes[2].num.text, "1", "level 1: mốc hiện tại ở dưới cùng")
	t.eq(h.path_nodes[0].num.text, "3", "level 1: hai mốc khoá phía trên")
	t.ok(h.path_nodes[0].badge.texture != null, "mốc khoá có icon khoá")
	_check_background(t, h, "thường")
	h.queue_free()
	for tier in ["hard", "very_hard"]:
		var lv := 2
		while lv < 400 and g.difficulty_of(lv) != tier:
			lv += 1
		t.ok(lv < 400, "có level %s" % tier)
		g.s.level = lv
		h = _home()
		t.ok(h.hard_tag.visible, "%s: nút Chơi ghi độ khó" % tier)
		t.eq(h.hard_tag.text, "VERY HARD" if tier == "very_hard" else "HARD", "%s: chữ độ khó" % tier)
		t.ok(h.path_nodes[1].skull.texture != null, "%s: mốc hiện tại có đầu lâu" % tier)
		t.eq(h.path_nodes[2].num.text, str(lv - 1), "%s: mốc vừa qua ở dưới" % tier)
		t.ok(h.path_nodes[2].badge.texture != null, "%s: mốc vừa qua có dấu tích" % tier)
		_check_background(t, h, tier)
		h.queue_free()


## Ba mốc thẳng hàng trên đường giữa ray kẹo thẳng đứng; mốc khoá là lục giác xám ở mọi độ khó.
func test_nodes_on_rail(t: T) -> void:
	for level in [1, 7]:
		_g(level)
		var h := _home()
		var rail := h.get_node("%Rail") as Control
		var k := rail.size.y / HomeScript.RAIL_RECT.size.y
		t.near(rail.size.x / HomeScript.RAIL_RECT.size.x, k, 0.001, "L%d: ray co đều hai chiều" % level)
		var mid := rail.get_rect().get_center().x
		for pn: Dictionary in h.path_nodes:
			var c: Vector2 = (pn.root as Control).get_rect().get_center()
			t.near(c.x, mid, 1.0, "L%d: mốc %s nằm trên ray" % [level, (pn.num as Label).text])
			t.ok(c.y > rail.position.y and c.y < rail.get_rect().end.y, "L%d: mốc %s trong chiều dài ray" % [level, (pn.num as Label).text])
		var cur := 2 if level == 1 else 1
		var locked: Dictionary = h.path_nodes[0]
		t.eq((locked.sprite as TextureRect).texture, UiAtlas.tex("hex_gray"), "L%d: mốc khoá là lục giác xám" % level)
		var glow := h.get_node("%Glow") as Control
		t.near(glow.get_rect().get_center().x, (h.path_nodes[cur].root as Control).get_rect().get_center().x, 1.0,
			"L%d: glow theo mốc hiện tại" % level)
		h.queue_free()


## Nền Home giống nhau ở mọi độ khó: dải xanh của khung Hard, lớp TopShade, hoạ tiết kẹo mờ 2,7% (7/255).
func _check_background(t: T, h: Control, label: String) -> void:
	t.ok(h.get_node("%Gradient").visible, "%s: dải nền xanh" % label)
	t.ok(h.get_node("%TopShade").visible, "%s: lớp TopShade" % label)
	t.near(h.get_node("%CandyPattern").modulate.a, 7.0 / 255.0, 0.0001, "%s: hoạ tiết kẹo mờ" % label)
