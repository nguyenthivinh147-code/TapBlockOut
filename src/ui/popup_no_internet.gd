extends "res://src/ui/stub_ui.gd"
## Wireframe 1.6 No Internet. MaintainInternetLayer (color-cube-match-puzzle) is only the no-Wi-Fi corner icon
## (noInternetGO, shown while offline); the dialog is a copy of DownloadDataLayer's PopupLoginNoInternet, the popup
## Unity shows when the first login fails offline ("Download failed!\nPlease connect..."): title, two-line message,
## Ok as the game's Retry, the X closes. Its Cancel stays inactive. The corner icon is drawn above the dialog's dim
## so the game's Wi-Fi icon stays visible. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")


func _build() -> void:
	ui = UnityUI.build(self, "MaintainInternetLayer")
	var s := UnityKit.spec("DownloadDataLayer", "PopupLoginNoInternet")
	s.a = true
	var pop: RefCounted = UnityKit.add(ui.node(""), s)
	pop.text("Panel/Image/txtHeader", tr("boot_offline_title"))
	pop.text("Panel/Content/Description", "%s\n%s" % [tr("boot_offline_lost"), tr("boot_offline_body")])
	pop.text("Panel/Content/Button/Ok/Out", tr("boot_retry"))
	pop.on_click("Panel/Content/Button/Ok", _send.bind("retry"))
	pop.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	pop.relayout("Panel/Content/Button")
	var corner: Control = ui.node("Panel")
	corner.get_parent().move_child(corner, -1)
