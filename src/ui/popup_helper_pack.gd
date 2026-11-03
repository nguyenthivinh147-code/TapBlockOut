extends "res://src/ui/stub_ui.gd"
## Wireframe 4.7 Out of Space + Helper Pack: cứu lượt kèm gói trợ giúp. Chưa nối logic.
## SupportPackLayer (color-cube-match-puzzle) is the pack strip at the bottom of the screen: its Helper_Pack card
## sells the helper pack. The rescue part above it has no prefab here: PopupOkLayer frame (UnityKit) with the body
## and the Free (video) / gold buttons in the frame's button row (280x120, spacing 52).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Shop := preload("res://src/ui/shop.gd")

const SIZE := Vector2(724, 560)
const CARD := "Scroll View/Viewport/Content/Helper_Pack"
const VIDEO_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_5"
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
## The strip's reward texts are white on its white inner panel (unfinished in the prefab): the shop's item outline.
const ITEM_MAT := "Baloo Outline - DarkBlue"

var strip: RefCounted = null


func _sample() -> Dictionary:
	return SampleData.HELPER_PACK


func _build() -> void:
	ui = UnityKit.popup(self, tr("rescue_title"), SIZE, _send.bind("close"))
	var content: Control = ui.node("Panel/Content")
	UnityKit.label(content, tr("rescue_body"), Rect2(62, 150, SIZE.x - 124.0, 200), 44.0)
	var y := SIZE.y - 128.0
	var free := UnityKit.button(content, "blue", tr("common_free"), Rect2(56, y, 280, 120), _send.bind("free"))
	_icon_left(free, VIDEO_ICON)
	var gold := UnityKit.button(content, "yellow", Shop.fmt_n0(int(view.get("gold", 0))), Rect2(388, y, 280, 120),
		_send.bind("gold"))
	_icon_left(gold, GOLD_ICON)

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


## Icon at the left of a pill, its text moved right (like PopupRewardLayer's x2 button in popup_reward.gd).
func _icon_left(v: RefCounted, key: String) -> void:
	var out: Label = v.label("Out")
	var r: Dictionary = out.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x + 36.0, (r.pos as Vector2).y)
	r.size = Vector2((r.size as Vector2).x - 72.0, (r.size as Vector2).y)
	UnityUI.apply_rect(out)
	UnityKit.sprite(v.root, key, Rect2(16, 22, 76, 76))


func _item(p: String, tex: Texture2D, text: String) -> void:
	strip.texture(p, tex)
	(UnityUI.image_of(strip.node(p)) as Control).set("preserve_aspect", true)
	var l: Label = strip.text(p + "/Text (TMP)", text)
	if l != null:
		l.material = UnityUI.text_material(ITEM_MAT, false)
