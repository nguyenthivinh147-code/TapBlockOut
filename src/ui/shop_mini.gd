extends Control
## Shop mini: chỉ gói gold, mở ở mọi level khi người chơi thiếu gold và bấm mua.
## Không có prefab: khung PopupOkLayer cỡ 866x1110 (tiêu đề thu vào trong dải tím) + khung gold hiện có giống
## GoldPanel của HubTop (không có dấu cộng) + lưới gold của ShopCashLayer (SmallPack#2, ô Shop_GoldPack) cho 6 gói.
## Khung, khung gold, lưới, toast là node trong scenes/shop_mini.tscn; các ô gold theo catalog dựng lúc chạy.
## setup({source}); signal closed({bought: bool}). Đóng thì popup gọi quay lại.
## Bought gold flies from its tile's icon to the popup's gold chip (RewardFly: the popup is a "gold" target), which
## counts on as the coins land.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const Shop := preload("res://src/ui/shop.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

const LAYER := "ShopCashLayer"
const C := "GameObject/GameObject/Scroll View/Viewport/Content"

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
## Font size of %Coins saved in the scene; a long balance shrinks from it.
var _coins_font: int = 0
## sku -> gold icon of its tile (RewardFly source).
var _gold_icons: Dictionary = {}


func setup(args: Dictionary) -> void:
	Game.shop_opened("mini_" + str(args.get("source", "")))
	add_to_group(RewardFly.GROUP)
	_build()
	Game.coins_changed.connect(_on_coins_changed)


## RewardFly: gold bought here lands on the popup's gold chip.
func reward_target(kind: String) -> Control:
	return coins_label.get_parent().get_node_or_null("Icon") if kind == "gold" and is_instance_valid(coins_label) else null


## RewardFly: gold landed, the chip counts on.
func reward_refresh() -> void:
	_on_coins_changed(int(Game.s.coins))


func _build() -> void:
	buy_buttons.clear()
	# Frame (size, hidden parts), Coins, GoldGrid and Toast are nodes of scenes/shop_mini.tscn.
	ui = UnityKit.frame(self, tr("shop_mini_title"), close)
	for b in ui.field("closeButtons", "PopupOkUICoreLayer"):
		if (b as Control).name != "Bg":
			close_button = b

	# Gold balance in a chip like HubTop's GoldPanel.
	coins_label = %Coins
	_coins_font = coins_label.get_theme_font_size("font_size")
	_show_coins(int(Game.s.coins))

	var grid: Control = %GoldGrid
	var i := 0
	for e in Game.shop_catalog():
		var tv: RefCounted = UnityKit.add(grid, UnityKit.spec(LAYER, C + "/SmallPack#2/Shop_GoldPack"))
		tv.root.name = "Gold_%s" % str(e.id)
		tv.root.set_meta("u_rt", true)
		# RewardItemSO gold icons Gold1..Gold6, smallest pack first.
		tv.sprite("BG/Icon", "Gold%d" % mini(i + 1, 6))
		_gold_icons[str(e.sku)] = tv.node("BG/Icon")
		tv.text("GoldAmount/GoldQuantity", Shop.fmt_n0(int(e.gold)))
		tv.text("Button_Purchase/Text (TMP)", str(e.get("price_text", "")))
		var b: Button = tv.button("Button_Purchase")
		buy_buttons[str(e.sku)] = b
		b.connect("clicked", buy.bind(str(e.sku)))
		var tag := Shop.sale_tag(e)
		if tag != "":
			var s := UnityKit.spec(LAYER, C + "/StarterPack/SellBadge")
			s.a = true
			var bv: RefCounted = UnityKit.add(tv.root, s, Rect2(-22, -26, 100, 100))
			bv.text("SellBadgeTxt", tag)
		i += 1
	UnityUI.relayout(grid)

	toast_label = %Toast
	toast_label.modulate.a = 0.0


func buy(sku: String) -> void:
	if _busy or _closed:
		return
	# One purchase at a time; only the pressed button greys out (Unity StoreItem locks nothing else).
	_busy = true
	var src: Button = buy_buttons.get(sku)
	if is_instance_valid(src):
		src.call("set_interactable", false)
	Sfx.play("sfx_button")
	var r: Dictionary = await Game.buy_sku(sku)
	if not is_inside_tree():
		return
	_busy = false
	if is_instance_valid(src):
		src.call("set_interactable", true)
	match str(r.get("status", "error")):
		"ok":
			if bool(r.granted):
				bought_any = true
				if RewardFly.launch(null, RewardFly.sku_reward(sku), {"gold": _gold_icons.get(sku)}) == 0:
					Sfx.play("sfx_coin")
				toast(tr("shop_buy_ok"))
			else:
				toast(tr("shop_buy_failed"))
		"pending":
			toast(tr("shop_buy_pending"))
		"cancel", "offline":
			pass
		_:
			toast(tr("shop_buy_failed"))


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
		_show_coins(v)


func _show_coins(v: int) -> void:
	coins_label.text = Shop.fmt_n0(maxi(v - RewardFly.held("gold"), 0))
	coins_label.add_theme_font_size_override("font_size", _coins_font)
	PopupKit.fit_font(coins_label, coins_label.size.x)


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"bought": bought_any})
