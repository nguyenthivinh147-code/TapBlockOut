extends Control
## Wireframe 8.4: popup lên league. Huy hiệu league mới, lời chào, thưởng của các league vừa lên, nút Nhận.
## setup({view}): view = Game.lb_pending_view() ({leagues, league, reward}); không truyền thì tự đọc.
## Nhận hoặc đóng đều gọi Game.lb_claim() (thưởng không mất khi bấm X). closed({"action": "claim", "reward"}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const BOOSTERS := ["hint", "move", "smash"]

var view: Dictionary = {}
var _built: bool = false
var _done: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", Game.lb_pending_view())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var k := PopupKit.make(self, tr("lb_result_title"), _claim, {"banner": "win"})
	var box: VBoxContainer = k.box
	var league := str(view.get("league", "silver"))
	box.add_child(LbKit.league_badge(league, 180))
	var hello := PopupKit.text(tr("lb_result_promoted") % LbKit.league_name(league), ThemeKit.FS_BODY, ThemeKit.BROWN)
	hello.name = "PromotedLabel"
	box.add_child(hello)
	var tiles := _tiles(view.get("reward", {}))
	if not tiles.is_empty():
		box.add_child(PopupKit.text(tr("lb_result_reward"), ThemeKit.FS_SMALL + 2, ThemeKit.INK_DIM))
		box.add_child(PopupKit.row(tiles))
	var claim := ThemeKit.make_button(tr("daily_claim"), "primary")
	claim.name = "ClaimButton"
	claim.pressed.connect(_claim)
	box.add_child(claim)
	Sfx.play("sfx_win")
	PopupKit.show_in(k)


func _ready() -> void:
	setup.call_deferred()


func _tiles(reward: Dictionary) -> Array:
	var out: Array = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		out.append(PopupKit.reward_tile(ThemeKit.icon("ui_gold"), tr("shop_gold_pack") % coins, 80.0))
	var items: Dictionary = reward.get("items", {})
	for kind in BOOSTERS:
		var n := int(items.get(kind, 0))
		if n > 0:
			out.append(PopupKit.reward_tile(ThemeKit.icon("booster_" + kind), "%s %s" % [tr("booster_" + kind), tr("booster_count") % n], 80.0))
	var inf := int(reward.get("inf_min", 0))
	if inf > 0:
		out.append(PopupKit.reward_tile(ThemeKit.icon("ui_heart"), tr("weekly_reward_inf") % inf, 80.0))
	return out


func _claim() -> void:
	if _done:
		return
	_done = true
	Sfx.play("button")
	var r: Dictionary = Game.lb_claim()
	if not r.is_empty():
		Sfx.play("sfx_coin")
	closed.emit({"action": "claim", "reward": r})
