extends "res://src/ui/stub_ui.gd"
## Wireframe 9.5 Keep Your Streak? (design.md mục 7 "Win Streak"): xác nhận bỏ ván khi chuỗi thắng sẽ tụt. level.gd
## mở thay cho popup_keep_playing (4.6) khi lượt Win Streak đang đếm và chuỗi lớn hơn mốc đã đạt gần nhất, như
## ReplayGameButton / ReturnToMenuButton của color-cube-match-puzzle chọn PopupKeepPlayingWinstreak khi
## CanIncreaseStreak. Bỏ ván thì chuỗi tụt về mốc đó; ván mất mạng thì báo thêm.
## Layout of PopupKeepPlayingWinstreak: purple frame, the crying cat bar with the streak cat icon, the warning and the
## red Quit button (state 0). The game's streak count takes the broken heart's place; Continue (keep playing, a copy
## of Quit on the green pill, state 1 of UIPopupKeepPlayingWinstreak) shares the row like PopupOkLayer's pair (280
## each, spacing 52). Its video icon of the earlier mock-up stays hidden: keeping on costs nothing.
## setup({view}): {mode: "home" | "restart" | "give_up", streak, drop_to, life: bool}.
## closed({"action": "quit" | "continue" | "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")
const KeepPlaying := preload("res://src/ui/popup_keep_playing.gd")

const LAYER := "PopupKeepPlayingWinstreak"
const ROW := "Panel/Content/Button"


func _sample() -> Dictionary:
	return {"mode": "home", "streak": 5, "drop_to": 4, "life": true}


func _build() -> void:
	var texts: Array = KeepPlaying.MODES.get(str(view.get("mode", "home")), KeepPlaying.MODES.home)
	ui = UnityUI.build(self, LAYER)
	ui.text("Panel/GameObject/txtHeader", tr("streak_keep_title"))
	for b in ui.field("closeButtons", "UIPopupKeepPlayingWinstreak"):
		(b as Button).connect("clicked", _send.bind("close"))
	var lines := [tr("streak_keep_drop") % int(view.get("drop_to", 0))]
	if bool(view.get("life", false)):
		lines.append(tr("streak_keep_life"))
	ui.text("Panel/Content/Description", "\n".join(lines))
	# StreakText fills the broken heart's slot (centre x 117, y 74.1) up to the cat icon.
	UnityUI.set_text(%StreakText, tr("streak_row") % int(view.get("streak", 0)))
	ui.text(ROW + "/Ok/Out", tr(str(texts[2])))
	ui.on_click(ROW + "/Ok", _send.bind("quit")).name = "ConfirmButton"
	var cont: Button = %Continue
	(cont.get_node("VideoIcon") as Control).visible = false
	# Out was laid right of the video icon: the whole pill now (auto size reads the Unity rect).
	var out := cont.get_node("Out") as Label
	var r: Dictionary = out.get_meta("u_rect")
	r.amin = Vector2.ZERO
	r.amax = Vector2.ONE
	r.pos = Vector2(0, 4)
	r.size = Vector2(-32, -24)
	UnityUI.apply_rect(out)
	UnityUI.set_text(out, tr("level_restart_no"))
	cont.connect("clicked", _send.bind("continue"))
	cont.name = "CancelButton"
