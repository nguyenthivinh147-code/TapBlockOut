extends Control
## Màn hết mạng: đếm ngược, nạp bằng gold, xem video (+1 mạng), về Home.
## setup(args): {source?}; "hub" là mở từ tim trên thanh trên, dạng popup đè lên màn đang mở: tiêu đề "Thêm mạng",
## không tự đóng khi còn mạng; đầy mạng (hoặc vô hạn) thì ẩn nút video, nút gold và đếm ngược.
## Dữ liệu lấy từ Game.lives_view().
## closed(result): "refilled" (đã có mạng, quay lại chơi) | "home". Mở từ hub thì không bao giờ "refilled":
## nạp xong cũng là "home".
## Không có video thì hiện dòng báo, vẫn chờ được.
## Dựng theo PopupMoreHeartLayer (color-cube-match-puzzle): tim kèm số mạng, "mạng kế tiếp" và chip đồng hồ,
## nút video (AdsBtn) và nút gold (GoldBtn: +N tim, giá gold). X và chạm nền (NavigationBackButton) là về Home.
## Không bán BundleHeart (game không có gói này ở đây): chỗ của nó dành cho dòng giải thích và thông báo.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Config := preload("res://src/config.gd")
const VIDEO_PLACEMENT := "refill_life"
const LAYER := "PopupMoreHeartLayer"
## Lines under the popup (where BundleHeart sits), from the panel's bottom edge: body, no-video note, message.
const NOTE_Y := [-150.0, -290.0, -400.0]
## The chip holds "All lives back in h:mm:ss": wider than the prefab's 246 (sliced pill).
const CHIP_W := 340.0

var ui: RefCounted = null
var _busy: bool = false
var _built: bool = false
var _from_hub: bool = false
var _title: Label
var _lives_lbl: Label
var _next_lbl: Label
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
	ui = UnityUI.build(self, LAYER)
	_title = ui.text("Panel/Image/txtHeader", tr("no_lives_title"))
	var home: Button = ui.button("Panel/Top/btnTurnOff")
	home.name = "HomeButton"
	home.connect("clicked", _on_home_pressed)
	ui.on_click("Bg", _on_home_pressed)
	ui.show("Panel/BundleHeart", false)
	var pc := "Panel/Content/Preview/Content"
	for p in [pc + "/Amount_Backup", pc + "/Infinite", pc + "/Continue (1)", "Panel/Content/Description/Text (TMP)#2"]:
		ui.show(p, false)
	_lives_lbl = ui.label(pc + "/HeartIcon/Text (TMP)")
	_lives_lbl.name = "LivesLabel"
	_next_lbl = ui.label("Panel/Content/Description/Text (TMP)")
	_next_lbl.name = "NextLabel"
	var chip: Control = ui.node("Panel/Content/Description/Image")
	UnityKit.set_size(chip, Vector2(CHIP_W, (chip.get_meta("u_rect").size as Vector2).y))
	_full_lbl = ui.label("Panel/Content/Description/Image/Text (TMP)")
	_full_lbl.name = "FullLabel"
	var fr: Dictionary = _full_lbl.get_meta("u_rect")
	fr.pos = Vector2(38, (fr.pos as Vector2).y)
	fr.size = Vector2(CHIP_W - 100.0, (fr.size as Vector2).y)
	UnityUI.apply_rect(_full_lbl)
	_auto_size(_full_lbl, 38.0, true)

	_video_btn = ui.button("Panel/Content/GameObject/AdsBtn")
	_video_btn.name = "VideoButton"
	_video_btn.connect("clicked", _on_video_pressed)
	var vt: Label = ui.label("Panel/Content/GameObject/AdsBtn/Out")
	_auto_size(vt, 56.0, true)
	UnityUI.set_text(vt, tr("no_lives_video"))
	_gold_btn = ui.button("Panel/Content/GameObject/GoldBtn")
	_gold_btn.name = "GoldButton"
	_gold_btn.connect("clicked", _on_gold_pressed)
	ui.label("Panel/Content/GameObject/GoldBtn/Price/Text (TMP)").name = "GoldPrice"
	ui.text("Panel/Content/GameObject/GoldBtn/Image/Out", "+%d" % int(Config.ECON.refill_lives))

	var panel: Control = ui.node("Panel")
	_body = _note(panel, "", NOTE_Y[0], "BodyLabel")
	_body.visible = true
	_no_ads_lbl = _note(panel, tr("no_lives_no_ads"), NOTE_Y[1], "NoAdsLabel")
	_msg = _note(panel, "", NOTE_Y[2], "MessageLabel")
	_msg.visible = false
	ui.relayout("Panel/Content/GameObject")

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = false
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	_heart_beat.call_deferred()


## White outlined line on the dim under the popup (Baloo Outline - Black, like text on art in the prefabs).
func _note(panel: Control, text: String, y: float, node_name: String) -> Label:
	var l := UnityKit.label(panel, text, Rect2(0, 0, 100, 100), 40.0, "ffffffff", "Baloo Outline - Black")
	l.name = node_name
	var r: Dictionary = l.get_meta("u_rect")
	r.amin = Vector2(0.5, 0)
	r.amax = Vector2(0.5, 0)
	r.pos = Vector2(0, y)
	r.size = Vector2(760, 120)
	r.pivot = Vector2(0.5, 0.5)
	UnityUI.apply_rect(l)
	return l


## TMP auto size (and word wrap) on a text the prefab sized for a shorter Unity string. The text spec is shared
## with the layout cache, so it is copied before the change.
func _auto_size(l: Label, max_size: float, wrap: bool) -> void:
	var t: Dictionary = (l.get_meta("u_txt") as Dictionary).duplicate(true)
	t.auto = [18.0, max_size]
	t.w = wrap
	l.set_meta("u_txt", t)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if not l.resized.is_connected(UnityUI.fit_text):
		l.resized.connect(UnityUI.fit_text.bind(l))


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
	ui.show("Panel/Content/Description", not full)
	ui.show("Panel/Content/GameObject", not full)
	if full:
		_no_ads_lbl.visible = false
		_msg.visible = false
		return
	var secs := int(v.seconds_to_next)
	UnityUI.set_text(_next_lbl, tr("no_lives_next") % format_time(secs))
	var regen := int(Config.LIVES.regen_sec)
	UnityUI.set_text(_full_lbl, tr("no_lives_full_in") % format_time(secs + maxi(mx - count - 1, 0) * regen))
	ui.text("Panel/Content/GameObject/GoldBtn/Price/Text (TMP)", str(int(v.refill_price)))
	ui.relayout("Panel/Content/GameObject/GoldBtn/Price")
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
