extends "res://src/ui/stub_ui.gd"
## Wireframe 2.4 Remove Ads (design.md mục 7): icon Remove Ads trên Home và offer Remove Ads sau interstitial thứ 3
## trong ngày (Offers, thay cho popup_offer). Hai gói một lần: remove_ads (thẻ thường) và remove_ads_bundle (thẻ
## bundle: bỏ quảng cáo kèm gold và booster, Config.SKUS). Mua qua Game.buy_sku; xong thì hiện popup thưởng (6.3,
## chỉ gói có gold hoặc booster) và đóng. Restore gọi Game.restore_purchases. Đã sở hữu một trong hai gói thì Main
## không mở popup này.
## Layout of PopupRemoveAds (color-cube-match-puzzle): ribbon title, the bundle card (its contents: gold + No Ads, then
## the boosters, filled by Shop.fill_no_ads_bundle like the Shop's card) and the plain Remove Ads card with two lines
## (no ads, rewarded stays optional; the plain pack has no gold). The full-screen
## Continue is "close"; Restore is ShopCashLayer's RestorePurchase button under it.
## closed({"action": "bought" | "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const Config := preload("res://src/config.gd")
const Shop := preload("res://src/ui/shop.gd")

const BUNDLE := "Panel_Pack/Shop_RemoveAdsBundle"
const CARD := "Panel_Pack/Shop_RemoveAds"
const POPUP_REWARD := "res://scenes/popup_reward.tscn"

var _busy: bool = false


func _sample() -> Dictionary:
	return {}


func _build() -> void:
	# Restore (ShopCashLayer's RestorePurchase, the prefab's 48-unit card gap below "Continue") and the hidden bundle
	# contents (only its No Ads item stays) are saved in scenes/popup_remove_ads.tscn.
	ui = UnityUI.build(self, "PopupRemoveAds")
	ui.text("Panel_Pack/Title/Title_txt", tr("shop_remove_ads"))
	ui.text(BUNDLE + "/PackName", tr("shop_remove_ads_bundle"))
	ui.text(BUNDLE + "/Button_Purchase/Text (TMP)", Platform.price("remove_ads_bundle"))
	ui.on_click(BUNDLE + "/Button_Purchase", _buy.bind("remove_ads_bundle"))
	Shop.fill_no_ads_bundle(ui, BUNDLE)
	ui.text(CARD + "/PackName", tr("shop_remove_ads"))
	ui.text(CARD + "/Description", tr("ads_noads_one"))
	ui.text(CARD + "/InterAdsTxt", "- " + tr("ads_noads_two"))
	# The plain pack is no ads only (no gold): its third line ("bonus gold") stays hidden.
	ui.show(CARD + "/BannerAdsTxt", false)
	ui.text(CARD + "/Button_Purchase/Text (TMP)", tr("ads_noads_buy") % Platform.price("remove_ads"))
	ui.on_click(CARD + "/Button_Purchase", _buy.bind("remove_ads"))
	ui.text("Continue/Text (TMP)", tr("offer_no_thanks"))
	ui.on_click("Continue", _send.bind("close"))
	var restore: RefCounted = ui.sub(%Restore)
	restore.text("Button/Text (TMP)", tr("shop_restore"))
	restore.on_click("Button", _restore)


func _buy(sku: String) -> void:
	if _busy:
		return
	_busy = true
	var r: Dictionary = await Game.buy_sku(sku)
	if not is_inside_tree():
		return
	_busy = false
	if str(r.get("status", "")) == "ok" and bool(r.get("granted", false)):
		var info: Dictionary = Config.SKUS.get(sku, {})
		var inv: Dictionary = info.get("inv", {})
		# The plain pack is no ads only: nothing to show in Purchase Success.
		if int(info.get("gold", 0)) > 0 or not inv.is_empty():
			open_over(POPUP_REWARD, {"view": {"title": "shop_buy_ok", "reward": {"coins": int(info.get("gold", 0)),
				"items": inv}}})
		_send("bought")


func _restore() -> void:
	if _busy:
		return
	_busy = true
	await Game.restore_purchases()
	if not is_inside_tree():
		return
	_busy = false
	if bool(Game.s.get("no_ads", false)):
		_send("bought")
