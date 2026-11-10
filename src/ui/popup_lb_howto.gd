extends Control
## Wireframe 8.2 How it works: luật leaderboard (khối ngôi sao -> mảnh -> điểm -> lên league). closed(null).
## Layout of LeaderboardDescriptionLayer (LeaguesDesc): three illustrated steps and a closing line carry the game's
## four rules; the steps pop in one by one like LeaderboarDescriptionAnim. Tap anywhere closes (the dim Panel).

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")

const DESC := "Panel/LeaguesDesc/"
## Step pictures drawn from the game's art (tools/render_lb_howto.gd) in place of the prefab's ic_league1..3:
## crystal block -> piece, piece = +1 rank point, Silver -> Gold league with its reward.
const ART := "res://assets/ui/lb_howto_%d.png"
## LeaderboarDescriptionAnim: _step1.._step4, OutBack scale 0 -> 1.
const STEPS := ["Step1", "Step2", "Step3", "Desc"]
const ANIM_DUR := 0.8
const ANIM_GAP := 0.3

var ui: RefCounted = null
var _built: bool = false


func setup(_args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "LeaderboardDescriptionLayer")
	ui.text(DESC + "txtHeader", tr("lb_howto_title"))
	for i in 3:
		ui.text(DESC + "Step%d/Desc" % (i + 1), tr("lb_howto_%d" % (i + 1)))
		var img := UnityUI.image_of(ui.node(DESC + "Step%d" % (i + 1)))
		if img != null:
			img.call("set_texture", load(ART % (i + 1)) as Texture2D)
			img.set("preserve_aspect", true)
	ui.text(DESC + "Desc", tr("lb_howto_4"))
	ui.text("Panel/TapToContinueTxt", tr("boot_tap_continue"))
	var ok: Button = ui.on_click("Panel", _close)
	ok.name = "OkButton"
	_play_steps.call_deferred()


func _ready() -> void:
	setup.call_deferred()


## LeaderboarDescriptionAnim.PlayScaleAnimationAsync (custom script, not run by unity_ui.gd).
func _play_steps() -> void:
	if not is_inside_tree():
		return
	var e := UnityUI.ease_of(26)
	for i in STEPS.size():
		var step: Control = ui.node(DESC + str(STEPS[i]))
		step.scale = Vector2.ZERO
		var tw := step.create_tween().set_trans(e[0]).set_ease(e[1])
		tw.tween_interval(ANIM_GAP * i)
		tw.tween_property(step, "scale", Vector2.ONE, ANIM_DUR)


func _close() -> void:
	closed.emit(null)
