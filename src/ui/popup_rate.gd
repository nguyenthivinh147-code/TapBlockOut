extends "res://src/ui/stub_ui.gd"
## Wireframe 4.3 Rate Us. Layout of PopupRatingLayer (color-cube-match-puzzle): Ok rates, btnTurnOff closes
## (PopupRatingUICoreLayer.button / closeButtons). OnDisplayLayout enables the Star Animator, whose "Rating" clip
## pops the five star fills in one after another. level.gd opens it once, after the win card of the level where
## Rate us unlocks (Config.UNLOCK.review, s.meta.rated): Yes (closed({"action": "rate"})) then opens the store's
## in-app review (Game.rate_now), X closes ({"action": "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")


func _build() -> void:
	ui = UnityUI.build(self, "PopupRatingLayer")
	ui.text("Panel/Image/txtHeader", tr("win_rate_title"))
	ui.text("Panel/Text (TMP)", tr("win_rate_body"))
	ui.text("Panel/Ok/Out", tr("common_yes"))
	ui.on_click("Panel/Ok", _send.bind("rate"))
	for b in ui.field("closeButtons", "PopupRatingUICoreLayer"):
		(b as Button).connect("clicked", _send.bind("close"))
