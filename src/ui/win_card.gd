extends Control
## Thẻ thắng: +gold, x2 (L1 miễn phí), Tiếp tục.
## setup(args): kết quả Game.on_level_won ({coins, x2_available, x2_free, rate_prompt}).
## x2: popup tự gọi Game.claim_x2 (xem video, hoặc miễn phí ở L1).
## closed(result): {x2_offered, x2_taken, rate_prompt, coins}. Bên gọi (level) gọi
## Game.leave_win_card(result.x2_offered, result.x2_taken) rồi mới sang level kế.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const X2_PLACEMENT := "x2_coins"

var _args: Dictionary = {}
var _busy: bool = false
var _x2_taken: bool = false
var _panel: Control = null
var _reward: Label = null
var _msg: Label = null
var _x2_btn: Button = null


func setup(args: Dictionary) -> void:
	_args = args
	_busy = false
	_x2_taken = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()


func _label(text: String, size: int, color: Color, node_name: String) -> Label:
	var l := ThemeKit.make_label(text, size, color)
	l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	return l


func _coins() -> int:
	return int(_args.get("coins", 0))


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = ThemeKit.make_panel()
	_panel.name = "Panel"
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_panel.add_child(box)

	box.add_child(_label(tr("win_title"), ThemeKit.FS_TITLE, ThemeKit.TEXT, "TitleLabel"))
	box.add_child(_label(tr("win_subtitle"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM, "SubtitleLabel"))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var coin := TextureRect.new()
	coin.name = "CoinIcon"
	coin.texture = ThemeKit.icon("coin")
	coin.custom_minimum_size = Vector2(80, 80)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(coin)
	_reward = ThemeKit.make_label(tr("win_reward") % _coins(), ThemeKit.FS_HUGE, ThemeKit.GOLD)
	_reward.name = "RewardLabel"
	row.add_child(_reward)
	box.add_child(row)

	if bool(_args.get("x2_available", false)):
		var free := bool(_args.get("x2_free", false))
		_x2_btn = ThemeKit.make_button(tr("win_x2_free") if free else tr("win_x2"),
			"primary" if free else "video")
		_x2_btn.name = "X2Button"
		_x2_btn.pressed.connect(_on_x2_pressed)
		box.add_child(_x2_btn)
		if free:
			box.add_child(_label(tr("tut_x2"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "X2HintLabel"))
		else:
			Game.offer_video(X2_PLACEMENT)

	_msg = _label("", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "MessageLabel")
	_msg.visible = false
	box.add_child(_msg)

	var cont := ThemeKit.make_button(tr("win_continue"), "secondary" if _x2_btn != null else "primary")
	cont.name = "ContinueButton"
	cont.pressed.connect(_on_continue_pressed)
	box.add_child(cont)

	Sfx.play("sfx_win")
	_animate_in.call_deferred()


func _animate_in() -> void:
	if _panel != null and is_instance_valid(_panel):
		ThemeKit.popup_in(_panel)


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
