extends Control
## Shop đầy đủ (màn "shop", mở từ Config.UNLOCK.shop, L11): gói gold theo giá hôm nay, video gold, gói khác, Restore.
## Thân màn là ShopCashLayer của color-cube-match-puzzle (unity_ui.gd): ScrollRect với mục No Ads (thẻ No Ads Bundle và
## Remove Ads; có một trong hai gói thì ẩn cả mục, như ProductBundleBase của Unity), các thẻ gói
## (Starter, Level, Rescue: chỉ hiện khi đủ điều kiện của offer, Game.offer_in_shop; không thẻ nào thì ẩn cả tiêu đề),
## Helper Packs và Bundles (đang không bán gói nào nên ẩn), tiêu đề Gold, gói lớn và lưới gold (FreeGoldPack là video
## gold mỗi ngày của game). Gói mua một lần (consumable false) đã sở hữu thì ẩn thẻ, kể cả ngay sau khi mua.
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
const RewardFly := preload("res://src/ui/reward_fly.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")

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
## Shop sections Helper Packs and Bundles (_add_pack_sections). helper_epic and bundle_sweet, bundle_tasty,
## bundle_yummy are hidden from the Shop (user request 2026-11-09; the SKUs stay in Config.SKUS); helper_great is sold
## only in the out-of-moves popup (user request 2026-11-10). A section with no SKU on sale (boosters_open, not owned)
## shows no title.
const HELPER_SKUS := []
const BUNDLE_SKUS := []
## Hearts section (wireframe 6.1, heart packs): off in every build, debug included (user request 2026-11-10).
const SHOW_HEARTS := false
## Section titles sit this much closer to the first card under them than Content's 48 spacing (user request
## 2026-11-10); the gap above a title stays (hug_title).
const TITLE_HUG := 30.0
## Section titles show in capitals and pack names as the strings write them (each word capitalised), whatever the
## prefab's TMP UpperCase style says (user request 2026-11-13). PACK_NAMES: the cards with a PackName, the bundle
## cards included (templates of _pack_copy).
const TITLES := ["NoAdsTitle", "BundleTitle", "GoldTitle"]
const PACK_NAMES := ["Shop_RemoveAdsBundle", "Shop_RemoveAds", "StarterPack", "SpecialPack", "BundleSweet",
	"BundleTasty", "BundleYummy"]
## ShopCashLayer card for each offer pack (remove_ads, remove_ads_bundle have their own Shop_RemoveAds* cards), under
## the BundleTitle; a card shows only while its offer is on sale (Game.offer_in_shop, _show_packs).
const PACK_CARDS := {"starter_pack": "StarterPack", "level_pack": "SpecialPack", "rescue_pack": "BundleSweet"}
## Card art swapped in at build time (assets/ui/<name>.png, on the card's "Image (2)"): the prefab's art shows the
## Unity game's boosters. remove_ads_bundle: Shop_RemoveAdsBundle in ShopCashLayer and PopupRemoveAds.
const PACK_ART := {
	"starter_pack": "art_starter_pack", "level_pack": "art_level_pack_shop", "remove_ads_bundle": "art_no_ads_bundle",
}
## UIShopCashLayer.SetupLayerData: the panel is 183 units shorter when the bottom bar shows. HubNav is taller
## than Unity's BottomBarLayer, so the panel loses the height of HubNav's bar (182 of its 886-wide frame) when larger.
const BOTTOM_BAR := 183.0
const NAV_BAR_FRAME := Vector2(886, 182)
## Toast pill (%ToastBg, behind the text): space around the text, canvas units. The text has no plate of its own and
## the toast sits over the scrolled list (the Restore Purchases row at the bottom).
const TOAST_PAD := Vector2(36, 18)
## ADS Daily pill: "0 / 5 ads watched" is longer than Unity's timer there (Vietnamese, Portuguese...), so it wraps onto
## two lines and shrinks down to this size instead of overflowing the pill (two_lines).
const VIDEO_TEXT_MIN := 12.0
## ADS Daily pill: the prefab's navy tint is swapped for a lighter blue (same sprite).
const VIDEO_PILL_COLOR := Color("5b9fe8")
## Watch button once the day's videos are used: the gray pill of UnityKit.BUTTONS, with its text material.
const VIDEO_BTN_ON := "green"
const VIDEO_BTN_OFF := "gray"
## Dim of the TV icon on the gray Watch button.
const VIDEO_ICON_OFF := Color(0.7, 0.7, 0.7, 1.0)
## UIShopCashLayer.ShowLayer fades the scroll view in.
const FADE_IN := 0.3
## RewardItemSO gold icons: IAPProductSO gives cube.sort.color.gold.N the gold ItemId N.
const GOLD_ICONS := ["Gold1", "Gold2", "Gold3", "Gold4", "Gold5"]
const HEART_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_15"
const HEART_INF_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_16"
const BOOSTERS := ["hint", "move", "smash"]
## sku_inf of a pack with unlimited lives for good (inf_forever).
const INF_FOREVER := -1
## Smallest auto size of the "Forever" amount under an infinite heart (set_inf_label).
const INF_TEXT_MIN := 18.0
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
var toast_bg: Control = null
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
## Button whose store call is running (greyed out while _busy).
var _busy_src: Button = null
var _closed: bool = false
var _toast_tween: Tween = null
var _video_text: Label = null
var _video_clock: Control = null
var _video_btn_text: Label = null
var _video_btn_icon: Control = null
## Pill label rect with the clock icon (the prefab's) and without it (centered): offsets from u_rect.pos.x.
var _video_text_x: float = 0.0
var _video_state: int = -1
var _video_tick: float = 0.0
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
		if Game.offer_in_shop(sku):
			_pack_card(str(PACK_CARDS[sku]), sku)
	_show_packs()
	ui.text(C + "/GoldTitle/Text (TMP)", tr("shop_section_gold"))
	_gold_cards(catalog)
	_video_card()
	_restore_row()
	_add_pack_sections()
	_pass_scroll_buttons()
	ui.relayout(C)
	_fade_in()

	toast_label = %Toast
	toast_bg = %ToastBg
	toast_label.modulate.a = 0.0
	_fit_panel()

	_hub_bars()
	_animate()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


## A new aspect ratio (window resize, rotation, split screen) changes the canvas width (UnityUI refits the canvas
## first, its handler is connected earlier), so Content's layout groups place the cards again: build() arranged them
## for the width the Shop opened at.
func _on_resized() -> void:
	_fit_panel()
	if ui != null and is_instance_valid(ui.node(C)):
		ui.relayout(C)


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
	for t in TITLES:
		var l: Label = ui.label(C + "/" + t + "/Text (TMP)")
		l.uppercase = true
		one_line(l)
		hug_title(ui.node(C + "/" + t))
	for card in PACK_NAMES:
		var name_label := ui.node(C).get_node_or_null(str(card) + "/PackName") as Label
		if name_label != null:
			name_label.uppercase = false
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
	ui.text(p + "/PackName", _pack_title("remove_ads"))
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


## Shows the offer pack cards (PACK_CARDS) on sale now (Game.offer_in_shop) and their "Other packs" title while one
## shows. A one-time pack owned hides its card, also right after it is bought in this visit (user request
## 2026-11-10). True if a visibility changed.
func _show_packs() -> bool:
	var changed := false
	var any := false
	for sku in PACK_CARDS:
		var c: Control = ui.node(C + "/" + str(PACK_CARDS[sku]))
		var want: bool = buy_buttons.has(sku) and Game.offer_in_shop(sku) and not is_owned(sku)
		changed = changed or c.visible != want
		c.visible = want
		any = any or want
	var title: Control = ui.node(C + "/BundleTitle")
	changed = changed or title.visible != any
	title.visible = any
	return changed


## The Shop_RemoveAdsBundle card (ShopCashLayer and PopupRemoveAds) at `card`: Config.SKUS.remove_ads_bundle's gold
## and boosters in the card's slots (first row gold + No Ads, second row the boosters); empty slots hide.
## Returns the gold item, for the gold that flies to the chip.
static func fill_no_ads_bundle(u: RefCounted, card: String) -> Control:
	pack_art(u, card, "remove_ads_bundle")
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
	pack_art(ui, p, sku)
	var ic: Control = ui.node(p + "/ItemContainer")
	fill_items(ic, sku_items(sku))
	var gold_item := ic.get_node_or_null("Item_gold")
	if gold_item != null:
		_gold_from[sku] = gold_item
	_buy_button(p + "/Button_Purchase", sku)


## PACK_ART of sku on the card's "Image (2)" (the prefab's art stays when the game's file is missing).
static func pack_art(u: RefCounted, card: String, sku: String) -> void:
	var art := str(PACK_ART.get(sku, ""))
	if art != "" and ThemeKit.has_real_icon(art):
		u.texture(card + "/Image (2)", ThemeKit.icon(art))


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
	_video_btn_text = ui.text(p + "/Button_Ads/Text (TMP)", tr("ads_daily_watch"))
	_video_btn_icon = video_button.get_node_or_null("Image")
	var pill: Control = ui.node(p + "/Image")
	UnityUI.image_of(pill).call("set_color", VIDEO_PILL_COLOR)
	_video_clock = ui.node(p + "/Image/Image")
	_video_text = ui.label(p + "/Image/Text (TMP)")
	_video_text_x = float((_video_text.get_meta("u_rect") as Dictionary).pos.x)
	two_lines(_video_text, VIDEO_TEXT_MIN)
	_refresh_video()
	if Game.shop_videos_left() > 0:
		Game.offer_video("shop_coins")


## Videos left: the pill counts "n / 5" without the clock icon and the Watch button is live. All used: the pill shows
## the clock and the time to the next day (_process ticks it), and the Watch button is gray.
func _refresh_video() -> void:
	var total := int(Config.ECON.shop_video_max)
	var left: int = Game.shop_videos_left()
	var used_up := left <= 0
	if is_instance_valid(_video_text):
		if used_up:
			UnityUI.set_text(_video_text, HubTop.fmt_time(Game.shop_videos_reset_in()))
		else:
			UnityUI.set_text(_video_text, tr("ads_daily_progress") % [total - left, total])
		_set_video_state(1 if used_up else 0)
	if is_instance_valid(video_button):
		video_button.call("set_interactable", left > 0 and _busy_src != video_button)


## Swaps the pill (clock icon, label position) and the Watch button (green or gray) when the state changes.
func _set_video_state(state: int) -> void:
	if state == _video_state:
		return
	_video_state = state
	var counting_down := state == 1
	if is_instance_valid(_video_clock):
		_video_clock.visible = counting_down
	var r: Dictionary = _video_text.get_meta("u_rect")
	r.pos = Vector2(_video_text_x if counting_down else 0.0, float(r.pos.y))
	UnityUI.apply_rect(_video_text)
	if is_instance_valid(video_button):
		var key: String = VIDEO_BTN_OFF if counting_down else VIDEO_BTN_ON
		UnityUI.set_sprite(video_button, str(UnityKit.BUTTONS[key][0]))
		if is_instance_valid(_video_btn_text):
			_video_btn_text.material = UnityUI.text_material(str(UnityKit.BUTTONS[key][1]), false)
		if is_instance_valid(_video_btn_icon):
			_video_btn_icon.self_modulate = VIDEO_ICON_OFF if counting_down else Color.WHITE


## The countdown shows h:mm:ss, so it redraws once a second; the next day brings the videos back.
func _process(delta: float) -> void:
	if _video_state != 1 or not is_instance_valid(_video_text):
		return
	_video_tick += delta
	if _video_tick < 1.0:
		return
	_video_tick = 0.0
	_refresh_video()


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


## A label whose text may be longer than the prefab's: it wraps onto lines and auto sizes down to min_size instead of
## growing past its rect at the prefab's smallest size.
static func two_lines(l: Label, min_size: float) -> void:
	if l == null:
		return
	var t: Dictionary = (l.get_meta("u_txt") as Dictionary).duplicate(true)
	var auto: Variant = t.get("auto")
	t.auto = [min_size, float(auto[1]) if auto is Array else float(t.get("fs", 36.0))]
	t.w = true
	l.set_meta("u_txt", t)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


## [[kind, amount], ...] of a SKU: gold, unlimited lives (sku_inf), then hint, move, smash. Like the StarterPack card
## (gold and infinite heart on the first row, boosters on the second), so 5 items fill the rows the same way.
static func sku_items(sku: String) -> Array:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var out: Array = []
	if int(info.get("gold", 0)) > 0:
		out.append(["gold", int(info.gold)])
	if sku_inf(info) != 0:
		out.append(["heart_inf", sku_inf(info)])
	var inv: Dictionary = info.get("inv", {})
	for k in BOOSTERS:
		if int(inv.get(k, 0)) > 0:
			out.append([k, int(inv[k])])
	return out


## Unlimited lives of a SKU (Config.SKUS): INF_FOREVER for inf_forever, else its minutes (inf_min; 0 = none).
static func sku_inf(info: Dictionary) -> int:
	return INF_FOREVER if bool(info.get("inf_forever", false)) else int(info.get("inf_min", 0))


## Sets the amount label under an infinite heart (inf_text). "Forever" is longer than the prefab's "30m": that label
## auto sizes on one line (TMP auto size, INF_TEXT_MIN up to its size) to stay inside its slot.
static func set_inf_label(l: Label, minutes: int) -> void:
	if l == null:
		return
	if minutes == INF_FOREVER and l.has_meta("u_txt"):
		var t: Dictionary = (l.get_meta("u_txt") as Dictionary).duplicate(true)
		var auto: Variant = t.get("auto")
		t.auto = [INF_TEXT_MIN, float(auto[1]) if auto is Array else float(t.get("fs", 36.0))]
		t.w = false
		l.set_meta("u_txt", t)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	UnityUI.set_text(l, inf_text(minutes))


## Amount text of unlimited lives (sku_inf): "Forever" (shop_heart_forever), whole hours as "Infinite 3h", else
## minutes as "30m" (the PopupStarterPack prefab's own text).
static func inf_text(minutes: int) -> String:
	if minutes == INF_FOREVER:
		return TranslationServer.translate("shop_heart_forever")
	if minutes >= 60 and minutes % 60 == 0:
		return TranslationServer.translate("shop_heart_inf") % (minutes / 60)
	return TranslationServer.translate("weekly_reward_min") % minutes


## ShopProductSetup.SetupItem: the baked rows are replaced by rows of BonusItem copies (first row holds the
## remainder, then rows of PER_ROW, a Plus between items), centred like its layout groups.
## items: [[kind, amount]]; kind gold, hint, move, smash, heart (amount lives) or heart_inf (amount sku_inf).
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


## PopupRewardItem.SetupData: icon and quantity (gold "N0", boosters "x1", hearts "x5", "30m" or "Infinite 1h").
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
			if kind == "heart_inf":
				set_inf_label(v.label("Text (TMP)"), n)
			else:
				v.text("Text (TMP)", TranslationServer.translate("shop_heart_count") % n)
		_:
			# The game's booster icon in the magnet's image slot (its size animation stays).
			v.texture("ImgBoosterMagnet", ThemeKit.icon("booster_" + kind))
			v.text("Text (TMP)", TranslationServer.translate("booster_count") % n)


# --- Helper Packs, Bundles (wireframe 6.2) ---

## Helper Packs and Bundles (Config.SKUS helper_*, bundle_*: design.md mục 7) after the other packs, as copies of the
## bundle cards (GreatPack / EpicPack are unfinished in the prefab: white placeholder art). The Hearts section
## (wireframe 6.1) is not wired to logic yet and is off (SHOW_HEARTS); when on, debug builds only (Config.ui_preview),
## buttons say "coming soon". A helper pack is sold once every booster in it is unlocked (boosters_open); a one-time
## pack already owned is left out (_show_pack_copies hides one bought during the visit).
func _add_pack_sections() -> void:
	var content: Control = ui.node(C)
	var at: int = ui.node(C + "/BundleSweet").get_index() + 1
	if SHOW_HEARTS and Config.ui_preview():
		at = _add_heart_preview(content, at)
	var level := int(Game.s.level)
	var helpers := HELPER_SKUS.filter(func(k: Variant) -> bool: return boosters_open(str(k), level) and not is_owned(str(k)))
	if not helpers.is_empty():
		at = _preview_title(content, at, tr("shop_section_helpers"), "HelpersTitle")
	for i in helpers.size():
		at = _pack_copy(content, at, str(helpers[i]), str(["BundleTasty", "BundleYummy"][mini(i, 1)]), "HelperOffer")
	var on_sale := BUNDLE_SKUS.filter(func(k: Variant) -> bool: return not is_owned(str(k)))
	if not on_sale.is_empty():
		at = _preview_title(content, at, tr("shop_section_bundles"), "BundlesTitle")
	var bundles := ["BundleSweet", "BundleTasty", "BundleYummy"]
	for i in on_sale.size():
		at = _pack_copy(content, at, str(on_sale[i]), str(bundles[mini(i, bundles.size() - 1)]), "")


## Helper Packs / Bundles copies: a one-time pack bought during this visit hides its card, and a section left with no
## card hides its title. True if a visibility changed.
func _show_pack_copies() -> bool:
	var content: Control = ui.node(C)
	var changed := false
	for sec: Array in [["HelpersTitle", HELPER_SKUS], ["BundlesTitle", BUNDLE_SKUS]]:
		var any := false
		for sku in sec[1]:
			var c := content.get_node_or_null("Pack_" + str(sku)) as Control
			if c == null:
				continue
			var want := c.visible and not is_owned(str(sku))
			changed = changed or c.visible != want
			c.visible = want
			any = any or want
		var title := content.get_node_or_null(str(sec[0])) as Control
		if title != null and title.visible != any:
			title.visible = any
			changed = true
	return changed


## Every booster of sku is unlocked at `level` (Config.UNLOCK): helper_great holds Smash, so from L17.
static func boosters_open(sku: String, level: int) -> bool:
	var inv: Dictionary = Config.SKUS.get(sku, {}).get("inv", {})
	for k in inv:
		if int(inv[k]) > 0 and not Unlocks.is_open(str(k), level):
			return false
	return true


## A copy of a bundle card selling sku (the real BundleSweet card sells the rescue pack): name, contents, price.
func _pack_copy(content: Control, at: int, sku: String, card: String, art: String) -> int:
	var s := UnityKit.spec(LAYER, C + "/" + card)
	s.a = true
	var v: RefCounted = UnityKit.add(content, s)
	v.root.name = "Pack_" + sku
	v.root.set_meta("u_rt", true)
	content.move_child(v.root, at)
	v.label("PackName").uppercase = false
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


func _preview_title(content: Control, at: int, text: String, node_name: String = "") -> int:
	var v := UnityKit.add(content, UnityKit.spec(LAYER, C + "/BundleTitle"))
	v.root.set_meta("u_rt", true)
	if node_name != "":
		v.root.name = node_name
	v.label("Text (TMP)").uppercase = true
	one_line(v.label("Text (TMP)"))
	v.text("Text (TMP)", text)
	hug_title(v.root)
	content.move_child(v.root, at)
	return at + 1


## Takes TITLE_HUG off a section title's preferred height in Content's VerticalLayoutGroup and keeps its ribbon and
## text where they were from the title's top (each side moves by its anchor times TITLE_HUG), so the cards under it
## move up and the gap above it stays.
static func hug_title(title: Control) -> void:
	if title == null:
		return
	var u: Dictionary = (title.get_meta("u") as Dictionary).duplicate(true)
	var pref: Array = u.le.pref
	pref[1] = float(pref[1]) - TITLE_HUG
	title.set_meta("u", u)
	for ch in title.get_children():
		if not (ch is Control) or not ch.has_meta("u_rect"):
			continue
		var c := ch as Control
		c.offset_top += c.anchor_top * TITLE_HUG
		c.offset_bottom += c.anchor_bottom * TITLE_HUG
		UnityUI.rect_from_node(c)


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
			# Its own key: shop_remove_ads also captions the Home button and titles the No Ads section.
			return tr("shop_remove_ads_name")
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
	# All run: a bought Level Pack closes its offer and hides its card (_show_packs), a bought one-time pack hides its
	# card (_show_packs, _show_pack_copies).
	var moved := _show_no_ads()
	moved = _show_packs() or moved
	moved = _show_pack_copies() or moved
	if moved:
		ui.relayout(C)
	_refresh_video()


func buy(sku: String) -> void:
	if _busy or _closed:
		return
	var src: Button = buy_buttons.get(sku)
	_set_busy(true, src)
	Sfx.play("sfx_button")
	var before := int(Game.s.coins)
	var r: Dictionary = await Game.buy_sku(sku)
	if not is_inside_tree():
		return
	_set_busy(false, src)
	var flew := false
	if bool(r.get("granted", false)):
		bought_any = true
		# Gold leaves its card before _refresh hides a bought No Ads section.
		flew = _fly_gold(_gold_from.get(sku), int(Game.s.coins) - before)
		_refresh()
		# Purchase Success (wireframe 6.3) for packs with boosters or lives; gold packs only fly their gold.
		var items := sku_items(sku)
		if items.size() > 1 or (items.size() == 1 and str(items[0][0]) != "gold"):
			_show_reward(sku, flew)
	_show_buy_result(r, flew)


## Purchase Success; its parts fly to their counters as it closes (the gold only when it did not fly already).
func _show_reward(sku: String, gold_flew: bool = false) -> void:
	var args := {"view": {"title": "shop_buy_ok", "reward": RewardFly.sku_reward(sku),
		"flown": ["gold"] if gold_flew else []}}
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
	_set_busy(true, video_button)
	var before := int(Game.s.coins)
	var ok: bool = await Game.shop_watch_video()
	if not is_inside_tree():
		return
	_set_busy(false, video_button)
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
	_set_busy(true, restore_button)
	var ok: bool = await Game.restore_purchases()
	if not is_inside_tree():
		return
	_set_busy(false, restore_button)
	_refresh()
	toast(tr("shop_restore_ok") if ok else tr("shop_restore_none"))


## One store call at a time (buy, video, Restore): the others wait, but only the pressed button src greys out.
## Unity StoreItem locks nothing else, and the store sheet or the ad covers the Shop anyway.
func _set_busy(v: bool, src: Button) -> void:
	_busy = v
	_busy_src = src if v else null
	if src == video_button:
		_refresh_video()
	elif is_instance_valid(src) and not is_owned_button(src):
		src.call("set_interactable", not v)


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
	_fit_toast_bg()
	toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)


## The pill behind the toast hugs its text (lines wrapped at the label's width), TOAST_PAD around it.
func _fit_toast_bg() -> void:
	if not is_instance_valid(toast_bg) or toast_label.text.is_empty():
		return
	var font := toast_label.get_theme_font("font")
	var fs := toast_label.get_theme_font_size("font_size")
	var line := float(toast_label.get_theme_constant("line_spacing"))
	var brk := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var sz := font.get_multiline_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_CENTER, toast_label.size.x, fs, -1, brk)
	var lines := maxi(1, roundi(sz.y / font.get_height(fs)))
	var half := Vector2(minf(sz.x, toast_label.size.x), (font.get_height(fs) + line) * lines - line) * 0.5 + TOAST_PAD
	toast_bg.offset_left = -half.x
	toast_bg.offset_right = half.x
	toast_bg.offset_top = -half.y
	toast_bg.offset_bottom = half.y


## While gold flies, the chip counts on its own (HubTop.gold_shown, ShopFx; RewardFly.held).
func _on_coins_changed(v: int) -> void:
	if is_instance_valid(coins_label) and not (fx != null and fx.flying()):
		coins_label.text = str(maxi(v - RewardFly.held("gold"), 0))


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"bought": bought_any})
