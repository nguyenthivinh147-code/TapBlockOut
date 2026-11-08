extends Control
## Màn hết mạng: đếm ngược, nạp bằng gold, xem video (+1 mạng), về Home.
## setup(args): {source?}; "hub" là mở từ tim trên thanh trên, dạng popup đè lên màn đang mở: tiêu đề "Thêm mạng",
## không tự đóng khi còn mạng; đầy mạng (hoặc vô hạn) thì ẩn nút video, nút gold và đếm ngược, chỗ đếm ngược cạnh
## tim ghi dòng báo đầy (vô hạn) bằng text của prefab cho trạng thái này, dòng giải thích dưới popup ẩn đi.
## Dữ liệu lấy từ Game.lives_view().
## closed(result): "refilled" (đã có mạng, quay lại chơi) | "home". Mở từ hub thì không bao giờ "refilled":
## nạp xong cũng là "home".
## Không có video thì hiện dòng báo, vẫn chờ được.
## Dựng theo PopupMoreHeartLayer (color-cube-match-puzzle): tim kèm số mạng, dòng "mạng kế tiếp sau" và chip đồng hồ
## ghi thời gian tới mạng kế (dòng đếm ngược duy nhất), nút video (AdsBtn) và nút gold (GoldBtn: +N tim, icon gold và giá qua UnityKit.gold_price). X và chạm nền
## (NavigationBackButton) là về Home.
## Không bán BundleHeart (game không có gói này ở đây): chỗ của nó dành cho dòng giải thích và thông báo.
## Ba dòng dưới popup (giải thích, không có video, thông báo), chip đồng hồ nới rộng (340) và đồng hồ làm mới là node
## trong scenes/no_lives.tscn.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Config := preload("res://src/config.gd")
const VIDEO_PLACEMENT := "refill_life"
const LAYER := "PopupMoreHeartLayer"

var ui: RefCounted = null
var _busy: bool = false
var _built: bool = false
var _from_hub: bool = false
var _title: Label
var _lives_lbl: Label
var _next_lbl: Label
var _time_lbl: Label
var _full_lbl: Label
var _body: Label
var _gold_btn: Button
var _video_btn: Button
var _no_ads_lbl: Label
var _msg: Label
var _timer: Timer
var _beat: Tween = null


func setup(args: Dictionary = {}) -> void:
	_busy = false
	_from_hub = str(args.get("source", "")) == "hub"
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


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The scene saves the layer as the game uses it (BundleHeart and unused parts hidden, wider chip, auto sized
	# texts) plus the three lines under the popup and the refresh timer; this only names, fills and wires.
	ui = UnityUI.build(self, LAYER)
	_title = ui.text("Panel/Image/txtHeader", tr("no_lives_title"))
	var home: Button = ui.button("Panel/Top/btnTurnOff")
	home.name = "HomeButton"
	home.connect("clicked", _on_home_pressed)
	ui.on_click("Bg", _on_home_pressed)
	_lives_lbl = ui.label("Panel/Content/Preview/Content/HeartIcon/Text (TMP)")
	_lives_lbl.name = "LivesLabel"
	_next_lbl = ui.label("Panel/Content/Description/Text (TMP)")
	_next_lbl.name = "NextLabel"
	_time_lbl = ui.label("Panel/Content/Description/Image/Text (TMP)")
	_time_lbl.name = "TimeLabel"
	# Prefab text for the full state ("Looks like your hearts are full!"); its Continue button stays hidden.
	_full_lbl = ui.label("Panel/Content/Description/Text (TMP)#2")
	_full_lbl.name = "FullLabel"
	ui.show("Panel/Content/Description/Text (TMP)#2/Continue", false)

	_video_btn = ui.button("Panel/Content/GameObject/AdsBtn")
	_video_btn.name = "VideoButton"
	_video_btn.connect("clicked", _on_video_pressed)
	ui.text("Panel/Content/GameObject/AdsBtn/Out", tr("no_lives_video"))
	_gold_btn = ui.button("Panel/Content/GameObject/GoldBtn")
	_gold_btn.name = "GoldButton"
	_gold_btn.connect("clicked", _on_gold_pressed)
	ui.label("Panel/Content/GameObject/GoldBtn/Price/Text (TMP)").name = "GoldPrice"
	ui.text("Panel/Content/GameObject/GoldBtn/Image/Out", "+%d" % int(Config.ECON.refill_lives))

	_body = %BodyLabel
	_body.visible = true
	_no_ads_lbl = %NoAdsLabel
	UnityUI.set_text(_no_ads_lbl, tr("no_lives_no_ads"))
	_msg = %MessageLabel
	_msg.visible = false
	ui.relayout("Panel/Content/GameObject")

	_timer = %RefreshTimer
	_timer.timeout.connect(refresh)
	_timer.start()
	_heart_beat.call_deferred()


## HeartAnimation (StartHeartAnimation on show): intro from StartScale, then a squash pulse to EndScale and back.
## Builder gap: the script is not run by unity_ui.gd.
func _heart_beat() -> void:
	var heart: Control = ui.node("Panel/Content/Preview/Content/HeartIcon")
	if heart == null or not heart.is_inside_tree():
		return
	var base := heart.scale
	var intro := UnityUI.ease_of(28)
	var loop := UnityUI.ease_of(26)
	heart.scale = base * 1.15
	_beat = heart.create_tween()
	_beat.tween_property(heart, "scale", base, 0.75).set_trans(intro[0]).set_ease(intro[1])
	_beat.tween_callback(func() -> void:
		if not is_instance_valid(heart):
			return
		var tw := heart.create_tween().set_loops()
		tw.tween_property(heart, "scale", Vector2(base.x * 0.94, base.y * 0.85), 0.35).set_trans(loop[0]).set_ease(loop[1])
		tw.tween_property(heart, "scale", base, 0.35).set_trans(loop[0]).set_ease(loop[1]))


## Làm mới số liệu từ Game.lives_view(); đóng "refilled" khi đã có mạng (trừ khi mở từ hub).
func refresh() -> void:
	if not _built or _busy:
		return
	var v: Dictionary = Game.lives_view()
	var count := int(v.count)
	var mx := int(v.max)
	if not _from_hub and bool(v.can_play):
		_finish("refilled")
		return
	var infinite := bool(v.infinite)
	var full := infinite or count >= mx
	UnityUI.set_text(_title, tr("no_lives_more_title" if _from_hub else "no_lives_title"))
	var body := "no_lives_body"
	if _from_hub:
		body = "no_lives_unlimited_body" if infinite else ("no_lives_full_body" if full else "no_lives_more_body")
	UnityUI.set_text(_body, tr(body))
	UnityUI.set_text(_lives_lbl, str(count))
	ui.show("Panel/Content/GameObject", not full)
	_next_lbl.visible = not full
	ui.show("Panel/Content/Description/Image", not full)
	_full_lbl.visible = full
	_body.visible = not full
	if full:
		UnityUI.set_text(_full_lbl, tr(body))
		_no_ads_lbl.visible = false
		_msg.visible = false
		return
	UnityUI.set_text(_next_lbl, tr("no_lives_next"))
	UnityUI.set_text(_time_lbl, format_time(int(v.seconds_to_next)))
	UnityKit.gold_price(_gold_btn, int(v.refill_price))
	var can_gold := bool(v.can_refill_gold)
	_gold_btn.modulate.a = 1.0 if can_gold else 0.6
	var video_ready := bool(v.video_ready)
	_video_btn.call("set_interactable", video_ready)
	_no_ads_lbl.visible = not video_ready


func _finish(result: Variant) -> void:
	_timer.stop()
	closed.emit("home" if _from_hub and result == "refilled" else result)


func _show_msg(text: String) -> void:
	UnityUI.set_text(_msg, text)
	_msg.visible = true


func _set_busy(v: bool) -> void:
	_busy = v
	for b in find_children("*", "Button", true, false):
		if b.has_method("set_interactable"):
			b.call("set_interactable", not v)
		else:
			(b as Button).disabled = v


func _on_gold_pressed() -> void:
	if _busy:
		return
	if not Game.refill_gold():
		_show_msg(tr("no_lives_not_enough_gold"))
		return
	Sfx.play("sfx_coin")
	_finish("refilled")


func _on_video_pressed() -> void:
	if _busy:
		return
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
	_finish("home")
