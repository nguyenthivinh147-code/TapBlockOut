extends RefCounted
## Màn đã dựng UI nhưng chưa nối logic: mở được, nút đủ cỡ, không lộ tên khoá dịch, và không lọt vào bản phát hành.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const Gallery := preload("res://src/ui/ui_gallery.gd")

const DIR := "user://test_ui_stubs"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g(level: int = 30) -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.s.level = level
	g.test_now = 1_800_000_000
	return g


func _open(scene: String, args: Dictionary = {}) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.setup(args)
	return node


func _walk_labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_walk_labels(c, out)


func test_every_screen_builds(t: T) -> void:
	_g()
	var re := RegEx.create_from_string("^[a-z]+_[a-z0-9_]+$")
	for s in Gallery.SCREENS:
		var scene := str(s[1])
		var node := _open(scene)
		t.ok(node.get_child_count() > 0, scene + " có nội dung")
		var texts: Array = []
		_walk_labels(node, texts)
		var raw: Array = []
		for x in texts:
			if re.search(str(x)) != null:
				raw.append(x)
		t.eq(raw, [], scene + " không lộ tên khoá dịch")
		for b in node.find_children("*", "Button", true, false):
			var btn := b as Button
			# Prefab buttons (unity_ui.gd) keep the Unity art size and grow only their hit area.
			var h: float = (btn.call("hit_size") as Vector2).y if btn.has_method("hit_size") else btn.custom_minimum_size.y
			t.ok(h >= 96 - 0.01, "%s/%s cao >= 96" % [scene, btn.name])
		node.free()


func test_buttons_only_emit_closed(t: T) -> void:
	var g := _g()
	var coins := int(g.s.coins)
	for scene in ["popup_remove_ads", "popup_heart_bundle", "popup_helper_pack", "popup_weekly_upsell"]:
		var node := _open(scene)
		var got: Array = []
		node.closed.connect(func(r: Variant) -> void: got.append(r))
		for b in node.find_children("*", "Button", true, false):
			(b as Button).pressed.emit()
		t.ok(got.size() > 0, scene + " phát closed")
		t.ok((got[0] as Dictionary).has("action"), scene + " kèm action")
		node.free()
	t.eq(int(g.s.coins), coins, "không đụng gold")
	t.eq(g.s.buys.size(), 0, "không tạo giao dịch")


func test_view_arg_overrides_sample(t: T) -> void:
	_g()
	var node := _open("popup_streak_end", {"view": {"streak": 99, "gold": 1, "hint": 1}})
	var texts: Array = []
	_walk_labels(node, texts)
	t.ok(str(texts).contains("99"), "dùng view truyền vào")
	node.free()


func test_hidden_in_release(t: T) -> void:
	_g()
	Config.ui_preview_override = 0
	var home := _open("home")
	t.ok(not home.find_child("LeaderboardButton", true, false).disabled, "Bảng xếp hạng đã nối logic: mở theo level, không theo bản build")
	var got: Array = []
	home.closed.connect(func(r: Variant) -> void: got.append(r))
	var labels: Array = []
	_walk_labels(home, labels)
	t.ok(not labels.has(home.tr("streak_title")), "không có Win Streak")
	t.ok(not labels.has(home.tr("home_ads_daily")), "không có ADS Daily")
	home.free()
	var settings := _open("settings")
	t.ok(settings.find_child("GalleryButton", true, false) == null, "không có danh sách xem trước")
	settings.free()
	var shop := _open("shop", {"source": "test"})
	var shop_labels: Array = []
	_walk_labels(shop, shop_labels)
	t.ok(not shop_labels.has(shop.tr("shop_section_bundles")), "Shop không bán gói chưa có logic")
	shop.free()
	Config.ui_preview_override = -1


func test_entry_points_in_preview(t: T) -> void:
	_g()
	Config.ui_preview_override = 1
	var home := _open("home")
	t.ok(not home.find_child("LeaderboardButton", true, false).disabled, "Bảng xếp hạng mở")
	var got: Array = []
	home.closed.connect(func(r: Variant) -> void: got.append(r))
	home.find_child("LeaderboardButton", true, false).pressed.emit()
	t.eq(got[0], {"action": "ranking"}, "icon Bảng xếp hạng")
	var labels: Array = []
	_walk_labels(home, labels)
	t.ok(not labels.has(home.tr("home_ads_daily")), "ADS Daily nằm trong Shop, không có trên Home")
	home.free()
	var settings := _open("settings")
	t.ok(settings.find_child("GalleryButton", true, false) != null, "có danh sách xem trước")
	settings.free()
	Config.ui_preview_override = -1


func test_ingame_settings(t: T) -> void:
	var g := _g()
	var node := _open("popup_ingame_settings")
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	var was := bool(g.s.settings.music)
	node.toggle_buttons["music"].pressed.emit()
	t.eq(bool(g.s.settings.music), not was, "đổi cài đặt thật")
	node.toggle_buttons["music"].pressed.emit()
	node.home_button.pressed.emit()
	node.retry_button.pressed.emit()
	t.eq(got, ["home", "retry"], "Home và Retry trả kết quả cho level")
	node.free()
