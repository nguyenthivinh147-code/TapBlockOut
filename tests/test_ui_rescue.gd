extends RefCounted
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")

const DIR := "user://test_ui_rescue"
const SCENE := "res://scenes/popup_rescue.tscn"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g() -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	var p: Node = _tree().root.get_node("Platform")
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	return g


func _mount(args: Dictionary) -> Control:
	var node := (load(SCENE) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", args)
	return node


func _wait(state: Dictionary) -> void:
	for i in 120:
		if state.has("r"):
			return
		await _tree().process_frame


func _watch(node: Control) -> Dictionary:
	var state := {}
	node.connect("closed", func(r: Variant) -> void: state["r"] = r)
	return state


func _btn(node: Node, node_name: String) -> Button:
	return node.find_child(node_name, true, false) as Button


func _lbl(node: Node, node_name: String) -> Label:
	return node.find_child(node_name, true, false) as Label


## Chữ hiển thị của nút: nút prefab (unity_ui.gd) vẽ chữ bằng Label con, nút thường dùng Button.text.
func _btn_text(b: Button) -> String:
	if b.text != "":
		return b.text
	for l in b.find_children("*", "Label", true, false):
		if (l as Label).visible:
			return (l as Label).text
	return ""


func _offer_args(g: Node, attempt: Dictionary) -> Dictionary:
	var args: Dictionary = g.rescue_offer(attempt).duplicate()
	args["attempt"] = attempt
	return args


func test_buy_with_gold(t: T) -> void:
	var g := _g()
	g.s.coins = 5000
	var attempt: Dictionary = g.start_attempt()
	var before: int = attempt.board.moves_left()
	var p := _mount(_offer_args(g, attempt))
	var st := _watch(p)
	t.eq(_lbl(p, "TitleLabel").text, p.tr("rescue_title"), "tiêu đề")
	t.eq(_lbl(p, "RemainingLabel").text, p.tr("rescue_remaining") % attempt.board.remaining_count(), "Còn N khối")
	t.eq(_btn_text(_btn(p, "BuyButton")), "1900", "nút mua chỉ ghi giá")
	t.ok(_btn(p, "UseButton") == null, "không có nút Dùng khi kho trống")
	t.ok(_btn(p, "VideoButton") != null, "lần 1 có video")
	t.ok(_lbl(p, "WarnLabel") == null, "cảnh báo mạng nằm ở hộp xác nhận, không ở popup")
	_btn(p, "BuyButton").pressed.emit()
	await _wait(st)
	t.eq(st.get("r"), "gold", "đóng với gold")
	t.eq(int(g.s.coins), 3100, "trừ 1900")
	t.eq(attempt.board.moves_left(), before + 3, "+3 MOVES")
	p.free()


func test_need_coins(t: T) -> void:
	var g := _g()
	g.s.coins = 100
	var attempt: Dictionary = g.start_attempt()
	var before: int = attempt.board.moves_left()
	var p := _mount(_offer_args(g, attempt))
	var st := _watch(p)
	t.ok(_lbl(p, "NeedGoldLabel") != null, "báo thiếu gold")
	_btn(p, "BuyButton").pressed.emit()
	await _wait(st)
	t.eq(st.get("r"), "need_coins", "mở shop mini")
	t.eq(int(g.s.coins), 100, "không trừ gold")
	t.eq(attempt.board.moves_left(), before, "chưa cộng MOVES")
	p.free()


func test_inventory(t: T) -> void:
	var g := _g()
	g.s.inv["move"] = 1
	g.s.coins = 0
	var attempt: Dictionary = g.start_attempt()
	var p := _mount(_offer_args(g, attempt))
	var st := _watch(p)
	t.ok(_btn(p, "UseButton") != null, "có nút Dùng")
	t.ok(_btn(p, "BuyButton") == null, "không nút mua")
	t.eq(_btn_text(_btn(p, "UseButton")), p.tr("rescue_use"), "chữ nút Dùng")
	t.ok(_lbl(p, "StockLabel") != null, "hiện số trong kho")
	_btn(p, "UseButton").pressed.emit()
	await _wait(st)
	t.eq(st.get("r"), "inventory", "dùng kho")
	t.eq(int(g.s.inv.move), 0, "kho giảm 1")
	t.eq(int(g.s.coins), 0, "không tốn gold")
	p.free()


func test_skip_closes_with_skip(t: T) -> void:
	var g := _g()
	var attempt: Dictionary = g.start_attempt()
	var p := _mount(_offer_args(g, attempt))
	var st := _watch(p)
	t.eq(_btn_text(_btn(p, "SkipButton")), p.tr("rescue_give_up"), "nút bỏ cuộc")
	_btn(p, "SkipButton").pressed.emit()
	await _wait(st)
	t.eq(st.get("r"), "skip", "bỏ qua")
	p.free()


func test_video_every_time(t: T) -> void:
	var g := _g()
	g.s.coins = 5000
	var attempt: Dictionary = g.start_attempt()
	var prices := [1900, 2200, 2500, 2800]
	for i in 4:
		var before: int = attempt.board.moves_left()
		var p := _mount(_offer_args(g, attempt))
		var st := _watch(p)
		t.eq(_btn_text(_btn(p, "BuyButton")), str(prices[i]), "giá lần %d" % (i + 1))
		t.ok(_btn(p, "VideoButton") != null, "lần %d có video" % (i + 1))
		_btn(p, "VideoButton").pressed.emit()
		await _wait(st)
		t.eq(st.get("r"), "video", "xem video lần %d" % (i + 1))
		t.eq(attempt.board.moves_left(), before + 3, "+3 MOVES")
		t.eq(int(g.s.coins), 5000, "video không tốn gold")
		p.free()
	t.eq(g.rescue_offer(attempt).lost, true, "quá 4 lần là thua")


func test_static_args(t: T) -> void:
	_g()
	var args := {"index": 2, "price": 2500, "use_inventory": false, "video": false,
		"affordable": true, "remaining": 1, "warn_life": true}
	var p := _mount(args)
	var st := _watch(p)
	t.eq(_lbl(p, "RemainingLabel").text, p.tr("rescue_remaining_one"), "Còn 1 khối")
	t.ok(_btn(p, "VideoButton") == null, "video tắt thì không có nút")
	_btn(p, "BuyButton").pressed.emit()
	await _wait(st)
	t.eq(st.get("r"), "gold", "không có attempt: chỉ trả kết quả")
	p.free()


func test_video_closed_early_stays_open(t: T) -> void:
	var g := _g()
	var attempt: Dictionary = g.start_attempt()
	var before: int = attempt.board.moves_left()
	var p := _mount(_offer_args(g, attempt))
	var st := _watch(p)
	var plat: Node = _tree().root.get_node("Platform")
	plat.ads.simulate("closed")
	_btn(p, "VideoButton").pressed.emit()
	for i in 10:
		await _tree().process_frame
	t.ok(not st.has("r"), "chưa đóng")
	t.eq(attempt.board.moves_left(), before, "không thưởng")
	t.ok(_lbl(p, "MessageLabel").visible, "hiện báo lỗi")
	t.eq(_lbl(p, "MessageLabel").text, p.tr("ads_closed_early"), "xem hết video mới có thưởng")
	t.ok(not _btn(p, "VideoButton").disabled, "thử lại được")
	p.free()


func test_layout_rules(t: T) -> void:
	var g := _g()
	var attempt: Dictionary = g.start_attempt()
	var p := _mount(_offer_args(g, attempt))
	for b in p.find_children("*", "Button", true, false):
		var btn := b as Button
		# Prefab buttons (unity_ui.gd) keep the Unity art size and grow only their hit area.
		var hit: Vector2 = btn.call("hit_size") if btn.has_method("hit_size") else btn.custom_minimum_size
		t.ok(hit.x >= 96 - 0.01 and hit.y >= 96 - 0.01, "nút >= 96x96: " + btn.name)
	t.eq(p.find_children("*", "Timer", true, false).size(), 0, "không đếm ngược")
	# PopupReviveLayer: một nền mờ (Bg của prefab, đổi tên Dim), không màn đỏ.
	t.eq(p.find_children("*", "ColorRect", true, false).size(), 0, "không ColorRect, nền mờ là ảnh prefab")
	var dim: Control = p.find_child("Dim", true, false)
	var img: Control = dim.get("image") if dim.get("image") != null else dim
	var c: Color = img.get("color")
	t.ok(c.r < 0.1 and c.g < 0.1 and c.a > 0.5, "nền mờ trung tính")
	p.free()
