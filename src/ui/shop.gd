extends Control
## Shop đầy đủ (màn "shop", mở từ L5): gói gold theo giá hôm nay, video gold, gói khác, Restore.
## Chung khung hub (thanh trên, thanh dưới) với Home theo wireframe 6.1, 6.2.
## setup({source}); signal closed({bought: bool, action?}); action: shop, profile, settings, no_lives, ranking.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const SampleData := preload("res://src/ui/sample_data.gd")
const Config := preload("res://src/config.gd")

const PACK_SKUS := ["starter_pack", "level_pack", "rescue_pack", "remove_ads"]
const GOLD_COLS := 3

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
	theme = ThemeKit.make_theme()
	add_child(ThemeKit.make_background())
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	add_child(page)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 8)
	page.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top := HubTop.new()
	top.action.connect(_on_hub_action)
	root.add_child(top)
	coins_label = top.gold_label

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	_add_video_row()

	var catalog: Array = Game.shop_catalog()
	var any_sale := false
	for e in catalog:
		if bool(e.get("sale", false)):
			any_sale = true
	if any_sale:
		var sale := ThemeKit.make_label(tr("shop_sale_weekend"), ThemeKit.FS_BUTTON, ThemeKit.GOLD)
		sale.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(sale)

	_list.add_child(_section(tr("shop_section_gold")))
	var grid := GridContainer.new()
	grid.columns = GOLD_COLS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_list.add_child(grid)
	for e in catalog:
		var tile := _gold_tile(e)
		buy_buttons[str(e.sku)] = tile.button
		(tile.button as Button).pressed.connect(buy.bind(str(e.sku)))
		grid.add_child(tile.panel)

	_list.add_child(_section(tr("shop_section_other")))
	for sku in PACK_SKUS:
		_add_pack_row(sku)

	if Config.ui_preview():
		_add_preview_sections()

	restore_button = ThemeKit.make_button(tr("shop_restore"), "secondary")
	restore_button.pressed.connect(restore)
	_list.add_child(restore_button)

	toast_label = ThemeKit.make_label("", ThemeKit.FS_BODY, ThemeKit.TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	var nav := HubNav.new("shop")
	nav.tab.connect(_on_tab)
	page.add_child(nav)
	nav.refresh()
	close_button = nav.home_btn


## Dải tiêu đề mục (sprite ribbon vàng).
func _section(text: String) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(420, 76)
	p.add_theme_stylebox_override("panel", UiAtlas.box("strip_yellow", Vector4(60, 0, 60, 0), Vector4(56, 2, 56, 16)))
	var l := ThemeKit.make_label(text, ThemeKit.FS_BODY)
	l.add_theme_color_override("font_outline_color", ThemeKit.GOLD_STROKE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Ô gói gold trong lưới 3 cột: khung shop xanh, ảnh gold, số gold, giá. Trả {panel, button}.
func _gold_tile(entry: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiAtlas.box("frame_shop_blue", Vector4(40, 40, 40, 90), Vector4(16, 16, 16, 12)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	v.add_child(ThemeKit.make_icon("shop_" + str(entry.id), 110))
	var gold := ThemeKit.ink_label(tr("shop_gold_pack") % int(entry.gold), ThemeKit.FS_SMALL, ThemeKit.BROWN)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold)
	if bool(entry.get("sale", false)):
		var tag := tr("shop_sale")
		if int(entry.get("sale_percent", 0)) > 0:
			tag = "%s -%d%%" % [tag, int(entry.sale_percent)]
		var t := ThemeKit.ink_label(tag, ThemeKit.FS_SMALL - 4, ThemeKit.INK_DANGER)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	var b := ThemeKit.make_button(str(entry.get("price_text", "")), "primary")
	b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
	v.add_child(b)
	return {"panel": panel, "button": b}


## Mục Figma chưa có logic bán (wireframe 6.2): Hearts, Helper Packs, Bundles. Nút chỉ báo "sắp có".
func _add_preview_sections() -> void:
	_list.add_child(_section(tr("shop_section_hearts")))
	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 8)
	_list.add_child(hearts)
	for h in SampleData.SHOP_HEARTS:
		hearts.add_child(_preview_tile("big_heart_inf" if bool(h.get("infinite", false)) else "big_heart",
			tr("shop_heart_inf") % int(h.hours) if bool(h.get("infinite", false)) else tr("shop_heart_count") % int(h.count), str(h.price)))
	_list.add_child(_section(tr("shop_section_helpers")))
	var packs := HBoxContainer.new()
	packs.add_theme_constant_override("separation", 8)
	_list.add_child(packs)
	for p in SampleData.SHOP_HELPERS:
		var card := _pack_card(str(p.art))
		packs.add_child(card.panel)
		(card.box as VBoxContainer).add_child(ThemeKit.make_icon(str(p.icon), 120))
		var name_l := ThemeKit.ink_label(tr(str(p.title)), ThemeKit.FS_SMALL + 2, ThemeKit.BROWN)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(card.box as VBoxContainer).add_child(name_l)
		(card.box as VBoxContainer).add_child(_soon_button(str(p.price)))
	_list.add_child(_section(tr("shop_section_bundles")))
	for b in SampleData.SHOP_BUNDLES:
		var card := _pack_card(str(b.art))
		_list.add_child(card.panel)
		var title := ThemeKit.ink_label(tr(str(b.title)), ThemeKit.FS_BODY, ThemeKit.BROWN)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(card.box as VBoxContainer).add_child(title)
		var desc := ThemeKit.ink_label(tr("shop_bundle_desc"), ThemeKit.FS_SMALL - 2, ThemeKit.INK_DIM)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(card.box as VBoxContainer).add_child(desc)
		(card.box as VBoxContainer).add_child(_soon_button(str(b.price)))


## Khung gói: thân kem ở trên, đáy màu đặt nút giá. Trả {panel, box}.
func _pack_card(art: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiAtlas.box(art, Vector4(60, 60, 60, 120), Vector4(30, 26, 30, 12)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return {"panel": panel, "box": box}


func _preview_tile(region: String, caption: String, price: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiAtlas.box("frame_shop_blue", Vector4(40, 40, 40, 90), Vector4(16, 16, 16, 12)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	v.add_child(ThemeKit.make_sprite(region, 100))
	var l := ThemeKit.ink_label(caption, ThemeKit.FS_SMALL - 2, ThemeKit.BROWN)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(_soon_button(price))
	return panel


func _soon_button(price: String) -> Button:
	var b := ThemeKit.make_button(price, "primary")
	b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
	b.pressed.connect(func() -> void: toast(tr("common_coming_soon")))
	return b


func _on_hub_action(action: String) -> void:
	Sfx.play("sfx_button")
	if action == "shop":
		return
	_leave(action)


func _on_tab(tab_name: String) -> void:
	match tab_name:
		"home":
			close()
		"ranking":
			_leave("ranking")


## Rời Shop sang màn khác của hub.
func _leave(action: String) -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"bought": bought_any, "action": action})


## Một dòng gói gold: {panel, button}. Dùng chung với shop_mini.
static func make_gold_row(entry: Dictionary, gold_text: String, sale_text: String) -> Dictionary:
	var panel := ThemeKit.make_well()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	h.add_child(ThemeKit.make_icon("shop_" + str(entry.id), ThemeKit.ICON_SIZE))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ThemeKit.ink_label(gold_text, ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
	if bool(entry.get("sale", false)):
		var tag := sale_text
		if int(entry.get("sale_percent", 0)) > 0:
			tag = "%s -%d%%" % [sale_text, int(entry.sale_percent)]
		v.add_child(ThemeKit.ink_label(tag, ThemeKit.FS_SMALL - 2, ThemeKit.INK_DANGER))
		var base_price := str(entry.get("base_price_text", ""))
		if base_price != "":
			var old := RichTextLabel.new()
			old.bbcode_enabled = true
			old.fit_content = true
			old.scroll_active = false
			old.autowrap_mode = TextServer.AUTOWRAP_OFF
			old.add_theme_font_size_override("normal_font_size", ThemeKit.FS_SMALL)
			old.add_theme_color_override("default_color", ThemeKit.INK_DIM)
			old.text = "[s]%s[/s]" % base_price.replace("[", "[lb]")
			v.add_child(old)
	var b := ThemeKit.make_button(str(entry.get("price_text", "")), "primary")
	b.custom_minimum_size = Vector2(170, ThemeKit.MIN_BUTTON.y)
	b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 4)
	h.add_child(b)
	return {"panel": panel, "button": b}


func _add_video_row() -> void:
	var left: int = Game.shop_videos_left()
	var panel := ThemeKit.make_well(ThemeKit.WELL_HOT, ThemeKit.WELL_HEADER)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	h.add_child(ThemeKit.make_icon("ui_gold", 80))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ThemeKit.ink_label(tr("shop_free_gold") % int(Config.ECON.shop_video_coins), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
	var info := ThemeKit.ink_label("", ThemeKit.FS_SMALL - 2, ThemeKit.INK_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	video_button = ThemeKit.make_button(tr("ads_watch"), "video")
	video_button.custom_minimum_size = Vector2(170, 96)
	video_button.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
	video_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	video_button.pressed.connect(watch_video)
	h.add_child(video_button)
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
	var panel := ThemeKit.make_well()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	h.add_child(ThemeKit.make_icon("shop_" + sku, ThemeKit.ICON_SIZE))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(ThemeKit.ink_label(_pack_title(sku), ThemeKit.FS_SMALL + 4, ThemeKit.BROWN))
	var d := ThemeKit.ink_label(_pack_desc(sku), ThemeKit.FS_SMALL - 2, ThemeKit.INK_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var owned := is_owned(sku)
	var b := ThemeKit.make_button(tr("shop_owned") if owned else Platform.price(sku), "primary")
	b.custom_minimum_size = Vector2(170, ThemeKit.MIN_BUTTON.y)
	b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 4)
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
