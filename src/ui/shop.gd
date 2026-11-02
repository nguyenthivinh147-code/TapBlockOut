extends Control
## Shop đầy đủ (màn "shop", mở từ L5): gói gold theo giá hôm nay, video gold, gói khác, Restore.
## setup({source}); signal closed({bought: bool}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Config := preload("res://src/config.gd")

const PACK_SKUS := ["starter_pack", "level_pack", "rescue_pack", "remove_ads"]

var close_button: Button = null
var video_button: Button = null
var restore_button: Button = null
var toast_label: Label = null
var coins_label: Label = null
## sku -> nút mua
var buy_buttons: Dictionary = {}
var bought_any: bool = false
var last_toast: String = ""

var _source: String = ""
var _busy: bool = false
var _closed: bool = false
var _list: VBoxContainer = null
var _toast_tween: Tween = null


func setup(args: Dictionary) -> void:
	_source = str(args.get("source", ""))
	Game.shop_opened(_source)
	_build()
	Game.coins_changed.connect(_on_coins_changed)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	buy_buttons.clear()
	add_child(ThemeKit.make_background())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := ThemeKit.make_label(tr("shop_title"), ThemeKit.FS_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	coins_label = ThemeKit.make_label(str(int(Game.s.coins)), ThemeKit.FS_BUTTON, ThemeKit.GOLD)
	head.add_child(coins_label)
	close_button = ThemeKit.make_button(tr("common_close"), "secondary")
	close_button.pressed.connect(close)
	head.add_child(close_button)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)

	var catalog: Array = Game.shop_catalog()
	var any_sale := false
	for e in catalog:
		if bool(e.get("sale", false)):
			any_sale = true
	if any_sale:
		var sale := ThemeKit.make_label(tr("shop_sale_weekend"), ThemeKit.FS_BUTTON, ThemeKit.GOLD)
		sale.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(sale)

	_list.add_child(ThemeKit.make_label(tr("shop_section_gold"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM))
	_add_video_row()
	for e in catalog:
		var row := make_gold_row(e, tr("shop_gold_pack") % int(e.gold), tr("shop_sale"))
		buy_buttons[str(e.sku)] = row.button
		(row.button as Button).pressed.connect(buy.bind(str(e.sku)))
		_list.add_child(row.panel)

	_list.add_child(ThemeKit.make_label(tr("shop_section_other"), ThemeKit.FS_BODY, ThemeKit.TEXT_DIM))
	for sku in PACK_SKUS:
		_add_pack_row(sku)

	restore_button = ThemeKit.make_button(tr("shop_restore"), "secondary")
	restore_button.pressed.connect(restore)
	_list.add_child(restore_button)

	toast_label = ThemeKit.make_label("", ThemeKit.FS_BODY, ThemeKit.TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)


## Một dòng gói gold: {panel, button}. Dùng chung với shop_mini.
static func make_gold_row(entry: Dictionary, gold_text: String, sale_text: String) -> Dictionary:
	var panel := ThemeKit.make_panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	var icon := TextureRect.new()
	icon.texture = ThemeKit.icon("shop_" + str(entry.id))
	icon.custom_minimum_size = Vector2(ThemeKit.ICON_SIZE, ThemeKit.ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ThemeKit.make_label(gold_text, ThemeKit.FS_BUTTON, ThemeKit.GOLD))
	if bool(entry.get("sale", false)):
		var tag := sale_text
		if int(entry.get("sale_percent", 0)) > 0:
			tag = "%s -%d%%" % [sale_text, int(entry.sale_percent)]
		v.add_child(ThemeKit.make_label(tag, ThemeKit.FS_SMALL, ThemeKit.DANGER))
		var base_price := str(entry.get("base_price_text", ""))
		if base_price != "":
			var old := RichTextLabel.new()
			old.bbcode_enabled = true
			old.fit_content = true
			old.scroll_active = false
			old.autowrap_mode = TextServer.AUTOWRAP_OFF
			old.add_theme_font_size_override("normal_font_size", ThemeKit.FS_SMALL)
			old.add_theme_color_override("default_color", ThemeKit.TEXT_DIM)
			old.text = "[s]%s[/s]" % base_price.replace("[", "[lb]")
			v.add_child(old)
	var b := ThemeKit.make_button(str(entry.get("price_text", "")), "primary")
	b.custom_minimum_size = Vector2(200, ThemeKit.MIN_BUTTON.y)
	h.add_child(b)
	return {"panel": panel, "button": b}


func _add_video_row() -> void:
	var left: int = Game.shop_videos_left()
	var panel := ThemeKit.make_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	video_button = ThemeKit.make_button(tr("shop_video") % int(Config.ECON.shop_video_coins), "video")
	video_button.pressed.connect(watch_video)
	v.add_child(video_button)
	var info := ThemeKit.make_label("", ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	if left > 0:
		info.text = tr("shop_video_left") % [left, int(Config.ECON.shop_video_max)]
		Game.offer_video("shop_coins")
	else:
		info.text = tr("shop_video_none")
		video_button.disabled = true
	_list.add_child(panel)


func _pack_title(sku: String) -> String:
	match sku:
		"starter_pack":
			return tr("shop_starter_pack")
		"level_pack":
			return tr("shop_level_pack")
		"rescue_pack":
			return tr("shop_rescue_pack")
		"remove_ads":
			return tr("shop_remove_ads")
	return sku


func _pack_desc(sku: String) -> String:
	var gold := int(Config.SKUS.get(sku, {}).get("gold", 0))
	match sku:
		"starter_pack":
			return tr("shop_starter_pack_desc") % gold
		"level_pack":
			return tr("shop_level_pack_desc") % gold
		"rescue_pack":
			return tr("shop_rescue_pack_desc")
		"remove_ads":
			return tr("shop_remove_ads_desc") % gold
	return ""


## Món mua một lần đã có trong bản lưu.
func is_owned(sku: String) -> bool:
	if bool(Config.SKUS.get(sku, {}).get("consumable", true)):
		return false
	if sku == "remove_ads" and bool(Game.s.get("no_ads", false)):
		return true
	for e in Game.s.buys:
		if e is Dictionary and str(e.get("sku", "")) == sku:
			return true
	return false


func _add_pack_row(sku: String) -> void:
	if not Config.SKUS.has(sku):
		return
	var panel := ThemeKit.make_panel()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	panel.add_child(h)
	var icon := TextureRect.new()
	icon.texture = ThemeKit.icon("shop_" + sku)
	icon.custom_minimum_size = Vector2(ThemeKit.ICON_SIZE, ThemeKit.ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ThemeKit.make_label(_pack_title(sku), ThemeKit.FS_BUTTON, ThemeKit.TEXT))
	var d := ThemeKit.make_label(_pack_desc(sku), ThemeKit.FS_SMALL, ThemeKit.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var owned := is_owned(sku)
	var b := ThemeKit.make_button(tr("shop_owned") if owned else Platform.price(sku), "primary")
	b.custom_minimum_size = Vector2(200, ThemeKit.MIN_BUTTON.y)
	b.disabled = owned
	b.pressed.connect(buy.bind(sku))
	h.add_child(b)
	buy_buttons[sku] = b
	_list.add_child(panel)


func buy(sku: String) -> void:
	if _busy or _closed:
		return
	_set_busy(true)
	Sfx.play("sfx_button")
	var r: Dictionary = await Game.buy_sku(sku)
	if not is_inside_tree():
		return
	_set_busy(false)
	if bool(r.get("granted", false)):
		bought_any = true
		_build()
	_show_buy_result(r)


func _show_buy_result(r: Dictionary) -> void:
	match str(r.get("status", "error")):
		"ok":
			if bool(r.granted):
				Sfx.play("sfx_coin")
				toast(tr("shop_buy_ok"))
			else:
				toast(tr("shop_buy_failed"))
		"pending":
			toast(tr("shop_buy_pending"))
		"owned":
			toast(tr("shop_owned"))
		"cancel":
			pass
		_:
			toast(tr("shop_buy_failed"))


func watch_video() -> void:
	if _busy or _closed:
		return
	_set_busy(true)
	var ok: bool = await Game.shop_watch_video()
	if not is_inside_tree():
		return
	_set_busy(false)
	if ok:
		bought_any = true
		Sfx.play("sfx_coin")
		_build()
	elif Game.shop_videos_left() <= 0:
		toast(tr("shop_video_none"))
	else:
		toast(tr("ads_not_available") if Game.last_ad_reason == "not_ready" else tr("ads_failed"))


func restore() -> void:
	if _busy or _closed:
		return
	_set_busy(true)
	var ok: bool = await Game.restore_purchases()
	if not is_inside_tree():
		return
	_set_busy(false)
	_build()
	toast(tr("shop_restore_ok") if ok else tr("shop_restore_none"))


func _set_busy(v: bool) -> void:
	_busy = v
	for b in buy_buttons.values():
		if is_instance_valid(b) and not is_owned_button(b):
			(b as Button).disabled = v
	if is_instance_valid(video_button) and (v or Game.shop_videos_left() > 0):
		video_button.disabled = v
	if is_instance_valid(restore_button):
		restore_button.disabled = v


func is_owned_button(b: Button) -> bool:
	for sku in buy_buttons:
		if buy_buttons[sku] == b:
			return is_owned(sku)
	return false


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
