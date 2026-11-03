extends "res://src/ui/stub_ui.gd"
## Wireframe 5.3 Heart Support Pack: gói mạng khi hết mạng. Chưa nối logic.
## SupportPackLayer (color-cube-match-puzzle) strip at the bottom: its Starter_Pack card is the support pack (the
## game's line about the pack on the card, price button "buy"). Above it the PopupOkLayer frame (UnityKit) with the
## title, the heart and the refill button ("refill").

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const CARD := "Scroll View/Viewport/Content/Starter_Pack"

var strip: RefCounted = null


func _sample() -> Dictionary:
	return SampleData.HEART_SUPPORT


func _build() -> void:
	# Frame (724 x 560), Heart (PopupMoreHeartLayer's HeartIcon size, 200) and RefillButton are nodes of
	# scenes/popup_heart_support.tscn. The strip adds no node, so the scene keeps it closed: its changes stay here.
	ui = UnityKit.frame(self, tr("hearts_support_title"), _send.bind("close"))
	UnityUI.set_text(%RefillButton.get_node("Out"), tr("hearts_support_refill"))
	%RefillButton.connect("clicked", _send.bind("refill"))

	strip = UnityUI.build(self, "SupportPackLayer", {"reveal": false})
	strip.show("Scroll View/Viewport/Content/Helper_Pack", false)
	strip.show("Tab", false)
	var name_l: Label = strip.label(CARD + "/Bottom_Group/HELPER PACK")
	# One-line pack name in the prefab: the game's sentence wraps in the same box.
	var t: Dictionary = (name_l.get_meta("u_txt") as Dictionary).duplicate(true)
	t.w = true
	name_l.set_meta("u_txt", t)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UnityUI.set_text(name_l, tr("hearts_support_body"))
	strip.text(CARD + "/Bottom_Group/Button/Text (TMP)", tr("hearts_support_buy") % str(view.get("price", "")))
	strip.on_click(CARD + "/Bottom_Group/Button", _send.bind("buy"))
	strip.sprite(CARD + "/Bg/Icon", "BundleTim")
	(UnityUI.image_of(strip.node(CARD + "/Bg/Icon")) as Control).set("preserve_aspect", true)
	# The pack's contents, timer and sale tag are not set in the game yet.
	for x in ["/Right_Panel", "/Image", "/Sale"]:
		strip.show(CARD + x, false)
	strip.relayout("Scroll View/Viewport/Content")
	var sc: Node = strip.node("Scroll View").get_node_or_null("ScrollRect")
	if sc != null:
		sc.call("set_content_position", Vector2.ZERO)
