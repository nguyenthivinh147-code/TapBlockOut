extends Control
## Popup thắng level Road Trip (wireframe Road Trip S4, S5): hộp quà đang nhắm nảy lên, thanh tiến độ chạy từ
## "trước" tới "sau" (Game.on_level_won của level road_trip: before, after). Level vừa thắng là level có hộp: thanh
## đầy, hộp rung rồi bật mở, từng vật phẩm nảy ra (đã cộng vào kho từ Game), nút Nhận; không thì nút Tiếp tục.
## Đi hết đường (done) thì thêm dòng chúc mừng.
## setup(args): kết quả Game.on_level_won ({level, box, reward, before, after, done}). closed("ok"); Back cũng đóng.
## No Unity prefab of its own: PopupOkLayer's frame (header, cream well, pill button) like Daily Challenge, built at
## runtime (UnityKit.popup); the bar and reward tiles are game sprites placed in canvas units.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const RoadTrip := preload("res://src/meta/road_trip.gd")
const RoadTripMap := preload("res://src/ui/road_trip_map.gd")

## Panel and pieces in canvas units (PopupOkLayer frame, header strip 130).
const PANEL := Vector2(724, 860)
const WELL := Rect2(52, 150, 620, 520)
const BOX := Rect2(247, 160, 230, 230)
const BAR := Rect2(112, 412, 500, 60)
const BAR_TEXT := Rect2(112, 402, 500, 80)
const NOTE := Rect2(80, 500, 564, 130)
const REWARDS_Y := 498.0
const TILE := 110.0
const TILE_GAP := 50.0
const BUTTON := Rect2(222, 710, 280, 120)
const BAR_FILL := Color("7BD43A")
const BAR_TRACK := Color("4A2C7A")
const BOOSTER_ICON := {"hint": "booster_hint", "smash": "booster_smash", "move": "booster_move"}
## Thanh chạy, hộp rung và bật mở (giây).
const BAR_SEC := 0.6
const SHAKE_SEC := 0.45
const OPEN_SEC := 0.35

var ui: RefCounted = null
var box_sprite: Control = null
var bar_fill: Control = null
var bar_label: Label = null
var note_label: Label = null
var button: Control = null
## Ô thưởng (hiện khi hộp mở).
var reward_tiles: Array[Control] = []

var _args: Dictionary = {}
var _built: bool = false
var _closed: bool = false


func setup(args: Dictionary) -> void:
	_args = args
	_build()
	if not UnityUI.baking:
		_play.call_deferred()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box_i := int(_args.get("box", -1))
	var opened := box_i >= 0
	ui = UnityKit.popup(self, tr("win_title"), PANEL)
	var content: Control = ui.node("Panel/Content")
	UnityKit.well(content, WELL)
	# Hộp đang nhắm: hộp vừa mở, hoặc hộp kế tiếp sau level vừa thắng.
	var target := RoadTrip.boxes()[box_i] if opened else RoadTrip.next_box(int(_args.get("level", 1)))
	var icon_i := maxi(RoadTrip.box_index(target), 0)
	box_sprite = UnityKit.sprite(content, "", BOX, ThemeKit.icon(str(RoadTripMap.BOX_ICONS[icon_i % RoadTripMap.BOX_ICONS.size()])))
	box_sprite.name = "BoxSprite"
	box_sprite.visible = target > 0
	# Thanh tiến độ: khung tím, lõi xanh theo tỉ lệ (neo trái, anchor_right = tỉ lệ).
	var bar := UnityKit.sprite(content, "", BAR)
	bar.name = "Bar"
	# A sprite node without a sprite draws a white rect, like Unity's Image; only its children show.
	bar.self_modulate = Color(1, 1, 1, 0)
	var track := Panel.new()
	track.name = "Track"
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _round(BAR_TRACK))
	bar.add_child(track)
	bar_fill = Panel.new()
	bar_fill.name = "Fill"
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.add_theme_stylebox_override("panel", _round(BAR_FILL))
	bar_fill.anchor_bottom = 1.0
	track.add_child(bar_fill)
	var before: Vector2i = _args.get("before", Vector2i.ZERO)
	_set_fill(_ratio(before))
	bar.visible = before.y > 0
	bar_label = UnityKit.label(content, _bar_text(before), BAR_TEXT, 44.0, "ffffffff", "Baloo Outline - Purple")
	bar_label.name = "BarLabel"
	bar_label.visible = bar.visible
	note_label = UnityKit.label(content, _note_text(), NOTE, 34.0)
	note_label.name = "NoteLabel"
	note_label.visible = not opened
	_build_rewards(content)
	button = UnityKit.button(content, "green", tr("daily_claim") if opened else tr("win_continue"), BUTTON, _on_ok).root
	button.name = "OkButton"


func _build_rewards(content: Control) -> void:
	var reward: Dictionary = _args.get("reward", {})
	var keys := reward.keys()
	var total := keys.size() * TILE + maxi(keys.size() - 1, 0) * TILE_GAP
	var x := (PANEL.x - total) * 0.5
	for k in keys:
		var tile := UnityKit.sprite(content, "", Rect2(x, REWARDS_Y, TILE, TILE), ThemeKit.icon(str(BOOSTER_ICON.get(k, "ui_gift"))))
		tile.name = "Reward_" + str(k)
		var l := UnityKit.label(content, "x%d" % int(reward[k]), Rect2(x - 20, REWARDS_Y + TILE - 6, TILE + 40, 60), 40.0,
			"ffffffff", "Baloo Outline - Purple")
		l.name = "RewardCount_" + str(k)
		tile.visible = false
		l.visible = false
		tile.set_meta("count", l)
		reward_tiles.append(tile)
		x += TILE + TILE_GAP


static func _round(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(32)
	return b


static func _ratio(p: Vector2i) -> float:
	return clampf(float(p.x) / float(p.y), 0.0, 1.0) if p.y > 0 else 0.0


func _bar_text(p: Vector2i) -> String:
	return "%d/%d" % [p.x, p.y]


func _note_text() -> String:
	if bool(_args.get("done", false)):
		return tr("rt_done")
	var after: Vector2i = _args.get("after", Vector2i.ZERO)
	var left := after.y - after.x
	if after.y <= 0:
		return ""
	return tr("rt_win_more_one") if left == 1 else tr("rt_win_more") % left


func _set_fill(f: float) -> void:
	bar_fill.anchor_right = f
	bar_fill.offset_left = 0.0
	bar_fill.offset_right = 0.0
	bar_fill.offset_top = 0.0
	bar_fill.offset_bottom = 0.0
	bar_fill.visible = f > 0.0


## Hộp nảy vào, thanh chạy tới "sau"; có hộp mở thì rung, bật mở và thả từng vật phẩm.
func _play() -> void:
	if not is_inside_tree():
		return
	Sfx.play("win")
	box_sprite.pivot_offset = box_sprite.size * 0.5
	box_sprite.scale = Vector2(0.6, 0.6)
	var tin := box_sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(box_sprite, "scale", Vector2.ONE, 0.35)
	var before: Vector2i = _args.get("before", Vector2i.ZERO)
	var after: Vector2i = _args.get("after", Vector2i.ZERO)
	var tw := create_tween()
	tw.tween_interval(0.3)
	tw.tween_method(_set_fill, _ratio(before), _ratio(after), BAR_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: UnityUI.set_text(bar_label, _bar_text(after)))
	await tw.finished
	if _closed or not is_inside_tree() or reward_tiles.is_empty():
		return
	await _open_box()


func _open_box() -> void:
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
	for i in reward_tiles.size():
		var t := reward_tiles[i]
		var l := t.get_meta("count") as Control
		t.visible = true
		l.visible = true
		t.pivot_offset = t.size * 0.5
		t.scale = Vector2.ZERO
		var tt := t.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tt.tween_interval(0.1 + 0.12 * i)
		tt.tween_property(t, "scale", Vector2.ONE, 0.3)


func _on_ok() -> void:
	if _closed:
		return
	_closed = true
	closed.emit("ok")
