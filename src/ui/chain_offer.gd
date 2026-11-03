extends Control
## Layer Chain Offer. Cửa sổ trượt `Config.CHAIN.window` bước: bước hiện tại nhận được,
## bước trước đã nhận, bước sau bị khoá. setup(args); signal closed({claimed: int}).
## Dựng theo PopupChainOffer (color-cube-match-puzzle): 6 ô ChainOfferPack nối bằng tia UIRay theo hình rắn,
## mỗi ô một bước của cửa sổ. Trạng thái ô như ChainOfferPackItem.UpdateStatusPack: Locked -> nút khoá,
## Available -> nút nhận / giá, Claimed -> BGClaim + nút xám.

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Shop := preload("res://src/ui/shop.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const Config := preload("res://src/config.gd")

const LAYER := "PopupChainOffer"
const LIST := "Panel/Content/ListPack"
## The six on-screen slots in path order (ChainOfferPack (6)..(9) wait off-screen for the slide animation).
const SLOTS := ["ChainOfferPack", "ChainOfferPack (1)", "ChainOfferPack (2)", "ChainOfferPack (3)", "ChainOfferPack (4)",
	"ChainOfferPack (5)"]
const SPARE_SLOTS := ["ChainOfferPack (6)", "ChainOfferPack (7)", "ChainOfferPack (8)", "ChainOfferPack (9)"]
const BUTTONS := ["Button_Purchase", "Button_Purchase_Lock", "Button_Free", "Button_Free_Lock", "Button_Claim"]
## ShopRewardItem slots of a pack's reward row.
const ITEMS := ["ShopRewardItem(Clone)", "ShopRewardItem(Clone) (2)", "ShopRewardItem(Clone) (3)"]
const VIDEO_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_5"

var view: Dictionary = {}
var claim_button: Button = null
var close_button: Button = null
var time_label: Label = null
var toast_text: String = ""
var claimed_count: int = 0
var node_states: Array[String] = []  # "claimed" | "claimable" | "locked", theo thứ tự đang hiện
var ui: RefCounted = null

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
		UnityUI.set_text(time_label, tr("chain_time_left") % fmt_time(int(v.seconds_left)))


static func fmt_time(sec: int) -> String:
	sec = maxi(sec, 0)
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]


## Bước đầu tiên của cửa sổ trượt (kẹp trong chuỗi), giữ lại 1 bước đã nhận phía trước.
static func window_start(step: int, count: int, size: int) -> int:
	return clampi(step - 1, 0, maxi(0, count - size))


func _rebuild() -> void:
	var first_build := _content == null
	if _content != null:
		_content.queue_free()
		_content = null
	claim_button = null
	time_label = null
	node_states = []
	view = Game.chain_view()

	var root := Control.new()
	root.name = "Layer"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_content = root
	# ShowPopupAnimation once; a rebuild after a claim keeps the panel in place.
	ui = UnityUI.build(root, LAYER, {"reveal": first_build})
	for p in ["Panel/Top/Image/txtHeader BG2", "Panel/Top/Image/txtHeader BG1", "Panel/Top/Image/txtHeader"]:
		ui.text(p, tr("chain_title"))
	close_button = ui.button("Panel/Top/btnTurnOff")
	close_button.name = "CloseButton"
	for b in ui.field("closeButtons", "UIPopupChainOffer"):
		(b as Button).connect("clicked", close)
	for s in SPARE_SLOTS:
		ui.show(LIST + "/" + s, false)
	# Line under the timer: the game's status text (done, expired, error), hidden otherwise.
	var status: Label = ui.label("Panel/Top/Text (TMP)#2")
	status.name = "StatusLabel"

	if view.is_empty():
		UnityUI.set_text(status, tr("chain_expired"))
		ui.show("Panel/Top/Time", false)
		ui.show("Panel/Content", false)
		return
	time_label = ui.label("Panel/Top/Time/Text (TMP)")
	time_label.name = "TimeLabel"
	UnityUI.set_text(time_label, tr("chain_time_left") % fmt_time(int(view.seconds_left)))
	var count := int(view.count)
	var step := int(view.step)
	var size := mini(maxi(int(Config.CHAIN.get("window", 6)), 1), SLOTS.size())
	var first := window_start(step, count, size)
	var shown := 0
	for i in range(first, mini(count, first + size)):
		_slot(str(SLOTS[shown]), i, view.steps[i], step)
		shown += 1
	for k in range(shown, SLOTS.size()):
		ui.show(LIST + "/" + str(SLOTS[k]), false)
	# UIPopupChainOffer.listEndObjArrow: the ray past the last slot shows while later steps exist.
	for a in ui.field("listEndObjArrow", "UIPopupChainOffer"):
		if a != null:
			(a as Control).visible = first + size < count
	var msg := toast_text
	if msg == "" and step >= count:
		msg = tr("chain_done")
		status.name = "DoneLabel"
	elif msg != "":
		status.name = "ToastLabel"
	status.visible = msg != ""
	UnityUI.set_text(status, msg)


## One ChainOfferPack: reward row and the button of its state.
func _slot(slot: String, i: int, st: Dictionary, current: int) -> void:
	var p := LIST + "/" + slot
	var state := "claimed" if i < current else ("claimable" if i == current else "locked")
	node_states.append(state)
	ui.node(p).name = "Node%d" % i
	var type := str(st.get("type", "free"))
	var reward: Dictionary = RewardText.sku_reward(str(st.get("sku", ""))) if type == "pay" else st
	_fill_rewards(p + "/ItemContainer/Row(Clone)", reward)
	for b in BUTTONS:
		ui.show(p + "/" + b, false)
	ui.show(p + "/BGClaim", state == "claimed")
	var button := ""
	var text := ""
	match state:
		"claimed":
			button = "Button_Claim"
			text = tr("chain_claimed")
		"claimable":
			button = "Button_Purchase" if type == "pay" else "Button_Free"
			text = _label(type, st)
		_:
			button = "Button_Purchase_Lock" if type == "pay" else "Button_Free_Lock"
			text = _label(type, st)
	var bp := p + "/" + button
	ui.show(bp, true)
	Shop.one_line(ui.label(bp + "/ComboText/Text (TMP)"))
	ui.text(bp + "/ComboText/Text (TMP)", text)
	var b: Button = ui.button(bp)
	if state == "claimable":
		claim_button = b
		b.name = "ClaimButton"
		b.connect("clicked", claim)
	elif state == "claimed":
		b.call("set_interactable", false)
	ui.relayout(bp)
	if state == "claimable" and type == "ad":
		# Video step: the TV icon of the game's video buttons at the left edge, added after the layout pass
		# (the button's HorizontalLayoutGroup would line it up with ComboText).
		UnityKit.sprite(b, VIDEO_ICON, Rect2(-22, -14, 60, 60))


func _label(type: String, st: Dictionary) -> String:
	if type == "free":
		return tr("chain_free")
	if type == "ad":
		return tr("chain_ad")
	return tr("chain_pay") % Platform.price(str(st.get("sku", "")))


## ChainOfferPackItem.SetupUIPack: one ShopRewardItem per reward (gold, then boosters), the rest hidden.
func _fill_rewards(row: String, reward: Dictionary) -> void:
	var items: Array = []
	if int(reward.get("coins", 0)) > 0:
		items.append(["gold", int(reward.coins)])
	var inv: Dictionary = reward.get("items", {})
	for k in RewardText.BOOSTER_ORDER:
		if int(inv.get(k, 0)) > 0:
			items.append([k, int(inv[k])])
	for j in ITEMS.size():
		var ip := row + "/" + str(ITEMS[j])
		ui.show(ip, j < items.size())
		if j >= items.size():
			continue
		var kind := str(items[j][0])
		var n := int(items[j][1])
		if kind == "gold":
			ui.text(ip + "/Text (TMP)", Shop.fmt_n0(n))
		else:
			ui.texture(ip, ThemeKit.icon("booster_" + kind))
			ui.text(ip + "/Text (TMP)", tr("booster_count") % n)
	ui.relayout(row)


func claim() -> void:
	if _busy or _closed:
		return
	_busy = true
	if claim_button != null:
		claim_button.call("set_interactable", false)
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
