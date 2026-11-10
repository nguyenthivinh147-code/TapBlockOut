extends RefCounted
## Rewards flying to their counters (reward_fly.gd, item_fx.gd): parts of a reward, the topmost target outside the
## source popup, counters holding the old number and counting on as icons land, holds ended by the owner leaving,
## a bought booster's flight in a level, nothing while baking.
const T := preload("res://tests/t.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")
const PopupRewardScene := preload("res://scenes/popup_reward.tscn")

const DIR := "user://test_test_ui_reward_fly"


## A target answering reward_target(kind) with its own icon for the kinds it takes, counting refreshes.
class FakeHolder extends Control:
	var kinds: Array = []
	var icon: Control = null
	var refreshed := 0

	func _init(take: Array) -> void:
		kinds = take
		add_to_group("reward_fly")
		icon = Control.new()
		icon.position = Vector2(40, 40)
		icon.size = Vector2(60, 60)
		add_child(icon)

	func reward_target(kind: String) -> Control:
		return icon if kinds.has(kind) else null

	func reward_refresh() -> void:
		refreshed += 1


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _g() -> Node:
	var g: Node = _root().get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	RewardFly.reset()
	return g


func _src(at: Vector2) -> Control:
	var c := TextureRect.new()
	c.position = at
	c.size = Vector2(100, 100)
	_root().add_child(c)
	return c


func _free(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.free()


## The number a counter shows once its roll (UiTween.roll, real frames) ends; the steps here do not run frames.
func _shown(label: Label) -> String:
	return str(UiTween.roll_target(label)) if label.has_meta(UiTween.META_ROLL) else label.text


## Steps the flights for `steps` x 0.05 s (past the last landing and its afterglow), frees them and returns the label
## texts seen after each step.
func _run(fx: Array, label: Label = null, steps: int = 40) -> Array:
	var seen: Array = []
	for i in steps:
		for f in fx:
			if is_instance_valid(f):
				(f as Node).call("_process", 0.05)
		if label != null and (seen.is_empty() or str(seen.back()) != _shown(label)):
			seen.append(_shown(label))
	for f in fx:
		_free(f)
	return seen


## Flights in the tree not yet freed.
func _flights() -> Array:
	return _root().find_children("Reward*Fx", "", true, false).filter(func(n: Node) -> bool:
		return n.has_signal("arrived") and not n.is_queued_for_deletion())


func test_parts(t: T) -> void:
	t.eq(RewardFly.parts({"coins": 50, "items": {"hint": 2, "smash": 0}, "inf_min": 30, "lives": 0}),
		{"gold": 50, "hint": 2, "inf": 30}, "phần khác 0, theo tên RewardFly")
	t.eq(RewardFly.parts({}), {}, "thưởng rỗng")
	t.eq(RewardFly.sku_reward("helper_great").get("items"), {"hint": 2, "move": 2, "smash": 1}, "thưởng của SKU")


func test_gold_and_booster_fly_to_bars(t: T) -> void:
	var g := _g()
	var top: Control = HubTop.create()
	_root().add_child(top)
	top.size = Vector2(886, 124)
	var nav: Control = HubNav.create("home")
	_root().add_child(nav)
	nav.position = Vector2(0, 1000)
	nav.size = Vector2(886, 248)
	var before := int(g.s.coins)
	g.s.coins = before + 100
	g.coins_changed.emit(int(g.s.coins))
	var label: Label = top.get("gold_label")
	t.eq(_shown(label), str(before + 100), "chip hiện ví trước khi bay")
	var src_gold := _src(Vector2(300, 600))
	var src_hint := _src(Vector2(450, 600))
	var fx := RewardFly.fly(null, {"coins": 100, "items": {"hint": 2}},
		{"gold": src_gold, "hint": src_hint})
	t.eq(fx.size(), 2, "gold và Gợi ý cùng bay")
	t.eq(str(fx[0].name), "RewardGoldFx", "gold bay bằng CoinFx")
	t.eq(str(fx[1].name), "RewardItemFx", "booster bay bằng ItemFx")
	t.eq(RewardFly.held("gold"), 100, "gold đang bay")
	t.eq(RewardFly.held("hint"), 2, "Gợi ý đang bay")
	t.eq(_shown(label), str(before), "chip giữ số cũ")
	var seen := _run(fx, label)
	t.ok(seen.size() >= 3, "chip đếm dần: %s" % str(seen))
	for i in range(1, seen.size()):
		t.ok(int(seen[i]) > int(seen[i - 1]), "số chỉ tăng")
	t.eq(_shown(label), str(before + 100), "chạm hết thì chip đúng ví")
	t.eq(RewardFly.held("gold"), 0, "hết gold bay")
	t.eq(RewardFly.held("hint"), 0, "hết Gợi ý bay")
	t.eq(RewardFly.target("hint"), nav.get("_icons").get("home"), "ngoài màn chơi booster về tab Home")
	_free(src_gold)
	_free(src_hint)
	_free(top)
	_free(nav)


func test_topmost_target_outside_owner(t: T) -> void:
	_g()
	var low := FakeHolder.new(["gold", "hint"])
	_root().add_child(low)
	var popup := Control.new()
	_root().add_child(popup)
	var inner := FakeHolder.new(["gold"])
	popup.add_child(inner)
	var high := FakeHolder.new(["hint"])
	_root().add_child(high)
	t.eq(RewardFly.target("hint"), high.icon, "đích vẽ trên cùng thắng")
	t.eq(RewardFly.target("gold"), inner.icon, "đích trong popup cũng là đích")
	t.eq(RewardFly.target("gold", popup), low.icon, "bỏ đích trong popup nguồn")
	t.eq(RewardFly.target("smash"), null, "không ai nhận thì không có đích")
	low.icon.visible = false
	t.eq(RewardFly.target("gold", popup), null, "icon ẩn không là đích")
	var src := _src(Vector2(200, 200))
	t.eq(RewardFly.launch(popup, {"items": {"smash": 1}}, {"smash": src}), 0, "không đích thì không bay")
	t.eq(RewardFly.held("smash"), 0, "không giữ gì")
	var hidden := _src(Vector2(200, 200))
	hidden.visible = false
	t.eq(RewardFly.launch(popup, {"items": {"hint": 1}}, {"hint": hidden}), 0, "nguồn ẩn thì không bay")
	var fx := RewardFly.fly(popup, {"items": {"hint": 1}}, {"hint": Rect2(10, 10, 80, 80)})
	t.eq(fx.size(), 1, "nguồn là Rect2 vẫn bay")
	var refreshed := high.refreshed
	_run(fx)
	t.ok(high.refreshed > refreshed, "chạm thì ô đếm cập nhật")
	for n in [low, popup, high, src, hidden]:
		_free(n)


func test_hold_until_launch_or_exit(t: T) -> void:
	_g()
	var holder := FakeHolder.new(["gold", "move"])
	_root().add_child(holder)
	var owner := Control.new()
	_root().add_child(owner)
	RewardFly.hold(owner, {"coins": 30, "items": {"move": 1}, "inf_min": 10}, ["move"])
	t.eq(RewardFly.held("gold"), 30, "giữ gold")
	t.eq(RewardFly.held("move"), 0, "phần trong skip không giữ")
	t.eq(RewardFly.held("inf"), 0, "mạng vô hạn không có số để giữ")
	RewardFly.hold(owner, {"coins": 40})
	t.eq(RewardFly.held("gold"), 40, "giữ lại thì thay chứ không cộng dồn")
	_free(owner)
	t.eq(RewardFly.held("gold"), 0, "owner rời cây thì nhả")

	var owner2 := Control.new()
	_root().add_child(owner2)
	RewardFly.hold(owner2, {"coins": 30})
	var src := _src(Vector2(300, 300))
	var fx := RewardFly.fly(owner2, {"coins": 30}, {"gold": src})
	t.eq(fx.size(), 1, "bay từ popup")
	t.eq(RewardFly.held("gold"), 30, "phần giữ chuyển sang phần bay, không gấp đôi")
	_free(owner2)
	t.eq(RewardFly.held("gold"), 30, "owner rời cây sau launch không nhả thêm")
	t.eq(fx[0].get_parent(), holder, "hiệu ứng nằm dưới UI chứa ô đếm")
	_free(holder)
	t.eq(RewardFly.held("gold"), 0, "UI chứa ô đếm bị xoá giữa chừng thì hiện nốt")
	_free(src)


func test_popup_reward_holds_and_flies_on_close(t: T) -> void:
	var g := _g()
	var top: Control = HubTop.create()
	_root().add_child(top)
	top.size = Vector2(886, 124)
	var before := int(g.s.coins)
	g.s.coins = before + 200
	g.coins_changed.emit(int(g.s.coins))
	var p: Node = PopupRewardScene.instantiate()
	_root().add_child(p)
	p.call("setup", {"view": {"reward": {"coins": 200}}})
	var label: Label = top.get("gold_label")
	t.eq(_shown(label), str(before), "popup mở: chip giữ số trước thưởng")
	t.eq(RewardFly.held("gold"), 200, "giữ gold của popup")
	p.emit_signal("closed", null)
	var fx := _flights()
	t.eq(fx.size(), 1, "đóng (cả Back) thì gold bay")
	_free(p)
	t.eq(RewardFly.held("gold"), 200, "popup xoá rồi vẫn đang bay")
	_run(fx, label)
	t.eq(_shown(label), str(before + 200), "bay xong chip đúng ví")
	# Gold that already flew (Shop) is not held nor flown again.
	var p2: Node = PopupRewardScene.instantiate()
	_root().add_child(p2)
	p2.call("setup", {"view": {"reward": {"coins": 200}, "flown": ["gold"]}})
	t.eq(RewardFly.held("gold"), 0, "gold đã bay thì không giữ")
	p2.emit_signal("closed", null)
	t.eq(_flights().size(), 0, "không bay lại")
	_free(p2)
	_free(top)


func test_nothing_while_baking(t: T) -> void:
	_g()
	var holder := FakeHolder.new(["gold"])
	_root().add_child(holder)
	var owner := Control.new()
	_root().add_child(owner)
	var src := _src(Vector2(100, 100))
	UnityUI.baking = true
	RewardFly.hold(owner, {"coins": 10})
	var n := RewardFly.launch(owner, {"coins": 10}, {"gold": src})
	UnityUI.baking = false
	t.eq(n, 0, "đang bake thì không bay")
	t.eq(RewardFly.held("gold"), 0, "đang bake thì không giữ")
	for x in [holder, owner, src]:
		_free(x)
