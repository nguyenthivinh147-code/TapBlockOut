extends Control
## Thẻ thua: Thử lại, Về Home, và Gói Cứu Nguy nếu Game báo.
## setup(args): {offer: String ("rescue_pack" khi Game.check_offer báo, bằng cách nghe offer_ready), life_charged: bool,
##   price_text: String (tuỳ chọn, mặc định lấy giá store của SKU)}.
## closed(result): "retry" | "home". Bên gọi tự bắt đầu lượt mới (hoặc chuyển no_lives).
## Mua gói: popup tự gọi Game.offer_buy, không đóng.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

var _args: Dictionary = {}
var _busy: bool = false
var _panel: Control = null
var _pack_box: Control = null
var _msg: Label = null


func setup(args: Dictionary) -> void:
	_args = args
	_busy = false
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


func _price_text(offer_id: String) -> String:
	if _args.has("price_text"):
		return str(_args.price_text)
	var sku := str(Config.OFFERS.get(offer_id, {}).get("sku", offer_id))
	return Platform.price(sku)


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

	box.add_child(_label(tr("lose_title"), ThemeKit.FS_TITLE, ThemeKit.TEXT, "TitleLabel"))
	box.add_child(_label(tr("lose_body"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM, "BodyLabel"))
	if bool(_args.get("life_charged", false)):
		box.add_child(_label(tr("lose_life_lost"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "LifeLabel"))

	if str(_args.get("offer", "")) == "rescue_pack":
		var pack := VBoxContainer.new()
		pack.name = "PackBox"
		pack.add_theme_constant_override("separation", 12)
		pack.add_child(_label(tr("lose_pack_title"), ThemeKit.FS_BODY, ThemeKit.GOLD, "PackTitleLabel"))
		pack.add_child(_label(tr("lose_pack_body"), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "PackBodyLabel"))
		var buy := ThemeKit.make_button(tr("lose_pack_buy") % _price_text("rescue_pack"), "video")
		buy.name = "PackBuyButton"
		buy.pressed.connect(_on_pack_pressed)
		pack.add_child(buy)
		box.add_child(pack)
		_pack_box = pack

	_msg = _label("", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM, "MessageLabel")
	_msg.visible = false
	box.add_child(_msg)

	var retry := ThemeKit.make_button(tr("lose_retry"), "primary")
	retry.name = "RetryButton"
	retry.pressed.connect(_on_retry_pressed)
	box.add_child(retry)
	var home := ThemeKit.make_button(tr("lose_home"), "ghost")
	home.name = "HomeButton"
	home.pressed.connect(_on_home_pressed)
	box.add_child(home)

	Sfx.play("sfx_lose")
	_animate_in.call_deferred()


func _animate_in() -> void:
	if _panel != null and is_instance_valid(_panel):
		ThemeKit.popup_in(_panel)


func _set_busy(v: bool) -> void:
	_busy = v
	for b in find_children("*", "Button", true, false):
		(b as Button).disabled = v


func _on_retry_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	closed.emit("retry")


func _on_home_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	closed.emit("home")


func _on_pack_pressed() -> void:
	if _busy:
		return
	Sfx.play("sfx_button")
	_set_busy(true)
	var r: Dictionary = await Game.offer_buy("rescue_pack")
	if not is_inside_tree():
		return
	_set_busy(false)
	var status := str(r.get("status", "error"))
	if status == "ok" and bool(r.get("granted", false)):
		_msg.text = tr("shop_buy_ok")
		if _pack_box != null:
			_pack_box.visible = false
	elif status == "pending":
		_msg.text = tr("shop_buy_pending")
	elif status == "cancel":
		_msg.visible = false
		return
	else:
		_msg.text = tr("shop_buy_failed")
	_msg.visible = true
