extends Control
## Thẻ người chơi khi chạm một hàng ở World Ranking: avatar, tên, cờ, league, hạng, điểm.
## setup({view}): một hàng của Game.lb_world_view().rows. closed(null).
## No prefab: UnityKit frame (PopupOkLayer, title = player name) with LeaderboardLayer pieces: the Top1 avatar and
## frame, the league pill (TimeRemain: trophy, league name, points in the time slot with the piece icon), world
## rank in PopupOkLayer's body text, OK pill. All of it is nodes of scenes/popup_lb_player.tscn; the script fills
## the row's data and wires the buttons.

signal closed(result: Variant)

const LbKit := preload("res://src/ui/lb_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

var view: Dictionary = {}
var ui: RefCounted = null
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", {})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Frame 724 x 808, avatar (195 at y 150), flag line, league pill (610 x 93, piece icon in the time slot), rank
	# line and OK pill are nodes of scenes/popup_lb_player.tscn.
	ui = UnityKit.frame(self, LbKit.display_name(view), _close)
	LbKit.set_avatar(%Avatar, str(view.get("avatar", "")), str(view.get("frame", "")))
	var flag := str(view.get("flag", ""))
	%FlagText.visible = flag != ""
	UnityUI.set_text(%FlagText, flag)
	var league := str(view.get("league", ""))
	var pv: RefCounted = ui.sub(%LeaguePill)
	pv.show("RankIcon", league != "")
	pv.show("RankName", league != "")
	if league != "":
		LbKit.set_league_icon(pv.node("RankIcon"), league)
		pv.text("RankName", tr("lb_league") % LbKit.league_name(league))
	pv.text("Image/TimeText", tr("lb_player_points") % int(view.get("points", 0)))
	UnityUI.set_text(%RankLabel, tr("lb_world_rank") % LbKit.fmt_int(int(view.get("rank", 0))))
	UnityUI.set_text(%OkButton.get_node("Out"), tr("common_ok"))
	%OkButton.connect("clicked", _close)


func _ready() -> void:
	setup.call_deferred()


func _close() -> void:
	closed.emit(null)
