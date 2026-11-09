extends "res://src/ui/stub_ui.gd"
## Wireframe 1.2 Check Update (design.md mục 8 "Bản thử", Config.CONTENT.latest_version, min_version): Main mở sau
## khi tải game khi phiên bản app thấp hơn bản mới nhất trên Remote Config (Game.update_state). Update Now mở trang
## game trên store (Game.open_store). Không bắt buộc: Để sau hoặc X đóng, một lần mỗi lần mở game. Bắt buộc (dưới
## min_version): ẩn Để sau và X, Back không đóng, Update Now giữ popup mở.
## Layout of CheckUpdateLayer (color-cube-match-puzzle): okButton is the game's Update Now, btnTurnOff closes like
## UICheckUpdate.HideThis. The game's Later is a copy of PopupOkLayer's Cancel (blue pill) placed before Ok in the
## same HorizontalLayoutGroup, as PopupOkLayer does. setup({view}): {force: bool}.
## closed({"action": "later" | "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _sample() -> Dictionary:
	return {"force": false}


func _build() -> void:
	# Later (PopupOkLayer's Cancel before Ok) is a node of scenes/popup_update.tscn.
	var force := bool(view.get("force", false))
	ui = UnityUI.build(self, "CheckUpdateLayer")
	ui.text("Panel/Image/txtHeader", tr("boot_update_title"))
	ui.text("Panel/Content/Description", tr("boot_update_force") if force else tr("boot_update_body"))
	ui.text("Panel/Content/Button/Ok/Out", tr("boot_update_now"))
	ui.on_click("Panel/Content/Button/Ok", _on_update)
	ui.on_click("Panel/Top/btnTurnOff", _send.bind("close"))
	ui.show("Panel/Top/btnTurnOff", not force)
	UnityUI.set_text(%LaterButton.get_node("Out"), tr("boot_later"))
	%LaterButton.connect("clicked", _send.bind("later"))
	%LaterButton.visible = not force
	ui.relayout("Panel/Content/Button")


## Main: Back does not dismiss a forced update.
func blocks_back() -> bool:
	return bool(view.get("force", false))


func _on_update() -> void:
	Game.open_store()
	if not bool(view.get("force", false)):
		_send("update")
