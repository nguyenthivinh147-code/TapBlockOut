extends RefCounted
## A reward just received flies from its icon (in the popup that shows it) into the counter that holds it, as Unity's
## RewardItemFlyEffectController and MoneyFlyEffectController do (design.md mục 2 "Phần thưởng bay vào ô đếm"):
## - gold: the gold chip of the top bar (HubTop), many coins (CoinFx) as in the Shop;
## - lives, inf (minutes of unlimited lives): the lives chip of HubTop, one heart (ItemFx);
## - hint, move, smash: the booster's button in a level; outside a level the Home tab of the bottom bar (HubNav), like
##   Unity's HomeTabPosition. One icon each (ItemFx).
## Targets are the nodes of GROUP: each answers reward_target(kind) with a visible Control or null. The one drawn on
## top (last in tree order) wins, skipping the popup the reward flies from. A part with no target or no source icon
## does not fly: its counter shows it at once.
## Counters show the wallet minus held(kind), the part still flying; each landing takes its share off, calls
## reward_refresh() on every node of GROUP, bumps the target and plays a sound. "inf" has no number: the chip changes
## at once and the heart only bumps it.
## hold(owner, reward): a popup showing a reward the game granted before it opened (popup Reward) keeps the counters
## on the old numbers until launch(); if the owner leaves the tree first, the hold ends.
## A flight lives under the target's top ancestor (Main in the game): it outlives the popup it leaves, and goes with
## the UI that holds its counter (the counter then shows the rest at once).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const CoinFx := preload("res://src/ui/coin_fx.gd")
const ItemFx := preload("res://src/ui/item_fx.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")
const Config := preload("res://src/config.gd")

const GROUP := "reward_fly"
## Parts of a reward in flight order; one part leaves STAGGER s after the one before.
const ORDER := ["gold", "lives", "inf", "hint", "move", "smash"]
const BOOSTERS := ["hint", "move", "smash"]
const STAGGER := 0.12
## Landing: the target swells to BUMP (BUMP_LAST on the last coin of a part) and settles in BUMP_SEC.
const BUMP := 1.15
const BUMP_LAST := 1.35
const BUMP_SEC := 0.35

## kind -> amount still flying (or held by hold()); counters show the wallet minus this.
static var _held: Dictionary = {}
## owner instance id -> {kind: amount} held by hold().
static var _holds: Dictionary = {}


## Amount of `kind` the counters do not show yet.
static func held(kind: String) -> int:
	return int(_held.get(kind, 0))


## {coins, items: {hint, move, smash}, inf_min, inf_forever, lives} -> {gold, hint, move, smash, inf, lives}, parts
## above 0 (inf_forever counts as inf 1).
static func parts(reward: Dictionary) -> Dictionary:
	var out := {}
	var inf := 1 if bool(reward.get("inf_forever", false)) else int(reward.get("inf_min", 0))
	var raw := {"gold": reward.get("coins", 0), "lives": reward.get("lives", 0), "inf": inf}
	var items: Dictionary = reward.get("items", {})
	for k in BOOSTERS:
		raw[k] = items.get(k, 0)
	for k in ORDER:
		if int(raw[k]) > 0:
			out[k] = int(raw[k])
	return out


## The reward a store SKU grants (Config.SKUS: gold, inv, inf_min, inf_forever), as Game.grant_purchase gives it.
static func sku_reward(sku: String) -> Dictionary:
	var info: Dictionary = Config.SKUS.get(sku, {})
	return {"coins": int(info.get("gold", 0)), "items": info.get("inv", {}), "inf_min": int(info.get("inf_min", 0)),
		"inf_forever": bool(info.get("inf_forever", false))}


## Keeps the counters on the numbers before `reward` (already granted) until launch() for owner; ends by itself when
## owner leaves the tree. Parts in `skip` are not held.
static func hold(owner: Node, reward: Dictionary, skip: Array = []) -> void:
	if owner == null or UnityUI.baking:
		return
	var id := owner.get_instance_id()
	_unhold(id, false)
	var a := _counted(parts(reward), skip)
	if a.is_empty():
		return
	_holds[id] = a
	_add(a, 1)
	owner.tree_exited.connect(func() -> void: _unhold(id), CONNECT_ONE_SHOT)
	_refresh()


## Flies the parts of `reward` (already granted) from icons[kind] (Controls of owner, read now, or their Rect2 in
## canvas coordinates) to their counters. Ends owner's hold. Returns how many parts fly.
static func launch(owner: Node, reward: Dictionary, icons: Dictionary, skip: Array = []) -> int:
	return fly(owner, reward, icons, skip).size()


## launch() returning the flights (CoinFx / ItemFx nodes; await `arrived` on one to wait for its landing).
static func fly(owner: Node, reward: Dictionary, icons: Dictionary, skip: Array = []) -> Array[Control]:
	if owner != null:
		_unhold(owner.get_instance_id(), false)
	var out: Array[Control] = []
	if not UnityUI.baking:
		var all := parts(reward)
		for kind: String in ORDER:
			if not all.has(kind) or skip.has(kind):
				continue
			var from: Variant = icons.get(kind)
			if not _shown(from):
				continue
			var to := target(kind, owner)
			if to == null:
				continue
			out.append(_fly(from, to, kind, int(all[kind]), out.size() * STAGGER))
	_refresh()
	return out


## The counter icon `kind` flies to: from the topmost node of GROUP outside `skip_owner`; null when none shows.
static func target(kind: String, skip_owner: Node = null) -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group(GROUP)
	for i in range(nodes.size() - 1, -1, -1):
		var h := nodes[i]
		if h.is_queued_for_deletion() or not h.is_inside_tree() or not h.has_method("reward_target"):
			continue
		if skip_owner != null and (skip_owner == h or skip_owner.is_ancestor_of(h)):
			continue
		var c: Variant = h.call("reward_target", kind)
		if c is Control and is_instance_valid(c) and (c as Control).is_visible_in_tree() \
				and (c as Control).get_viewport_rect().intersects((c as Control).get_global_rect()):
			return c
	return null


## Picture of a reward icon: a TextureRect's texture, a Unity image's sprite (atlas region kept), a button's icon;
## else (or for a Rect2 source) the game's icon for `kind`.
static func icon_texture(c: Variant, kind: String) -> Texture2D:
	var tex: Texture2D = null
	if not (is_instance_valid(c) and c is Control):
		pass
	elif c is TextureRect:
		tex = (c as TextureRect).texture
	elif UnityUI.image_of(c) != null:
		var img := UnityUI.image_of(c)
		tex = img.get("tex")
		var region: Rect2 = img.get("region")
		if tex != null and region.has_area():
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = region
			tex = at
	elif c is Button:
		tex = (c as Button).icon
	if tex != null:
		return tex
	match kind:
		"gold":
			return ThemeKit.icon("ui_gold")
		"lives":
			return ThemeKit.icon("ui_heart")
		"inf":
			return ThemeKit.icon("ic_lives")
	return ThemeKit.icon("booster_" + kind)


## Ends every flight's hold and every hold (tests).
static func reset() -> void:
	_held.clear()
	_holds.clear()


## A source on screen: a Rect2 with an area, or a Control shown in the tree.
static func _shown(from: Variant) -> bool:
	if from is Rect2:
		var r: Rect2 = from
		return r.has_area()
	return is_instance_valid(from) and from is Control and (from as Control).is_visible_in_tree()


static func _counted(all: Dictionary, skip: Array) -> Dictionary:
	var out := {}
	for k: String in all:
		if k != "inf" and not skip.has(k):
			out[k] = int(all[k])
	return out


static func _add(a: Dictionary, sign_: int) -> void:
	for k: String in a:
		_held[k] = maxi(held(k) + sign_ * int(a[k]), 0)
		if int(_held[k]) == 0:
			_held.erase(k)


static func _unhold(id: int, refresh: bool = true) -> void:
	if not _holds.has(id):
		return
	_add(_holds[id], -1)
	_holds.erase(id)
	if refresh:
		_refresh()


static func _fly(from: Variant, to: Control, kind: String, amount: int, wait: float) -> Control:
	var tree := Engine.get_main_loop() as SceneTree
	var counted := 0 if kind == "inf" else amount
	var left := {"n": counted}
	_add({kind: counted}, 1)
	# By id: the target may be freed before the icon lands (the screen changed).
	var to_id := to.get_instance_id()
	var land := func(share: int, last: bool) -> void:
		var take := mini(share, int(left.n)) if not last else int(left.n)
		left.n = int(left.n) - take
		_add({kind: take}, -1)
		_refresh()
		var c := instance_from_id(to_id) as Control
		if c != null:
			_bump(c, last)
		if kind == "gold":
			Sfx.play("sfx_coin")
		else:
			Sfx.play_or("sfx_crystal_get", "sfx_coin")
	var fx: Control
	if kind == "gold":
		fx = CoinFx.new()
		fx.name = "RewardGoldFx"
		_host_of(to, tree).add_child(fx)
		fx.call("start", from, to, icon_texture(from, kind), CoinFx.MAX_COINS, amount, Callable(), land)
	else:
		fx = ItemFx.new()
		fx.name = "RewardItemFx"
		_host_of(to, tree).add_child(fx)
		fx.call("start_item", from, to, icon_texture(from, kind), counted, land)
	fx.call("wait", wait)
	# Freed before the last landing (scene change, tests): the counters show the rest at once.
	fx.tree_exiting.connect(func() -> void:
		if int(left.n) > 0:
			_add({kind: int(left.n)}, -1)
			left.n = 0
			_refresh())
	return fx


## Parent of a flight: the target's ancestor right under the root (Main in the game), so the flight outlives the
## popup it leaves but goes with the UI that holds its counter. The effects are top_level: they draw over that UI.
static func _host_of(c: Node, tree: SceneTree) -> Node:
	var n := c
	while n.get_parent() != null and n.get_parent() != tree.root:
		n = n.get_parent()
	return n if n.get_parent() == tree.root else tree.root


static func _bump(c: Control, last: bool) -> void:
	UiTween.bump(c, BUMP_LAST if last else BUMP, BUMP_SEC)


static func _refresh() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP):
		if n.has_method("reward_refresh"):
			n.call("reward_refresh")
