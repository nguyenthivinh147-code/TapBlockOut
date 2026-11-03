extends "res://src/ui/stub_ui.gd"
## Wireframe 2.4 Remove Ads: mua bỏ quảng cáo. Chưa nối logic.
## Layout of PopupRemoveAds (color-cube-match-puzzle): ribbon title, the bundle card (buy_bundle) and the plain
## Remove Ads card (buy) whose three lines carry the game's three points. The full-screen Continue is "close";
## Restore is ShopCashLayer's RestorePurchase button under it.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const BUNDLE := "Panel_Pack/Shop_RemoveAdsBundle"
const CARD := "Panel_Pack/Shop_RemoveAds"


func _sample() -> Dictionary:
	return SampleData.REMOVE_ADS


func _build() -> void:
	# Restore (ShopCashLayer's RestorePurchase, the prefab's 48-unit card gap below "Continue") and the hidden bundle
	# contents (only its No Ads item stays) are saved in scenes/popup_remove_ads.tscn.
	ui = UnityUI.build(self, "PopupRemoveAds")
	ui.text("Panel_Pack/Title/Title_txt", tr("shop_remove_ads"))
	ui.text(BUNDLE + "/PackName", (tr("ads_noads_bundle") % "").strip_edges())
	ui.text(BUNDLE + "/Button_Purchase/Text (TMP)", str(view.get("bundle_price", "")))
	ui.on_click(BUNDLE + "/Button_Purchase", _send.bind("buy_bundle"))
	ui.text(CARD + "/PackName", tr("shop_remove_ads"))
	ui.text(CARD + "/Description", tr("ads_noads_one"))
	ui.text(CARD + "/InterAdsTxt", "- " + tr("ads_noads_two"))
	ui.text(CARD + "/BannerAdsTxt", "- " + tr("ads_noads_three"))
	ui.text(CARD + "/Button_Purchase/Text (TMP)", tr("ads_noads_buy") % str(view.get("price", "")))
	ui.on_click(CARD + "/Button_Purchase", _send.bind("buy"))
	ui.text("Continue/Text (TMP)", tr("offer_no_thanks"))
	ui.on_click("Continue", _send.bind("close"))
	var restore: RefCounted = ui.sub(%Restore)
	restore.text("Button/Text (TMP)", tr("shop_restore"))
	restore.on_click("Button", _send.bind("restore"))
