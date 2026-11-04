extends Control
## Popup hết MOVES: +3 Move bằng gold, kho hoặc video. Bố cục PopupReviveLayer (color-cube-match-puzzle): khung tím,
## ô kem có icon +3 Move, hàng nút [video][gold], dòng "Bỏ cuộc" dưới khung như nút Retry của prefab.
## Nút gold chỉ có icon gold và giá (UnityKit.gold_price); còn trong kho thì cùng nút đó ghi "Dùng".
## setup(args): kết quả RescueFlow.offer (hoặc Game.rescue_offer), thêm tuỳ chọn:
##   attempt: Dictionary  có thì popup tự gọi Game.rescue_accept và chỉ đóng khi thành công.
## closed(result): "inventory" | "gold" | "video" (đã +3 MOVES nếu có attempt),
##   "skip" (bấm Bỏ cuộc hoặc X: bên gọi hỏi xác nhận mất mạng rồi tự gọi Game.rescue_skip),
##   "need_coins" (thiếu gold, bên gọi mở shop mini rồi dựng lại popup).
## Bấm Back của Android: main phát closed(null), bên gọi coi như "skip".

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UButton := preload("res://src/ui/u_button.gd")
const VIDEO_PLACEMENT := "continue_moves"
const ROW := "Bg/Panel/Content/GameObject"

var _args: Dictionary = {}
var _busy: bool = false
var _msg: Label = null
var ui: RefCounted = null


## Runs once: the layer is a node of scenes/popup_rescue.tscn (the caller opens a new popup for every offer).
func setup(args: Dictionary) -> void:
	if ui != null:
		return
	_args = args
	_build()


func _remaining_text(n: int) -> String:
	return tr("rescue_remaining_one") if n == 1 else tr("rescue_remaining") % n


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "PopupReviveLayer")
	ui.node("Bg").name = "Dim"
	ui.text("Bg/Panel/Image/txtHeader", tr("rescue_title")).name = "TitleLabel"
	ui.text("Bg/Panel/Content/Description (1)", _remaining_text(int(_args.get("remaining", 0)))).name = "RemainingLabel"
	ui.text("Bg/Panel/Content/Description", tr("rescue_body")).name = "BodyLabel"
	ui.texture("Bg/Panel/Content/Preview/Content/Icon", ThemeKit.icon("booster_move"))
	# The game has no first-time free revive, helper pack or hold-to-see-board: hide those parts of the prefab.
	for p in ["Bg/Panel/Content/FreeObject", "Bg/Panel/HelperPack", "Bg/Panel/Text (TMP)"]:
		ui.show(p, false)
	ui.show(ROW, true)
	for b in ui.field("closeButtons", "PopupReviveLayer"):
		(b as Button).connect("clicked", _on_skip_pressed)

	var use_inv := bool(_args.get("use_inventory", false))
	var affordable := bool(_args.get("affordable", false))
	var main_btn: Button
	if use_inv:
		main_btn = _pill(ROW + "/GoldBtn", "UseButton", tr("rescue_use"), "Baloo Outline - Yellow")
	else:
		main_btn = ui.button(ROW + "/GoldBtn")
		main_btn.name = "BuyButton"
		UnityKit.gold_price(main_btn, int(_args.get("price", 0)))
	main_btn.connect("clicked", _on_main_pressed)
	if use_inv and _args.has("inv_move"):
		_status("StockLabel", tr("rescue_in_stock") % int(_args.inv_move))
	elif not use_inv and not affordable:
		_status("NeedGoldLabel", tr("rescue_need_gold"))

	if bool(_args.get("video", false)):
		var vid := _pill(ROW + "/AdsBtn", "VideoButton", tr("rescue_video"), "Baloo Outline - Blue 1")
		vid.connect("clicked", _on_video_pressed)
		Game.offer_video(VIDEO_PLACEMENT)
	else:
		ui.show(ROW + "/AdsBtn", false)
	ui.relayout(ROW)

	var skip: Button = ui.button(ROW + "/Retry")
	skip.name = "SkipButton"
	ui.text(ROW + "/Retry/Out", tr("rescue_give_up"))
	skip.connect("clicked", _on_skip_pressed)

	# White line under the popup (the prefab's lower hint text) for ad errors.
	_msg = ui.text("Bg/Panel/Text (TMP) (1)", "")
	_msg.name = "MessageLabel"
	_msg.visible = false


## A row button of the prefab with the game's label: the inactive "Out" text fills the pill (two lines, auto size)
## in the outline material of the prefab's price text; the price row is hidden.
func _pill(path: String, node_name: String, label: String, mat: String) -> Button:
	var b: Button = ui.button(path)
	b.name = node_name
	ui.show(path + "/Price", false)
	var out: Label = ui.label(path + "/Out")
	# u_txt is the cached prefab dict: change a copy.
	var t: Dictionary = (out.get_meta("u_txt") as Dictionary).duplicate()
	t.auto = [18.0, 40.0]
	t.w = true
	out.set_meta("u_txt", t)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	out.material = UnityUI.text_material(mat, false)
	# Keep clear of the TV icon on the video pill's top-right corner.
	var right := 56.0 if ui.has(path + "/Image") else 24.0
	var r: Dictionary = out.get_meta("u_rect")
	r.amin = Vector2(0, 0)
	r.amax = Vector2(1, 1)
	r.pos = Vector2((24.0 - right) * 0.5, 4.0)
	r.size = Vector2(-24.0 - right, -24.0)
	UnityUI.apply_rect(out)
	out.visible = true
	ui.text(path + "/Out", label)
	return b


## Status line at the bottom of the cream well, under the icon (Description style).
func _status(node_name: String, text: String) -> Label:
	var s := UnityKit.spec("PopupReviveLayer", "Bg/Panel/Content/Description")
	s.n = node_name
	s.txt.s = text
	s.txt.fs = 32.0
	s.txt.auto = [18.0, 32.0]
	# Well spans y 83..576 of the 838 panel; the icon ends at 531 (the line overlaps its bottom edge a little).
	return UnityKit.add(ui.node("Bg/Panel/Content"), s, Rect2(72, 520, 580, 44)).root as Label


func _set_busy(v: bool) -> void:
	_busy = v
	for b in find_children("*", "Button", true, false):
		if b is UButton:
			(b as UButton).set_interactable(not v)
		else:
			(b as Button).disabled = v


func _show_msg(text: String) -> void:
	_msg.visible = true
	ui.text("Bg/Panel/Text (TMP) (1)", text)


func _finish(result: Variant) -> void:
	closed.emit(result)


func _on_main_pressed() -> void:
	if _busy:
		return
	if bool(_args.get("use_inventory", false)):
		await _accept("inventory")
	elif not bool(_args.get("affordable", false)):
		_finish("need_coins")
	else:
		await _accept("gold")


func _on_video_pressed() -> void:
	if _busy:
		return
	await _accept("video")


func _on_skip_pressed() -> void:
	if _busy:
		return
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
