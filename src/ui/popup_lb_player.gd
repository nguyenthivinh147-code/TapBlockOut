extends Control
## Thẻ người chơi khi chạm một hàng ở World Ranking: avatar, tên, cờ, league, hạng, điểm.
## setup({view}): một hàng của Game.lb_world_view().rows. closed(null).
## No prefab: UnityKit frame (PopupOkLayer, title = player name) with LeaderboardLayer pieces: the Top1 avatar and
## frame, the league pill (TimeRemain: trophy, league name, points in the time slot with the piece icon), world
## rank in PopupOkLayer's body text, OK pill.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "LeaderboardLayer"
const TOP1 := "BG/Panel/ToggleGroup/RankingContent/LastWeekLeaders/Leaders/Top1/Avatar"
const PILL := "BG/Panel/ToggleGroup/LeaguesContent/TimeRemainBG/TimeRemain"
const W := 724.0
const AVATAR := Rect2(264.5, 150, 195, 195)
const FLAG_Y := 355.0
const PILL_Y := 420.0
const RANK_Y := 530.0
const BTN := Vector2(280, 120)
const BTN_Y := 620.0
const BOTTOM := 68.0

var view: Dictionary = {}
var ui: RefCounted = null
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", {})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityKit.popup(self, LbKit.display_name(view), Vector2(W, BTN_Y + BTN.y + BOTTOM), _close)
	var box: Control = ui.node("Panel/Content")
	var av := UnityKit.spec(LAYER, TOP1)
	av.n = "Avatar"
	var avv: RefCounted = UnityKit.add(box, av, AVATAR)
	LbKit.set_avatar(avv.root, str(view.get("avatar", "")), str(view.get("frame", "")))
	var flag := str(view.get("flag", ""))
	if flag != "":
		UnityKit.label(box, flag, Rect2(62, FLAG_Y, W - 124, 56), 40.0).name = "FlagText"
	var league := str(view.get("league", ""))
	var pill := UnityKit.spec(LAYER, PILL)
	pill.n = "LeaguePill"
	var pv: RefCounted = UnityKit.add(box, pill, Rect2((W - 610.0) * 0.5, PILL_Y, 610, 93))
	if league != "":
		LbKit.set_league_icon(pv.node("RankIcon"), league)
		pv.text("RankName", tr("lb_league") % LbKit.league_name(league))
	else:
		pv.show("RankIcon", false)
		pv.show("RankName", false)
	pv.text("Image/TimeText", tr("lb_player_points") % int(view.get("points", 0)))
	pv.texture("Image/ClockIcon", ThemeKit.icon(LbKit.PIECE_ICON))
	var rank := UnityKit.label(box, tr("lb_world_rank") % LbKit.fmt_int(int(view.get("rank", 0))), Rect2(62, RANK_Y, W - 124, 70), 48.0)
	rank.name = "RankLabel"
	var ok: Control = UnityKit.button(box, "green", tr("common_ok"), Rect2((W - BTN.x) * 0.5, BTN_Y, BTN.x, BTN.y), _close).root
	ok.name = "OkButton"


func _ready() -> void:
	setup.call_deferred()


func _close() -> void:
	closed.emit(null)
