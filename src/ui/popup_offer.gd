extends Control
## Popup offer dùng chung cho starter_pack, remove_ads, rescue_pack, level_pack, special_pack.
## setup({id}); không có id thì lấy offer đang mở đầu tiên. signal closed({id, bought}).
## Prefab theo offer (color-cube-match-puzzle): starter_pack PopupStarterPack, special_pack PopupSpecialPack,
## level_pack PopupFlashPack (gói có hạn), rescue_pack PopupOfferLayer (khung BuyBoster), remove_ads PopupRemoveAds.
## Nút X / chạm nền (closeButtons, Continue của PopupRemoveAds) là "để sau".

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Shop := preload("res://src/ui/shop.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")
const Config := preload("res://src/config.gd")

const BOOSTER_ORDER := ["hint", "move", "smash"]
const LAYERS := {
	"starter_pack": "PopupStarterPack", "special_pack": "PopupSpecialPack", "level_pack": "PopupFlashPack",
	"rescue_pack": "PopupOfferLayer", "remove_ads": "PopupRemoveAds",
}
## Reward slots of Panel/Content/Preview/Bottom/Group in the pack popups (Image (3) is the infinite-heart slot).
const SLOTS := {"gold": "Image", "hint": "Image (1)", "move": "Image (2)", "smash": "Image (4)", "heart": "Image (3)"}
const SLOT_ICONS := {"hint": "ImgBoosterMagnet", "move": "ImgBoosterStorage", "smash": "ImgBoosterCapacity"}
const GROUP := "Panel/Content/Preview/Bottom/Group"
## PackTimeCounter of PopupStarterPack, copied into prefabs that have no timer of their own.
const TIMER_SPEC := ["PopupStarterPack", "Panel/Content/Preview/Platform/Time"]
## Card art swapped in at build time (assets/ui/<name>.png): the prefab's art shows the Unity game's boosters.
const PACK_ART := {"level_pack": "art_level_pack"}
const PACK_ART_IMAGE := "Panel/Content/Image"
## Card background replaced at build time (the prefab card draws the Unity cat and boosters).
const PACK_BG := {"starter_pack": "bg_starter_pack"}
const PACK_BG_IMAGE := "Panel/Bg (1)"

var offer_id: String = ""
var sku: String = ""
var buy_button: Button = null
var later_button: Button = null
var time_label: Label = null
var toast_label: Label = null
var last_toast: String = ""
var ui: RefCounted = null

var _until: int = 0
var _busy: bool = false
var _closed: bool = false
var _toast_tween: Tween = null
## RewardFly part -> its icon on the card: bought, the pack's contents fly from there to their counters.
var _icons: Dictionary = {}


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


## Các dòng nội dung gói: bỏ quảng cáo (gói no_ads), gold, mạng vô hạn và booster.
func contents() -> Array[String]:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var out: Array[String] = []
	if bool(info.get("no_ads", false)):
		out.append(tr("shop_remove_ads"))
	var gold := int(info.get("gold", 0))
	if gold > 0:
		out.append(tr("shop_gold_pack") % gold)
	if bool(info.get("inf_forever", false)):
		out.append(tr("shop_lives_forever"))
	elif int(info.get("inf_min", 0)) > 0:
		out.append(tr("weekly_reward_inf") % int(info.inf_min))
	var inv: Dictionary = info.get("inv", {})
	for k in BOOSTER_ORDER:
		if int(inv.get(k, 0)) > 0:
			out.append("%s %s" % [_booster_name(k), tr("booster_count") % int(inv[k])])
	return out


func _build() -> void:
	var layer := str(LAYERS.get(offer_id, "PopupStarterPack"))
	ui = UnityUI.build(self, layer)
	match layer:
		"PopupOfferLayer":
			_build_booster()
		"PopupRemoveAds":
			_build_remove_ads()
		_:
			_build_pack(layer)
	if time_label == null:
		_add_timer()
	_update_time()
	toast_label = UnityKit.label(ui.node(""), "", Rect2(0, 0, 100, 100), 44.0, "ffffffff", "Baloo Outline - Black")
	toast_label.name = "Toast"
	var r: Dictionary = toast_label.get_meta("u_rect")
	r.amin = Vector2(0, 0)
	r.amax = Vector2(1, 0)
	r.pos = Vector2(0, 160)
	r.size = Vector2(-120, 120)
	UnityUI.apply_rect(toast_label)
	toast_label.modulate.a = 0.0


## PopupStarterPack / PopupSpecialPack / PopupFlashPack: illustrated card, title on the ribbon, timer, reward row,
## price button (FreeBtn). The game's body line sits above the reward box in the box's text style.
func _build_pack(layer: String) -> void:
	for p in ["Panel/Image/txtHeader BG2", "Panel/Image/txtHeader BG1", "Panel/Image/txtHeader"]:
		ui.text(p, _title())
	later_button = ui.button("Panel/btnTurnOff")
	for b in ui.field("closeButtons"):
		(b as Button).connect("clicked", close)
	ui.show("Panel/SellBadge", false)
	if ui.has("Panel/MoreValue"):
		ui.show("Panel/MoreValue", false)
	if ui.has("Panel/Content/Preview/Platform/NumberPurchar"):
		ui.show("Panel/Content/Preview/Platform/NumberPurchar", false)
	ui.show("Panel/Content/Preview/Bottom/tag_sale", false)
	var timer := "Panel/Content/Preview/Platform/Time (1)" if ui.has("Panel/Content/Preview/Platform/Time (1)") \
		else "Panel/Content/Preview/Platform/Time"
	ui.show(timer, _until > 0)
	time_label = ui.label(timer + "/Text (TMP)")
	var art := str(PACK_ART.get(offer_id, ""))
	if art != "" and ui.has(PACK_ART_IMAGE) and ThemeKit.has_real_icon(art):
		ui.texture(PACK_ART_IMAGE, ThemeKit.icon(art))
	var bg := str(PACK_BG.get(offer_id, ""))
	if bg != "" and ui.has(PACK_BG_IMAGE) and ThemeKit.has_real_icon(bg):
		ui.texture(PACK_BG_IMAGE, ThemeKit.icon(bg))
	_fill_slots()
	buy_button = ui.button("Panel/Content/GameObject/FreeBtn")
	buy_button.connect("clicked", buy)
	ui.text("Panel/Content/GameObject/FreeBtn/Out", Platform.price(sku))
	# Body: the reward quantity text style (Baloo Outline - DarkBlue), wrapped. Starter / Special: above the Bottom
	# box on the card art. Flash: its LimitedPack image fills that space, so the line goes under the price button.
	var s := UnityKit.spec(layer, GROUP + "/Image/Text (TMP)")
	s.n = "Body"
	s.txt.fs = 40.0
	s.txt.auto = [18.0, 40.0]
	s.txt.w = true
	s.txt.s = _body()
	if layer == "PopupFlashPack":
		s.r = [0.5, 0, 0.5, 0, 0, -205, 700, 110, 0.5, 0.5]
		UnityKit.add(ui.node("Panel"), s)
	else:
		var br: Dictionary = ui.node("Panel/Content/Preview/Bottom").get_meta("u_rect")
		s.r = [0.5, 0, 0.5, 0, 0, (br.pos as Vector2).y + (br.size as Vector2).y + 70.0, 620, 120, 0.5, 0.5]
		UnityKit.add(ui.node("Panel/Content/Preview"), s)


## Bottom/Group slots: gold, unlimited lives (Shop.sku_inf) and the game's boosters; empty slots hidden, the rest spread
## over the slots' span.
func _fill_slots() -> void:
	var info: Dictionary = Config.SKUS.get(sku, {})
	var inv: Dictionary = info.get("inv", {})
	var amounts := {"gold": int(info.get("gold", 0)), "heart": Shop.sku_inf(info)}
	for k in BOOSTER_ORDER:
		amounts[k] = int(inv.get(k, 0))
	var lo := INF
	var hi := -INF
	var shown: Array[Control] = []
	for kind in ["gold", "heart", "hint", "move", "smash"]:
		var p := GROUP + "/" + str(SLOTS[kind])
		var n: Control = ui.node(p)
		var x := ((n.get_meta("u_rect") as Dictionary).pos as Vector2).x
		lo = minf(lo, x)
		hi = maxf(hi, x)
		var amount := int(amounts[kind])
		n.visible = amount != 0
		if amount == 0:
			continue
		shown.append(n)
		if kind == "gold":
			ui.text(p + "/Text (TMP)", Shop.fmt_n0(amount))
			_icons["gold"] = n
		elif kind == "heart":
			Shop.set_inf_label(ui.label(p + "/Text (TMP)"), amount)
			_icons["inf"] = ui.node(p + "/ImgVoHanTim")
		else:
			ui.texture(p + "/" + str(SLOT_ICONS[kind]), ThemeKit.icon("booster_" + kind))
			ui.text(p + "/Text (TMP)", tr("booster_count") % amount)
			_icons[kind] = ui.node(p + "/" + str(SLOT_ICONS[kind]))
	# Ordered left to right like the prefab: gold, unlimited lives, then hint, move, smash.
	for i in shown.size():
		var r: Dictionary = shown[i].get_meta("u_rect")
		var t := 0.5 if shown.size() == 1 else float(i) / float(shown.size() - 1)
		r.pos = Vector2(lerpf(lo, hi, t), (r.pos as Vector2).y)
		UnityUI.apply_rect(shown[i])


## PopupOfferLayer, BuyBoster panel: icon in the cream well, description, one green price button (FreeBtn).
func _build_booster() -> void:
	ui.show("Panel/StarterPack", false)
	ui.show("Panel/SpecialPack", false)
	var p := "Panel/BuyBoster"
	ui.text(p + "/Image/txtHeader", _title())
	ui.text(p + "/Content/Description", _body())
	var items := Shop.sku_items(sku)
	var kind := str(items[items.size() - 1][0]) if not items.is_empty() else "move"
	ui.texture(p + "/Content/Preview/Content/Icon", ThemeKit.icon("booster_" + kind if kind != "gold" else "ui_gold"))
	_icons[kind] = ui.node(p + "/Content/Preview/Content/Icon")
	later_button = ui.button(p + "/Top/btnTurnOff")
	for b in ui.field("closeButtons", "PopupOfferUICoreLayer"):
		(b as Button).connect("clicked", close)
	for x in ["Continue", "GoldBtn", "AdsBtn"]:
		ui.show(p + "/Content/GameObject/" + x, false)
	ui.show(p + "/Content/GameObject/FreeBtn", true)
	buy_button = ui.button(p + "/Content/GameObject/FreeBtn")
	buy_button.connect("clicked", buy)
	ui.text(p + "/Content/GameObject/FreeBtn/Out", Platform.price(sku))
	ui.relayout("Panel")


## PopupRemoveAds: the plain Remove Ads card (no bundle in the game); the full-screen Continue is "maybe later".
func _build_remove_ads() -> void:
	ui.text("Panel_Pack/Title/Title_txt", _title())
	ui.show("Panel_Pack/Shop_RemoveAdsBundle", false)
	var p := "Panel_Pack/Shop_RemoveAds"
	ui.text(p + "/PackName", tr("shop_remove_ads"))
	ui.show(p + "/InterAdsTxt", false)
	ui.show(p + "/BannerAdsTxt", false)
	var d: Label = ui.label(p + "/Description")
	var r: Dictionary = d.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x, -113.0)
	r.size = Vector2((r.size as Vector2).x, 160.0)
	UnityUI.apply_rect(d)
	UnityUI.set_text(d, _body())
	# The single card sits where the two cards were centred (Title -288, bundle -712.7, card -1182.3).
	var card: Control = ui.node(p)
	var cr: Dictionary = card.get_meta("u_rect")
	cr.pos = Vector2(0, -712.7)
	UnityUI.apply_rect(card)
	buy_button = ui.button(p + "/Button_Purchase")
	buy_button.connect("clicked", buy)
	ui.text(p + "/Button_Purchase/Text (TMP)", Platform.price(sku))
	later_button = ui.button("Continue")
	later_button.connect("clicked", close)
	ui.text("Continue/Text (TMP)", tr("offer_no_thanks"))


## Timer chip of PopupStarterPack under the title when the prefab has none (rescue, remove ads offers).
func _add_timer() -> void:
	var s := UnityKit.spec(TIMER_SPEC[0], TIMER_SPEC[1])
	s.a = true
	s.n = "Time"
	s.r = [0.5, 1, 0.5, 1, 0, -240, 238, 68, 0.5, 0.5]
	var v := UnityKit.add(ui.node(""), s)
	v.root.visible = _until > 0
	time_label = v.label("Text (TMP)")


func _process(_delta: float) -> void:
	if _until > 0:
		_update_time()


func _update_time() -> void:
	if _until <= 0 or time_label == null:
		if time_label != null:
			time_label.visible = false
		return
	var left := _until - Game.now()
	time_label.visible = left > 0
	if left > 0:
		var t := tr("offer_time_left") % format_time(left)
		if time_label.text != t:
			UnityUI.set_text(time_label, t)


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
	buy_button.call("set_interactable", false)
	Sfx.play("sfx_button")
	var r: Dictionary = await Game.offer_buy(offer_id)
	if not is_inside_tree():
		return
	_busy = false
	buy_button.call("set_interactable", true)
	match str(r.get("status", "error")):
		"ok":
			if bool(r.granted):
				# Unity's PopupOffer: the contents fly to their counters (RewardFly); the coin sound plays here
				# when nothing flies.
				if RewardFly.launch(self, RewardFly.sku_reward(sku), _icons) == 0:
					Sfx.play("sfx_coin")
				_finish(true)
			else:
				toast(tr("shop_buy_failed"))
		"pending":
			toast(tr("shop_buy_pending"))
		"cancel", "offline":
			pass
		"owned":
			toast(tr("shop_owned"))
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


func close() -> void:
	_finish(false)


func _finish(bought: bool) -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"id": offer_id, "bought": bought})
