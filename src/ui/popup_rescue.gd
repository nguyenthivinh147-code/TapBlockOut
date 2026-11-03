extends Control
## Popup hết MOVES: +3 Move bằng gold, kho hoặc video.
## setup(args): kết quả RescueFlow.offer (hoặc Game.rescue_offer), thêm tuỳ chọn:
##   attempt: Dictionary  có thì popup tự gọi Game.rescue_accept và chỉ đóng khi thành công.
## closed(result): "inventory" | "gold" | "video" (đã +3 MOVES nếu có attempt),
##   "skip" (bấm Bỏ cuộc: bên gọi hỏi xác nhận mất mạng rồi tự gọi Game.rescue_skip),
##   "need_coins" (thiếu gold, bên gọi mở shop mini rồi dựng lại popup).
## Bấm Back của Android: main phát closed(null), bên gọi coi như "skip".

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const VIDEO_PLACEMENT := "continue_moves"

var _args: Dictionary = {}
var _busy: bool = false
var _panel: Control = null
var _msg: Label = null


func setup(args: Dictionary) -> void:
	_args = args
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_build()


func _label(text: String, size: int, color: Color, node_name: String) -> Label:
	return PopupKit.text(text, size, color, node_name)


func _remaining_text(n: int) -> String:
	return tr("rescue_remaining_one") if n == 1 else tr("rescue_remaining") % n


func _build() -> void:
	var k := PopupKit.make(self, tr("rescue_title"), _on_skip_pressed, {"banner": "red"})
	_panel = k.card
	var box: VBoxContainer = k.box

	box.add_child(ThemeKit.make_icon("booster_move", 150))
	box.add_child(_label(tr("rescue_body"), ThemeKit.FS_BODY, ThemeKit.INK, "BodyLabel"))
	box.add_child(_label(_remaining_text(int(_args.get("remaining", 0))), ThemeKit.FS_BODY, ThemeKit.BROWN, "RemainingLabel"))

	var use_inv := bool(_args.get("use_inventory", false))
	var affordable := bool(_args.get("affordable", false))
	var price := int(_args.get("price", 0))
	if use_inv:
		if _args.has("inv_move"):
			box.add_child(_label(tr("rescue_in_stock") % int(_args.inv_move), ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "StockLabel"))
		var use_btn := ThemeKit.make_button(tr("rescue_use"), "primary")
		use_btn.name = "UseButton"
		use_btn.pressed.connect(_on_main_pressed)
		box.add_child(use_btn)
	else:
		var buy_btn := ThemeKit.make_button(tr("rescue_buy") % price, "gold" if affordable else "secondary")
		buy_btn.name = "BuyButton"
		buy_btn.pressed.connect(_on_main_pressed)
		box.add_child(buy_btn)
		if not affordable:
			box.add_child(_label(tr("rescue_need_gold"), ThemeKit.FS_SMALL, ThemeKit.INK_DANGER, "NeedGoldLabel"))

	if bool(_args.get("video", false)):
		var vid := ThemeKit.make_button(tr("rescue_video"), "video")
		vid.name = "VideoButton"
		ThemeKit.set_button_icon(vid, "ui_video")
		vid.add_theme_font_size_override("font_size", ThemeKit.FS_BODY - 2)
		vid.pressed.connect(_on_video_pressed)
		box.add_child(vid)
		Game.offer_video(VIDEO_PLACEMENT)

	_msg = _label("", ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "MessageLabel")
	_msg.visible = false
	box.add_child(_msg)

	var skip := ThemeKit.make_button(tr("rescue_give_up"), "ghost")
	skip.name = "SkipButton"
	skip.pressed.connect(_on_skip_pressed)
	box.add_child(skip)

	_animate_in.call_deferred()


func _animate_in() -> void:
	if _panel != null and is_instance_valid(_panel):
		ThemeKit.popup_in(_panel)


func _set_busy(v: bool) -> void:
	_busy = v
	for b in find_children("*", "Button", true, false):
		(b as Button).disabled = v


func _show_msg(text: String) -> void:
	_msg.text = text
	_msg.visible = true


func _finish(result: Variant) -> void:
	closed.emit(result)


func _on_main_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	if bool(_args.get("use_inventory", false)):
		await _accept("inventory")
	elif not bool(_args.get("affordable", false)):
		_finish("need_coins")
	else:
		await _accept("gold")


func _on_video_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	await _accept("video")


func _on_skip_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	_finish("skip")


func _accept(method: String) -> void:
	var ok := true
	if _args.has("attempt"):
		_set_busy(true)
		ok = await Game.rescue_accept(_args.attempt, method)
		if not is_inside_tree():
			return
		_set_busy(false)
	if ok:
		Sfx.play("sfx_moves")
		_finish(method)
		return
	if method == "video":
		match Game.last_ad_reason:
			"not_ready":
				_show_msg(tr("ads_not_available"))
			"closed":
				_show_msg(tr("ads_closed_early"))
			_:
				_show_msg(tr("ads_failed"))
	else:
		_show_msg(tr("rescue_need_gold"))
