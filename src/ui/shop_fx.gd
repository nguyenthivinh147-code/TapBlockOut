extends Control
## The Shop's own animation, not in the ShopCashLayer prefab: a full-rect child of the Shop screen named "ShopFx" (meta
## u_rt, ignores taps), last so the flying gold passes over the bars.
## - enter(cards): as the screen opens, the cards of the scroll content (titles, packs, gold grid, Restore) pop in one
##   after another from the top: each fades in and grows from ENTER_SCALE to its size with a small overshoot.
## - idle(content): loops (UiMotion) once the cards are in: the gold icons of the tiles float (FLOAT), the -50% sale
##   badges wobble (WOBBLE), a light band sweeps over the buy buttons and the big gold pack (SHINE). Neighbours start
##   a step apart, top to bottom, so each loop ripples down the shop.
## - fly_gold(from, gold): gold that a purchase or a video just put in the wallet flies from the card to the top bar's
##   gold chip (CoinFx, as on the win card). The chip counts up from the balance before, and its icon bumps with a
##   coin sound as each coin lands; flights that overlap count on together.
## - pop(c): a control whose state just changed (price -> Owned) swells and settles.
## Nothing runs while baking (UnityUI.baking), so the saved scene stays still.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")
const CoinFx := preload("res://src/ui/coin_fx.gd")

## enter: card i starts ENTER_DELAY + min(i, ENTER_STEPS) * ENTER_STEP s after opening, fades in over ENTER_FADE s and
## grows from ENTER_SCALE over ENTER_GROW s (back ease). Cards past ENTER_STEPS are below the fold and come in together.
const ENTER_DELAY := 0.05
const ENTER_STEP := 0.06
const ENTER_STEPS := 7
const ENTER_FADE := 0.2
const ENTER_GROW := 0.4
const ENTER_SCALE := 0.86
## idle: the first loop starts IDLE_DELAY s after opening (the cards are in), the next of the same kind a step later.
const IDLE_DELAY := 0.7
const FLOAT_STEP := 0.3
const WOBBLE_STEP := 0.15
const SHINE_STEP := 0.12
## Prefab names: tile icons are "Icon" under a tile's "BG"; buy buttons draw their pill in "image".
const BUTTONS := ["Button_Purchase", "Button_Ads"]
const BIG_PACK := "Shop_GoldBigPack"
## fly_gold: the chip icon bumps to BUMP (BUMP_LAST for the last coin) and settles in BUMP_SEC.
const BUMP := 1.15
const BUMP_LAST := 1.35
const BUMP_SEC := 0.35
## pop: swells to POP_SCALE and settles in POP_SEC.
const POP_SCALE := 1.35
const POP_SEC := 0.35

## HubTop whose gold chip the coins fly to.
var top: Control = null
## Tween of enter() (null before, or while baking).
var enter_tween: Tween = null

var _flights := 0
## Gold the chip shows while coins fly.
var _shown := 0


func _init() -> void:
	name = "ShopFx"
	set_meta("u_rt", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Pops in the visible cards in order.
func enter(cards: Array) -> void:
	if UnityUI.baking:
		return
	var shown: Array[Control] = []
	for c in cards:
		if c is Control and (c as Control).visible:
			shown.append(c)
	if shown.is_empty():
		return
	enter_tween = create_tween().set_parallel(true)
	for i in shown.size():
		var c := shown[i]
		var base := c.scale
		var d := ENTER_DELAY + mini(i, ENTER_STEPS) * ENTER_STEP
		c.modulate.a = 0.0
		c.scale = base * ENTER_SCALE
		enter_tween.tween_property(c, "modulate:a", 1.0, ENTER_FADE).set_delay(d)
		enter_tween.tween_property(c, "scale", base, ENTER_GROW).set_delay(d) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Starts the loops on the cards under content.
func idle(content: Control) -> void:
	if UnityUI.baking:
		return
	var icons: Array[Control] = []
	var badges: Array[Control] = []
	var shines: Array[Control] = []
	for n in content.find_children("*", "Control", true, false):
		var c := n as Control
		if not _shown_under(c, content):
			continue
		if c.name == "Icon" and c.get_parent().name == "BG":
			icons.append(c)
		elif c.name == "SellBadge":
			badges.append(c)
		elif c.name == "image" and BUTTONS.has(str(c.get_parent().name)):
			shines.append(c)
		elif c.name == "BG" and c.get_parent().name == BIG_PACK:
			shines.append(c)
	_loop(icons, UiMotion.FLOAT, FLOAT_STEP)
	_loop(badges, UiMotion.WOBBLE, WOBBLE_STEP)
	_loop(shines, UiMotion.SHINE, SHINE_STEP)


## c and its parents up to root are visible (works before the screen is in the tree).
static func _shown_under(c: Control, root: Control) -> bool:
	var n: Node = c
	while n != null and n != root:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		n = n.get_parent()
	return true


## Attaches kind to each node, top to bottom (then left to right), each step s after the one above.
func _loop(nodes: Array[Control], kind: int, step: float) -> void:
	nodes.sort_custom(func(a: Control, b: Control) -> bool:
		var pa := a.get_global_rect().position
		var pb := b.get_global_rect().position
		return pa.y < pb.y - 1.0 or (absf(pa.y - pb.y) <= 1.0 and pa.x < pb.x))
	for i in nodes.size():
		UiMotion.attach(nodes[i], kind, IDLE_DELAY + i * step)


## Flies gold (already in the wallet) from `from` to the top bar's gold chip. False when nothing flies (no gold, no
## bar, baking, off screen): the caller then plays the coin sound itself.
func fly_gold(from: Control, gold: int) -> bool:
	if gold <= 0 or UnityUI.baking or not is_inside_tree() or not is_instance_valid(top) \
			or not is_instance_valid(from) or not from.is_visible_in_tree():
		return false
	if _flights == 0:
		_shown = maxi(int(Game.s.coins) - gold, 0)
	_flights += 1
	top.set("gold_shown", _shown)
	var icon: TextureRect = top.get("gold_icon")
	var fx: Control = CoinFx.new()
	fx.name = "GoldFx"
	add_child(fx)
	fx.start(from, icon, icon.texture, CoinFx.MAX_COINS, gold, Callable(), _on_land)
	return true


## True while coins are on their way to the chip.
func flying() -> bool:
	return _flights > 0


func _on_land(gold: int, last: bool) -> void:
	if not is_instance_valid(top):
		return
	_shown += gold
	if last:
		_flights = maxi(_flights - 1, 0)
	top.set("gold_shown", -1 if _flights == 0 else _shown)
	var icon: Control = top.get("gold_icon")
	var k := BUMP_LAST if last else BUMP
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2(k, k)
	icon.create_tween().tween_property(icon, "scale", Vector2.ONE, BUMP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("sfx_coin")


func pop(c: Control) -> void:
	if UnityUI.baking or not is_instance_valid(c):
		return
	c.scale = Vector2(POP_SCALE, POP_SCALE)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, POP_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
