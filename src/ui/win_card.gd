extends Control
## Thẻ thắng: +gold, x2 (L1 miễn phí), Tiếp tục.
## setup(args): kết quả Game.on_level_won ({coins, x2_available, x2_free, rate_prompt, progress, lb}).
## x2: popup tự gọi Game.claim_x2 (xem video, hoặc miễn phí ở L1).
## closed(result): {x2_offered, x2_taken, rate_prompt, coins}. Bên gọi (level) gọi
## Game.leave_win_card(result.x2_offered, result.x2_taken) rồi mới sang level kế.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const X2_PLACEMENT := "x2_coins"

var _args: Dictionary = {}
var _busy: bool = false
var _x2_taken: bool = false
var _panel: Control = null
var _reward: Label = null
var _msg: Label = null
var _x2_btn: Button = null
var _bar: ProgressBar = null
var _pct: Label = null
var _prog_after: float = 0.0
var _prog_unlocked: bool = false
var _feature_names: String = ""
var _lb_points: Label = null
var _lb_rank: Label = null


func setup(args: Dictionary) -> void:
	_args = args
	_busy = false
	_x2_taken = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()


func _label(text: String, size: int, color: Color, node_name: String) -> Label:
	return PopupKit.text(text, size, color, node_name)


func _coins() -> int:
	return int(_args.get("coins", 0))


func _build() -> void:
	var k := PopupKit.make(self, tr("win_title"), Callable(), {"banner": "win"})
	_panel = k.card
	var box: VBoxContainer = k.box

	box.add_child(_label(tr("win_subtitle"), ThemeKit.FS_BODY, ThemeKit.INK_DIM, "SubtitleLabel"))
	_build_progress(box)

	var well := ThemeKit.make_well()
	box.add_child(well)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	well.add_child(row)
	var coin := ThemeKit.make_icon("coin", 96)
	coin.name = "CoinIcon"
	row.add_child(coin)
	_reward = ThemeKit.gold_label(tr("win_reward") % _coins(), ThemeKit.FS_TITLE + 12)
	_reward.name = "RewardLabel"
	row.add_child(_reward)
	_build_lb(box)

	_msg = _label("", ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "MessageLabel")
	_msg.visible = false
	box.add_child(_msg)

	var cont := ThemeKit.make_button(tr("win_continue"), "primary")
	cont.name = "ContinueButton"
	cont.pressed.connect(_on_continue_pressed)
	box.add_child(cont)

	if bool(_args.get("x2_available", false)):
		var free := bool(_args.get("x2_free", false))
		_x2_btn = ThemeKit.make_button(tr("win_x2_free") if free else tr("win_x2"), "gold" if free else "video")
		_x2_btn.name = "X2Button"
		if not free:
			ThemeKit.set_button_icon(_x2_btn, "ui_video")
		_x2_btn.pressed.connect(_on_x2_pressed)
		box.add_child(_x2_btn)
		if free:
			box.add_child(_label(tr("tut_x2"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "X2HintLabel"))
		else:
			Game.offer_video(X2_PLACEMENT)

	Sfx.play("sfx_win")
	_animate_in.call_deferred()


## Thanh tiến trình tới tính năng kế tiếp (Unlocks.feature_progress). Ẩn khi hết tính năng để mở.
func _build_progress(box: VBoxContainer) -> void:
	var p: Dictionary = _args.get("progress", {})
	if not bool(p.get("has_next", false)):
		return
	_prog_after = float(p.after)
	_prog_unlocked = _prog_after >= 1.0
	var names: PackedStringArray = []
	for f in p.features:
		names.append(tr("feature_" + str(f)))
	_feature_names = ", ".join(names)
	box.add_child(_label(tr("feature_next") % _feature_names, ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "FeatureLabel"))
	var row := HBoxContainer.new()
	row.name = "FeatureProgress"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_bar = ProgressBar.new()
	_bar.name = "FeatureBar"
	_bar.custom_minimum_size = Vector2(400, 28)
	ThemeKit.style_bar(_bar)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.value = float(p.before)
	row.add_child(_bar)
	_pct = ThemeKit.ink_label("%d%%" % roundi(float(p.before) * 100.0), ThemeKit.FS_SMALL)
	_pct.name = "FeaturePercent"
	_pct.custom_minimum_size.x = 80
	row.add_child(_pct)
	box.add_child(row)


## Leaderboard (args.lb = Game.on_level_won().lb): +điểm đếm dần, hạng cũ đếm tới hạng mới; vừa lên league thì
## hiện tên league mới. Ẩn khi level không có mảnh.
func _build_lb(box: VBoxContainer) -> void:
	var lb: Dictionary = _args.get("lb", {})
	if lb.is_empty():
		return
	var well := ThemeKit.make_well()
	well.name = "LbRow"
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	h.add_child(ThemeKit.make_icon("lb_piece", 56))
	_lb_points = ThemeKit.ink_label(tr("lb_win_points") % 0, ThemeKit.FS_SMALL + 4, ThemeKit.BROWN)
	_lb_points.name = "LbPointsLabel"
	h.add_child(_lb_points)
	_lb_rank = ThemeKit.ink_label("", ThemeKit.FS_SMALL + 4, ThemeKit.INK_GOOD)
	_lb_rank.name = "LbRankLabel"
	h.add_child(_lb_rank)
	if not (lb.get("promoted", []) as Array).is_empty():
		_lb_rank.text = tr("lb_league") % LbKit.league_name(str(lb.get("league_id", "")))
	else:
		_lb_rank.text = tr("lb_win_rank") % int(lb.get("rank_before", 0))
	box.add_child(well)


func _animate_lb() -> void:
	var lb: Dictionary = _args.get("lb", {})
	if lb.is_empty() or _lb_points == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_lb_points, 0.0, float(lb.get("added", 0)), 0.6)
	if (lb.get("promoted", []) as Array).is_empty():
		tw.tween_method(_set_lb_rank, float(lb.get("rank_before", 0)), float(lb.get("rank_after", 0)), 0.9).set_trans(Tween.TRANS_SINE)
	else:
		_lb_rank.pivot_offset = _lb_rank.size * 0.5
		_lb_rank.scale = Vector2(0.3, 0.3)
		tw.tween_property(_lb_rank, "scale", Vector2.ONE, 0.4).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_lb_points(v: float) -> void:
	if is_instance_valid(_lb_points):
		_lb_points.text = tr("lb_win_points") % roundi(v)


func _set_lb_rank(v: float) -> void:
	if is_instance_valid(_lb_rank):
		_lb_rank.text = tr("lb_win_rank") % roundi(v)


func _animate_progress() -> void:
	if _bar == null:
		return
	var tw := create_tween()
	tw.tween_method(_set_progress, _bar.value, _prog_after, 0.8).set_trans(Tween.TRANS_SINE)
	if _prog_unlocked:
		tw.tween_callback(_show_unlocked)


func _set_progress(v: float) -> void:
	if _bar == null or not is_instance_valid(_bar):
		return
	_bar.value = v
	_pct.text = "%d%%" % roundi(v * 100.0)


## Đạt 100%: thay dòng "Mở khoá tiếp" bằng thông báo đã mở.
func _show_unlocked() -> void:
	var l := find_child("FeatureLabel", true, false) as Label
	if l == null:
		return
	l.text = tr("feature_unlocked") % _feature_names
	l.add_theme_color_override("font_color", ThemeKit.BROWN)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ZERO
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("sfx_coin")


func _animate_in() -> void:
	if _panel != null and is_instance_valid(_panel):
		ThemeKit.popup_in(_panel)
	_animate_progress()
	_animate_lb()


func _set_busy(v: bool) -> void:
	_busy = v
	for b in find_children("*", "Button", true, false):
		(b as Button).disabled = v
	if not v and _x2_taken and _x2_btn != null:
		_x2_btn.disabled = true


func _on_x2_pressed() -> void:
	if _busy or _x2_taken:
		return
	Sfx.play("sfx_button")
	_set_busy(true)
	var ok: bool = await Game.claim_x2()
	if not is_inside_tree():
		return
	if ok:
		_x2_taken = true
		_reward.text = tr("win_reward") % (_coins() * 2)
		_reward.pivot_offset = _reward.size * 0.5
		var pulse := create_tween()
		pulse.tween_property(_reward, "scale", Vector2(1.25, 1.25), 0.12)
		pulse.tween_property(_reward, "scale", Vector2.ONE, 0.18)
		_x2_btn.text = tr("win_x2_done")
		_msg.visible = false
		Sfx.play("sfx_coin")
	else:
		match Game.last_ad_reason:
			"not_ready":
				_msg.text = tr("ads_not_available")
			"closed":
				_msg.text = tr("ads_closed_early")
			_:
				_msg.text = tr("ads_failed")
		_msg.visible = true
	_set_busy(false)


func _on_continue_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	closed.emit({
		"x2_offered": bool(_args.get("x2_available", false)),
		"x2_taken": _x2_taken,
		"rate_prompt": bool(_args.get("rate_prompt", false)),
		"coins": _coins() * (2 if _x2_taken else 1),
	})
