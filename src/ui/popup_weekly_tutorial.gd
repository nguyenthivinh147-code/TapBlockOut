extends Control
## Popup "How to earn rewards" của Weekly Pass: key theo độ khó, cách nhận thưởng, quyền lợi VIP.
## Mở sau tutorial hoặc bằng nút "i" / biểu tượng chìa trong layer. setup(args); signal closed({}).
## No Unity prefab: PopupOkLayer frame (UnityKit). Each key source is a description row of DailyRewardAdLayer
## (Bottom (1)/Group/DescText: icon on the left, text 40) on the cream well, the notes are body text and Ok is the
## PopupOkLayer button at its place (68 above the bottom edge).

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

const DESC_ROW := "Panel/Content/Preview/Bottom (1)/Group/DescText"
const SIZE := Vector2(724, 1080)
const ROW := Vector2(640, 110)
const ROW_STEP := 126.0
const NOTE_H := 112.0

var ok_button: Button = null
var rows: Array[Control] = []
var ui: RefCounted = null

var _closed: bool = false


func setup(_args: Dictionary = {}) -> void:
	if ui == null:
		_build()


func _ready() -> void:
	if ui == null:
		_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityKit.popup(self, tr("weekly_howto_title"), SIZE, close)
	var content: Control = ui.node("Panel/Content")
	var x := (SIZE.x - ROW.x) * 0.5
	var y := 130.0

	var cfg: Dictionary = Config.WEEKLY
	for r in [
		["weekly_howto_normal", int(cfg.get("points_normal", 1))],
		["weekly_howto_hard", int(cfg.get("points_hard", 3))],
		["weekly_howto_very_hard", int(cfg.get("points_very_hard", 5))],
	]:
		var row := _key_row(content, tr(r[0]), int(r[1]), Rect2(x, y, ROW.x, ROW.y))
		rows.append(row)
		y += ROW_STEP

	y += 10.0
	for note in [tr("weekly_howto_claim"), tr("weekly_howto_vip") % int(cfg.get("vip_bonus_hearts", 3)), tr("weekly_howto_season")]:
		UnityKit.label(content, note, Rect2(x, y, ROW.x, NOTE_H), 32, UnityKit.INK, "", HORIZONTAL_ALIGNMENT_LEFT)
		y += NOTE_H

	var ok := UnityKit.button(content, "green", tr("common_ok"), Rect2((SIZE.x - 280.0) * 0.5, SIZE.y - 68.0 - 120.0, 280, 120), close)
	ok_button = ok.root as Button
	ok_button.name = "OkButton"


## Cream well with DescText (key icon, text) and the key count on the right.
func _key_row(parent: Control, text: String, points: int, rect: Rect2) -> Control:
	var well := UnityKit.well(parent, rect)
	well.name = "KeyRow"
	var s := UnityKit.spec("DailyRewardAdLayer", DESC_ROW)
	s.txt.c = UnityKit.INK
	s.txt.s = text
	s.ch[0].img.sp = null
	s.ch[0].img.pa = true
	var v := UnityKit.add(well, s, Rect2(0, (rect.size.y - 80.0) * 0.5, rect.size.x - 120.0, 80))
	v.texture("Image", ThemeKit.icon("mech_key"))
	var n := UnityKit.label(well, tr("weekly_howto_points") % points, Rect2(rect.size.x - 130.0, 0, 110, rect.size.y), 56,
		"ffffffff", "Baloo Outline - Orange")
	n.name = "Points"
	return well


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({})
