extends "res://src/ui/stub_ui.gd"
## Wireframe 3.8 New Booster Unlocked: mở booster mới. Bố cục BoosterTutorialLayer (color-cube-match-puzzle): tiêu đề
## ba lớp chữ, tên booster, icon giữa tia sáng quay, số lượng, mô tả, nút xanh (nút mua của game). Dòng "Chạm để tiếp
## tục" là bản sao chữ mô tả đặt dưới nút; chạm ra ngoài nút thì đóng. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]


func _sample() -> Dictionary:
	return SampleData.BOOSTER_UNLOCK


func _build() -> void:
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, tr("booster_new_title"))
	ui.text(PANEL + "/BoosterName", tr("booster_new_name"))
	ui.texture(PANEL + "/BoosterImage/Icon", ThemeKit.icon("booster_move"))
	UnityUI.image_of(ui.node(PANEL + "/BoosterImage/Icon")).preserve_aspect = true
	ui.text(PANEL + "/BoosterQuantity", tr("booster_count") % int(view.count))
	ui.text(PANEL + "/BoosterDescription", tr("booster_new_body"))
	ui.node(PANEL + "/ClaimButton").name = "BuyButton"
	ui.text(PANEL + "/ClaimButton/Text (TMP)", tr("booster_buy") % int(view.price))
	ui.on_click(PANEL + "/ClaimButton", _send.bind("buy"))
	# Under the button with the gap between description and button (BoosterDescription y -308.8, button -487.6).
	var s := UnityKit.spec("BoosterTutorialLayer", PANEL + "/BoosterDescription")
	s.n = "TapLabel"
	s.r[5] = -487.6 - (487.6 - 308.8) * 0.7
	s.r[7] = 60.0
	s.txt.s = tr("boot_tap_continue")
	s.txt.fs = 36.0
	s.txt.auto = [18.0, 36.0]
	UnityKit.add(ui.node(PANEL), s)


## "Tap to continue": a tap outside the buy button closes.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("close")
