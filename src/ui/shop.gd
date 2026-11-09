extends Control
## Shop đầy đủ (màn "shop", mở từ L5): gói gold theo giá hôm nay, video gold, gói khác, Restore.
## Thân màn là ShopCashLayer của color-cube-match-puzzle (unity_ui.gd): ScrollRect với mục No Ads (thẻ No Ads Bundle và
## Remove Ads; có một trong hai gói thì ẩn cả mục, như ProductBundleBase của Unity), các thẻ gói
## (Starter, Level, Rescue), tiêu đề Gold, gói lớn và lưới gold (FreeGoldPack là video gold mỗi ngày của game).
## Thanh trên, thanh dưới dùng chung với Home (HubTop, HubNav) đè lên trên như CurrencyLayer, BottomBarLayer của Unity.
## scenes/shop.tscn giữ layer đã chỉnh cho game: "BG (2)" ẩn, nền là node Background ở gốc màn (assets/bg/bg_shop.png,
## sọc kẹo pastel hồng tím, phủ cả vùng ngoài safe area), ExitBtn và các thẻ không dùng ẩn, Viewport cắt theo rect, rect chữ thẻ
## Remove Ads và nút video; cùng Toast, khung Hub. Script điền chữ, giá, món theo SKU, thẻ preview, đặt các giá trị
## trùng mặc định của Godot (_defaults); HubTop, HubNav dựng lúc chạy.
## Anim của game đè lên layer (ShopFx, shop_fx.gd): thẻ hiện lần lượt khi mở màn, icon gold nổi, nhãn sale lắc, vệt sáng
## quét nút giá; gold vừa mua hoặc xem video bay từ thẻ lên chip gold của HubTop; giá đổi sang Owned thì nảy.
## setup({source}); signal closed({bought: bool, action?}); action: shop, profile, settings, lives, ranking.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const SampleData := preload("res://src/ui/sample_data.gd")
const Config := preload("res://src/config.gd")
const ShopFx := preload("res://src/ui/shop_fx.gd")

const LAYER := "ShopCashLayer"
const PANEL := "GameObject"
const SCROLL := "GameObject/GameObject/Scroll View"
const C := "GameObject/GameObject/Scroll View/Viewport/Content"
const POPUP_REWARD := "res://scenes/popup_reward.tscn"
const PACK_SKUS := ["starter_pack", "level_pack", "rescue_pack", "remove_ads", "remove_ads_bundle"]
## The No Ads section (title, Shop_RemoveAdsBundle, Shop_RemoveAds). Like ProductBundleBase, owning either no_ads
## SKU hides all of it.
const NO_ADS_NODES := ["NoAdsTitle", "Shop_RemoveAdsBundle", "Shop_RemoveAds"]
## Booster slots of the Shop_RemoveAdsBundle card's second row (same in ShopCashLayer and PopupRemoveAds): path under
## ItemContainer, its booster image. Left to right the prefab places Capacity, Magnet, Storage (Plus#2 between the
## first two, Plus between the last two), so the boosters read hint, move, smash like the other cards.
const NO_ADS_BOOSTERS := {
	"hint": ["Row(Clone)#2/ShopRewardItem(Clone)#3", "ImgBoosterCapacity"],
	"move": ["Row(Clone)#2/ShopRewardItem(Clone)", "ImgBoosterMagnet"],
	"smash": ["Row(Clone)#2/ShopRewardItem(Clone)#2", "ImgBoosterStorage"],
}
## Shop_RemoveAds description centre x from the card centre: right of the ADS icon (rect 393.7 wide, card 806).
const NO_ADS_DESC_X := 159.2
## ShopCashLayer card for each pack (remove_ads, remove_ads_bundle have their own Shop_RemoveAds* cards).
## Shop sections Helper Packs and Bundles (_add_pack_sections). helper_epic and bundle_sweet, bundle_tasty,
## bundle_yummy are hidden from the Shop (user request 2026-11-09; the SKUs stay in Config.SKUS); a section with no
## SKU shows no title.
const HELPER_SKUS := ["helper_great"]
const BUNDLE_SKUS := []
const PACK_CARDS := {"starter_pack": "StarterPack", "level_pack": "SpecialPack", "rescue_pack": "BundleSweet"}
## UIShopCashLayer.SetupLayerData: the panel is 183 units shorter when the bottom bar shows. HubNav is taller
## than Unity's BottomBarLayer, so the panel loses the height of HubNav's bar (182 of its 886-wide frame) when larger.
const BOTTOM_BAR := 183.0
const NAV_BAR_FRAME := Vector2(886, 182)
## UIShopCashLayer.ShowLayer fades the scroll view in.
const FADE_IN := 0.3
## RewardItemSO gold icons: IAPProductSO gives cube.sort.color.gold.N the gold ItemId N.
const GOLD_ICONS := ["Gold1", "Gold2", "Gold3", "Gold4", "Gold5"]
const HEART_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_15"
const HEART_INF_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_16"
const BOOSTERS := ["hint", "move", "smash"]
## ShopProductSetup: rewardPerRow 3, rows 104 high, VerticalLayoutGroup spacing 20, HorizontalLayoutGroup spacing 2.
const PER_ROW := 3
const ROW_H := 104.0
const ROW_GAP := 20.0
const ITEM_GAP := 2.0
## BonusItem clones baked into the StarterPack card: gold (100), booster (80), infinite heart (80), plus (28).
const ITEM_GOLD := "/StarterPack/ItemContainer/Row(Clone)/ShopRewardItem(Clone)"
const ITEM_BOOSTER := "/StarterPack/ItemContainer/Row(Clone)#2/ShopRewardItem(Clone)"
const ITEM_HEART := "/StarterPack/ItemContainer/Row(Clone)/ShopRewardItem(Clone) (1)"
const ITEM_PLUS := "/StarterPack/ItemContainer/Row(Clone)/Plus(Clone)"
## Hub actions main.gd answers with a popup over the Shop: the Shop stays the current screen and keeps taking taps.
const STAY_ACTIONS := ["lives", "settings"]

var close_button: Button = null
var video_button: Button = null
var restore_button: Button = null
var toast_label: Label = null
var coins_label: Label = null
## sku -> nút mua
var buy_buttons: Dictionary = {}
## sku -> chữ giá trên nút mua
var price_labels: Dictionary = {}
var bought_any: bool = false
var last_toast: String = ""
var ui: RefCounted = null
## ShopFx (shop_fx.gd), anim của game trên màn.
var fx: Control = null

var _source: String = ""
var _busy: bool = false
var _closed: bool = false
var _toast_tween: Tween = null
var _video_text: Label = null
var _top: Control = null
## sku -> node gold bay lên chip khi mua (icon gold của ô hoặc thẻ, không có thì nút mua)
var _gold_from: Dictionary = {}
var _video_icon: Control = null
## sku -> đang hiện Owned (đổi sang true thì giá nảy)
var _owned: Dictionary = {}


func setup(args: Dictionary) -> void:
	_source = str(args.get("source", ""))
	Game.shop_opened(_source)
	_build()
	Game.coins_changed.connect(_on_coins_changed)


func _build() -> void:
	buy_buttons.clear()
	price_labels.clear()
	_gold_from.clear()
	theme = ThemeKit.make_theme()
	# The layer as the shop shows it is saved in scenes/shop.tscn (see the header), with Toast and the Hub
	# containers; this fills texts, prices and items. Prefab nodes keep their Unity names in the scene (an
	# instanced scene's nodes cannot be renamed), so renames happen here.
	ui = UnityUI.build(self, LAYER, {"reveal": false})
	_fit_panel()
	_defaults()

	var catalog: Array = Game.shop_catalog()
	ui.text(C + "/NoAdsTitle/Text (TMP)", tr("shop_remove_ads"))
	_remove_ads_cards()
	ui.text(C + "/BundleTitle/Text (TMP)", tr("shop_section_other"))
	for sku in PACK_CARDS:
		_pack_card(str(PACK_CARDS[sku]), sku)
	ui.text(C + "/GoldTitle/Text (TMP)", tr("shop_section_gold"))
	_gold_cards(catalog)
	_video_card()
	_restore_row()
	_add_pack_sections()
	_pass_scroll_buttons()
	ui.relayout(C)
	_fade_in()

	toast_label = %Toast
	toast_label.modulate.a = 0.0
	_fit_panel()

	_hub_bars()
	_animate()
	if not resized.is_connected(_fit_panel):
		resized.connect(_fit_panel)


## ShopFx over the layer and the bars (last child): the content's cards pop in, the loops start.
func _animate() -> void:
	fx = ShopFx.new()
	add_child(fx)
	fx.top = _top
	var content: Control = ui.node(C)
	fx.enter(content.get_children())
	fx.idle(content)


## Changes to the layer's nodes that set a Godot default value: the scene does not keep those as overrides of an
## instanced scene's nodes, so they are made here.
func _defaults() -> void:
	# Builder gap: a Mask inside the Viewport's Mask does not clip in Godot (nested clip_children), so the
	# rectangular Viewport mask clips by rect (and its graphic is clear) and the cards' BlurredBorder masks work.
	ui.node(SCROLL + "/Viewport").clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	for t in ["/NoAdsTitle/Text (TMP)", "/BundleTitle/Text (TMP)", "/GoldTitle/Text (TMP)"]:
		one_line(ui.label(C + t))
	# One line like "10,000" in the prefab: bigger amounts grow past the rect instead of wrapping.
	ui.label(C + "/Shop_GoldBigPack/GoldQuantityTxt").autowrap_mode = TextServer.AUTOWRAP_OFF
	# RestorePurchase is hidden in the prefab (see _restore_row).
	ui.show(C + "/RestorePurchase", true)


func _fit_panel() -> void:
	if ui == null or not is_instance_valid(ui.node(PANEL)):
		return
	var w := size.x if size.x > 0.0 else 720.0
	var vp := size if size.y > 0.0 else Vector2(720, 1280)
	var bar := NAV_BAR_FRAME.y * w / NAV_BAR_FRAME.x / UnityUI.canvas_scale(vp)
	UnityKit.set_size(ui.node(PANEL), Vector2(0, -maxf(BOTTOM_BAR, bar)))
	if is_instance_valid(toast_label):
		_anchor(toast_label, Vector2(0, 0), Vector2(1, 0), Vector2(0, maxf(BOTTOM_BAR, bar) + 90.0), Vector2(-120, 120))


## HubTop and HubNav over the layer, like Home (CurrencyLayer and BottomBarLayer sit over ShopCashLayer in Unity).
## The Hub VBoxContainer and its HubMargin are nodes of the scene; the bars are built here.
func _hub_bars() -> void:
	var page: Control = %Hub
	# UnityUI.build moves the layer's Canvas above the screen's other children: the bars go back on top.
	move_child(page, -1)
	var top: HubTop = HubTop.create()
	top.set_meta("u_rt", true)
	top.hide_side_buttons()
	top.action.connect(_on_hub_action)
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	%HubMargin.add_child(top)
	_top = top
	coins_label = top.gold_label
	var nav: HubNav = HubNav.create("shop")
	nav.set_meta("u_rt", true)
	nav.tab.connect(_on_tab)
	page.add_child(nav)
	nav.refresh()
	close_button = nav.home_btn


func _fade_in() -> void:
	var sv: Control = ui.node(SCROLL)
	sv.modulate.a = 0.0
	_fade_later.call_deferred(sv)


func _fade_later(sv: Control) -> void:
	if is_instance_valid(sv) and sv.is_inside_tree():
		sv.create_tween().tween_property(sv, "modulate:a", 1.0, FADE_IN)
	elif is_instance_valid(sv):
		sv.modulate.a = 1.0


## Builder gap: buttons added after build() into a ScrollRect content keep MOUSE_FILTER_STOP and would eat drags.
func _pass_scroll_buttons() -> void:
	for b in ui.node(C).find_children("*", "Button", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_PASS


func _anchor(c: Control, amin: Vector2, amax: Vector2, pos: Vector2, sz: Vector2) -> void:
	var r: Dictionary = c.get_meta("u_rect")
	r.amin = amin
	r.amax = amax
	r.pos = pos
	r.size = sz
	UnityUI.apply_rect(c)


# --- cards ---

## The No Ads section: bundle card (remove_ads_bundle, hidden in the scene) and the plain card (remove_ads).
func _remove_ads_cards() -> void:
	var b := C + "/Shop_RemoveAdsBundle"
	ui.text(b + "/PackName", _pack_title("remove_ads_bundle"))
	# No discounted bundle SKU in the game: no sale badge, no struck price.
	ui.show(b + "/SellBadge", false)
	ui.show(b + "/Button_Purchase/DiscountLine", false)
	_gold_from["remove_ads_bundle"] = fill_no_ads_bundle(ui, b)
	_buy_button(b + "/Button_Purchase", "remove_ads_bundle")
	var p := C + "/Shop_RemoveAds"
	ui.text(p + "/PackName", tr("shop_remove_ads"))
	# One game sentence instead of three short lines: in the scene the description takes the rect of all three.
	# The scene centres that rect on the card, so the text starts over the ADS icon: move it right of the icon.
	var d: Label = ui.label(p + "/Description")
	var r: Dictionary = (d.get_meta("u_rect") as Dictionary).duplicate()
	r.pos = Vector2(NO_ADS_DESC_X, (r.pos as Vector2).y)
	d.set_meta("u_rect", r)
	UnityUI.apply_rect(d)
	ui.text(p + "/Description", _pack_desc("remove_ads"))
	_buy_button(p + "/Button_Purchase", "remove_ads")
	_show_no_ads()


## Shows the No Ads section while neither no_ads SKU is owned. True if its visibility changed.
func _show_no_ads() -> bool:
	var want := not bool(Game.s.get("no_ads", false))
	var changed := false
	for n in NO_ADS_NODES:
		var c: Control = ui.node(C + "/" + str(n))
		changed = changed or c.visible != want
		c.visible = want
	return changed


## The Shop_RemoveAdsBundle card (ShopCashLayer and PopupRemoveAds) at `card`: Config.SKUS.remove_ads_bundle's gold
## and boosters in the card's slots (first row gold + No Ads, second row the boosters); empty slots hide.
## Returns the gold item, for the gold that flies to the chip.
static func fill_no_ads_bundle(u: RefCounted, card: String) -> Control:
	var items := card + "/ItemContainer"
	var info: Dictionary = Config.SKUS.get("remove_ads_bundle", {})
	var gold := int(info.get("gold", 0))
	var gold_item := items + "/Row(Clone)/ShopRewardItem(Clone) (1)"
	u.show(gold_item, gold > 0)
	u.show(items + "/Row(Clone)/Plus(Clone)", gold > 0)
	u.text(gold_item + "/Text (TMP)", fmt_n0(gold))
	var inv: Dictionary = info.get("inv", {})
	var shown := 0
	for k in NO_ADS_BOOSTERS:
		var slot: Array = NO_ADS_BOOSTERS[k]
		var path := items + "/" + str(slot[0])
		var n := int(inv.get(k, 0))
		u.show(path, n > 0)
		if n <= 0:
			continue
		shown += 1
		u.texture(path + "/" + str(slot[1]), ThemeKit.icon("booster_" + k))
		u.text(path + "/Text (TMP)", TranslationServer.translate("booster_count") % n)
	u.show(items + "/Row(Clone)#2", shown > 0)
	# A plus between two shown neighbours only.
	u.show(items + "/Row(Clone)#2/Plus(Clone)#2", int(inv.get("hint", 0)) > 0 and int(inv.get("move", 0)) > 0)
	u.show(items + "/Row(Clone)#2/Plus(Clone)", int(inv.get("move", 0)) > 0 and int(inv.get("smash", 0)) > 0)
	u.relayout(items)
	return u.node(gold_item)


func _pack_card(card: String, sku: String) -> void:
	var p := C + "/" + card
	ui.text(p + "/PackName", _pack_title(sku))
	var ic: Control = ui.node(p + "/ItemContainer")
	fill_items(ic, sku_items(sku))
	var gold_item := ic.get_node_or_null("Item_gold")
	if gold_item != null:
		_gold_from[sku] = gold_item
	_buy_button(p + "/Button_Purchase", sku)


func _buy_button(path: String, sku: String) -> void:
	var b: Button = ui.button(path)
	buy_buttons[sku] = b
	price_labels[sku] = ui.label(path + "/Text (TMP)")
	b.connect("clicked", buy.bind(sku))
	if not _gold_from.has(sku):
		_gold_from[sku] = b
	_show_owned(sku)


func _show_owned(sku: String) -> void:
	var owned := is_owned(sku)
	var l: Label = price_labels.get(sku)
	if l != null:
		UnityUI.set_text(l, tr("shop_owned") if owned else Platform.price(sku))
	var b: Button = buy_buttons.get(sku)
	if b != null:
		b.call("set_interactable", not owned)
	var was := bool(_owned.get(sku, owned))
	_owned[sku] = owned
	if owned and not was and fx != null:
		fx.pop(l)


## Shop_GoldBigPack takes the biggest pack, the grid tiles (Shop_GoldPack .. (4)) the others in order.
func _gold_cards(catalog: Array) -> void:
	var tiles := ["Shop_GoldPack", "Shop_GoldPack (1)", "Shop_GoldPack (2)", "Shop_GoldPack (3)", "Shop_GoldPack (4)"]
	var any_sale := false
	for i in catalog.size():
		var e: Dictionary = catalog[i]
		any_sale = any_sale or bool(e.get("sale", false))
		var sku := str(e.sku)
		var p := ""
		if i == catalog.size() - 1 or i >= tiles.size():
			p = C + "/Shop_GoldBigPack"
			ui.text(p + "/GoldQuantityTxt", fmt_n0(int(e.gold)))
			_gold_from[sku] = ui.node(p + "/GoldQuantityTxt/Image (1)")
		else:
			p = C + "/SmallPack#2/" + str(tiles[i])
			ui.sprite(p + "/BG/Icon", str(GOLD_ICONS[mini(i, GOLD_ICONS.size() - 1)]))
			ui.text(p + "/GoldAmount/GoldQuantity", fmt_n0(int(e.gold)))
			_gold_from[sku] = ui.node(p + "/BG/Icon")
		var b: Button = ui.button(p + "/Button_Purchase")
		buy_buttons[sku] = b
		price_labels[sku] = ui.label(p + "/Button_Purchase/Text (TMP)")
		UnityUI.set_text(price_labels[sku], str(e.get("price_text", "")))
		b.connect("clicked", buy.bind(sku))
		var tag := sale_tag(e)
		if tag != "":
			_sale_badge(ui.node(p), tag)
	# Weekend sale: the big pack's PopularTag ribbon carries the game's sale line.
	ui.show(C + "/Shop_GoldBigPack/PopularTag", any_sale)
	ui.text(C + "/Shop_GoldBigPack/PopularTag/PopularTag", tr("shop_sale_weekend"))


## Sale badge text of a gold pack (entry of Game.shop_catalog): "-50%" for a `_sale` SKU cheaper than the plain one,
## "x2" (or "+N%") for one at the same price with more gold, "" when the pack is not on sale.
static func sale_tag(e: Dictionary) -> String:
	if not bool(e.get("sale", false)):
		return ""
	if int(e.get("sale_percent", 0)) > 0:
		return "-%d%%" % int(e.sale_percent)
	var base := int(e.get("base_gold", 0))
	var gold := int(e.get("gold", 0))
	if base <= 0 or gold <= base:
		return ""
	if gold % base == 0:
		@warning_ignore("integer_division")
		return "x%d" % (gold / base)
	return "+%d%%" % roundi(100.0 * (gold - base) / base)


## SellBadge of the pack cards (StarterPack/SellBadge), at the tile's top-left corner like on the cards.
func _sale_badge(parent: Control, text: String) -> void:
	var s := UnityKit.spec(LAYER, C + "/StarterPack/SellBadge")
	s.a = true
	var v: RefCounted = UnityKit.add(parent, s, Rect2(-22, -26, 100, 100))
	v.root.set_meta("u_rt", true)
	v.text("SellBadgeTxt", text)


## FreeGoldPack = ADS Daily: shop_video_coins gold per video, shop_video_max videos a day.
func _video_card() -> void:
	var p := C + "/SmallPack#2/FreeGoldPack"
	ui.node(p).name = "AdsDaily"
	ui.text(p + "/GoldQuantity", fmt_n0(int(Config.ECON.shop_video_coins)))
	video_button = ui.button(p + "/Button_Ads")
	video_button.connect("clicked", watch_video)
	_video_icon = video_button.get_parent().get_node_or_null("BG/Icon")
	# The game's "Watch video" is longer than Unity's "0/5": the scene moves it right of the TV icon.
	ui.text(p + "/Button_Ads/Text (TMP)", tr("ads_daily_watch"))
	_video_text = ui.label(p + "/Image/Text (TMP)")
	_refresh_video()
	if Game.shop_videos_left() > 0:
		Game.offer_video("shop_coins")


func _refresh_video() -> void:
	var total := int(Config.ECON.shop_video_max)
	var left: int = Game.shop_videos_left()
	if is_instance_valid(_video_text):
		UnityUI.set_text(_video_text, tr("ads_daily_progress") % [total - left, total])
	if is_instance_valid(video_button):
		video_button.call("set_interactable", left > 0 and not _busy)


## RestorePurchase (iOS only in Unity); the game offers it on every platform.
func _restore_row() -> void:
	var p := C + "/RestorePurchase"
	ui.text(p + "/Button/Text (TMP)", tr("shop_restore"))
	restore_button = ui.button(p + "/Button")
	restore_button.connect("clicked", restore)


# --- ShopProductSetup ---

## Builder gap: with word wrap on, fit_text keeps a size whose single line it measures as fitting, then the Label
## wraps it onto a second line (Vietnamese ribbon titles, Unity's own "MIỄN PHÍ"). Short labels stay on one line
## and auto size by width. The text spec is shared with the layout cache, so it is copied first.
static func one_line(l: Label) -> void:
	if l == null:
		return
	var t: Dictionary = (l.get_meta("u_txt") as Dictionary).duplicate(true)
	t.w = false
	l.set_meta("u_txt", t)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	UnityUI.set_text(l, l.text)

## C# ToString("N0") as the Unity shop shows amounts: 1234567 -> "1,234,567" (separator per language,
## ThemeKit.thousands_sep: Vietnamese "1.234.567").
static func fmt_n0(n: int) -> String:
	var sep := ThemeKit.thousands_sep()
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = sep + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## [[kind, amount], ...] of a SKU: gold, then hint, move, smash.
static func sku_items(sku: String) -> Array:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var out: Array = []
	if int(info.get("gold", 0)) > 0:
		out.append(["gold", int(info.gold)])
	var inv: Dictionary = info.get("inv", {})
	for k in BOOSTERS:
		if int(inv.get(k, 0)) > 0:
			out.append([k, int(inv[k])])
	# Unlimited lives (bundles): shown in hours.
	if int(info.get("inf_min", 0)) > 0:
		out.append(["heart_inf", maxi(1, int(round(float(info.inf_min) / 60.0)))])
	return out


## ShopProductSetup.SetupItem: the baked rows are replaced by rows of BonusItem copies (first row holds the
## remainder, then rows of PER_ROW, a Plus between items), centred like its layout groups.
## items: [[kind, amount]]; kind gold, hint, move, smash, heart (amount lives) or heart_inf (amount hours).
static func fill_items(ic: Control, items: Array) -> void:
	for c in ic.get_children():
		if c is Control and (c as Control).has_meta("u"):
			(c as Control).visible = false
	var rows: Array = []
	var i := 0
	var n := items.size() % PER_ROW
	if n == 0:
		n = PER_ROW
	while i < items.size():
		rows.append(items.slice(i, i + n))
		i += n
		n = PER_ROW
	var box := UnityUI.rect_size(ic)
	var y := (box.y - (rows.size() * ROW_H + maxi(0, rows.size() - 1) * ROW_GAP)) * 0.5
	for row in rows:
		var specs: Array = []
		for j in row.size():
			if j > 0:
				specs.append(UnityKit.spec(LAYER, C + ITEM_PLUS))
			specs.append(item_spec(row[j]))
		var w := 0.0
		for s in specs:
			w += float(s.r[6])
		w += ITEM_GAP * (specs.size() - 1)
		var x := (box.x - w) * 0.5
		for j in specs.size():
			var s: Dictionary = specs[j]
			var sz := Vector2(float(s.r[6]), float(s.r[7]))
			var v: RefCounted = UnityKit.add(ic, s, Rect2(Vector2(x, y + (ROW_H - sz.y) * 0.5), sz))
			v.root.set_meta("u_rt", true)
			if j % 2 == 0:
				_item_fill(v, row[j / 2])
			x += sz.x + ITEM_GAP
		y += ROW_H + ROW_GAP


## Spec of the BonusItem for one reward.
static func item_spec(item: Array) -> Dictionary:
	match str(item[0]):
		"gold":
			return UnityKit.spec(LAYER, C + ITEM_GOLD)
		"heart", "heart_inf":
			return UnityKit.spec(LAYER, C + ITEM_HEART)
	return UnityKit.spec(LAYER, C + ITEM_BOOSTER)


## PopupRewardItem.SetupData: icon and quantity (gold "N0", boosters "x1", hearts "x5" or "1h").
static func _item_fill(v: RefCounted, item: Array) -> void:
	var kind := str(item[0])
	var n := int(item[1])
	var root: Control = v.root
	root.name = "Item_" + kind
	match kind:
		"gold":
			v.text("Text (TMP)", fmt_n0(n))
		"heart", "heart_inf":
			v.sprite("ImgVoHanTim", HEART_INF_ICON if kind == "heart_inf" else HEART_ICON)
			v.text("Text (TMP)", (TranslationServer.translate("shop_heart_inf") % n) if kind == "heart_inf" \
				else TranslationServer.translate("shop_heart_count") % n)
		_:
			# The game's booster icon in the magnet's image slot (its size animation stays).
			v.texture("ImgBoosterMagnet", ThemeKit.icon("booster_" + kind))
			v.text("Text (TMP)", TranslationServer.translate("booster_count") % n)


# --- Helper Packs, Bundles (wireframe 6.2) ---

## Helper Packs and Bundles (Config.SKUS helper_*, bundle_*: design.md mục 7) after the other packs, as copies of the
## bundle cards (GreatPack / EpicPack are unfinished in the prefab: white placeholder art). The Hearts section
## (wireframe 6.1) is not wired to logic yet: debug builds only (Config.ui_preview), buttons say "coming soon".
func _add_pack_sections() -> void:
	var content: Control = ui.node(C)
	var at: int = ui.node(C + "/BundleSweet").get_index() + 1
	if Config.ui_preview():
		at = _add_heart_preview(content, at)
	if not HELPER_SKUS.is_empty():
		at = _preview_title(content, at, tr("shop_section_helpers"))
	for i in HELPER_SKUS.size():
		at = _pack_copy(content, at, str(HELPER_SKUS[i]), str(["BundleTasty", "BundleYummy"][mini(i, 1)]), "HelperOffer")
	if not BUNDLE_SKUS.is_empty():
		at = _preview_title(content, at, tr("shop_section_bundles"))
	var bundles := ["BundleSweet", "BundleTasty", "BundleYummy"]
	for i in BUNDLE_SKUS.size():
		at = _pack_copy(content, at, str(BUNDLE_SKUS[i]), str(bundles[mini(i, bundles.size() - 1)]), "")


## A copy of a bundle card selling sku (the real BundleSweet card sells the rescue pack): name, contents, price.
func _pack_copy(content: Control, at: int, sku: String, card: String, art: String) -> int:
	var s := UnityKit.spec(LAYER, C + "/" + card)
	s.a = true
	var v: RefCounted = UnityKit.add(content, s)
	v.root.name = "Pack_" + sku
	v.root.set_meta("u_rt", true)
	content.move_child(v.root, at)
	v.text("PackName", _pack_title(sku))
	if art != "":
		v.sprite("Image (2)", art)
	var ic: Control = v.node("ItemContainer")
	fill_items(ic, sku_items(sku))
	var b: Button = v.button("Button_Purchase")
	buy_buttons[sku] = b
	price_labels[sku] = v.label("Button_Purchase/Text (TMP)")
	b.connect("clicked", buy.bind(sku))
	var gold_item := ic.get_node_or_null("Item_gold")
	_gold_from[sku] = gold_item if gold_item != null else b
	_show_owned(sku)
	return at + 1


func _add_heart_preview(content: Control, at: int) -> int:
	at = _preview_title(content, at, tr("shop_section_hearts"))
	var grid := UnityKit.add(content, UnityKit.spec(LAYER, C + "/SmallPack#2"))
	grid.root.name = "HeartPacks"
	grid.root.set_meta("u_rt", true)
	content.move_child(grid.root, at)
	at += 1
	for c in grid.root.get_children():
		(c as Control).visible = false
	for h in SampleData.SHOP_HEARTS:
		var inf := bool(h.get("infinite", false))
		var t := UnityKit.add(grid.root, UnityKit.spec(LAYER, C + "/SmallPack#2/Shop_GoldPack"))
		t.sprite("BG/Icon", HEART_INF_ICON if inf else HEART_ICON)
		t.text("GoldAmount/GoldQuantity", tr("shop_heart_inf") % int(h.hours) if inf else tr("shop_heart_count") % int(h.count))
		t.text("Button_Purchase/Text (TMP)", str(h.price))
		t.on_click("Button_Purchase", toast.bind(tr("common_coming_soon")))
	return at


func _preview_title(content: Control, at: int, text: String) -> int:
	var v := UnityKit.add(content, UnityKit.spec(LAYER, C + "/BundleTitle"))
	v.root.set_meta("u_rt", true)
	one_line(v.label("Text (TMP)"))
	v.text("Text (TMP)", text)
	content.move_child(v.root, at)
	return at + 1


# --- hub ---

func _on_hub_action(action: String) -> void:
	Sfx.play("sfx_button")
	if action == "shop":
		return
	_leave(action)


func _on_tab(tab_name: String) -> void:
	match tab_name:
		"home":
			close()
		"road_trip":
			_leave("road_trip")


## Rời Shop sang màn khác của hub; action trong STAY_ACTIONS chỉ mở popup trên Shop nên không khoá Shop.
func _leave(action: String) -> void:
	if _closed:
		return
	_closed = not STAY_ACTIONS.has(action)
	closed.emit({"bought": bought_any, "action": action})


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
		"remove_ads_bundle":
			return tr("shop_remove_ads_bundle")
	if sku.begins_with("helper_") or sku.begins_with("bundle_"):
		return tr("shop_" + sku)
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
			# No gold in the pack any more: the offer's sentence (no full-screen ads, one-time purchase).
			return tr("offer_remove_ads_body")
	return ""


## Món mua một lần đã có trong bản lưu.
func is_owned(sku: String) -> bool:
	if bool(Config.SKUS.get(sku, {}).get("consumable", true)):
		return false
	if bool(Config.SKUS.get(sku, {}).get("no_ads", false)) and bool(Game.s.get("no_ads", false)):
		return true
	for e in Game.s.buys:
		if e is Dictionary and str(e.get("sku", "")) == sku:
			return true
	return false


## Cập nhật trạng thái sau mua, xem video, restore (giữ vị trí cuộn).
func _refresh() -> void:
	for sku in PACK_SKUS:
		if buy_buttons.has(sku):
			_show_owned(sku)
	if _show_no_ads():
		ui.relayout(C)
	_refresh_video()


func buy(sku: String) -> void:
	if _busy or _closed:
		return
	_set_busy(true)
	Sfx.play("sfx_button")
	var before := int(Game.s.coins)
	var r: Dictionary = await Game.buy_sku(sku)
	if not is_inside_tree():
		return
	_set_busy(false)
	var flew := false
	if bool(r.get("granted", false)):
		bought_any = true
		# Gold leaves its card before _refresh hides a bought No Ads section.
		flew = _fly_gold(_gold_from.get(sku), int(Game.s.coins) - before)
		_refresh()
		# Purchase Success (wireframe 6.3) for packs with boosters or lives; gold packs only fly their gold.
		var items := sku_items(sku)
		if items.size() > 1 or (items.size() == 1 and str(items[0][0]) != "gold"):
			_show_reward(sku)
	_show_buy_result(r, flew)


func _show_reward(sku: String) -> void:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var args := {"view": {"title": "shop_buy_ok", "reward": {"coins": int(info.get("gold", 0)),
		"items": info.get("inv", {}), "inf_min": int(info.get("inf_min", 0))}}}
	var host := get_parent()
	if host != null and host.has_method("open_popup"):
		host.call("open_popup", POPUP_REWARD, args)


## Gold vừa vào ví bay từ `from` lên chip gold (ShopFx); false thì không bay, bên gọi tự phát tiếng xu.
func _fly_gold(from: Variant, gold: int) -> bool:
	return fx != null and from is Control and is_instance_valid(from) and fx.fly_gold(from, gold)


## flew: gold đang bay lên chip, tiếng xu phát khi từng đồng chạm chip.
func _show_buy_result(r: Dictionary, flew: bool = false) -> void:
	match str(r.get("status", "error")):
		"ok":
			if bool(r.granted):
				if not flew:
					Sfx.play("sfx_coin")
				toast(tr("shop_buy_ok"))
			else:
				toast(tr("shop_buy_failed"))
		"pending":
			toast(tr("shop_buy_pending"))
		"owned":
			toast(tr("shop_owned"))
		"cancel", "offline":
			pass
		_:
			toast(tr("shop_buy_failed"))


func watch_video() -> void:
	if _busy or _closed:
		return
	_set_busy(true)
	var before := int(Game.s.coins)
	var ok: bool = await Game.shop_watch_video()
	if not is_inside_tree():
		return
	_set_busy(false)
	if ok:
		bought_any = true
		if not _fly_gold(_video_icon, int(Game.s.coins) - before):
			Sfx.play("sfx_coin")
		_refresh()
	elif Game.shop_videos_left() <= 0:
		toast(tr("shop_video_none"))
	else:
		if not Game.notice_shown(Game.last_ad_reason):
			toast(tr("ads_failed"))


func restore() -> void:
	if _busy or _closed:
		return
	_set_busy(true)
	var ok: bool = await Game.restore_purchases()
	if not is_inside_tree():
		return
	_set_busy(false)
	_refresh()
	toast(tr("shop_restore_ok") if ok else tr("shop_restore_none"))


func _set_busy(v: bool) -> void:
	_busy = v
	for b in buy_buttons.values():
		if is_instance_valid(b) and not is_owned_button(b):
			(b as Button).call("set_interactable", not v)
	_refresh_video()
	if is_instance_valid(restore_button):
		restore_button.call("set_interactable", not v)


func is_owned_button(b: Button) -> bool:
	for sku in buy_buttons:
		if buy_buttons[sku] == b:
			return is_owned(sku)
	return false


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


## While gold flies, the chip counts on its own (HubTop.gold_shown, ShopFx).
func _on_coins_changed(v: int) -> void:
	if is_instance_valid(coins_label) and not (fx != null and fx.flying()):
		coins_label.text = str(v)


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"bought": bought_any})
