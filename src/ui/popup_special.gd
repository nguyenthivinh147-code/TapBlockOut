extends Control
## Popup mời vào Màn đặc biệt (design.md mục 7 "Màn đặc biệt"): khung PopupOkLayer dựng lúc chạy (UnityKit.popup) như
## popup thắng Road Trip. Tiêu đề "Màn đặc biệt", quả bom, luật, ô thưởng (hộp quà "?"), dòng vé. Còn vé: nút Bắt đầu;
## hết vé: dòng đếm ngược tới vé chờ kế và nút OK. Đọc Game.special_view() (setup không cần view).
## closed({"action": "start" | "close"}); Back cũng đóng (null).

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const RoadTripMap := preload("res://src/ui/road_trip_map.gd")

const PANEL := Vector2(724, 820)
const WELL := Rect2(52, 150, 620, 470)
const BOMB := Rect2(252, 160, 220, 220)
const RULE := Rect2(80, 380, 564, 100)
const BOX := Rect2(312, 478, 100, 100)
const BOX_MARK := Rect2(312, 478, 100, 100)
const TICKETS := Rect2(60, 560, 604, 56)
const BUTTON := Rect2(222, 660, 280, 120)

var ui: RefCounted = null
var tickets_label: Label = null
var button: Control = null

var _built: bool = false
var _closed: bool = false
var _has_ticket: bool = false
var _shown_sec: int = -1


func setup(_args: Dictionary = {}) -> void:
	_build()


func _ready() -> void:
	setup.call_deferred()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var v: Dictionary = Game.special_view()
	_has_ticket = int(v.tickets) > 0
	ui = UnityKit.popup(self, tr("special_title"), PANEL, _send.bind("close"))
	var content: Control = ui.node("Panel/Content")
	UnityKit.well(content, WELL)
	var bomb := UnityKit.sprite(content, "", BOMB, ThemeKit.icon("special_bomb"))
	bomb.name = "BombSprite"
	UnityKit.label(content, tr("special_rule"), RULE, 38.0).name = "RuleLabel"
	var box := UnityKit.sprite(content, "", BOX, RoadTripMap.box_tex(0))
	box.name = "RewardBox"
	UnityKit.label(content, "?", BOX_MARK, 56.0, "ffffffff", "Baloo Outline - Purple").name = "RewardMark"
	tickets_label = UnityKit.label(content, "", TICKETS, 34.0)
	tickets_label.name = "TicketsLabel"
	_refresh_tickets(v)
	button = UnityKit.button(content, "green", tr("special_start") if _has_ticket else tr("common_ok"), BUTTON,
		_send.bind("start" if _has_ticket else "close")).root
	button.name = "StartButton" if _has_ticket else "OkButton"
	if not UnityUI.baking:
		bomb.pivot_offset = bomb.size * 0.5
		var tw := bomb.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bomb, "scale", Vector2.ONE * 1.06, 0.5)
		tw.tween_property(bomb, "scale", Vector2.ONE, 0.5)


func _refresh_tickets(v: Dictionary) -> void:
	var n := int(v.tickets)
	var wait := int(v.wait_sec)
	_shown_sec = wait
	var text := ""
	if n > 0:
		text = tr("special_tickets") % n
		if not bool(v.timer_ready):
			text += "  ·  " + tr("special_next_ticket") % _fmt(wait)
	else:
		text = tr("special_next_ticket") % _fmt(wait)
	UnityUI.set_text(tickets_label, text)


func _process(_delta: float) -> void:
	if not _built or _closed:
		return
	var v: Dictionary = Game.special_view()
	if int(v.wait_sec) != _shown_sec:
		_refresh_tickets(v)


## "1:05:09" hoặc "5:09".
static func _fmt(sec: int) -> String:
	@warning_ignore("integer_division")
	var h := sec / 3600
	@warning_ignore("integer_division")
	var m := (sec % 3600) / 60
	var s := sec % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]


func _send(action: String) -> void:
	if _closed:
		return
	_closed = true
	Sfx.play("button")
	closed.emit({"action": action})
