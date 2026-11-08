extends RefCounted
## Every gold purchase button: atlas_main's yellow pill with only the gold coin and the price.
const T := preload("res://tests/t.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_ui_gold_buttons"
const NOW := 1_800_000_000


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g() -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var p: Node = _root().get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	return g


func _mount(scene: String, args: Dictionary = {}) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_root().add_child(node)
	node.call("setup", args)
	return node


func _btn(node: Node, node_name: String) -> Button:
	return node.find_child(node_name, true, false) as Button


func _is_sprite(img: Control, region: String) -> bool:
	return img != null and img.get("tex") == UiAtlas.sheet_of(region) and img.get("region") == UiAtlas.rect_of(region)


## Visible content of a gold button: its texts and whether a gold coin of atlas_main shows.
func _content(b: Button) -> Dictionary:
	var texts: Array = []
	var coin := false
	for c in b.find_children("*", "Control", true, false):
		if not (c as Control).is_visible_in_tree():
			continue
		if c is Label and (c as Label).text != "":
			texts.append((c as Label).text)
		elif _is_sprite(c as Control, "big_coin"):
			coin = true
	return {"texts": texts, "coin": coin}


func _check(t: T, b: Button, price: String, what: String) -> void:
	t.ok(b != null, what + ": có nút")
	if b == null:
		return
	t.ok(_is_sprite(UnityUI.image_of(b), "pill_yellow"), what + ": pill vàng của atlas_main")
	var c := _content(b)
	t.eq(c.texts, [price], what + ": chỉ có giá")
	t.ok(c.coin, what + ": có icon gold")


func test_rescue(t: T) -> void:
	var g := _g()
	g.s.coins = 5000
	var p := _mount("popup_rescue", g.rescue_offer(g.start_attempt()).duplicate())
	_check(t, _btn(p, "BuyButton"), "1900", "cứu lượt")
	p.free()


func test_rescue_not_affordable(t: T) -> void:
	var g := _g()
	g.s.coins = 100
	var p := _mount("popup_rescue", g.rescue_offer(g.start_attempt()).duplicate())
	_check(t, _btn(p, "BuyButton"), "1900", "cứu lượt thiếu gold")
	p.free()


func test_no_lives(t: T) -> void:
	var g := _g()
	g.s.level = 10
	g.s.lives = {"count": 0, "next_at": NOW + 900}
	var p := _mount("no_lives")
	var b := _btn(p, "GoldButton")
	t.ok(_is_sprite(UnityUI.image_of(b), "pill_yellow"), "nạp mạng: pill vàng của atlas_main")
	var price: Label = p.find_child("GoldPrice", true, false)
	t.eq(price.text, "900", "nạp mạng: giá")
	t.ok(_is_sprite(price.get_parent().get_node("Image"), "big_coin"), "nạp mạng: icon gold cạnh giá")
	p.free()


func test_helper_pack(t: T) -> void:
	_g()
	var p := _mount("popup_helper_pack")
	_check(t, _btn(p, "GoldButton"), "900", "gói trợ giúp")
	p.free()


func test_profile(t: T) -> void:
	var g := _g()
	g.s.level = 5
	var p := (load("res://scenes/profile.tscn") as PackedScene).instantiate() as Control
	_root().add_child(p)
	p.setup({})
	for id in ["avatar_01", "frame_03"]:
		p.select(id)
		var b: Button = p.buy_button
		_check(t, b, "50" if id == "avatar_01" else "100", id)
		var coin := b.get_node("Image")
		t.ok(coin.get_index() < b.get_node("Text (TMP)").get_index(), id + ": icon gold trước giá")
	p.free()
