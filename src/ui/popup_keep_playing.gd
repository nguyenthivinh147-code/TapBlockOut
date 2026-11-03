extends "res://src/ui/stub_ui.gd"
## Wireframe 4.6 Keep Playing?: xác nhận bỏ lượt mất mạng. Bố cục PopupKeepPlaying (color-cube-match-puzzle): tim vỡ
## nhịp như HeartAnimation, nút Quit ở state 0 của prefab (ImageStateKeeper / TMP_StateHandler: pill đỏ, viền đỏ) và
## bản sao ở state 1 (pill xanh lá) cho "Chơi tiếp", hai nút cỡ hàng nút của PopupOkLayer. Chưa nối logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const ROW := "Panel/Content/Button"
## Two buttons fill the 612-unit row like PopupOkLayer (280 + 52 + 280).
const BTN_W := 280.0
## HeartAnimation fields of the prefab (intro InBounce, then a Flip loop OutBack).
const HEART_START := Vector2(1.15, 1.15)
const HEART_END := Vector2(0.94, 0.85)


func _build() -> void:
	ui = UnityUI.build(self, "PopupKeepPlaying")
	ui.text("Panel/GameObject/txtHeader", tr("lose_keep_title"))
	ui.text("Panel/Content/Description", tr("lose_keep_body"))
	for b in ui.field("closeButtons", "PopupKeepPlaying"):
		(b as Button).connect("clicked", _send.bind("close"))

	# State 1 (Replay): green pill, green outline.
	var keep := UnityKit.spec("PopupKeepPlaying", ROW + "/Ok")
	keep.n = "KeepButton"
	keep.img.sp = UnityKit.BUTTONS.green[0]
	keep.r[6] = BTN_W
	keep.ch[0].txt.mat = UnityKit.BUTTONS.green[1]
	keep.ch[0].txt.s = tr("level_restart_no")
	var kv: RefCounted = UnityKit.add(ui.node(ROW), keep)
	kv.on_click("", _send.bind("keep"))
	ui.node(ROW).move_child(kv.root, 0)
	# State 0 (Quit): red pill, red outline.
	var quit: Control = ui.node(ROW + "/Ok")
	quit.name = "QuitButton"
	var r: Dictionary = quit.get_meta("u_rect")
	r.size = Vector2(BTN_W, (r.size as Vector2).y)
	UnityUI.apply_rect(quit)
	ui.label(ROW + "/Ok/Out").material = UnityUI.text_material(UnityKit.BUTTONS.red[1], false)
	ui.text(ROW + "/Ok/Out", tr("lose_keep_quit"))
	ui.on_click(ROW + "/Ok", _send.bind("quit"))
	ui.relayout(ROW)

	# The note sits on the bottom strip of the cream well (well spans y 155..440 of the 660 panel).
	var note := UnityKit.spec("PopupKeepPlaying", "Panel/Content/Description")
	note.n = "NoteLabel"
	note.txt.s = tr("lose_keep_note")
	note.txt.fs = 28.0
	note.txt.auto = [18.0, 28.0]
	note.txt.h = 2
	UnityKit.add(ui.node("Panel/Content"), note, Rect2(72, 392, 580, 44))
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
