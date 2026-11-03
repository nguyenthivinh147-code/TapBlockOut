extends Control
## Popup "How to earn rewards" của Weekly Pass: key theo độ khó, cách nhận thưởng, quyền lợi VIP.
## Mở sau tutorial hoặc bằng nút "i" / biểu tượng chìa trong layer. setup(args); signal closed({}).
## No Unity prefab: PopupOkLayer frame (UnityKit). Each key source is a description row of DailyRewardAdLayer
## (Bottom (1)/Group/DescText: icon on the left, text 40) on the cream well, the notes are body text and Ok is the
## PopupOkLayer button at its place (68 above the bottom edge). All of it is saved in
## scenes/popup_weekly_tutorial.tscn; the script sets the texts and wires Ok and the close buttons.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Config := preload("res://src/config.gd")

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
	# Frame (724 x 1080), the three key rows (cream well, DescText with the key icon, Points), Note1..3 and OkButton
	# are nodes of scenes/popup_weekly_tutorial.tscn.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityKit.frame(self, tr("weekly_howto_title"), close)
	var cfg: Dictionary = Config.WEEKLY
	for r in [
		[%KeyRowNormal, "weekly_howto_normal", int(cfg.get("points_normal", 1))],
		[%KeyRowHard, "weekly_howto_hard", int(cfg.get("points_hard", 3))],
		[%KeyRowVeryHard, "weekly_howto_very_hard", int(cfg.get("points_very_hard", 5))],
	]:
		var row: Control = r[0]
		UnityUI.set_text(row.get_node("DescText"), tr(r[1]))
		UnityUI.set_text(row.get_node("Points"), tr("weekly_howto_points") % int(r[2]))
		rows.append(row)
	UnityUI.set_text(%Note1, tr("weekly_howto_claim"))
	UnityUI.set_text(%Note2, tr("weekly_howto_vip") % int(cfg.get("vip_bonus_hearts", 3)))
	UnityUI.set_text(%Note3, tr("weekly_howto_season"))
	ok_button = %OkButton
	UnityUI.set_text(ok_button.get_node("Out"), tr("common_ok"))
	ok_button.connect("clicked", close)


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({})
