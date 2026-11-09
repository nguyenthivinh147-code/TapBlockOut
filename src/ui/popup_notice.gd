extends "res://src/ui/stub_ui.gd"
## Wireframe 11.2 Ad Not Available: one-button notice. Layout of PopupOkLayer (color-cube-match-puzzle),
## the cancel button hidden like PopupOkLayerData.IsHideCancelButton. Main opens it when no rewarded video is
## available (Game.notice "not_ready"); level.gd for "You lost your streak." (ShowPopupNotifyLayer of
## ME_WinStreak). setup({view}): {title, body} (translation keys). closed({"action": "ok" | "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _build() -> void:
	ui = UnityUI.build(self, "PopupOkLayer")
	ui.text("Panel/Image/txtHeader", tr(str(view.get("title", "ads_notice_title"))))
	ui.text("Panel/Content/Description", tr(str(view.get("body", "ads_not_available"))))
	ui.show("Panel/Content/Button/Cancel", false)
	ui.text("Panel/Content/Button/Ok/Out", tr("common_ok"))
	ui.on_click("Panel/Content/Button/Ok", _send.bind("ok"))
	for b in ui.field("closeButtons", "PopupOkUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
	ui.relayout("Panel/Content/Button")
