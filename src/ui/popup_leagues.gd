extends Control
## Wireframe 8.3 Leagues: 7 league, khoảng điểm và thưởng nhận khi lên league.
## setup({view}): view = Game.lb_leagues_view() ({current, points, rows}); không truyền thì tự đọc. closed(null).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")

const LIST_H := 760.0

var view: Dictionary = {}
var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", Game.lb_leagues_view())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var k := PopupKit.make(self, tr("lb_leagues_title"), _close)
	var box: VBoxContainer = k.box
	box.add_child(PopupKit.text(tr("lb_leagues_sub"), ThemeKit.FS_SMALL + 2, ThemeKit.INK_DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PopupKit.CONTENT_W, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for r in view.get("rows", []):
		list.add_child(_row(r))
	var ok := ThemeKit.make_button(tr("common_ok"), "primary")
	ok.name = "OkButton"
	ok.pressed.connect(_close)
	box.add_child(ok)
	PopupKit.show_in(k)


func _ready() -> void:
	setup.call_deferred()


func _row(r: Dictionary) -> Control:
	var cur := bool(r.get("current", false))
	var well := ThemeKit.make_well(ThemeKit.WELL_HOT if cur else ThemeKit.WELL, ThemeKit.WELL_HEADER if cur else Color(0, 0, 0, 0))
	well.name = "League_" + str(r.id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	h.add_child(LbKit.league_badge(str(r.id), 84))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(ThemeKit.ink_label(LbKit.league_name(str(r.id)), ThemeKit.FS_SMALL + 6, ThemeKit.BROWN))
	var span := tr("lb_league_range_top") % int(r.min) if int(r.max) < 0 else tr("lb_league_range") % [int(r.min), int(r.max)]
	v.add_child(ThemeKit.ink_label(span, ThemeKit.FS_SMALL - 2))
	var reward := ThemeKit.ink_label(RewardText.text(r.get("reward", {})), ThemeKit.FS_SMALL - 4, ThemeKit.INK_DIM)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(reward)
	var status := ""
	if cur:
		status = tr("lb_current")
	elif bool(r.get("reached", false)):
		status = tr("lb_reached")
	if status != "":
		var c := ThemeKit.ink_label(status, ThemeKit.FS_SMALL - 2, ThemeKit.INK_GOOD)
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(c)
	return well


func _close() -> void:
	Sfx.play("button")
	closed.emit(null)
