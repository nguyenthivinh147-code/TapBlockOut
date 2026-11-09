extends "res://src/ui/stub_ui.gd"
## Wireframe 9.2 Win Streak Main (design.md mục 7 "Win Streak"): tháp mốc chuỗi thắng, nhận thưởng từng mốc.
## Layout of PopupWinStreakMain (color-cube-match-puzzle): the brick tower with one balcony per milestone
## (UI_EWStreakProgress.InitMilestoneData, 200 units per streak), the cat at the current streak and its bubble.
## EWStreakMilestoneItem: a reached milestone not yet claimed shows its Claim button (Game.streak_claim, then the
## reward popup); a claimed one shows the check and a grey chest. A chest tap shows EWStreakRewardInfo (the
## milestone's rewards) above it until the next tap. The "i" button opens the rules (popup_streak_rewards). The time
## pill counts down to the end of the event on an Active day, else shows txtEnd. The game's Play button is a copy of
## PopupWinStreakInstruction's Start button, as far below the frame: closed({"action": "play"}).
## setup({view}): Game.streak_view() by default.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const HubTop := preload("res://src/ui/hub_top.gd")

const LAYER := "PopupWinStreakMain"
const POPUP_RULES := "res://scenes/popup_streak_rewards.tscn"
const POPUP_REWARD := "res://scenes/popup_reward.tscn"
const CONTENT := "Panel/Image#3/Scroll View/Viewport/Content"
const PROGRESS := CONTENT + "/Progress"
const MILESTONE := PROGRESS + "/MilestoneContainer/Milestone"
const CAT := PROGRESS + "/FlyCat"
const INFO := CONTENT + "/RewardInfo"
const INFO_ITEM := INFO + "/GameObject/RewardItem"
## UI_EWStreakProgress.milestoneSpacingY and WinStreakCatFly.balconyHeight.
const SPACING := 200.0
const BALCONY_H := 10.0
## ImageStateKeeper of Milestone/Level: not reached, the milestone reached last, passed.
const DIAMOND := "UI_Winstreak_Atlas:UI_Winstreak_Atlas_14"
const DIAMOND_OFFSET := [160.0, 0.0, 80.0]
## SkeletonGraphicDefaultGrayscale on a claimed milestone's chest.
const CLAIMED_TINT := Color(0.55, 0.55, 0.55, 1.0)
## EWStreakMilestoneItem.GetPositionInfoReward: the tooltip's pivot (top, 0.27 across) this far from the chest
## centre (left, up), Unity units: the 200-unit tooltip ends just above the 120-unit chest.
const INFO_OFFSET := Vector2(-60.0, 260.0)

## Milestone streak -> {view, claim: Button, check: Control, chest: Control}.
var items: Dictionary = {}
var _scroll: Node = null
var _time_label: Label = null
var _ends_at_ms: int = -1
var _info_shown: bool = false
var _busy: bool = false


func _sample() -> Dictionary:
	return Game.streak_view()


func _build() -> void:
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/Header/txtHeader", tr("streak_title"))
	for b in ui.field("closeButtons", "UIPopupWinStreakMain"):
		(b as Button).connect("clicked", _send.bind("close"))
	ui.on_click("Panel/Button", _on_info)
	_build_time()
	_build_tower()
	# PlayButton (scene node): PopupWinStreakInstruction's Start button, as far below the frame.
	UnityUI.set_text(%PlayButton.get_node("Out"), tr("home_play"))
	%PlayButton.connect("clicked", _send.bind("play"))
	(ui.node(INFO) as Control).visible = false
	if not UnityUI.baking:
		var t := Timer.new()
		t.name = "Tick"
		t.wait_time = 1.0
		t.autostart = true
		t.timeout.connect(_tick)
		add_child(t)


## RefreshTimeDisplayState: countdown on an Active day, txtEnd otherwise. The pill keeps its prefab size, so it
## holds the time only (the clock says "ends in").
func _build_time() -> void:
	var running := bool(view.get("running", false))
	_time_label = ui.label("Panel/Time/Text (TMP)")
	ui.show("Panel/Time/Text (TMP)", running)
	ui.show("Panel/Time/txtEnd", not running)
	ui.text("Panel/Time/txtEnd", tr("streak_ended"))
	_tick()


func _tick() -> void:
	if _time_label == null or not is_instance_valid(_time_label) or not bool(view.get("running", false)):
		return
	if _ends_at_ms < 0:
		_ends_at_ms = Time.get_ticks_msec() + int(view.get("ends_in", 0)) * 1000
	UnityUI.set_text(_time_label, HubTop.fmt_time(int((_ends_at_ms - Time.get_ticks_msec()) / 1000.0)))


func _build_tower() -> void:
	var streak := int(view.get("streak", 0))
	var rows: Array = view.get("milestones", [])
	var marks: Array[int] = []
	for r in rows:
		marks.append(int(r.streak))
	var top: int = marks.back() if not marks.is_empty() else 0
	# Workaround (builder): a Mask inside a Mask (Image#3 and its Viewport) draws nothing under the inner one, so
	# the sky viewport clips as a RectMask2D (clip_contents in the scene); the rounded frame keeps its Mask. The
	# scene cannot hold clip_children back at its default, so it is set here.
	ui.node("Panel/Image#3/Scroll View/Viewport").clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	# CalculateContentSize: one step per streak plus two.
	var content: Control = ui.node(CONTENT)
	UnityKit.set_size(content, Vector2(0, SPACING * (float(top) + 2.0)))
	UnityUI.relayout(content)
	# ImageSlider: fill = streak / last milestone.
	ui.image(PROGRESS + "/Image").call("set_fill", clampf(float(streak) / float(maxi(1, top)), 0.0, 1.0))
	# The template stays at streak 0 as the starting balcony (its "0" is in the scene); InitMilestoneData clones it
	# per milestone.
	var reached := 0
	for m in marks:
		if m <= streak:
			reached = m
	for r: Dictionary in rows:
		var m := int(r.streak)
		var item: RefCounted = ui.clone(MILESTONE)
		item.root.name = "Milestone%d" % m
		var rr: Dictionary = item.root.get_meta("u_rect")
		rr.pos = Vector2((rr.pos as Vector2).x, SPACING * m)
		UnityUI.apply_rect(item.root)
		item.show(" Info", true)
		item.text("Level/Text (TMP)", str(m))
		_diamond(item.image("Level"), 0 if m > streak else (1 if m == reached else 2))
		var claim: Button = item.on_click(" Info/ClaimBtn", _on_claim.bind(m))
		claim.name = "ClaimButton"
		item.text(" Info/ClaimBtn/Text (TMP)", tr("daily_claim"))
		var chest: Button = item.on_click(" Info/ChestIcon", _on_chest.bind(m))
		items[m] = {"view": item, "claim": claim, "check": item.node(" Info/ChestIcon/Image#3"),
			"chest": item.node(" Info/ChestIcon/Image#2"), "chest_btn": chest}
		_set_claim_state(m, bool(r.reached), bool(r.claimed))
	# Milestones are added after build: let drags that start on their buttons reach the ScrollRect.
	for b in content.find_children("*", "Button", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	_place_cat(streak, marks)
	_scroll = ui.node("Panel/Image#3/Scroll View").get_node_or_null("ScrollRect")
	_scroll_to_cat.call_deferred()


## EWStreakMilestoneItem.UpdateData: Claim while reached and not claimed; the check and a grey chest once claimed.
func _set_claim_state(m: int, reached: bool, is_claimed: bool) -> void:
	var it: Dictionary = items.get(m, {})
	if it.is_empty():
		return
	(it.claim as Control).visible = reached and not is_claimed
	if it.check != null:
		(it.check as Control).visible = is_claimed
	if it.chest != null:
		(it.chest as Control).modulate = CLAIMED_TINT if is_claimed else Color.WHITE


func _on_claim(m: int) -> void:
	if _busy:
		return
	_busy = true
	_hide_info()
	var reward: Dictionary = Game.streak_claim(m)
	if reward.is_empty():
		_busy = false
		return
	_set_claim_state(m, true, true)
	_mark_view_claimed(m)
	var p := open_over(POPUP_REWARD, {"view": {"reward": reward}})
	if p != null and p.has_signal("closed"):
		p.connect("closed", func(_r: Variant) -> void: _busy = false, CONNECT_ONE_SHOT)
	else:
		_busy = false


func _mark_view_claimed(m: int) -> void:
	for r in view.get("milestones", []):
		if int(r.streak) == m:
			r["claimed"] = true
	view["claimable"] = maxi(0, int(view.get("claimable", 0)) - 1)


func _on_info() -> void:
	_hide_info()
	open_over(POPUP_RULES)


## EWStreakRewardInfo.SetupData: one PopupRewardItem per reward of the milestone, the tooltip above its chest.
func _on_chest(m: int) -> void:
	var info: Control = ui.node(INFO)
	var reward: Dictionary = {}
	for r in view.get("milestones", []):
		if int(r.streak) == m:
			reward = r.reward
	for c in (ui.node(INFO + "/GameObject") as Control).get_children():
		if c.has_meta("u_clone"):
			c.queue_free()
	for e: Dictionary in LbKit.reward_entries(reward):
		var v: RefCounted = ui.clone(INFO_ITEM)
		LbKit.set_entry_icon(v.root, e)
		v.text("Text (TMP)", str(e.amount))
	ui.relayout(INFO + "/GameObject")
	# Same coordinate space: the tooltip and the milestone both sit in Content (the milestone through Progress).
	var chest: Control = (items[m] as Dictionary).chest_btn
	var content: Control = ui.node(CONTENT)
	var at := content.get_global_transform().affine_inverse() * (chest.get_global_rect().get_center())
	var r: Dictionary = info.get_meta("u_rect")
	var csize := UnityUI.rect_size(content)
	# Content is bottom-up in Unity units: x from the centre, y up from the bottom.
	r.amin = Vector2(0.5, 0.0)
	r.amax = Vector2(0.5, 0.0)
	r.pos = Vector2(at.x - csize.x * 0.5 + INFO_OFFSET.x, csize.y - at.y + INFO_OFFSET.y)
	UnityUI.apply_rect(info)
	info.visible = true
	info.modulate.a = 1.0
	_info_shown = true
	Sfx.play("button")


func _hide_info() -> void:
	if not _info_shown:
		return
	_info_shown = false
	var info: Control = ui.node(INFO)
	if info != null:
		info.visible = false


## EWStreakRewardInfo.Update: the next tap anywhere hides the tooltip.
func _input(event: InputEvent) -> void:
	if not _info_shown:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_hide_info.call_deferred()


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
	# SetIdleStateVisible(true): the bubble over the cat, here with the game's current streak. Shown here: the scene
	# cannot hold it back at its default (visible) over the prefab's hidden state.
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
