extends "res://src/ui/stub_ui.gd"
## Wireframe 1.2 Check Update. Layout of CheckUpdateLayer (color-cube-match-puzzle): okButton is the game's
## Update Now, btnTurnOff closes like UICheckUpdate.HideThis. The game's Later is a copy of PopupOkLayer's Cancel
## (blue pill) placed before Ok in the same HorizontalLayoutGroup, as PopupOkLayer does. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")


func _build() -> void:
	ui = UnityUI.build(self, "CheckUpdateLayer")
	ui.text("Panel/Image/txtHeader", tr("boot_update_title"))
	ui.text("Panel/Content/Description", tr("boot_update_body"))
	ui.text("Panel/Content/Button/Ok/Out", tr("boot_update_now"))
	ui.on_click("Panel/Content/Button/Ok", _send.bind("update"))
	ui.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	var later: RefCounted = UnityKit.add(ui.node("Panel/Content/Button"), UnityKit.spec("PopupOkLayer", "Panel/Content/Button/Cancel"))
	later.root.get_parent().move_child(later.root, 0)
	later.text("Out", tr("boot_later"))
	later.on_click("", _send.bind("later"))
	ui.relayout("Panel/Content/Button")
