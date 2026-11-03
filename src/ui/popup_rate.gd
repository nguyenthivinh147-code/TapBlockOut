extends "res://src/ui/stub_ui.gd"
## Wireframe 4.3 Rate Us. Layout of PopupRatingLayer (color-cube-match-puzzle): Ok rates, btnTurnOff closes
## (PopupRatingUICoreLayer.button / closeButtons). OnDisplayLayout enables the Star Animator, whose "Rating" clip
## pops the five star fills in one after another. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _build() -> void:
	ui = UnityUI.build(self, "PopupRatingLayer")
	ui.text("Panel/Image/txtHeader", tr("win_rate_title"))
	ui.text("Panel/Text (TMP)", tr("win_rate_body"))
	ui.text("Panel/Ok/Out", tr("common_yes"))
	ui.on_click("Panel/Ok", _send.bind("rate"))
	for b in ui.field("closeButtons", "PopupRatingUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
