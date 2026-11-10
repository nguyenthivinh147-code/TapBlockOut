extends "res://src/ui/stub_ui.gd"
## Wireframe 4.7 Out of Moves + Helper Pack: cứu lượt kèm gói trợ giúp (design.md mục 3 "Khi hết MOVES", mục 7).
## level.gd mở thay cho popup_rescue ở lần cứu đầu của ván khi đây là lần hết MOVES thứ HELPER_FROM_FAIL liên tiếp ở
## level đó và kho không còn +3 Move. Cùng tham số và kết quả với popup_rescue: setup(args) nhận Game.rescue_offer
## kèm attempt; closed("inventory" | "gold" | "video" | "skip" | "need_coins").
## SupportPackLayer (color-cube-match-puzzle) is the pack strip at the bottom of the screen: its Helper_Pack card
## sells helper_great (Config.SKUS); bought, the pack's +3 Move goes straight to the board (rescue by inventory).
## The rescue part above it has no prefab here: PopupOkLayer frame (UnityKit) with the body and the Free (video) /
## gold buttons in the frame's button row (280x120, spacing 52). X and Back give up ("skip").

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Shop := preload("res://src/ui/shop.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const Config := preload("res://src/config.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

## Config.ECON.helper_pack_sku (helper_great).
var SKU: String = str(Config.ECON.get("helper_pack_sku", "helper_great"))
const VIDEO_PLACEMENT := "continue_moves"
const CARD := "Scroll View/Viewport/Content/Helper_Pack"
## The strip's reward texts are white on its white inner panel (unfinished in the prefab): the shop's item outline.
const ITEM_MAT := "Baloo Outline - DarkBlue"
const RP := CARD + "/Right_Panel"
## Reward slots of the card for the pack's contents: the first row's single slot (the prefab's gold) takes gold or
## unlimited lives, the second row the boosters (_entries).
const SLOTS :=[RP + "/Row(Clone)/ShopRewardItem(Clone)", RP + "/Row(Clone)#2/ShopRewardItem(Clone)",
	RP + "/Row(Clone)#2/ShopRewardItem(Clone)#2", RP + "/Row(Clone)#2/ShopRewardItem(Clone)#3"]

var strip: RefCounted = null
var _busy: bool = false
## RewardFly part -> its slot on the pack card.
var _icons: Dictionary = {}


func _sample() -> Dictionary:
	return {"price": int(SampleData.HELPER_PACK.gold), "affordable": true, "video": true, "remaining": 3}


func setup(args: Dictionary = {}) -> void:
	# Called with Game.rescue_offer itself (like popup_rescue), or {view} from the UI gallery.
	if not args.has("view") and args.has("price"):
		args = {"view": args}
	super.setup(args)


func _build() -> void:
	# Frame (724 x 560), Body and the Free (video icon) / gold (gold icon) pills, their text moved right of the icon
	# like PopupRewardLayer's x2 button, are nodes of scenes/popup_helper_pack.tscn. The strip adds no node, so the
	# scene keeps it closed: its changes stay here.
	ui = UnityKit.frame(self, tr("rescue_title"), _on_skip)
	UnityUI.set_text(%Body, tr("rescue_body"))
	var free: Button = %FreeButton
	free.visible = bool(view.get("video", false))
	UnityUI.set_text(free.get_node("Out"), tr("common_free"))
	free.connect("clicked", _on_video)
	if free.visible:
		Game.offer_video(VIDEO_PLACEMENT)
	var gold: Button = %GoldButton
	UnityUI.set_text(gold.get_node("Out"), Shop.fmt_n0(int(view.get("price", 0))))
	UnityKit.gold_pill(gold)
	UnityKit.gold_coin(gold.get_node("Icon"))
	gold.connect("clicked", _on_gold)
	_build_strip()


func _build_strip() -> void:
	strip = UnityUI.build(self, "SupportPackLayer", {"reveal": false})
	strip.show("Scroll View/Viewport/Content/Starter_Pack", false)
	# One card: SupportPackUICoreLayer hides the tab dots and the scroll when a single pack shows.
	strip.show("Tab", false)
	strip.text(CARD + "/Bottom_Group/HELPER PACK", tr("lose_helper_title"))
	strip.text(CARD + "/Bottom_Group/Button/Text (TMP)", Platform.price(SKU))
	strip.on_click(CARD + "/Bottom_Group/Button", _on_buy).name = "BuyPackButton"
	strip.sprite(CARD + "/Bg/Icon", "HelperOffer")
	(UnityUI.image_of(strip.node(CARD + "/Bg/Icon")) as Control).set("preserve_aspect", true)
	var entries := _entries()
	# Boosters only (no gold, no unlimited lives): they take the second row and the first row goes.
	var top := not entries.is_empty() and str(entries[0].kind) in ["gold", "inf"]
	var first := 0 if top else 1
	strip.show(RP + "/Row(Clone)", top)
	if not top:
		# The rows sit at fixed spots in Right_Panel (no layout group): the lone second row moves to its middle.
		var row: Control = strip.node(RP + "/Row(Clone)#2")
		var r: Dictionary = (row.get_meta("u_rect") as Dictionary).duplicate()
		var panel: Dictionary = strip.node(RP).get_meta("u_rect")
		r.pos = Vector2((r.pos as Vector2).x, -(panel.size as Vector2).y * 0.5)
		row.set_meta("u_rect", r)
		UnityUI.apply_rect(row)
	for i in SLOTS.size():
		var p: String = SLOTS[i]
		if not strip.has(p):
			continue
		var k := i - first
		var on := k >= 0 and k < entries.size()
		strip.show(p, on)
		if on:
			_item(p, entries[k])
			_icons[str(entries[k].kind)] = strip.node(p)
	strip.show(RP + "/Row(Clone)#2/Plus(Clone)#2", strip.has(SLOTS[3]) and strip.node(SLOTS[3]).visible)
	strip.relayout("Scroll View/Viewport/Content")
	var sc: Node = strip.node("Scroll View").get_node_or_null("ScrollRect")
	if sc != null:
		sc.call("set_content_position", Vector2.ZERO)


## LbKit.reward_entries of the pack, unlimited lives moved before the boosters (after gold, if any) with the short
## amount text of the shop items ("Forever", "15m") that fits the slot (Shop.set_inf_label). A player who already has
## unlimited lives for good gains nothing from them: that part is left out (user request 2026-11-10).
func _entries() -> Array:
	var info: Dictionary = Config.SKUS.get(SKU, {})
	var entries := LbKit.reward_entries(RewardFly.sku_reward(SKU))
	var forever := bool(Game.lives_view().get("infinite_forever", false))
	for i in entries.size():
		if str(entries[i].kind) == "inf":
			var e: Dictionary = entries.pop_at(i)
			if forever:
				break
			e.amount = Shop.inf_text(Shop.sku_inf(info))
			e.inf = Shop.sku_inf(info)
			entries.insert(1 if not entries.is_empty() and str(entries[0].kind) == "gold" else 0, e)
			break
	return entries


func _item(p: String, e: Dictionary) -> void:
	LbKit.set_entry_icon(strip.node(p), e)
	var l: Label = strip.text(p + "/Text (TMP)", str(e.amount))
	if l != null:
		l.material = UnityUI.text_material(ITEM_MAT, false)
		if e.has("inf"):
			Shop.set_inf_label(l, int(e.inf))


func _on_gold() -> void:
	if _busy:
		return
	if bool(view.get("use_inventory", false)):
		await _accept("inventory")
	elif not bool(view.get("affordable", false)):
		closed.emit("need_coins")
	else:
		await _accept("gold")


func _on_video() -> void:
	if not _busy:
		await _accept("video")


func _on_skip() -> void:
	if not _busy:
		closed.emit("skip")


## Helper Pack: buy helper_great, then use its +3 Move at once.
func _on_buy() -> void:
	if _busy:
		return
	_busy = true
	var r: Dictionary = await Game.buy_sku(SKU)
	if not is_inside_tree():
		return
	_busy = false
	if str(r.get("status", "")) == "ok" and bool(r.get("granted", false)):
		# The pack's boosters fly from the card to their buttons (RewardFly); one +3 Move rescues at once, so it does
		# not fly.
		var reward := RewardFly.sku_reward(SKU)
		var items: Dictionary = (reward.get("items", {}) as Dictionary).duplicate()
		items["move"] = maxi(int(items.get("move", 0)) - 1, 0)
		reward["items"] = items
		if RewardFly.launch(self, reward, _icons) == 0:
			Sfx.play("sfx_coin")
		await _accept("inventory")


func _accept(method: String) -> void:
	var ok := true
	if view.has("attempt"):
		_busy = true
		ok = await Game.rescue_accept(view.attempt, method)
		if not is_inside_tree():
			return
		_busy = false
	if ok:
		Sfx.play("sfx_moves")
		closed.emit(method)
