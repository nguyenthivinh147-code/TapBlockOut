extends "res://src/ui/stub_ui.gd"
## Wireframe 9.5 Keep Your Streak?: giữ chuỗi bằng quảng cáo. Chưa nối logic.
## Layout of PopupKeepPlayingWinstreak (color-cube-match-puzzle): purple frame, the crying cat bar with the streak cat
## icon, the warning and the red Quit button. The game's streak count takes the broken heart's place (the game's
## text does not mention a heart); its video Continue is a copy of Quit on the green pill with the TV icon, and the
## two buttons share the row like PopupOkLayer's pair (280 each, spacing 52).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "PopupKeepPlayingWinstreak"
const ROW := "Panel/Content/Button"
const VIDEO_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_5"
const BUTTON_W := 280.0
## The streak count fills the broken heart's slot (centre x 117, y 74.1) up to the cat icon.
const STREAK_RECT := Rect2(-10, 74.1, 210, 90)


func _sample() -> Dictionary:
	return SampleData.STREAK_KEEP


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/GameObject/txtHeader", tr("streak_keep_title"))
	for b in ui.field("closeButtons", "UIPopupKeepPlayingWinstreak"):
		(b as Button).connect("clicked", _send.bind("close"))
	ui.text("Panel/Content/Description", "%s\n%s" % [tr("streak_keep_reset"), tr("streak_keep_body")])
	ui.show("Panel/Content/HeartIcon", false)
	var s := UnityKit.spec(LAYER, "Panel/Content/Description")
	s.n = "StreakText"
	s.r = [0.5, 0.5, 0.5, 0.5, STREAK_RECT.position.x + STREAK_RECT.size.x * 0.5, STREAK_RECT.position.y,
		STREAK_RECT.size.x, STREAK_RECT.size.y, 0.5, 0.5]
	s.txt.fs = 48.0
	s.txt.auto = [18.0, 48.0]
	UnityKit.add(ui.node("Panel/Content"), s).text("", tr("streak_row") % int(view.get("streak", 0)))
	_build_buttons()


func _build_buttons() -> void:
	var quit: Button = ui.button(ROW + "/Ok")
	UnityKit.set_size(quit, Vector2(BUTTON_W, 120))
	ui.text(ROW + "/Ok/Out", tr("lose_keep_quit"))
	quit.connect("clicked", _send.bind("quit"))
	var s := UnityKit.spec(LAYER, ROW + "/Ok")
	s.n = "Continue"
	s.r[6] = BUTTON_W
	s.img.sp = UnityKit.BUTTONS.green[0]
	var out: Dictionary = s.ch[0]
	out.txt.mat = UnityKit.BUTTONS.green[1]
	# Text moves right of the video icon (popup_reward's x2 offsets, widened for the 280 pill).
	out.r[4] = float(out.r[4]) + 45.0
	out.r[6] = float(out.r[6]) - 90.0
	var v := UnityKit.add(ui.node(ROW), s)
	v.text("Out", tr("streak_keep_ad"))
	v.on_click("", _send.bind("continue"))
	UnityKit.sprite(v.root, VIDEO_ICON, Rect2(10, 22, 76, 76))
	# Continue first, Quit second (wireframe order).
	ui.node(ROW).move_child(v.root, 0)
	ui.relayout(ROW)
