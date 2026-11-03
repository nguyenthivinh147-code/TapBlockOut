extends "res://src/ui/stub_ui.gd"
## Wireframe 4.6 Keep Playing?: xác nhận bỏ lượt mất mạng. Bố cục PopupKeepPlaying (color-cube-match-puzzle): tim vỡ
## nhịp như HeartAnimation, nút Quit ở state 0 của prefab (ImageStateKeeper / TMP_StateHandler: pill đỏ, viền đỏ) và
## bản sao ở state 1 (pill xanh lá) cho "Chơi tiếp", hai nút cỡ hàng nút của PopupOkLayer. Hai nút và dòng ghi chú là
## node trong scenes/popup_keep_playing.tscn; script chỉ điền chữ và nối nút. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const ROW := "Panel/Content/Button"
## HeartAnimation fields of the prefab (intro InBounce, then a Flip loop OutBack).
const HEART_START := Vector2(1.15, 1.15)
const HEART_END := Vector2(0.94, 0.85)


func _build() -> void:
	ui = UnityUI.build(self, "PopupKeepPlaying")
	ui.text("Panel/GameObject/txtHeader", tr("lose_keep_title"))
	ui.text("Panel/Content/Description", tr("lose_keep_body"))
	for b in ui.field("closeButtons", "PopupKeepPlaying"):
		(b as Button).connect("clicked", _send.bind("close"))

	# KeepButton (state 1, Replay: green pill) and NoteLabel are nodes of scenes/popup_keep_playing.tscn, which also
	# saves the prefab's Ok in state 0 (Quit: red pill, 280 wide).
	UnityUI.set_text(%KeepButton.get_node("Out"), tr("level_restart_no"))
	%KeepButton.connect("clicked", _send.bind("keep"))
	ui.node(ROW + "/Ok").name = "QuitButton"
	ui.text(ROW + "/Ok/Out", tr("lose_keep_quit"))
	ui.on_click(ROW + "/Ok", _send.bind("quit"))
	ui.relayout(ROW)
	UnityUI.set_text(%NoteLabel, tr("lose_keep_note"))
	_heart.call_deferred()


## HeartAnimation.StartHeartAnimation (OnShowLayer): 1.15 -> (0.94, 0.85) in 0.75 s, then back and forth to 1.
func _heart() -> void:
	var heart: Control = ui.node("Panel/Content/HeartIcon")
	if heart == null or not heart.is_inside_tree():
		return
	var intro := UnityUI.ease_of(28)
	var loop := UnityUI.ease_of(26)
	heart.scale = HEART_START
	var tw := heart.create_tween()
	tw.tween_property(heart, "scale", HEART_END, 0.75).set_trans(intro[0]).set_ease(intro[1])
	tw.tween_callback(func() -> void:
		var lp := heart.create_tween().set_loops().set_trans(loop[0]).set_ease(loop[1])
		lp.tween_property(heart, "scale", Vector2.ONE, 0.35)
		lp.tween_property(heart, "scale", HEART_END, 0.35))
