extends "res://src/ui/stub_ui.gd"
## Wireframe 3.8 New Booster Unlocked: mở booster mới. Bố cục BoosterTutorialLayer (color-cube-match-puzzle): tiêu đề
## ba lớp chữ, tên booster, icon giữa tia sáng quay, số lượng, mô tả, nút mua bằng gold (ClaimButton thành nút vàng chỉ
## có icon gold và giá, UnityKit.gold_price). Dòng "Chạm để tiếp tục" là bản sao chữ mô tả đặt dưới nút; chạm ra ngoài
## nút thì đóng. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]


func _sample() -> Dictionary:
	return SampleData.BOOSTER_UNLOCK


func _build() -> void:
	# The booster icon and TapLabel (under the button with 0.7 of the description-to-button gap) are saved in
	# scenes/booster_unlocked.tscn.
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, tr("booster_new_title"))
	ui.text(PANEL + "/BoosterName", tr("booster_new_name"))
	ui.text(PANEL + "/BoosterQuantity", tr("booster_count") % int(view.count))
	ui.text(PANEL + "/BoosterDescription", tr("booster_new_body"))
	var buy: Button = ui.on_click(PANEL + "/ClaimButton", _send.bind("buy"))
	buy.name = "BuyButton"
	UnityKit.gold_price(buy, int(view.price))
	UnityUI.set_text(%TapLabel, tr("boot_tap_continue"))


## "Tap to continue": a tap outside the buy button closes.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("close")
