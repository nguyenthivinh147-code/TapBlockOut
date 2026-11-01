extends Control
## Shop mini: chỉ gói gold, mở ở mọi level khi người chơi thiếu gold và bấm mua.
## setup({source}); signal closed({bought: bool}). Đóng thì popup gọi quay lại.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Shop := preload("res://src/ui/shop.gd")

var close_button: Button = null
var toast_label: Label = null
var coins_label: Label = null
## sku -> nút mua
var buy_buttons: Dictionary = {}
var bought_any: bool = false
var last_toast: String = ""

var _busy: bool = false
var _closed: bool = false
var _card: Control = null
var _toast_tween: Tween = null


func setup(args: Dictionary) -> void:
	Game.shop_opened("mini_" + str(args.get("source", "")))
	_build()
	Game.coins_changed.connect(_on_coins_changed)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	buy_buttons.clear()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := ThemeKit.make_panel()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	_card = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var head := HBoxContainer.new()
	var title := ThemeKit.make_label(tr("shop_mini_title"), ThemeKit.FS_TITLE - 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	coins_label = ThemeKit.make_label(str(int(Game.s.coins)), ThemeKit.FS_BUTTON, ThemeKit.GOLD)
	head.add_child(coins_label)
	v.add_child(head)

	for e in Game.shop_catalog():
		var row := Shop.make_gold_row(e, tr("shop_gold_pack") % int(e.gold), tr("shop_sale"))
		buy_buttons[str(e.sku)] = row.button
		(row.button as Button).pressed.connect(buy.bind(str(e.sku)))
		v.add_child(row.panel)

	toast_label = ThemeKit.make_label("", ThemeKit.FS_BODY)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.modulate.a = 0.0
	v.add_child(toast_label)

	close_button = ThemeKit.make_button(tr("shop_mini_close"), "secondary")
	close_button.pressed.connect(close)
	v.add_child(close_button)
	_animate_in.call_deferred(panel)


func buy(sku: String) -> void:
	if _busy or _closed:
		return
	_busy = true
	_set_buttons_disabled(true)
	Sfx.play("sfx_button")
	var r: Dictionary = await Game.buy_sku(sku)
	if not is_inside_tree():
		return
	_busy = false
	_set_buttons_disabled(false)
	match str(r.get("status", "error")):
		"ok":
			if bool(r.granted):
				bought_any = true
				Sfx.play("sfx_coin")
				toast(tr("shop_buy_ok"))
			else:
				toast(tr("shop_buy_failed"))
		"pending":
			toast(tr("shop_buy_pending"))
		"cancel":
			pass
		_:
			toast(tr("shop_buy_failed"))


func _set_buttons_disabled(v: bool) -> void:
	for b in buy_buttons.values():
		if is_instance_valid(b):
			(b as Button).disabled = v


func toast(text: String) -> void:
	last_toast = text
	if not is_instance_valid(toast_label):
		return
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)


func _on_coins_changed(v: int) -> void:
	if is_instance_valid(coins_label):
		coins_label.text = str(v)


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"bought": bought_any})


func _animate_in(card: Control) -> void:
	if is_instance_valid(card) and card.is_inside_tree():
		ThemeKit.popup_in(card)
