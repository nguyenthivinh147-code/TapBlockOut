extends "res://src/ui/stub_ui.gd"
## Wireframe 11.2 Ad Not Available: one-button notice. Layout of PopupOkLayer (color-cube-match-puzzle),
## the cancel button hidden like PopupOkLayerData.IsHideCancelButton. Main opens it when no rewarded video is
## available (Game.notice "not_ready"); level.gd for "You lost your streak." (ShowPopupNotifyLayer of
## ME_WinStreak); Settings as the Yes/No popup of Privacy Policy and Terms (PrivacyPolicyControl).
## setup({view}): {title, body, ok, cancel} (translation keys; ok defaults to common_ok, no cancel hides that
## button). closed({"action": "ok" | "cancel" | "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _build() -> void:
	ui = UnityUI.build(self, "PopupOkLayer")
	ui.text("Panel/Image/txtHeader", tr(str(view.get("title", "ads_notice_title"))))
	ui.text("Panel/Content/Description", tr(str(view.get("body", "ads_not_available"))))
	var cancel := str(view.get("cancel", ""))
	ui.show("Panel/Content/Button/Cancel", cancel != "")
	if cancel != "":
		ui.text("Panel/Content/Button/Cancel/Out", tr(cancel))
		ui.on_click("Panel/Content/Button/Cancel", _send.bind("cancel"))
	ui.text("Panel/Content/Button/Ok/Out", tr(str(view.get("ok", "common_ok"))))
	ui.on_click("Panel/Content/Button/Ok", _send.bind("ok"))
	for b in ui.field("closeButtons", "PopupOkUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
	ui.relayout("Panel/Content/Button")
