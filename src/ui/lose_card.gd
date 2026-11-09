extends Control
## Thẻ thua: Thử lại, Về Home, và Gói Cứu Nguy nếu Game báo. Bố cục LossPanel của EndGameUILayer
## (color-cube-match-puzzle): khung bạc có icon art_lose (thay tranh Popup_Lose của prefab, nấc nhấp nhô như đang khóc:
## UiMotion.SOB; giọt lệ là node Tear riêng, chảy xuống má: UiMotion.TEAR), ribbon xanh, hàng nút Home / Replay.
## Dòng chữ dưới khung là bản sao
## chữ "Still Wanna Play?" của prefab; Gói Cứu Nguy là bản sao HelperPack của PopupReviveLayer, đặt dưới hàng nút như
## prefab đó (khung đẩy lên cho vừa). Dòng chữ và dòng thông báo là node trong scenes/lose_card.tscn; dòng mất mạng và
## Gói Cứu Nguy chỉ thêm lúc chạy khi có.
## setup(args): {offer: String ("rescue_pack" khi Game.check_offer báo, bằng cách nghe offer_ready), life_charged: bool,
##   price_text: String (tuỳ chọn, mặc định lấy giá store của SKU)}.
## closed(result): "retry" | "home". Bên gọi tự bắt đầu lượt mới (hoặc chuyển no_lives).
## Mua gói: popup tự gọi Game.offer_buy, không đóng.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UButton := preload("res://src/ui/u_button.gd")
const UiMotion := preload("res://src/ui/ui_motion.gd")

const LOSS := "Panel/LossPanel"
## The art_lose icon inside the frame (scenes/lose_card.tscn); its child %Tear is the tear tools/split_tear.gd took off.
const ART := "Panel/LossPanel/BG/Image"
const ROW := "Panel/LossPanel/GameObject"
## Heights in canvas units under the frame (frame bottom at y -232.1 in the prefab): body line, life line, button
## row (prefab GameObject, so the row lands on its prefab place when only the body shows), message line, pack.
const BODY_H := 86.1
const LIFE_H := 56.0
const ROW_H := 137.2
const MSG_H := 56.0
const PACK_H := 480.0
## Space kept under the lowest element (the canvas is 1920 units tall, y from -960).
const BOTTOM := 936.0

var ui: RefCounted = null
var _args: Dictionary = {}
var _busy: bool = false
var _pack_box: Control = null
var _msg: Label = null


## Runs once: the layer and the lines are nodes of scenes/lose_card.tscn (callers open a new card each time).
func setup(args: Dictionary) -> void:
	if ui != null:
		return
	_args = args
	_busy = false
	_build()


func _price_text(offer_id: String) -> String:
	if _args.has("price_text"):
		return str(_args.price_text)
	var sku := str(Config.OFFERS.get(offer_id, {}).get("sku", offer_id))
	return Platform.price(sku)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "EndGameUILayer")
	ui.show("Panel/WinPanel", false)
	_enable_group(ui.node(LOSS))
	ui.text(LOSS + "/BG/Lose_Panel/Text (TMP)", tr("lose_title"))
	var life := bool(_args.get("life_charged", false))
	var pack := str(_args.get("offer", "")) == "rescue_pack"

	# Stack under the frame; lift everything when it would not fit above the bottom margin.
	var frame: Control = ui.node(LOSS + "/BG")
	var fr: Dictionary = frame.get_meta("u_rect")
	var bottom := float((fr.pos as Vector2).y) - float((fr.size as Vector2).y) * 0.5
	var need := BODY_H + (LIFE_H if life else 0.0) + ROW_H + (MSG_H + PACK_H if pack else 0.0)
	var shift := maxf(0.0, need - (bottom + BOTTOM))
	fr.pos = Vector2((fr.pos as Vector2).x, (fr.pos as Vector2).y + shift)
	UnityUI.apply_rect(frame)
	var y := bottom + shift

	# BodyLabel and MessageLabel are nodes of the scene; the life line and the pack are added only when they show.
	_place(%BodyLabel, y - BODY_H * 0.5, BODY_H)
	UnityUI.set_text(%BodyLabel, tr("lose_body"))
	y -= BODY_H
	if life:
		var l := _line("LifeLabel", tr("lose_life_lost"), 40.0, y - LIFE_H * 0.5, LIFE_H)
		ui.node(LOSS).move_child(l, (%MessageLabel as Control).get_index())
		y -= LIFE_H
	var row: Control = ui.node(ROW)
	var rr: Dictionary = row.get_meta("u_rect")
	rr.pos = Vector2((rr.pos as Vector2).x, y - ROW_H)
	UnityUI.apply_rect(row)
	y -= ROW_H
	_msg = %MessageLabel
	_place(_msg, y - MSG_H * 0.5, MSG_H)
	_msg.visible = false
	if pack:
		_build_pack(y - MSG_H - PACK_H * 0.5)

	var home: Button = ui.button(ROW + "/MainMenuBtn")
	home.name = "HomeButton"
	ui.text(ROW + "/MainMenuBtn/Text (TMP) (1)", tr("lose_home"))
	home.connect("clicked", _on_home_pressed)
	var retry: Button = ui.button(ROW + "/ReplayBtn")
	retry.name = "RetryButton"
	ui.text(ROW + "/ReplayBtn/Text (TMP) (1)", tr("lose_retry"))
	retry.connect("clicked", _on_retry_pressed)

	Sfx.play("sfx_lose")
	if not UnityUI.baking:
		UiMotion.attach(ui.node(ART), UiMotion.SOB)
		UiMotion.attach(%Tear, UiMotion.TEAR)
	_animate_in.call_deferred()


## Line in the style of the prefab's "Still Wanna Play?" text (white, blue outline), centred at y (canvas units).
func _line(node_name: String, text: String, size: float, y: float, h: float) -> Label:
	var s := UnityKit.spec("EndGameUILayer", LOSS + "/Image/Still Wanna Play?")
	s.n = node_name
	s.a = true
	s.r = [0.5, 0.5, 0.5, 0.5, 0, y, 687.5, h, 0.5, 0.5]
	s.txt.s = text
	s.txt.fs = size
	s.txt.auto = [18.0, size]
	s.txt.w = true
	return UnityKit.add(ui.node(LOSS), s).root as Label


## Moves a line of the scene to its row of the stack, centred at y (canvas units), like _line places a new one.
func _place(l: Label, y: float, h: float) -> void:
	var r: Dictionary = l.get_meta("u_rect")
	r.pos = Vector2(0, y)
	r.size = Vector2(687.5, h)
	UnityUI.apply_rect(l)


## Rescue Pack as PopupReviveLayer's HelperPack: game icon in place of the pack art, the pack text where the item
## rows were, the store price on the purchase button.
func _build_pack(y: float) -> void:
	var s := UnityKit.spec("PopupReviveLayer", "Bg/Panel/HelperPack")
	s.n = "PackBox"
	s.r = [0.5, 0.5, 0.5, 0.5, 0, y, 806, PACK_H, 0.5, 0.5]
	var v: RefCounted = UnityKit.add(ui.node(LOSS), s)
	_pack_box = v.root
	v.texture("Image (2)", ThemeKit.icon("booster_move"))
	UnityUI.image_of(v.node("Image (2)")).preserve_aspect = true
	v.text("PackName", tr("lose_pack_title")).name = "PackTitleLabel"
	var items: Control = v.node("ItemContainer")
	for c in items.get_children():
		(c as Control).visible = false
	var body := UnityKit.spec("PopupReviveLayer", "Bg/Panel/HelperPack/PackName")
	body.n = "PackBodyLabel"
	body.r = (UnityKit.spec("PopupReviveLayer", "Bg/Panel/HelperPack/ItemContainer").r as Array).duplicate()
	body.txt.s = tr("lose_pack_body")
	body.txt.fs = 44.0
	body.txt.auto = [18.0, 44.0]
	body.txt.w = true
	body.txt.h = 2
	body.txt.st = 0
	UnityKit.add(_pack_box, body)
	var buy: Button = v.button("Button_Purchase")
	buy.name = "PackBuyButton"
	v.text("Button_Purchase/Text (TMP)", _price_text("rescue_pack"))
	buy.connect("clicked", _on_pack_pressed)


func _animate_in() -> void:
	if ui == null or not is_inside_tree():
		return
	# GameOverPanel.PlayShowAnimation: canvas group alpha 0.3 -> 1 in 1 s, OutBack.
	var loss: Control = ui.node(LOSS)
	loss.modulate.a = 0.3
	create_tween().tween_property(loss, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## GameOverPanel turns the LossPanel CanvasGroup on (interactable, blocksRaycasts) when it shows; unity_ui.gd bakes the
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


func _set_busy(v: bool) -> void:
	_busy = v
	for b in ui.node(LOSS).find_children("*", "Button", true, false):
		(b as UButton).set_interactable(not v)


func _show_msg(text: String) -> void:
	_msg.visible = true
	UnityUI.set_text(_msg, text)


func _on_retry_pressed() -> void:
	if _busy:
		return
	closed.emit("retry")


func _on_home_pressed() -> void:
	if _busy:
		return
	closed.emit("home")


func _on_pack_pressed() -> void:
	if _busy:
		return
	_set_busy(true)
	var r: Dictionary = await Game.offer_buy("rescue_pack")
	if not is_inside_tree():
		return
	_set_busy(false)
	var status := str(r.get("status", "error"))
	if status == "ok" and bool(r.get("granted", false)):
		_show_msg(tr("shop_buy_ok"))
		if _pack_box != null:
			_pack_box.visible = false
	elif status == "pending":
		_show_msg(tr("shop_buy_pending"))
	elif status == "cancel" or status == "offline":
		_msg.visible = false
	else:
		_show_msg(tr("shop_buy_failed"))
