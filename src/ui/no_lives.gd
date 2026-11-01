extends Control
## Màn hết mạng: đếm ngược, nạp bằng gold, xem video (+1 mạng), về Home.
## setup(args): không cần khoá nào. Dữ liệu lấy từ Game.lives_view().
## closed(result): "refilled" (đã có mạng, quay lại chơi) | "home".
## Không có video thì hiện dòng báo, vẫn chờ được.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")
const VIDEO_PLACEMENT := "refill_life"

var _busy: bool = false
var _built: bool = false
var _title: Label
var _lives_lbl: Label
var _next_lbl: Label
var _full_lbl: Label
var _gold_btn: Button
var _video_btn: Button
var _no_ads_lbl: Label
var _msg: Label
var _timer: Timer


func setup(_args: Dictionary = {}) -> void:
	_busy = false
	if not _built:
		_build()
		_built = true
	Game.offer_video(VIDEO_PLACEMENT)
	refresh()


static func format_time(sec: int) -> String:
	sec = maxi(sec, 0)
	if sec >= 3600:
		return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]
	return "%d:%02d" % [sec / 60, sec % 60]


func _label(text: String, size: int, color: Color, node_name: String) -> Label:
	var l := ThemeKit.make_label(text, size, color)
	l.name = node_name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	return l


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ThemeKit.make_background())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	_title = _label(tr("no_lives_title"), ThemeKit.FS_TITLE, ThemeKit.TEXT, "TitleLabel")
	box.add_child(_title)
	box.add_child(_label(tr("no_lives_body"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM, "BodyLabel"))
	_lives_lbl = _label("", ThemeKit.FS_BODY, ThemeKit.GOLD, "LivesLabel")
	box.add_child(_lives_lbl)
	_next_lbl = _label("", ThemeKit.FS_TITLE, ThemeKit.TEXT, "NextLabel")
	box.add_child(_next_lbl)
	_full_lbl = _label("", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "FullLabel")
	box.add_child(_full_lbl)

	_gold_btn = ThemeKit.make_button("", "primary")
	_gold_btn.name = "GoldButton"
	_gold_btn.pressed.connect(_on_gold_pressed)
	box.add_child(_gold_btn)
	_video_btn = ThemeKit.make_button(tr("no_lives_video"), "video")
	_video_btn.name = "VideoButton"
	_video_btn.pressed.connect(_on_video_pressed)
	box.add_child(_video_btn)
	_no_ads_lbl = _label(tr("no_lives_no_ads"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "NoAdsLabel")
	box.add_child(_no_ads_lbl)

	_msg = _label("", ThemeKit.FS_SMALL, ThemeKit.DANGER, "MessageLabel")
	_msg.visible = false
	box.add_child(_msg)

	var home := ThemeKit.make_button(tr("no_lives_home"), "ghost")
	home.name = "HomeButton"
	home.pressed.connect(_on_home_pressed)
	box.add_child(home)

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = false
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()


## Làm mới số liệu từ Game.lives_view(); đóng "refilled" khi đã có mạng.
func refresh() -> void:
	if not _built or _busy:
		return
	var v: Dictionary = Game.lives_view()
	var count := int(v.count)
	var mx := int(v.max)
	if bool(v.can_play):
		_finish("refilled")
		return
	_lives_lbl.text = tr("no_lives_lives") % [count, mx]
	var secs := int(v.seconds_to_next)
	_next_lbl.text = tr("no_lives_next") % format_time(secs)
	var regen := int(Config.LIVES.regen_sec)
	_full_lbl.text = tr("no_lives_full_in") % format_time(secs + maxi(mx - count - 1, 0) * regen)
	_gold_btn.text = tr("no_lives_refill_gold") % int(v.refill_price)
	var can_gold := bool(v.can_refill_gold)
	_gold_btn.modulate.a = 1.0 if can_gold else 0.6
	var video_ready := bool(v.video_ready)
	_video_btn.disabled = not video_ready
	_no_ads_lbl.visible = not video_ready


func _finish(result: Variant) -> void:
	_timer.stop()
	closed.emit(result)


func _show_msg(text: String) -> void:
	_msg.text = text
	_msg.visible = true


func _set_busy(v: bool) -> void:
	_busy = v
	for b in find_children("*", "Button", true, false):
		(b as Button).disabled = v


func _on_gold_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	if not Game.refill_gold():
		_show_msg(tr("no_lives_not_enough_gold"))
		return
	Sfx.play("sfx_coin")
	_finish("refilled")


func _on_video_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	_set_busy(true)
	var ok: bool = await Game.refill_video()
	if not is_inside_tree():
		return
	_set_busy(false)
	if ok:
		_finish("refilled")
		return
	match Game.last_ad_reason:
		"not_ready":
			_show_msg(tr("no_lives_no_ads"))
		"closed":
			_show_msg(tr("ads_closed_early"))
		_:
			_show_msg(tr("ads_failed"))
	refresh()


func _on_home_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	_finish("home")
