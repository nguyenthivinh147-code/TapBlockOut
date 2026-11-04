extends "res://src/ui/stub_ui.gd"
## Wireframe 4.7 Out of Space + Helper Pack: cứu lượt kèm gói trợ giúp. Chưa nối logic.
## SupportPackLayer (color-cube-match-puzzle) is the pack strip at the bottom of the screen: its Helper_Pack card
## sells the helper pack. The rescue part above it has no prefab here: PopupOkLayer frame (UnityKit) with the body
## and the Free (video) / gold buttons in the frame's button row (280x120, spacing 52).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Shop := preload("res://src/ui/shop.gd")

const CARD := "Scroll View/Viewport/Content/Helper_Pack"
## The strip's reward texts are white on its white inner panel (unfinished in the prefab): the shop's item outline.
const ITEM_MAT := "Baloo Outline - DarkBlue"

var strip: RefCounted = null


func _sample() -> Dictionary:
	return SampleData.HELPER_PACK


func _build() -> void:
	# Frame (724 x 560), Body and the Free (video icon) / gold (gold icon) pills, their text moved right of the icon
	# like PopupRewardLayer's x2 button, are nodes of scenes/popup_helper_pack.tscn. The strip adds no node, so the
	# scene keeps it closed: its changes stay here.
	ui = UnityKit.frame(self, tr("rescue_title"), _send.bind("close"))
	UnityUI.set_text(%Body, tr("rescue_body"))
	UnityUI.set_text(%FreeButton.get_node("Out"), tr("common_free"))
	%FreeButton.connect("clicked", _send.bind("free"))
	UnityUI.set_text(%GoldButton.get_node("Out"), Shop.fmt_n0(int(view.get("gold", 0))))
	UnityKit.gold_pill(%GoldButton)
	UnityKit.gold_coin(%GoldButton.get_node("Icon"))
	%GoldButton.connect("clicked", _send.bind("gold"))

	strip = UnityUI.build(self, "SupportPackLayer", {"reveal": false})
	strip.show("Scroll View/Viewport/Content/Starter_Pack", false)
	# One card: SupportPackUICoreLayer hides the tab dots and the scroll when a single pack shows.
	strip.show("Tab", false)
	strip.text(CARD + "/Bottom_Group/HELPER PACK", tr("lose_helper_title"))
	strip.text(CARD + "/Bottom_Group/Button/Text (TMP)", str(view.get("price", "")))
	strip.on_click(CARD + "/Bottom_Group/Button", _send.bind("buy_pack"))
	strip.sprite(CARD + "/Bg/Icon", "HelperOffer")
	(UnityUI.image_of(strip.node(CARD + "/Bg/Icon")) as Control).set("preserve_aspect", true)
	var rp := CARD + "/Right_Panel"
	_item(rp + "/Row(Clone)/ShopRewardItem(Clone)", UiAtlas.tex("banner_coins"), tr("lose_helper_chest"))
	_item(rp + "/Row(Clone)#2/ShopRewardItem(Clone)", ThemeKit.icon("booster_hint"), tr("booster_count") % 1)
	_item(rp + "/Row(Clone)#2/ShopRewardItem(Clone)#2", ThemeKit.icon("booster_move"), tr("booster_move"))
	strip.show(rp + "/Row(Clone)#2/Plus(Clone)#2", false)
	strip.show(rp + "/Row(Clone)#2/ShopRewardItem(Clone)#3", false)
	strip.relayout("Scroll View/Viewport/Content")
	var sc: Node = strip.node("Scroll View").get_node_or_null("ScrollRect")
	if sc != null:
		sc.call("set_content_position", Vector2.ZERO)


func _item(p: String, tex: Texture2D, text: String) -> void:
	strip.texture(p, tex)
	(UnityUI.image_of(strip.node(p)) as Control).set("preserve_aspect", true)
	var l: Label = strip.text(p + "/Text (TMP)", text)
	if l != null:
		l.material = UnityUI.text_material(ITEM_MAT, false)
