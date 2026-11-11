extends Control
## Layer Chain Offer. Cửa sổ `Config.CHAIN.window` bước: bước trước đã nhận, bước hiện tại nhận được,
## bước sau bị khoá. Cửa sổ đứng yên tới khi bước hiện tại vượt ô cuối, nên gói vừa nhận được tích ngay tại chỗ;
## lúc phải trượt thì giữ dấu tích tại chỗ SLIDE_DELAY giây rồi mới trượt. setup(args); signal closed({claimed: int}).
## Dựng theo PopupChainOffer (color-cube-match-puzzle): 6 ô ChainOfferPack nối bằng tia UIRay theo hình rắn,
## mỗi ô một bước của cửa sổ. Trạng thái ô như ChainOfferPackItem.UpdateStatusPack: Locked -> nút khoá,
## Available -> nút nhận / giá, Claimed -> BGClaim + nút xám.
## Nhận xong mở popup Reward (PopupRewardLayer) với thưởng của bước; gói kế vẫn khoá tới khi popup đóng (Unity gọi
## OnSlotClaimed sau popup), cửa sổ cũng chỉ trượt sau đó. Bấm gói đang khoá: dòng dưới đồng hồ nhắc nhận gói trước
## (ChainOfferPackItem.OnTextPleaseUnlock).

signal closed(result: Variant)

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Shop := preload("res://src/ui/shop.gd")
const RewardText := preload("res://src/ui/reward_text.gd")
const Config := preload("res://src/config.gd")

const LAYER := "PopupChainOffer"
const POPUP_REWARD := "res://scenes/popup_reward.tscn"
## Title art: the prefab's chest (ic_EndlessTreasure) redrawn with this game's boosters
## (tools/compose_chain_offer_art.py).
const TITLE_IMAGE := "Panel/Top/Image"
const TITLE_ART := "art_chain_offer"
const LIST := "Panel/Content/ListPack"
const RAY := "Panel/Content/UIRay"
## The six on-screen slots in path order (ChainOfferPack (6)..(9) wait off-screen for the slide animation).
const SLOTS := ["ChainOfferPack", "ChainOfferPack (1)", "ChainOfferPack (2)", "ChainOfferPack (3)", "ChainOfferPack (4)",
	"ChainOfferPack (5)"]
const SPARE_SLOTS := ["ChainOfferPack (6)", "ChainOfferPack (7)", "ChainOfferPack (8)", "ChainOfferPack (9)"]
const BUTTONS := ["Button_Purchase", "Button_Purchase_Lock", "Button_Free", "Button_Free_Lock", "Button_Claim"]
## Button_Claim is the gray pill: its text takes the gray buttons' black stroke, not the prefab's "Baloo Outline - Black"
## (plum in this game).
const GRAY_TEXT_MAT := "Baloo Outline - Gray"
## ShopRewardItem slots of a pack's reward row.
const ITEMS := ["ShopRewardItem(Clone)", "ShopRewardItem(Clone) (2)", "ShopRewardItem(Clone) (3)"]
const VIDEO_ICON := "Resources_moved_UI_Maincenter:UI_Maincenter_5"
## Pack card backgrounds: the prefab gives ChainOfferPack (1) the yellow one (its current step always sits there).
## The window here stays put, so the yellow card follows the claimable step.
const BG_PLAIN := "UI_Shop_Packs_Atlas:UI_Shop_Packs_Atlas_8"
const BG_CURRENT := "UI_Shop_Packs_Atlas:UI_Shop_Packs_Atlas_9"
## Seconds the tick stays on the pack just claimed before the window slides to bring the next step on screen.
const SLIDE_DELAY := 0.8

var view: Dictionary = {}
var claim_button: Button = null
var close_button: Button = null
var time_label: Label = null
## Line under the timer: the game's status text (done, expired, error, locked tap).
var status_label: Label = null
var toast_text: String = ""
var claimed_count: int = 0
var node_states: Array[String] = []  # "claimed" | "claimable" | "locked", theo thứ tự đang hiện
var ui: RefCounted = null
## The Reward popup of the last claim while it is open.
var reward_popup: Node = null

var _content: Control = null
var _first: int = -1  # first step on screen; -1 before the first build
var _timer: Timer = null
var _busy: bool = false
var _closed: bool = false
## The Reward popup of the step before is open: the current step still shows locked.
var _hold: bool = false


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


## Bước đầu tiên của cửa sổ (kẹp trong chuỗi): đứng ở đầu chuỗi, chỉ trượt khi bước hiện tại phải nằm ở ô cuối.
static func window_start(step: int, count: int, size: int) -> int:
	return clampi(step - (size - 1), 0, maxi(0, count - size))


func _size() -> int:
	return mini(maxi(int(Config.CHAIN.get("window", 6)), 1), SLOTS.size())


## keep >= 0: show the window from that step instead of window_start (the tick lands where the player tapped).
func _rebuild(keep: int = -1) -> void:
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
	if ThemeKit.has_real_icon(TITLE_ART):
		ui.texture(TITLE_IMAGE, ThemeKit.icon(TITLE_ART))
	for p in ["Panel/Top/Image/txtHeader BG2", "Panel/Top/Image/txtHeader BG1", "Panel/Top/Image/txtHeader"]:
		ui.text(p, tr("chain_title"))
	close_button = ui.button("Panel/Top/btnTurnOff")
	close_button.name = "CloseButton"
	for b in ui.field("closeButtons", "UIPopupChainOffer"):
		(b as Button).connect("clicked", close)
	for s in SPARE_SLOTS:
		ui.show(LIST + "/" + s, false)
	# The prefab's UIRay arrows point back along the path, toward ChainOfferPack (where its packs slide to). Here the
	# path runs forward from ChainOfferPack (claimed -> claimable -> locked), so each arrow turns half a turn about
	# its centre to point at the next step.
	for a in ui.node(RAY).get_children():
		(a as Control).rotation += PI
	# Line under the timer: the game's status text (done, expired, error, locked tap), hidden otherwise.
	var status: Label = ui.label("Panel/Top/Text (TMP)#2")
	status.name = "StatusLabel"
	status_label = status

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
	var size := _size()
	var first := keep if keep >= 0 else window_start(step, count, size)
	_first = first
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
	var state := "claimed" if i < current else ("claimable" if i == current and not _hold else "locked")
	node_states.append(state)
	ui.node(p).name = "Node%d" % i
	ui.sprite(p + "/BG (1)", BG_CURRENT if state == "claimable" else BG_PLAIN)
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
	var label: Label = ui.label(bp + "/ComboText/Text (TMP)")
	Shop.one_line(label)
	ui.text(bp + "/ComboText/Text (TMP)", text)
	if button == "Button_Claim":
		label.material = UnityUI.text_material(GRAY_TEXT_MAT, false)
	var b: Button = ui.button(bp)
	if state == "claimable":
		claim_button = b
		b.name = "ClaimButton"
		b.connect("clicked", claim)
	elif state == "claimed":
		b.call("set_interactable", false)
	else:
		b.connect("clicked", locked_tap)
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
	var st: Dictionary = {}
	if not view.is_empty() and int(view.step) < int(view.count):
		st = view.steps[int(view.step)]
	var r: Dictionary = await Game.chain_claim()
	if not is_inside_tree() or _closed:
		_busy = false
		return
	if not bool(r.get("ok", false)):
		_busy = false
		if str(r.get("status", "")) not in ["cancel", "closed", "none"]:
			toast_text = tr("chain_failed")
		_rebuild()
		return
	claimed_count += 1
	var reward := got_reward(r, st)
	var popup := RewardText.text(reward) != "" and ResourceLoader.exists(POPUP_REWARD)
	# Without the popup the line under the timer says the reward came in.
	toast_text = "" if popup else tr("ads_reward_ok")
	# Same window first, so the tick lands on the pack the player tapped. The next pack opens once the popup closes.
	var held := _first
	_hold = popup
	_rebuild(held)
	if not popup:
		Sfx.play("sfx_coin")
		_after_reward(held)
		return
	# PopupRewardLayer plays the coin sound itself.
	reward_popup = _open_over(POPUP_REWARD, {"view": {"reward": reward}})
	reward_popup.connect("closed", func(_r: Variant) -> void:
		reward_popup = null
		_after_reward(held), CONNECT_ONE_SHOT)


## After the Reward popup: the next pack opens in place, or the window slides after a beat when it is off screen.
func _after_reward(held: int) -> void:
	var was_held := _hold
	_hold = false
	if not is_inside_tree() or _closed:
		_busy = false
		return
	var v := Game.chain_view()
	if v.is_empty() or window_start(int(v.step), int(v.count), _size()) == held:
		_busy = false
		if was_held:
			_rebuild(held)
		return
	await get_tree().create_timer(SLIDE_DELAY).timeout
	_busy = false
	if is_inside_tree() and not _closed:
		_rebuild()


## ChainOfferPackItem.OnTextPleaseUnlock: a locked pack says to claim the one before it first.
func locked_tap() -> void:
	if _closed or status_label == null or not is_instance_valid(status_label):
		return
	toast_text = tr("chain_unlock_first")
	status_label.name = "ToastLabel"
	status_label.visible = true
	UnityUI.set_text(status_label, toast_text)


## What the step just gave: {coins, items}; a Pay step's goods come with its SKU.
static func got_reward(r: Dictionary, st: Dictionary) -> Dictionary:
	if str(r.get("type", "")) == "pay":
		return RewardText.sku_reward(str(st.get("sku", "")))
	return r.get("reward", {})


## Opens a popup over this layer through Main.open_popup, or as a child when the layer runs alone (tests).
func _open_over(path: String, args: Dictionary) -> Node:
	var n := get_parent()
	while n != null:
		if n.has_method("open_popup") and n.has_method("add_popup"):
			return n.call("open_popup", path, args)
		n = n.get_parent()
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())
	node.call("setup", args)
	return node


func close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({"claimed": claimed_count})
