extends Control
## Layer Chain Offer. Cửa sổ trượt `Config.CHAIN.window` bước: bước hiện tại nhận được,
## bước trước đã nhận, bước sau bị khoá. setup(args); signal closed({claimed: int}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const Config := preload("res://src/config.gd")

var view: Dictionary = {}
var claim_button: Button = null
var close_button: Button = null
var time_label: Label = null
var toast_text: String = ""
var claimed_count: int = 0
var node_states: Array[String] = []  # "claimed" | "claimable" | "locked", theo thứ tự đang hiện

var _content: Control = null
var _timer: Timer = null
var _busy: bool = false
var _closed: bool = false


func setup(_args: Dictionary = {}) -> void:
	if _content != null:
		return
	_rebuild()


func _ready() -> void:
	if _content == null:
		setup()
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()


func _tick() -> void:
	if _closed or _content == null:
		return
	var v := Game.chain_view()
	if v.is_empty():
		close()
	elif time_label != null:
		time_label.text = tr("chain_time_left") % fmt_time(int(v.seconds_left))


static func fmt_time(sec: int) -> String:
	sec = maxi(sec, 0)
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]


## Bước đầu tiên của cửa sổ trượt (kẹp trong chuỗi), giữ lại 1 bước đã nhận phía trước.
static func window_start(step: int, count: int, size: int) -> int:
	return clampi(step - 1, 0, maxi(0, count - size))


func _rebuild() -> void:
	if _content != null:
		_content.queue_free()
		_content = null
	claim_button = null
	node_states = []
	view = Game.chain_view()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root
	var k := PopupKit.make(root, tr("chain_title"), close, {"separation": 10})
	close_button = k.close
	close_button.name = "CloseButton"
	var v: VBoxContainer = k.box

	if view.is_empty():
		v.add_child(PopupKit.text(tr("chain_expired")))
	else:
		time_label = PopupKit.text(tr("chain_time_left") % fmt_time(int(view.seconds_left)), ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "TimeLabel")
		v.add_child(time_label)
		var count := int(view.count)
		var step := int(view.step)
		var size := maxi(int(Config.CHAIN.get("window", 6)), 1)
		var first := window_start(step, count, size)
		for i in range(first, mini(count, first + size)):
			v.add_child(_node_row(i, view.steps[i], step))
		if step >= count:
			v.add_child(PopupKit.text(tr("chain_done"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM, "DoneLabel"))
	if toast_text != "":
		v.add_child(PopupKit.text(toast_text, ThemeKit.FS_SMALL, ThemeKit.INK_DANGER, "ToastLabel"))
	PopupKit.show_in(k)


## Một hàng: số bước, thưởng, nút/nhãn trạng thái.
func _node_row(i: int, st: Dictionary, current: int) -> Control:
	var state := "claimed" if i < current else ("claimable" if i == current else "locked")
	node_states.append(state)
	var type := str(st.get("type", "free"))
	var well := ThemeKit.make_well(ThemeKit.WELL_HOT if state == "claimable" else ThemeKit.WELL,
		ThemeKit.WELL_HEADER if state == "claimable" else Color(0, 0, 0, 0))
	well.name = "Node%d" % i
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	well.add_child(h)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(txt)
	txt.add_child(ThemeKit.ink_label(tr("chain_step") % (i + 1), ThemeKit.FS_SMALL - 2, ThemeKit.BROWN))
	var reward: Dictionary = RewardText.sku_reward(str(st.get("sku", ""))) if type == "pay" else st
	var rl := ThemeKit.ink_label(RewardText.text(reward), ThemeKit.FS_SMALL)
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_child(rl)
	match state:
		"claimed":
			h.add_child(ThemeKit.make_icon("ui_check", 72))
		"claimable":
			var label := tr("chain_free") if type == "free" else (tr("chain_ad") if type == "ad" \
				else tr("chain_pay") % Platform.price(str(st.get("sku", ""))))
			claim_button = ThemeKit.make_button(label, "primary" if type != "ad" else "video")
			claim_button.name = "ClaimButton"
			claim_button.custom_minimum_size = Vector2(180, 96)
			claim_button.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL + 2)
			claim_button.pressed.connect(claim)
			h.add_child(claim_button)
		_:
			h.add_child(ThemeKit.make_icon("ui_lock", 72))
	return well


func claim() -> void:
	if _busy or _closed:
		return
	_busy = true
	if claim_button != null:
		claim_button.disabled = true
	Sfx.play("button")
	var r: Dictionary = await Game.chain_claim()
	_busy = false
	if not is_inside_tree() or _closed:
		return
	if bool(r.get("ok", false)):
		claimed_count += 1
		toast_text = ""
		Sfx.play("sfx_coin")
	elif str(r.get("status", "")) not in ["cancel", "closed", "none"]:
		toast_text = tr("chain_failed")
	_rebuild()


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"claimed": claimed_count})
