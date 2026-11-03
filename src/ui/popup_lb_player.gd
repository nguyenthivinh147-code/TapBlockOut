extends Control
## Thẻ người chơi khi chạm một hàng ở World Ranking: avatar, tên, cờ, league, hạng, điểm.
## setup({view}): một hàng của Game.lb_world_view().rows. closed(null).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const Profile := preload("res://src/ui/profile.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")

var view: Dictionary = {}
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", {})
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var k := PopupKit.make(self, LbKit.display_name(view), _close)
	var box: VBoxContainer = k.box
	var av := Profile.make_avatar(str(view.get("avatar", "")), str(view.get("frame", "")), 160)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(av)
	var flag := LbKit.flag_chip(str(view.get("flag", "")))
	if flag != null:
		flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(flag)
	var league := str(view.get("league", ""))
	if league != "":
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 10)
		h.add_child(LbKit.league_badge(league, 72))
		h.add_child(ThemeKit.ink_label(tr("lb_league") % LbKit.league_name(league), ThemeKit.FS_BODY, ThemeKit.BROWN))
		box.add_child(h)
	var rank := PopupKit.text(tr("lb_world_rank") % LbKit.fmt_int(int(view.get("rank", 0))), ThemeKit.FS_SMALL + 4)
	rank.name = "RankLabel"
	box.add_child(rank)
	box.add_child(PopupKit.text(tr("lb_player_points") % int(view.get("points", 0)), ThemeKit.FS_SMALL + 2, ThemeKit.INK_DIM))
	var ok := ThemeKit.make_button(tr("common_ok"), "primary")
	ok.name = "OkButton"
	ok.pressed.connect(_close)
	box.add_child(ok)
	PopupKit.show_in(k)


func _ready() -> void:
	setup.call_deferred()


func _close() -> void:
	Sfx.play("button")
	closed.emit(null)
