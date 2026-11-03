extends Control
## Shop mini: chỉ gói gold, mở ở mọi level khi người chơi thiếu gold và bấm mua.
## Không có prefab: khung PopupOkLayer (UnityKit) + số gold (GoldQuantityTxt của Shop_GoldBigPack) + lưới gold
## của ShopCashLayer (SmallPack#2, ô Shop_GoldPack) cho 6 gói.
## setup({source}); signal closed({bought: bool}). Đóng thì popup gọi quay lại.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Shop := preload("res://src/ui/shop.gd")

const LAYER := "ShopCashLayer"
const C := "GameObject/GameObject/Scroll View/Viewport/Content"
## Panel: the 806-wide gold grid of ShopCashLayer plus the frame's side borders.
const SIZE := Vector2(866, 1110)
## Under the 130-unit header strip of PopupOkLayer.
const COINS_Y := 120.0
const GRID_Y := 236.0
const TOAST_Y := 972.0

var close_button: Button = null
var toast_label: Label = null
var coins_label: Label = null
## sku -> nút mua
var buy_buttons: Dictionary = {}
var bought_any: bool = false
var last_toast: String = ""
var ui: RefCounted = null

var _busy: bool = false
var _closed: bool = false
var _toast_tween: Tween = null


func setup(args: Dictionary) -> void:
	Game.shop_opened("mini_" + str(args.get("source", "")))
	_build()
	Game.coins_changed.connect(_on_coins_changed)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	buy_buttons.clear()
	ui = UnityKit.popup(self, tr("shop_mini_title"), SIZE, close)
	for b in ui.field("closeButtons", "PopupOkUICoreLayer"):
		if (b as Control).name != "Bg":
			close_button = b
	var content: Control = ui.node("Panel/Content")

	# Gold balance: the big pack's amount text with its coin icon.
	var coins := UnityKit.spec(LAYER, C + "/Shop_GoldBigPack/GoldQuantityTxt")
	coins.n = "Coins"
	var cv: RefCounted = UnityKit.add(content, coins, Rect2((SIZE.x - 200.0) * 0.5 - 36.0, COINS_Y, 200, 99))
	coins_label = cv.root as Label
	coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	UnityUI.set_text(coins_label, Shop.fmt_n0(int(Game.s.coins)))

	var grid_spec := UnityKit.spec(LAYER, C + "/SmallPack#2")
	grid_spec.n = "GoldGrid"
	grid_spec.ch = []
	var gv: RefCounted = UnityKit.add(content, grid_spec, Rect2((SIZE.x - 806.0) * 0.5, GRID_Y, 806, 724))
	var i := 0
	for e in Game.shop_catalog():
		var tv: RefCounted = UnityKit.add(gv.root, UnityKit.spec(LAYER, C + "/SmallPack#2/Shop_GoldPack"))
		tv.root.name = "Gold_%s" % str(e.id)
		# RewardItemSO gold icons Gold1..Gold6, smallest pack first.
		tv.sprite("BG/Icon", "Gold%d" % mini(i + 1, 6))
		tv.text("GoldAmount/GoldQuantity", Shop.fmt_n0(int(e.gold)))
		tv.text("Button_Purchase/Text (TMP)", str(e.get("price_text", "")))
		var b: Button = tv.button("Button_Purchase")
		buy_buttons[str(e.sku)] = b
		b.connect("clicked", buy.bind(str(e.sku)))
		if bool(e.get("sale", false)) and int(e.get("sale_percent", 0)) > 0:
			var s := UnityKit.spec(LAYER, C + "/StarterPack/SellBadge")
			s.a = true
			var bv: RefCounted = UnityKit.add(tv.root, s, Rect2(-22, -26, 100, 100))
			bv.text("SellBadgeTxt", "-%d%%" % int(e.sale_percent))
		i += 1
	UnityUI.relayout(gv.root)

	toast_label = UnityKit.label(content, "", Rect2(60, TOAST_Y, SIZE.x - 120.0, 80), 40.0)
	toast_label.name = "Toast"
	toast_label.modulate.a = 0.0


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
			(b as Button).call("set_interactable", not v)


func toast(text: String) -> void:
	last_toast = text
	if not is_instance_valid(toast_label):
		return
	UnityUI.set_text(toast_label, text)
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)


func _on_coins_changed(v: int) -> void:
	if is_instance_valid(coins_label):
		UnityUI.set_text(coins_label, Shop.fmt_n0(v))


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"bought": bought_any})
