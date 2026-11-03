extends "res://src/ui/stub_ui.gd"
## Wireframe 9.2 Win Streak Main: đường mốc chuỗi thắng. Chưa nối logic.
## Layout of PopupWinStreakMain (color-cube-match-puzzle): the brick tower with one balcony per milestone
## (UI_EWStreakProgress.InitMilestoneData, 200 units per streak), the cat at the current streak and its bubble.
## The game's Play button is a copy of PopupWinStreakInstruction's Start button, as far below the frame.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const LAYER := "PopupWinStreakMain"
const CONTENT := "Panel/Image#3/Scroll View/Viewport/Content"
const PROGRESS := CONTENT + "/Progress"
const MILESTONE := PROGRESS + "/MilestoneContainer/Milestone"
const CAT := PROGRESS + "/FlyCat"
## UI_EWStreakProgress.milestoneSpacingY and WinStreakCatFly.balconyHeight.
const SPACING := 200.0
const BALCONY_H := 10.0
## ImageStateKeeper of Milestone/Level: not reached, the milestone reached last, passed.
const DIAMOND := "UI_Winstreak_Atlas:UI_Winstreak_Atlas_14"
const DIAMOND_OFFSET := [160.0, 0.0, 80.0]
## PopupWinStreakInstruction: Start button centre 137.5 below the popup7 frame (y -500); popup8 ends at y -622.8.
const PLAY_Y := -622.8 - 137.5

var _scroll: Node = null


func _sample() -> Dictionary:
	return SampleData.STREAK_MAIN


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/Header/txtHeader", tr("streak_title"))
	for b in ui.field("closeButtons", "UIPopupWinStreakMain"):
		(b as Button).connect("clicked", _send.bind("close"))
	ui.on_click("Panel/Button", _send.bind("info"))
	_build_time()
	_build_tower()
	_build_play()


## RefreshTimeDisplayState: countdown on an active day, txtEnd otherwise. The pill keeps its prefab size, so it
## holds the time only (the clock says "ends in").
func _build_time() -> void:
	ui.show("Panel/Time/txtEnd", false)
	ui.text("Panel/Time/Text (TMP)", str(view.get("ends_in", "")))


func _build_tower() -> void:
	var streak := int(view.get("streak", 0))
	var marks: Array[int] = []
	for m in view.get("milestones", []):
		if int(m) > 0:
			marks.append(int(m))
	marks.sort()
	var top: int = marks.back() if not marks.is_empty() else 0
	# Workaround (builder): a Mask inside a Mask (Image#3 and its Viewport) draws nothing under the inner one, so
	# the sky viewport clips as a RectMask2D; the rounded frame keeps its Mask.
	var viewport: Control = ui.node("Panel/Image#3/Scroll View/Viewport")
	viewport.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	viewport.clip_contents = true
	# CalculateContentSize: one step per streak plus two.
	var content: Control = ui.node(CONTENT)
	UnityKit.set_size(content, Vector2(0, SPACING * (float(top) + 2.0)))
	UnityUI.relayout(content)
	# EWStreakRewardInfo (the chest tooltip) shows only after a chest tap.
	ui.show(CONTENT + "/RewardInfo", false)
	# ImageSlider: fill = streak / last milestone.
	ui.image(PROGRESS + "/Image").call("set_fill", clampf(float(streak) / float(maxi(1, top)), 0.0, 1.0))
	# The template stays at streak 0 as the starting balcony; InitMilestoneData clones it per milestone.
	var reached := 0
	for m in marks:
		if m <= streak:
			reached = m
	for m in marks:
		var item: RefCounted = ui.clone(MILESTONE)
		item.root.name = "Milestone%d" % m
		var r: Dictionary = item.root.get_meta("u_rect")
		r.pos = Vector2((r.pos as Vector2).x, SPACING * m)
		UnityUI.apply_rect(item.root)
		item.show(" Info", true)
		item.show(" Info/ClaimBtn", false)
		item.text("Level/Text (TMP)", str(m))
		_diamond(item.image("Level"), 0 if m > streak else (1 if m == reached else 2))
		item.show(" Info/ChestIcon/Image#3", m <= streak)
		item.on_click(" Info/ChestIcon", _send.bind("rewards"))
	ui.text(MILESTONE + "/Level/Text (TMP)", "0")
	# Milestones are added after build: let drags that start on their buttons reach the ScrollRect.
	for b in content.find_children("*", "Button", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	_place_cat(streak, marks)
	_scroll = ui.node("Panel/Image#3/Scroll View").get_node_or_null("ScrollRect")
	_scroll_to_cat.call_deferred()


## Workaround (export): the ImageStateKeeper sprites UI_Winstreak_Atlas_16 / _15 are not in _sprites.json; they sit
## next to _14 in the same atlas, 80 px apart.
func _diamond(img: Control, state: int) -> void:
	var si := UnityUI.sprite_info(DIAMOND)
	if si.is_empty() or img == null:
		return
	var r: Rect2 = si.region
	r.position.x += float(DIAMOND_OFFSET[state]) * r.size.x / 76.0
	img.call("set_texture", si.tex, r, Vector4.ZERO, float(si.scale))


## WinStreakCatFly.SetPosition: on a balcony the cat sits (Idle clip), between balconies it flies (Cat2 sprite).
func _place_cat(streak: int, marks: Array[int]) -> void:
	var cat: Control = ui.node(CAT)
	var on_balcony := streak == 0 or marks.has(streak)
	var r: Dictionary = cat.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x, SPACING * streak + (BALCONY_H if on_balcony else 0.0))
	UnityUI.apply_rect(cat)
	if not on_balcony:
		# Only the default Animator state (Idle) is exported; Flying keeps the prefab's Cat2 sprite.
		var anim := cat.get_node_or_null("Animator")
		if anim != null:
			anim.queue_free()
	# SetIdleStateVisible(true): the bubble over the cat, here with the game's current streak.
	ui.show(CAT + "/ProgressTxt", true)
	ui.text(CAT + "/ProgressTxt/txt", "%s\n%d" % [tr("streak_current"), streak])


## UI_EWStreakProgress.ScrollToStreak: the cat in the middle of the viewport.
func _scroll_to_cat() -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	var cat: Control = ui.node(CAT)
	var content: Control = ui.node(CONTENT)
	var viewport: Control = ui.node("Panel/Image#3/Scroll View/Viewport")
	var cat_y := float((cat.get_meta("u_rect") as Dictionary).pos.y)
	var span := content.size.y - viewport.size.y
	if span <= 0.0:
		return
	_scroll.call("set_vertical_normalized", clampf((cat_y - viewport.size.y * 0.5) / span, 0.0, 1.0))


func _build_play() -> void:
	var s := UnityKit.spec("PopupWinStreakInstruction", "Panel/Content/GameObject/FreeBtn")
	s.n = "PlayButton"
	s.r = [0.5, 0.5, 0.5, 0.5, 0.0, PLAY_Y, s.r[6], s.r[7], 0.5, 0.5]
	var v := UnityKit.add(ui.node("Panel"), s)
	v.text("Out", tr("home_play"))
	v.on_click("", _send.bind("play"))
