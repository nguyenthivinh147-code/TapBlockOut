extends "res://src/ui/stub_ui.gd"
## Wireframe 3.3 New Mechanic Intro: giới thiệu cơ chế mới. Bố cục MechanicTutorialLayer (color-cube-match-puzzle):
## ribbon tiêu đề, tên cơ chế, icon giữa hai lớp tia sáng quay, mô tả, nút xanh. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const PANEL := "GameObject/UnlockPanel"


func _sample() -> Dictionary:
	return SampleData.MECHANIC


func _build() -> void:
	var m := str(view.mech)
	ui = UnityUI.build(self, "MechanicTutorialLayer")
	ui.text(PANEL + "/Image/Text (TMP)", tr("level_new_mechanic"))
	ui.text(PANEL + "/BoosterName", tr("mech_" + m))
	ui.text(PANEL + "/BoosterDescription", tr("mech_%s_desc" % m))
	ui.texture(PANEL + "/BoosterImage/Icon", ThemeKit.icon("mech_" + m))
	UnityUI.image_of(ui.node(PANEL + "/BoosterImage/Icon")).preserve_aspect = true
	ui.text(PANEL + "/ClaimButton/Text (TMP)", tr("mech_got_it"))
	ui.on_click(PANEL + "/ClaimButton", _send.bind("ok"))
