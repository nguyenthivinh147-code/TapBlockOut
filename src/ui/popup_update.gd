extends "res://src/ui/stub_ui.gd"
## Wireframe 1.2 Check Update. Layout of CheckUpdateLayer (color-cube-match-puzzle): okButton is the game's
## Update Now, btnTurnOff closes like UICheckUpdate.HideThis. The game's Later is a copy of PopupOkLayer's Cancel
## (blue pill) placed before Ok in the same HorizontalLayoutGroup, as PopupOkLayer does. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _build() -> void:
	# Later (PopupOkLayer's Cancel before Ok) is a node of scenes/popup_update.tscn.
	ui = UnityUI.build(self, "CheckUpdateLayer")
	ui.text("Panel/Image/txtHeader", tr("boot_update_title"))
	ui.text("Panel/Content/Description", tr("boot_update_body"))
	ui.text("Panel/Content/Button/Ok/Out", tr("boot_update_now"))
	ui.on_click("Panel/Content/Button/Ok", _send.bind("update"))
	ui.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	UnityUI.set_text(%LaterButton.get_node("Out"), tr("boot_later"))
	%LaterButton.connect("clicked", _send.bind("later"))
	ui.relayout("Panel/Content/Button")
