extends "res://src/ui/stub_ui.gd"
## Wireframe 7.5 Weekly Pass Upsell (design.md mục 7 "Weekly Pass"): mời mua VIP. Main mở một lần mỗi mùa khi về Home
## lúc mùa Active, đã xem tutorial, đã có key và chưa VIP (Game.weekly_take_upsell). Nút giá mua VIP
## (Game.weekly_buy_vip); mua xong thì mở Weekly Pass (closed({"action": "bought"})), X đóng ({"action": "close"}).
## Ba dòng là quyền lợi VIP của game: thưởng VIP mỗi mốc, Bonus Bank, thêm mạng tối đa cả mùa.
## No Unity prefab: PopupOkLayer frame (UnityKit) with the time pill of PopupWinStreakMain, the light1 glow of
## PopupWinStreakInstruction's pack preview (the game's pack art instead of StarterPack), the perks as
## DailyRewardAdLayer description rows (tick icon, text 40) on the cream well and a green purchase pill.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const Config := preload("res://src/config.gd")

const PERKS := ["weekly_upsell_one", "weekly_upsell_two", "weekly_upsell_three"]

var _busy: bool = false


func _sample() -> Dictionary:
	var v: Dictionary = Game.weekly_view()
	return {"ends_in": int(v.get("seconds_left", 0))}


func _build() -> void:
	# Frame (724 x 1130), TimePill, PackGlow, PerkWell with Perk1..3 and BuyButton are nodes of
	# scenes/popup_weekly_upsell.tscn.
	ui = UnityKit.frame(self, tr("weekly_title"), _send.bind("close"))
	UnityUI.set_text(%TimePill.get_node("Text (TMP)"), tr("weekly_time_left") % HubTop.fmt_time(int(view.get("ends_in", 0))))
	var hearts := int(Config.WEEKLY.get("vip_bonus_hearts", 3))
	for i in PERKS.size():
		var t := tr(PERKS[i])
		if i == 2:
			t = t % hearts
		UnityUI.set_text(get_node("%%Perk%d" % (i + 1)), t)
	UnityUI.set_text(%BuyButton.get_node("Out"), Platform.price(str(Config.WEEKLY.sku)))
	%BuyButton.connect("clicked", _on_buy)


func _on_buy() -> void:
	if _busy:
		return
	_busy = true
	var r: Dictionary = await Game.weekly_buy_vip()
	if not is_inside_tree():
		return
	_busy = false
	if str(r.get("status", "")) == "ok" and bool(r.get("granted", false)):
		Sfx.play("sfx_coin")
		_send("bought")
