extends "res://src/ui/stub_ui.gd"
## Wireframe 7.5 Weekly Pass Upsell: giới thiệu Weekly Pass. Chưa nối logic.
## No Unity prefab: PopupOkLayer frame (UnityKit) with the time pill of PopupWinStreakMain, the light1 glow of
## PopupWinStreakInstruction's pack preview (the game's pack art instead of StarterPack), the perks as
## DailyRewardAdLayer description rows (tick icon, text 40) on the cream well and a green purchase pill.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const PERKS := ["weekly_upsell_one", "weekly_upsell_two", "weekly_upsell_three"]


func _sample() -> Dictionary:
	return SampleData.WEEKLY_UPSELL


func _build() -> void:
	# Frame (724 x 1130), TimePill, PackGlow, PerkWell with Perk1..3 and BuyButton are nodes of
	# scenes/popup_weekly_upsell.tscn.
	ui = UnityKit.frame(self, tr("weekly_title"), _send.bind("close"))
	UnityUI.set_text(%TimePill.get_node("Text (TMP)"), tr("weekly_time_left") % str(view.ends_in))
	for i in PERKS.size():
		UnityUI.set_text(get_node("%%Perk%d" % (i + 1)), tr(PERKS[i]))
	UnityUI.set_text(%BuyButton.get_node("Out"), str(view.price))
	%BuyButton.connect("clicked", _send.bind("buy"))
