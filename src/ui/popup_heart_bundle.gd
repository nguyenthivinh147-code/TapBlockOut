extends "res://src/ui/stub_ui.gd"
## Wireframe 5.2 Heart Bundle Offer: mạng vô hạn theo giờ. Chưa nối logic.
## Layout of PopupBundleHeart (color-cube-match-puzzle): illustrated card, ribbon title, timer chip, reward box.
## The game sells three durations: the box shows one infinite-heart slot (Image (3)) per row, spread like
## PopupStarterPack's slots, each with a green pill (PopupOkLayer's Ok, UnityKit) under it instead of FreeBtn.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const GROUP := "Panel/Content/Preview/Bottom/Group"
const HEART_INF := "Resources_moved_UI_Maincenter:UI_Maincenter_16"
## Price pills under the reward box (FreeBtn's row), Unity units.
const PILL := Vector2(190, 100)
## Timer chip offset from the Platform centre.
const TIME_Y := -120.0


func _sample() -> Dictionary:
	return SampleData.HEART_BUNDLE


func _build() -> void:
	ui = UnityUI.build(self, "PopupBundleHeart")
	for p in ["Panel/Image/txtHeader BG2", "Panel/Image/txtHeader BG1", "Panel/Image/txtHeader"]:
		ui.text(p, tr("hearts_bundle_title"))
	ui.on_click("Panel/btnTurnOff", _send.bind("close"))
	ui.on_click("Bg", _send.bind("close"))
	# The timer chip (inactive in this prefab) sits at the Platform centre, under the big title ribbon of this
	# card: it moves down below the ribbon.
	var time: Control = ui.node("Panel/Content/Preview/Platform/Time")
	time.visible = true
	var tr_: Dictionary = time.get_meta("u_rect")
	tr_.pos = Vector2(0, TIME_Y)
	UnityUI.apply_rect(time)
	ui.text("Panel/Content/Preview/Platform/Time/Text (TMP)", tr("offer_time_left") % str(view.get("ends_in", "")))
	ui.show("Panel/Content/Preview/Platform/NumberPurchar", false)
	ui.show("Panel/SellBadge", false)
	ui.show("Panel/Content/GameObject/FreeBtn", false)
	# Body under the timer, in the reward text style (Baloo Outline - DarkBlue).
	var s := UnityKit.spec("PopupBundleHeart", GROUP + "/Image/Text (TMP)")
	s.n = "Body"
	s.txt.fs = 48.0
	s.txt.auto = [18.0, 48.0]
	s.txt.w = true
	s.txt.s = tr("hearts_bundle_body")
	s.r = [0.5, 1, 0.5, 1, 0, -112.0 + TIME_Y - 34.0 - 45.0, 600, 70, 0.5, 0.5]
	UnityKit.add(ui.node("Panel/Content/Preview/Platform"), s)

	for x in ["Image", "Image (1)", "Image (2)", "Image (4)"]:
		ui.show(GROUP + "/" + x, false)
	var tpl := GROUP + "/Image (3)"
	ui.show(tpl, false)
	var rows: Array = view.get("rows", [])
	# Slot span of the prefab (Image .. Image (2) centres, -210 .. 217).
	var lo := -210.0
	var hi := 217.0
	var go: Control = ui.node("Panel/Content/GameObject")
	var go_w := UnityUI.rect_size(go).x
	for i in rows.size():
		var r: Dictionary = rows[i]
		var hours := int(r.get("hours", 1))
		var x := lerpf(lo, hi, 0.5 if rows.size() == 1 else float(i) / float(rows.size() - 1))
		var slot: RefCounted = ui.clone(tpl)
		slot.root.name = "Hours%d" % hours
		var sr: Dictionary = slot.root.get_meta("u_rect")
		sr.pos = Vector2(x, (sr.pos as Vector2).y)
		UnityUI.apply_rect(slot.root)
		slot.sprite("ImgVoHanTim", HEART_INF)
		slot.text("Text (TMP)", tr("hearts_hour_one") if hours == 1 else tr("hearts_hours") % hours)
		var b := UnityKit.button(go, "green", str(r.get("price", "")),
			Rect2(go_w * 0.5 + x - PILL.x * 0.5, 0, PILL.x, PILL.y), _send.bind("buy_%d" % hours))
		b.root.name = "Buy%d" % hours
