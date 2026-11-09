extends "res://src/ui/stub_ui.gd"
## Wireframe 3.7 Booster Coming Soon: chạm booster còn khoá ở level (level.gd, design.md mục 4 "Mở khoá theo level").
## Bố cục BoosterTutorialLayer (color-cube-match-puzzle): tiêu đề ba lớp chữ ("Chơi tiếp nhé!"), tia sáng quay, ba
## bản sao icon cạnh nhau, một ô cho mỗi booster theo thứ tự hàng booster: booster đã mở hiện icon của nó, booster còn
## khoá hiện ổ khoá. Mô tả ghi tên booster vừa chạm và level mở. Tên, số lượng và nút của prefab ẩn: chạm đâu cũng
## đóng như wireframe. setup({view}): {kind, level}. closed({"action": "tap"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]
## One icon slot per booster of the HUD row (scene nodes, 220 each, centres 240 apart).
const SLOTS := {"hint": "Icon_hint", "move": "Icon_move", "smash": "Icon_lock"}


func _sample() -> Dictionary:
	return {"kind": "smash", "level": int(Config.UNLOCK.get("smash", 17))}


func _build() -> void:
	# The three icons and the hidden name, quantity, button and icon slot are saved in scenes/booster_soon.tscn.
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, tr("booster_soon_keep"))
	var kind := str(view.get("kind", "smash"))
	ui.text(PANEL + "/BoosterDescription", tr("booster_soon_level") % [tr("booster_" + kind), int(view.get("level", 0))])
	var holder: Control = ui.node(PANEL + "/BoosterImage")
	var lock: Control = holder.get_node(SLOTS.smash)
	var lock_tex: Texture2D = lock.get("tex")
	var lock_region: Rect2 = lock.get("region")
	var level := int(Game.s.level)
	for k in SLOTS:
		var slot: Control = holder.get_node(SLOTS[k])
		if Unlocks.is_open(k, level) and k != kind:
			var t := ThemeKit.icon("booster_" + k)
			slot.set("tex", t)
			slot.set("region", Rect2(Vector2.ZERO, t.get_size()))
		else:
			slot.set("tex", lock_tex)
			slot.set("region", lock_region)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("tap")
