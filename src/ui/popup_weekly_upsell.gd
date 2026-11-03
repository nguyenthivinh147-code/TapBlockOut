extends "res://src/ui/stub_ui.gd"
## Wireframe 7.5 Weekly Pass Upsell: giới thiệu Weekly Pass. Chưa nối logic.
## No Unity prefab: PopupOkLayer frame (UnityKit) with the time pill of PopupWinStreakMain, the light1 glow of
## PopupWinStreakInstruction's pack preview (the game's pack art instead of StarterPack), the perks as
## DailyRewardAdLayer description rows (tick icon, text 40) on the cream well and a green purchase pill.

const UnityKit := preload("res://src/ui/unity_kit.gd")

const SIZE := Vector2(724, 1130)
const DESC_ROW := "Panel/Content/Preview/Bottom (1)/Group/DescText (1)"


func _sample() -> Dictionary:
	return SampleData.WEEKLY_UPSELL


func _build() -> void:
	ui = UnityKit.popup(self, tr("weekly_title"), SIZE, _send.bind("close"))
	var c: Control = ui.node("Panel/Content")

	var t := UnityKit.spec("PopupWinStreakMain", "Panel/Time")
	t.ch = [t.ch[0], t.ch[1]]
	(t.ch[1] as Dictionary).r[6] = 196.0
	var tv := UnityKit.add(c, t, Rect2((SIZE.x - 300.0) * 0.5, 104, 300, 68))
	tv.text("Text (TMP)", tr("weekly_time_left") % str(view.ends_in))

	var g := UnityKit.spec("PopupWinStreakInstruction", "Panel/Content/Preview/Bottom/Group/Image#2")
	g.a = true
	g.ch[0].img.sp = null
	g.ch[0].img.pa = true
	var gv := UnityKit.add(c, g, Rect2((SIZE.x - 400.0) * 0.5, 170, 400, 400))
	gv.texture("Image (5)", ThemeKit.icon("shop_gold_pack_6"))

	var well := UnityKit.well(c, Rect2(42, 580, 640, 300))
	var y := 20.0
	for key in ["weekly_upsell_one", "weekly_upsell_two", "weekly_upsell_three"]:
		var s := UnityKit.spec("DailyRewardAdLayer", DESC_ROW)
		s.txt.c = UnityKit.INK
		s.txt.s = tr(key)
		UnityKit.add(well, s, Rect2(10, y, 596, 80))
		y += 90.0

	UnityKit.button(c, "green", str(view.price), Rect2((SIZE.x - 280.0) * 0.5, SIZE.y - 68.0 - 120.0, 280, 120), _send.bind("buy"))
