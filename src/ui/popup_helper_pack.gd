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

## Config.ECON.helper_pack_sku (helper_great).
var SKU: String = str(Config.ECON.get("helper_pack_sku", "helper_great"))
const VIDEO_PLACEMENT := "continue_moves"
const CARD := "Scroll View/Viewport/Content/Helper_Pack"
## The strip's reward texts are white on its white inner panel (unfinished in the prefab): the shop's item outline.
const ITEM_MAT := "Baloo Outline - DarkBlue"
const RP := CARD + "/Right_Panel"
## Reward slots of the card for the pack's contents, in LbKit.reward_entries order.
const SLOTS := [RP + "/Row(Clone)/ShopRewardItem(Clone)", RP + "/Row(Clone)#2/ShopRewardItem(Clone)",
	RP + "/Row(Clone)#2/ShopRewardItem(Clone)#2", RP + "/Row(Clone)#2/ShopRewardItem(Clone)#3"]

var strip: RefCounted = null
var _busy: bool = false


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
	var info: Dictionary = Config.SKUS.get(SKU, {})
	var entries := LbKit.reward_entries({"coins": int(info.get("gold", 0)), "items": info.get("inv", {}),
		"inf_min": int(info.get("inf_min", 0))})
	for i in SLOTS.size():
		var p: String = SLOTS[i]
		if not strip.has(p):
			continue
		var on := i < entries.size()
		strip.show(p, on)
		if on:
			_item(p, entries[i])
	strip.show(RP + "/Row(Clone)#2/Plus(Clone)#2", entries.size() > 3)
	strip.relayout("Scroll View/Viewport/Content")
	var sc: Node = strip.node("Scroll View").get_node_or_null("ScrollRect")
	if sc != null:
		sc.call("set_content_position", Vector2.ZERO)


func _item(p: String, e: Dictionary) -> void:
	LbKit.set_entry_icon(strip.node(p), e)
	var l: Label = strip.text(p + "/Text (TMP)", str(e.amount))
	if l != null:
		l.material = UnityUI.text_material(ITEM_MAT, false)


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
