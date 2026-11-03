extends Control
## Popup offer dùng chung cho starter_pack, remove_ads, rescue_pack, level_pack.
## setup({id}); không có id thì lấy offer đang mở đầu tiên. signal closed({id, bought}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const Config := preload("res://src/config.gd")

const BOOSTER_ORDER := ["hint", "move", "smash"]

var offer_id: String = ""
var sku: String = ""
var buy_button: Button = null
var later_button: Button = null
var time_label: Label = null
var toast_label: Label = null
var last_toast: String = ""

var _until: int = 0
var _busy: bool = false
var _closed: bool = false
var _toast_tween: Tween = null


func setup(args: Dictionary) -> void:
	offer_id = str(args.get("id", ""))
	var open: Array = Game.offers_open()
	if offer_id == "" and not open.is_empty():
		offer_id = str(open[0].id)
	sku = Game.offer_sku(offer_id)
	for o in open:
		if str(o.id) == offer_id:
			_until = int(o.until)
	_build()


func _title() -> String:
	match offer_id:
		"starter_pack":
			return tr("offer_starter_pack_title")
		"level_pack":
			return tr("offer_level_pack_title")
		"remove_ads":
			return tr("offer_remove_ads_title")
		"rescue_pack":
			return tr("offer_rescue_pack_title")
		"special_pack":
			return tr("offer_special_pack_title")
	return ""


func _body() -> String:
	match offer_id:
		"starter_pack":
			return tr("offer_starter_pack_body")
		"level_pack":
			return tr("offer_level_pack_body")
		"remove_ads":
			return tr("offer_remove_ads_body")
		"rescue_pack":
			return tr("offer_rescue_pack_body")
		"special_pack":
			return tr("offer_special_pack_body")
	return ""


func _booster_name(kind: String) -> String:
	match kind:
		"hint":
			return tr("booster_hint")
		"move":
			return tr("booster_move")
		"smash":
			return tr("booster_smash")
	return kind


## Các dòng nội dung gói: gold và booster.
func contents() -> Array[String]:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var out: Array[String] = []
	var gold := int(info.get("gold", 0))
	if gold > 0:
		out.append(tr("shop_gold_pack") % gold)
	var inv: Dictionary = info.get("inv", {})
	for k in BOOSTER_ORDER:
		if int(inv.get(k, 0)) > 0:
			out.append("%s %s" % [_booster_name(k), tr("booster_count") % int(inv[k])])
	return out


func _build() -> void:
	var k := PopupKit.make(self, _title(), close)
	var v: VBoxContainer = k.box

	v.add_child(ThemeKit.make_icon("shop_" + sku, ThemeKit.ICON_SIZE * 2.0))
	v.add_child(PopupKit.text(_body(), ThemeKit.FS_SMALL + 4))
	v.add_child(_content_tiles())

	time_label = PopupKit.text("", ThemeKit.FS_SMALL, ThemeKit.INK_DIM)
	time_label.visible = false
	v.add_child(time_label)
	_update_time()

	buy_button = ThemeKit.make_button(tr("offer_buy") % Platform.price(sku), "primary")
	buy_button.pressed.connect(buy)
	v.add_child(buy_button)

	later_button = ThemeKit.make_button(tr("offer_no_thanks"), "ghost")
	later_button.pressed.connect(close)
	v.add_child(later_button)

	toast_label = PopupKit.text("", ThemeKit.FS_SMALL, ThemeKit.BROWN)
	toast_label.modulate.a = 0.0
	v.add_child(toast_label)
	_animate_in.call_deferred(k.card)


## Hàng ô thưởng theo nội dung gói: gold rồi từng booster.
func _content_tiles() -> Control:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var tiles: Array = []
	var gold := int(info.get("gold", 0))
	if gold > 0:
		tiles.append(PopupKit.reward_tile(ThemeKit.icon("ui_gold"), tr("shop_gold_pack") % gold, 72))
	var inv: Dictionary = info.get("inv", {})
	for b in BOOSTER_ORDER:
		if int(inv.get(b, 0)) > 0:
			var caption := "%s %s" % [_booster_name(b), tr("booster_count") % int(inv[b])]
			tiles.append(PopupKit.reward_tile(ThemeKit.icon("booster_" + b), caption, 72))
	return PopupKit.row(tiles, 8)


func _process(_delta: float) -> void:
	if _until > 0:
		_update_time()


func _update_time() -> void:
	if _until <= 0 or time_label == null:
		return
	var left := _until - Game.now()
	time_label.visible = left > 0
	if left > 0:
		time_label.text = tr("offer_time_left") % format_time(left)


## h:mm:ss, hoặc m:ss khi dưới 1 giờ.
static func format_time(sec: int) -> String:
	sec = maxi(sec, 0)
	var h := sec / 3600
	var m := (sec % 3600) / 60
	var s := sec % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


func buy() -> void:
	if _busy or _closed or offer_id == "":
		return
	_busy = true
	buy_button.disabled = true
	Sfx.play("sfx_button")
	var r: Dictionary = await Game.offer_buy(offer_id)
	if not is_inside_tree():
		return
	_busy = false
	buy_button.disabled = false
	match str(r.get("status", "error")):
		"ok":
			if bool(r.granted):
				Sfx.play("sfx_coin")
				_finish(true)
			else:
				toast(tr("shop_buy_failed"))
		"pending":
			toast(tr("shop_buy_pending"))
		"cancel":
			pass
		"owned":
			toast(tr("shop_owned"))
		_:
			toast(tr("shop_buy_failed"))


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


func close() -> void:
	_finish(false)


func _finish(bought: bool) -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"id": offer_id, "bought": bought})


func _animate_in(card: Control) -> void:
	if is_instance_valid(card) and card.is_inside_tree():
		ThemeKit.popup_in(card)
