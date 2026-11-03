extends Control
## Wireframe 8.3 Leagues: 7 league, khoảng điểm và thưởng nhận khi lên league.
## setup({view}): view = Game.lb_leagues_view() ({current, points, rows}); không truyền thì tự đọc. closed(null).
## No prefab: UnityKit frame (PopupOkLayer) with one PlayerLeaderboardItem per league (LeaderboardLayer's row,
## scaled to the popup): number, trophy in the avatar slot, name / range / reward lines, the Unity gift while the
## reward is still ahead, the point pill for Current / Reached; the current league has the player's green row.
## Frame, sub text and OK pill are nodes of scenes/popup_leagues.tscn; the rows follow Game.lb_leagues_view().

signal closed(result: Variant)

const LbKit := preload("res://src/ui/lb_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const W := 724.0
## Header strip of the frame, sub text, rows (PlayerLeaderboardItem 800 x 150 at ROW_SCALE), OK button
## (PopupOkLayer: 280 x 120, 68 from the bottom).
const HEADER := 130.0
const SUB_H := 80.0
const ROW := Vector2(800, 150)
const ROW_SCALE := 0.78
const BTN := Vector2(280, 120)
const BTN_GAP := 30.0
const BOTTOM := 68.0

var view: Dictionary = {}
var ui: RefCounted = null
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", Game.lb_leagues_view())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rows: Array = view.get("rows", [])
	var rows_h := ROW.y * ROW_SCALE * rows.size()
	var h := HEADER + SUB_H + rows_h + BTN_GAP + BTN.y + BOTTOM
	# Frame, sub text and OK pill are nodes of scenes/popup_leagues.tscn; the height and the OK row follow the rows.
	ui = UnityKit.popup(self, tr("lb_leagues_title"), Vector2(W, h), _close)
	var box: Control = ui.node("Panel/Content")
	UnityUI.set_text(%SubText, tr("lb_leagues_sub"))
	var ok: Control = %OkButton
	var y := HEADER + SUB_H
	for i in rows.size():
		_row(box, rows[i], i + 1, y)
		y += ROW.y * ROW_SCALE
	UnityKit.place(ok, Rect2((W - BTN.x) * 0.5, y + BTN_GAP, BTN.x, BTN.y))
	UnityUI.set_text(ok.get_node("Out"), tr("common_ok"))
	ok.connect("clicked", _close)


func _ready() -> void:
	setup.call_deferred()


func _row(box: Control, r: Dictionary, n: int, y: float) -> void:
	var cur := bool(r.get("current", false))
	var reached := bool(r.get("reached", false))
	var s := UnityKit.spec(LbKit.ITEM, "")
	s.a = true
	s.n = "League_" + str(r.id)
	var v: RefCounted = UnityKit.add(box, s, Rect2((W - ROW.x) * 0.5, y, ROW.x, ROW.y))
	v.root.scale = Vector2.ONE * ROW_SCALE
	# Rows sit between the sub text and the OK pill, as they were built.
	box.move_child(v.root, (%OkButton as Control).get_index())
	LbKit.set_atlas(v.node("BG"), LbKit.ROW_BG[0] if cur else LbKit.ROW_BG[4])
	v.show("PlayerArrow", cur)
	v.show("RankNumberTxt/Image", false)
	v.text("RankNumberTxt", str(n))
	v.show("Avatar/Frame", false)
	LbKit.set_league_icon(v.node("Avatar"), str(r.id))
	(v.image("Avatar")).set("preserve_aspect", true)
	var name_l: Label = v.text("PlayerName", LbKit.league_name(str(r.id)))
	_move(name_l, 36.0, 60.0)
	var span := tr("lb_league_range_top") % int(r.min) if int(r.max) < 0 else tr("lb_league_range") % [int(r.min), int(r.max)]
	_line(v.root, "RangeText", span, -10.0)
	var reward := RewardText.text(r.get("reward", {}))
	if reward != "":
		_line(v.root, "RewardText", reward, -46.0)
	v.show("Gift", reward != "" and not reached)
	# GiftPanelController opens the reward bubble on tap only; the reward is written on the row.
	v.show("Gift/RewardsParent", false)
	var status := tr("lb_current") if cur else (tr("lb_reached") if reached else "")
	v.show("PointPanel", status != "")
	v.show("PointPanel/RankPointIcon", false)
	var st: Label = v.text("PointPanel/PointText", status)
	_move(st, 0.0, 43.4, 0.0, 125.0)


## Moves / resizes a built text (RectTransform anchoredPosition and sizeDelta) and re-runs auto size.
static func _move(l: Label, y: float, h: float, x: float = NAN, w: float = NAN) -> void:
	var rr: Dictionary = l.get_meta("u_rect")
	rr.pos = Vector2((rr.pos as Vector2).x if is_nan(x) else x, y)
	rr.size = Vector2((rr.size as Vector2).x if is_nan(w) else w, h)
	UnityUI.apply_rect(l)
	UnityUI.fit_text(l)


## Extra line under the name: a copy of PlayerName at 28 units.
func _line(root: Control, n: String, text: String, y: float) -> void:
	var s := UnityKit.spec(LbKit.ITEM, "PlayerName")
	s.n = n
	s.txt.s = text
	s.txt.fs = 28.0
	s.txt.auto = [18.0, 28.0]
	s.r = [0.5, 0.5, 0.5, 0.5, -181.4, y, 295.4, 36.0, 0.0, 0.5]
	UnityKit.add(root, s)


func _close() -> void:
	closed.emit(null)
