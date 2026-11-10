extends Control
## Popup kết thúc Màn đặc biệt (design.md mục 7 "Màn đặc biệt"), khung PopupOkLayer dựng lúc chạy như popup thắng Road
## Trip. setup({"mode": "win" | "fail" | "boom", ...}):
## - win ({reward: loại booster, x2_available}): hộp quà nảy vào, rung rồi bật mở, booster bay ra (đã vào kho từ Game).
##   Nút x2 (xem quảng cáo special_x2: thêm 1 cái cùng loại, ô ghi x2) và nút Nhận.
##   closed({"action": "claim", "x2_taken": bool}).
## - fail (hết bước) / boom (bom nổ, ảnh bom tối và nghiêng): "Thử thách thất bại" / "Bùm!", "Hẹn gặp lần sau!", nút
##   "Level N" ({level}: level chính kế) và X. closed({"action": "level" | "close"}). Không có Chơi lại.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const RoadTripMap := preload("res://src/ui/road_trip_map.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

const PANEL := Vector2(724, 820)
const WELL := Rect2(52, 150, 620, 470)
const BOX := Rect2(247, 165, 230, 230)
const TILE := Rect2(302, 410, 120, 120)
const COUNT := Rect2(262, 520, 200, 64)
const BOMB := Rect2(252, 170, 220, 220)
const BODY := Rect2(80, 410, 564, 160)
const BUTTON := Rect2(222, 660, 280, 120)
const BUTTON_L := Rect2(70, 660, 280, 120)
const BUTTON_R := Rect2(374, 660, 280, 120)
const BOOSTER_ICON := {"hint": "booster_hint", "smash": "booster_smash", "move": "booster_move"}
const SHAKE_SEC := 0.45
const OPEN_SEC := 0.35

var ui: RefCounted = null
var box_sprite: Control = null
var reward_tile: Control = null
var count_label: Label = null
var x2_button: Control = null
var ok_button: Control = null

var _args: Dictionary = {}
var _mode: String = "win"
var _built: bool = false
var _closed: bool = false
var _busy: bool = false
var _x2_taken: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_args = args
	_mode = str(args.get("mode", "win"))
	_build()
	if not UnityUI.baking:
		_play.call_deferred()
		if _mode == "win":
			# The booster is in the inventory already: its button keeps the old count until the tile flies there as
			# the popup closes (Claim or Back); a tile not shown yet does not fly.
			RewardFly.hold(self, _fly_reward())
			closed.connect(func(_r: Variant) -> void:
				RewardFly.launch(self, _fly_reward(), {str(_args.get("reward", "hint")): reward_tile}), CONNECT_ONE_SHOT)


func _build() -> void:
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _mode == "win":
		_build_win()
	else:
		_build_fail()


func _build_win() -> void:
	ui = UnityKit.popup(self, tr("win_title"), PANEL)
	var content: Control = ui.node("Panel/Content")
	UnityKit.well(content, WELL)
	box_sprite = UnityKit.sprite(content, "", BOX, RoadTripMap.box_tex(0))
	box_sprite.name = "BoxSprite"
	var kind := str(_args.get("reward", "hint"))
	reward_tile = UnityKit.sprite(content, "", TILE, ThemeKit.icon(str(BOOSTER_ICON.get(kind, "booster_hint"))))
	reward_tile.name = "Reward_" + kind
	reward_tile.visible = false
	count_label = UnityKit.label(content, "x1", COUNT, 46.0, "ffffffff", "Baloo Outline - Purple")
	count_label.name = "RewardCount"
	count_label.visible = false
	var x2 := bool(_args.get("x2_available", false))
	if x2:
		var v: RefCounted = UnityKit.button(content, "blue", tr("special_x2"), BUTTON_L, _on_x2)
		x2_button = v.root
		x2_button.name = "X2Button"
		# PopupReviveLayer AdsBtn: TV icon on the top-right corner.
		UnityKit.add(x2_button, UnityKit.spec("PopupReviveLayer", "Bg/Panel/Content/GameObject/AdsBtn/Image"))
		Game.offer_video("special_x2")
	ok_button = UnityKit.button(content, "green", tr("daily_claim"), BUTTON_R if x2 else BUTTON, _on_claim).root
	ok_button.name = "ClaimButton"


func _build_fail() -> void:
	var boom := _mode == "boom"
	ui = UnityKit.popup(self, tr("special_boom_title") if boom else tr("special_fail_title"), PANEL, _send.bind("close"))
	var content: Control = ui.node("Panel/Content")
	UnityKit.well(content, WELL)
	var bomb := UnityKit.sprite(content, "", BOMB, ThemeKit.icon("special_bomb"))
	bomb.name = "BombSprite"
	if boom:
		bomb.self_modulate = Color(0.55, 0.45, 0.5)
		bomb.pivot_offset = BOMB.size * 0.5
		bomb.rotation_degrees = -14.0
	UnityKit.label(content, tr("special_fail_body"), BODY, 40.0).name = "BodyLabel"
	var lv := int(_args.get("level", 1))
	ok_button = UnityKit.button(content, "green", tr("level_title") % lv, BUTTON, _send.bind("level")).root
	ok_button.name = "LevelButton"


func _play() -> void:
	if not is_inside_tree() or _mode != "win":
		if is_inside_tree():
			Sfx.play_or("lose", "button")
		return
	Sfx.play("win")
	box_sprite.pivot_offset = box_sprite.size * 0.5
	box_sprite.scale = Vector2(0.6, 0.6)
	var tin := box_sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(box_sprite, "scale", Vector2.ONE, 0.35)
	await tin.finished
	if _closed or not is_inside_tree():
		return
	var shake := box_sprite.create_tween()
	for i in 6:
		shake.tween_property(box_sprite, "rotation_degrees", 8.0 if i % 2 == 0 else -8.0, SHAKE_SEC / 6.0)
	shake.tween_property(box_sprite, "rotation_degrees", 0.0, 0.05)
	await shake.finished
	if _closed or not is_inside_tree():
		return
	Sfx.play_or("rt_box", "coin")
	var pop := box_sprite.create_tween().set_parallel(true)
	pop.tween_property(box_sprite, "scale", Vector2(1.35, 1.35), OPEN_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(box_sprite, "modulate:a", 0.35, OPEN_SEC)
	_pop_tile()


func _pop_tile() -> void:
	reward_tile.visible = true
	count_label.visible = true
	reward_tile.pivot_offset = reward_tile.size * 0.5
	reward_tile.scale = Vector2.ZERO
	var tt := reward_tile.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.tween_interval(0.1)
	tt.tween_property(reward_tile, "scale", Vector2.ONE, 0.3)


func _on_x2() -> void:
	if _busy or _closed or _x2_taken:
		return
	_busy = true
	var ok: bool = await Game.special_claim_x2()
	_busy = false
	if not is_inside_tree() or _closed:
		return
	if not ok:
		return  # Không có video: Main báo bằng popup (Game.notice).
	_x2_taken = true
	RewardFly.hold(self, _fly_reward())
	if is_instance_valid(x2_button):
		x2_button.visible = false
	UnityUI.set_text(count_label, "x2")
	Sfx.play_or("rt_box", "coin")
	_pop_tile()


func _on_claim() -> void:
	if _busy:
		return
	if _closed:
		return
	_closed = true
	Sfx.play("button")
	closed.emit({"action": "claim", "x2_taken": _x2_taken})


## Win: the booster and its x2 copy.
func _fly_reward() -> Dictionary:
	return {"items": {str(_args.get("reward", "hint")): 2 if _x2_taken else 1}}


func _send(action: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play("button")
	closed.emit({"action": action})
