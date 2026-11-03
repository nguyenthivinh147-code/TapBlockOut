extends Control
## Thẻ thắng: +gold, x2 (L1 miễn phí), Tiếp tục. Bố cục WinPanel của EndGameUILayer (color-cube-match-puzzle):
## cúp và kèn, ribbon tiêu đề, thẻ người chơi trên bảng xếp hạng, thanh tính năng kế tiếp, dải phần thưởng, hàng nút.
## setup(args): kết quả Game.on_level_won ({coins, x2_available, x2_free, rate_prompt, progress, lb}).
## x2: popup tự gọi Game.claim_x2 (xem video, hoặc miễn phí ở L1). Nút x2 là FreeBtn (miễn phí) hoặc ClaimBtn (video).
## closed(result): {x2_offered, x2_taken, rate_prompt, coins}. Bên gọi (level) gọi
## Game.leave_win_card(result.x2_offered, result.x2_taken) rồi mới sang level kế.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const Config := preload("res://src/config.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UButton := preload("res://src/ui/u_button.gd")
const UAnim := preload("res://src/ui/u_anim.gd")
const X2_PLACEMENT := "x2_coins"

const WIN := "Panel/WinPanel"
const TOP := "Panel/WinPanel/WinPanel"
const CARD := "Panel/WinPanel/WinPanel/PlayerLeaderboardItem"
const FEATURE := "Panel/WinPanel/WinPanel/NewFeatureUnlock"
const REWARDS := "Panel/WinPanel/BG/RewardGroup/Rewards"
const ROW := "Panel/WinPanel/BG/GameObject"
## RewardItemSO icons: gold (RewardType.Gold, ItemId 0) and rank point (RewardType.RankPoint).
const GOLD_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_3"
const RANK_POINT_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_2"
## UILeaderboardUserCard image states of the player's own card: medal for rank 1..3, none from rank 4.
## (Its own-card background UI_Leaderboard_Atlas_29 is not in _sprites.json, so the prefab background stays.)
const MEDALS := ["UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_14", "UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_15",
	"UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_24"]
## Feature (Unlocks) -> game icon shown in the next-feature frame; hidden when the icon has no file.
const FEATURE_ICONS := {"daily_gift": "ui_gift", "hint": "booster_hint", "shop": "ui_shop", "move": "booster_move",
	"smash": "booster_smash", "lives": "ui_heart", "leaderboard": "ui_leaderboard"}

var ui: RefCounted = null
var _args: Dictionary = {}
var _busy: bool = false
var _x2_taken: bool = false
var _reward: Label = null
var _msg: Label = null
var _x2_btn: Button = null
var _x2_path: String = ""
var _x2_label: Label = null
var _bar: Control = null
var _pct: Label = null
var _prog_before: float = 0.0
var _prog_after: float = 0.0
var _prog_unlocked: bool = false
var _feature_names: String = ""
var _lb_points: Label = null
var _lb_rank: Label = null
var _lb_total: Label = null
var _lb_name: Label = null


func setup(args: Dictionary) -> void:
	_args = args
	_busy = false
	_x2_taken = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()


func _coins() -> int:
	return int(_args.get("coins", 0))


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "EndGameUILayer")
	ui.show("Panel/LossPanel", false)
	_enable_group(ui.node(WIN))
	ui.text(TOP + "/Panel/Image/Text (TMP)", tr("win_title"))
	ui.text("Panel/WinPanel/BG/RewardGroup/RewardsText", tr("win_subtitle")).name = "SubtitleLabel"
	_build_rewards()
	_build_lb()
	_build_progress()
	ui.relayout(TOP)
	_build_buttons()
	Sfx.play("sfx_win")
	_animate_in.call_deferred()


# --- rewards (VictoryPanel.InitRewards: one Reward.prefab per item) ---

func _build_rewards() -> void:
	var gold := _reward_item(GOLD_ICON, tr("win_reward") % _coins())
	gold.node("RewardIcon").name = "CoinIcon"
	_reward = gold.label("RewardText")
	_reward.name = "RewardLabel"
	var lb: Dictionary = _args.get("lb", {})
	if not lb.is_empty():
		# VictoryPanel adds a RankPoint reward when the leaderboard is open.
		var rp := _reward_item(RANK_POINT_ICON, tr("lb_win_points") % 0)
		rp.node("RewardIcon").name = "LbPointIcon"
		_lb_points = rp.label("RewardText")
		_lb_points.name = "LbPointsLabel"
	ui.relayout(REWARDS)


func _reward_item(icon: String, text: String) -> RefCounted:
	var v: RefCounted = UnityKit.add(ui.node(REWARDS), UnityKit.spec("Reward", ""))
	v.root.visible = true
	v.sprite("RewardIcon", icon)
	v.text("RewardText", text)
	return v


# --- leaderboard card (UILeaderboardUserCard of the player) ---

## args.lb = Game.on_level_won().lb: points count up, old rank counts to the new one; a promotion shows the new
## league in the name slot. Hidden when the level had no pieces.
func _build_lb() -> void:
	var lb: Dictionary = _args.get("lb", {})
	if lb.is_empty():
		ui.show(CARD, false)
		return
	ui.node(CARD).name = "LbRow"
	ui.show(CARD + "/Gift", false)
	var cos: Dictionary = Game.s.get("cos", {}) if Game.s.get("cos") is Dictionary else {}
	var avatar := str(cos.get("avatar", Config.COSMETICS.default_avatar))
	var frame := str(cos.get("frame", Config.COSMETICS.default_frame))
	if ThemeKit.has_real_icon(avatar):
		ui.texture(CARD + "/Avatar", ThemeKit.icon(avatar))
	if ThemeKit.has_real_icon(frame):
		ui.texture(CARD + "/Avatar/Frame", ThemeKit.icon(frame))
	_lb_rank = ui.label(CARD + "/RankNumberTxt")
	_lb_rank.name = "LbRankLabel"
	_set_lb_rank(float(lb.get("rank_before", 0)))
	_lb_name = ui.text(CARD + "/PlayerName", LbKit.display_name({"me": true}))
	_lb_name.name = "LbNameLabel"
	_lb_total = ui.label(CARD + "/PointPanel/PointText")
	_lb_total.name = "LbTotalLabel"
	_set_lb_total(float(lb.get("before", 0)))


func _animate_lb() -> void:
	var lb: Dictionary = _args.get("lb", {})
	if lb.is_empty() or _lb_points == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_lb_points, 0.0, float(lb.get("added", 0)), 0.6)
	tw.tween_method(_set_lb_total, float(lb.get("before", 0)), float(lb.get("after", 0)), 0.6)
	tw.tween_method(_set_lb_rank, float(lb.get("rank_before", 0)), float(lb.get("rank_after", 0)), 0.9).set_trans(Tween.TRANS_SINE)
	if not (lb.get("promoted", []) as Array).is_empty():
		_lb_name.scale = Vector2(0.3, 0.3)
		ui.text(CARD + "/PlayerName", tr("lb_league") % LbKit.league_name(str(lb.get("league_id", ""))))
		tw.tween_property(_lb_name, "scale", Vector2.ONE, 0.4).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_lb_points(v: float) -> void:
	if is_instance_valid(_lb_points):
		UnityUI.set_text(_lb_points, tr("lb_win_points") % roundi(v))


func _set_lb_total(v: float) -> void:
	if is_instance_valid(_lb_total):
		UnityUI.set_text(_lb_total, LbKit.fmt_int(roundi(v)))


## Rank number on the medal; the medal sprite follows the rank like the card's ImageStateKeeper.
func _set_lb_rank(v: float) -> void:
	if not is_instance_valid(_lb_rank):
		return
	var r := roundi(v)
	_lb_rank.text = str(r)
	var medal := CARD + "/RankNumberTxt/Image"
	ui.show(medal, r >= 1 and r <= MEDALS.size())
	if r >= 1 and r <= MEDALS.size():
		ui.sprite(medal, MEDALS[r - 1])


# --- next feature (VictoryPanel mechanic progress) ---

## Thanh tiến trình tới tính năng kế tiếp (Unlocks.feature_progress). Ẩn khi hết tính năng để mở.
func _build_progress() -> void:
	var p: Dictionary = _args.get("progress", {})
	if not bool(p.get("has_next", false)):
		ui.show(FEATURE, false)
		return
	ui.node(FEATURE).name = "FeatureProgress"
	_prog_before = float(p.before)
	_prog_after = float(p.after)
	_prog_unlocked = _prog_after >= 1.0
	var names: PackedStringArray = []
	for f in p.features:
		names.append(tr("feature_" + str(f)))
	_feature_names = ", ".join(names)
	ui.text(FEATURE + "/RewardsText", tr("feature_next") % _feature_names).name = "FeatureLabel"
	_bar = ui.node(FEATURE + "/Slider")
	_bar.name = "FeatureBar"
	_pct = ui.label(FEATURE + "/Slider/ProgressText")
	_pct.name = "FeaturePercent"
	_set_progress(0.0)
	var first := str(p.features[0]) if not (p.features as Array).is_empty() else ""
	var icon := str(FEATURE_ICONS.get(first, "mech_" + first))
	var feature_image := FEATURE + "/Slider/Image/FeatureImage"
	if icon != "" and ThemeKit.has_real_icon(icon):
		ui.texture(feature_image, ThemeKit.icon(icon))
		UnityUI.image_of(ui.node(feature_image)).preserve_aspect = true
	else:
		ui.show(feature_image, false)


## Smooth step from the value before this win to the value after, like AnimateProgressFill.
func _animate_progress() -> void:
	if _bar == null:
		return
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, float(ui.field("progressAnimDuration", "VictoryPanel")))
	if _prog_unlocked:
		tw.tween_callback(_show_unlocked)


func _set_progress(t: float) -> void:
	if _bar == null or not is_instance_valid(_bar):
		return
	var v := lerpf(_prog_before, _prog_after, t * t * (3.0 - 2.0 * t))
	UnityUI.set_slider(_bar, v)
	UnityUI.set_text(_pct, "%d%%" % roundi(v * 100.0))


## Đạt 100%: thay dòng "Mở khoá tiếp" bằng thông báo đã mở.
func _show_unlocked() -> void:
	var l := find_child("FeatureLabel", true, false) as Label
	if l == null:
		return
	UnityUI.set_text(l, tr("feature_unlocked") % _feature_names)
	l.scale = Vector2.ZERO
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("sfx_coin")


# --- buttons ---

func _build_buttons() -> void:
	var cont: Button = ui.button(ROW + "/ContinueBtn")
	cont.name = "ContinueButton"
	ui.text(ROW + "/ContinueBtn/Text (TMP)", tr("win_continue"))
	cont.connect("clicked", _on_continue_pressed)
	if bool(_args.get("x2_available", false)):
		var free := bool(_args.get("x2_free", false))
		# SetupButtonState: FreeBtn on the first claim, ClaimBtn (video) after; both show the doubled gold.
		var keep := "FreeBtn" if free else "ClaimBtn"
		ui.show(ROW + ("/ClaimBtn" if free else "/FreeBtn"), false)
		_x2_path = ROW + "/" + keep
		_x2_btn = ui.button(_x2_path)
		_x2_btn.name = "X2Button"
		_x2_label = ui.text(ROW + "/" + keep + "/Text (TMP)", tr("win_x2_free") if free else tr("win_x2"))
		if not free:
			# The game's label is longer than "Claim": keep it clear of the TV icon on the top-right corner.
			var r: Dictionary = _x2_label.get_meta("u_rect")
			r.pos = Vector2(-30, (r.pos as Vector2).y)
			r.size = Vector2(236, (r.size as Vector2).y)
			UnityUI.apply_rect(_x2_label)
		ui.label(ROW + "/" + keep + "/GameObject (1)/Text (TMP)").text = LbKit.fmt_int(_coins() * 2)
		ui.relayout(ROW + "/" + keep + "/GameObject (1)")
		_x2_btn.connect("clicked", _on_x2_pressed)
		if free:
			_line("X2HintLabel", tr("tut_x2"), 604.0)
		else:
			Game.offer_video(X2_PLACEMENT)
	else:
		ui.show(ROW + "/FreeBtn", false)
		ui.show(ROW + "/ClaimBtn", false)
	ui.relayout(ROW)
	_msg = _line("MessageLabel", "", 684.0)
	_msg.visible = false


## White outlined line under the button row (RewardsText style), centred, y = centre below the BG top.
func _line(node_name: String, text: String, y: float) -> Label:
	var s := UnityKit.spec("EndGameUILayer", "Panel/WinPanel/BG/RewardGroup/RewardsText")
	s.n = node_name
	s.r = [0.5, 1, 0.5, 1, 0, -y, 800, 80, 0.5, 0.5]
	s.txt.s = text
	s.txt.fs = 40.0
	s.txt.auto = [18.0, 40.0]
	s.txt.w = true
	s.txt.st = 0
	return UnityKit.add(ui.node("Panel/WinPanel/BG"), s).root as Label


# --- animation ---

func _animate_in() -> void:
	if ui == null or not is_inside_tree():
		return
	# VictoryPanel.PlayShowAnimation: canvas group alpha 0.3 -> 1 in 1 s, OutBack.
	var win: Control = ui.node(WIN)
	win.modulate.a = 0.3
	create_tween().tween_property(win, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for e in ui.scripts:
		if str(e.cs.get("name", "")) == "CurveDrivenImageScaler" and bool(int(e.cs.get("playOnStart", "1"))):
			_curve_scale(e.node, e.cs)
	_animate_progress()
	_animate_lb()


## CurveDrivenImageScaler (not in unity_ui.gd): scale x/y from AnimationCurves, loopCount cycles from startOffset.
func _curve_scale(c: Control, cs: Dictionary) -> void:
	var kx := _curve_keys(cs.get("scaleXCurve", {}))
	var ky := _curve_keys(cs.get("scaleYCurve", {}))
	if kx.is_empty() or ky.is_empty():
		return
	var dur := maxf(0.01, float(cs.get("duration", "1")))
	var loops := 1000 if bool(int(cs.get("infiniteLoop", "0"))) else maxi(1, int(cs.get("loopCount", "1")))
	var sign_x := signf(c.scale.x) if c.scale.x != 0.0 else 1.0
	var step := func(t: float) -> void:
		if is_instance_valid(c):
			var u := fposmod(t, dur) / dur
			c.scale = Vector2(UAnim.evaluate(kx, u) * sign_x, UAnim.evaluate(ky, u))
	c.create_tween().tween_method(step, float(cs.get("startOffset", "0")) * dur, loops * dur - 0.001, loops * dur - float(cs.get("startOffset", "0")) * dur)


## Unity AnimationCurve m_Curve -> u_anim keys [time, value, in_slope, out_slope] (infinite slope = stepped).
static func _curve_keys(curve: Variant) -> Array:
	var out: Array = []
	if not (curve is Dictionary):
		return out
	for k in (curve as Dictionary).get("m_Curve", []):
		var ins := float(k.get("inSlope", "0"))
		var outs := float(k.get("outSlope", "0"))
		out.append([float(k.get("time", "0")), float(k.get("value", "0")), ins if is_finite(ins) else null, outs if is_finite(outs) else null])
	return out


## VictoryPanel turns the WinPanel CanvasGroup on (interactable, blocksRaycasts) when it shows; unity_ui.gd bakes the
## prefab's off state into the subtree at build time, so give each node back the input it would have had.
static func _enable_group(c: Control) -> void:
	var spec: Dictionary = c.get_meta("u", {})
	if c is UButton:
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		(c as UButton).set_interactable(bool((spec.get("btn", spec.get("tog", {})) as Dictionary).get("inter", true)))
	elif c is Label:
		c.mouse_filter = Control.MOUSE_FILTER_PASS if bool((spec.get("txt", {}) as Dictionary).get("rt", false)) else Control.MOUSE_FILTER_IGNORE
	elif spec.has("img") or spec.has("raw"):
		c.mouse_filter = Control.MOUSE_FILTER_PASS if bool((spec.get("img", spec.get("raw", {})) as Dictionary).get("rt", false)) else Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control and ch.has_meta("u"):
			_enable_group(ch)


# --- actions ---

func _set_busy(v: bool) -> void:
	_busy = v
	for b in [ui.node(ROW + "/ContinueBtn"), _x2_btn]:
		if b != null:
			(b as UButton).set_interactable(not v)
	if not v and _x2_taken and _x2_btn != null:
		(_x2_btn as UButton).set_interactable(false)


func _on_x2_pressed() -> void:
	if _busy or _x2_taken:
		return
	_set_busy(true)
	var ok: bool = await Game.claim_x2()
	if not is_inside_tree():
		return
	if ok:
		_x2_taken = true
		UnityUI.set_text(_reward, tr("win_reward") % (_coins() * 2))
		var pulse := create_tween()
		pulse.tween_property(_reward, "scale", Vector2(1.25, 1.25), 0.12)
		pulse.tween_property(_reward, "scale", Vector2.ONE, 0.18)
		# AnimScaleButton.StopAnim (the loop OnDisplayLayout started).
		ui.stop(_x2_path)
		UnityUI.set_text(_x2_label, tr("win_x2_done"))
		_msg.visible = false
		Sfx.play("sfx_coin")
	else:
		match Game.last_ad_reason:
			"not_ready":
				UnityUI.set_text(_msg, tr("ads_not_available"))
			"closed":
				UnityUI.set_text(_msg, tr("ads_closed_early"))
			_:
				UnityUI.set_text(_msg, tr("ads_failed"))
		_msg.visible = true
	_set_busy(false)


func _on_continue_pressed() -> void:
	if _busy:
		return
	closed.emit({
		"x2_offered": bool(_args.get("x2_available", false)),
		"x2_taken": _x2_taken,
		"rate_prompt": bool(_args.get("rate_prompt", false)),
		"coins": _coins() * (2 if _x2_taken else 1),
	})
