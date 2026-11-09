extends "res://src/ui/stub_ui.gd"
## Wireframe 1.6 No Internet. MaintainInternetLayer (color-cube-match-puzzle) is only the no-Wi-Fi corner icon
## (noInternetGO, shown while offline); the dialog is a copy of DownloadDataLayer's PopupLoginNoInternet, the popup
## Unity shows when the first login fails offline ("Download failed!\nPlease connect..."): title, two-line message,
## Ok as the game's Retry, the X closes. Its Cancel stays inactive. The corner icon is drawn above the dialog's dim
## so the game's Wi-Fi icon stays visible.
## Main mở khi video hay mua hàng thất bại vì mất mạng (Game.notice "offline", kiểm bằng Game.online). Retry kiểm lại:
## có mạng thì đóng (closed({"action": "retry"})), chưa có thì giữ popup. X đóng ({"action": "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _build() -> void:
	# The dialog (PopupLoginNoInternet copy) is a node of scenes/popup_no_internet.tscn, before the corner icon.
	ui = UnityUI.build(self, "MaintainInternetLayer")
	var pop: RefCounted = ui.sub(%PopupLoginNoInternet)
	pop.text("Panel/Image/txtHeader", tr("boot_offline_title"))
	pop.text("Panel/Content/Description", "%s\n%s" % [tr("boot_offline_lost"), tr("boot_offline_body")])
	pop.text("Panel/Content/Button/Ok/Out", tr("boot_retry"))
	pop.on_click("Panel/Content/Button/Ok", _on_retry)
	pop.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	pop.relayout("Panel/Content/Button")


var _checking: bool = false


func _on_retry() -> void:
	if _checking:
		return
	_checking = true
	var ok: bool = await Game.online()
	_checking = false
	if ok and is_inside_tree():
		_send("retry")
