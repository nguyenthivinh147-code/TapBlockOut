extends Control
## Thẻ thắng: +gold, x2 (L1 miễn phí), Tiếp tục. Bố cục WinPanel của EndGameUILayer (color-cube-match-puzzle):
## cúp và kèn, ribbon tiêu đề, thẻ người chơi trên bảng xếp hạng, thanh tính năng kế tiếp, dải phần thưởng, hàng nút.
## Ô thưởng gold và dòng thông báo là node trong scenes/win_card.tscn; dòng gợi ý x2 thêm lúc chạy khi có. Dải phần
## thưởng chỉ có gold: điểm xếp hạng chỉ hiện ở thẻ người chơi (tổng điểm đếm dần), không có ô "+N điểm xếp hạng".
## setup(args): kết quả Game.on_level_won ({coins, move_coins, x2_available, x2_free, rate_prompt, progress, lb});
## ô gold hiện coins (đã gồm gold MOVES thừa). Màn level thêm moves_chip (chip lượt), moves_left và
## on_move_cashed(lượt): khi đó ô gold bắt đầu từ coins - move_coins, đồng gold bay từ chip vào ô (CoinFx), mỗi đồng
## rời chip thì gọi on_move_cashed, chạm ô thì số gold (cả số trên nút x2) tăng dần. Bấm x2 hay Tiếp tục thì cộng nốt.
## Lúc bay, cả khung chip lượt vẽ trên nền tối của thẻ (z_index CHIP_Z), xong thì về dưới nền.
## x2: popup tự gọi Game.claim_x2 (xem video, hoặc miễn phí ở L1). Nút x2 là FreeBtn (miễn phí) hoặc ClaimBtn (video).
## x2 xong thì thanh trên (HubTop, chỉ mạng và gold) trượt xuống, gold của thẻ bay từ ô gold lên chip gold của thanh
## (CoinFx), số trên chip đếm từ ví trước lúc thắng tới ví hiện tại, rồi thẻ tự đóng như Tiếp tục (nút khoá suốt lúc bay).
## closed(result): {x2_offered, x2_taken, rate_prompt, coins}. Bên gọi (level) gọi
## Game.leave_win_card(result.x2_offered, result.x2_taken) rồi mới sang level kế.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const Config := preload("res://src/config.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UButton := preload("res://src/ui/u_button.gd")
const UAnim := preload("res://src/ui/u_anim.gd")
const CoinFx := preload("res://src/ui/coin_fx.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const X2_PLACEMENT := "x2_coins"
## Gold MOVES thừa bắt đầu bay khi thẻ đã hiện chừng này giây.
const MOVE_GOLD_DELAY := 0.45
## Lúc gold MOVES thừa bay, chip lượt (dưới nền tối Bg của thẻ) vẽ trên thẻ ở z_index này, sáng dần từ độ tối của nền
## trong CHIP_FADE giây; bay xong thì mờ lại rồi về dưới nền. Đồng gold vẽ trên chip (CHIP_Z + 1).
const CHIP_Z := 2
const CHIP_FADE := 0.2
## x2 xong: thanh trên trượt xuống trong chừng này giây rồi gold mới bay; đồng cuối chạm chip thì đợi thêm X2_HOLD
## giây (loé và vòng sóng của CoinFx) rồi đóng thẻ. X2_TOP_Y: mép trên của thanh như ở Home (px thiết kế).
const X2_TOP_IN := 0.3
const X2_HOLD := 0.6
const X2_TOP_Y := 35.0

const WIN := "Panel/WinPanel"
const TOP := "Panel/WinPanel/WinPanel"
const CARD := "Panel/WinPanel/WinPanel/PlayerLeaderboardItem"
const FEATURE := "Panel/WinPanel/WinPanel/NewFeatureUnlock"
const REWARDS := "Panel/WinPanel/BG/RewardGroup/Rewards"
const ROW := "Panel/WinPanel/BG/GameObject"
## UILeaderboardUserCard image states of the player's own card: medal for rank 1..3, none from rank 4.
## (Its own-card background UI_Leaderboard_Atlas_29 is not in _sprites.json, so the prefab background stays.)
const MEDALS := ["UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_14", "UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_15",
	"UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_24"]
## Feature (Unlocks) -> game icon shown in the next-feature frame; hidden when the icon has no file.
const FEATURE_ICONS := {"daily_gift": "ui_gift", "hint": "booster_hint", "shop": "ui_shop", "move": "booster_move",
	"smash": "booster_smash", "lives": "ui_heart", "leaderboard": "ui_leaderboard", "road_trip": "ui_road_trip"}

var ui: RefCounted = null
var _args: Dictionary = {}
var _busy: bool = false
var _x2_taken: bool = false
var _reward: Label = null
var _msg: Label = null
var _x2_btn: Button = null
var _x2_path: String = ""
var _x2_label: Label = null
var _x2_amount: Label = null
## Gold đang hiện ở ô gold; đếm dần lên coins khi gold MOVES thừa bay vào.
var _shown: int = 0
## Còn gold MOVES thừa chưa vào ô; lượt đã báo màn level (chip lượt giảm); hiệu ứng đang bay.
var _move_gold_left: bool = false
var _moves_sent: int = 0
var _coin_fx: Control = null
var _reward_tw: Tween = null
## Chip lượt đang vẽ trên thẻ; z_index gốc của nó; tween sáng hay mờ của nó.
var _chip_lifted: bool = false
var _chip_z: int = 0
var _chip_tw: Tween = null
## Thanh trên hiện lúc gold x2 bay lên; số gold đang hiện trên chip của nó; đã phát closed.
var _top: Control = null
var _top_gold: int = 0
var _closed: bool = false
var _bar: Control = null
var _pct: Label = null
var _prog_before: float = 0.0
var _prog_after: float = 0.0
var _prog_unlocked: bool = false
var _feature_names: String = ""
var _lb_rank: Label = null
var _lb_total: Label = null
var _lb_name: Label = null


## Runs once: the layer, the gold reward and the message line are nodes of scenes/win_card.tscn (callers open a new
## card each time).
func setup(args: Dictionary) -> void:
	if ui != null:
		return
	_args = args
	_busy = false
	_x2_taken = false
	_closed = false
	_moves_sent = 0
	_move_gold_left = _move_coins() > 0 and _moves() > 0 and is_instance_valid(_args.get("moves_chip"))
	_shown = _coins() - _move_coins() if _move_gold_left else _coins()
	_build()


func _coins() -> int:
	return int(_args.get("coins", 0))


func _move_coins() -> int:
	return int(_args.get("move_coins", 0))


func _moves() -> int:
	return int(_args.get("moves_left", 0))


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ui = UnityUI.build(self, "EndGameUILayer")
	ui.show("Panel/LossPanel", false)
	_enable_group(ui.node(WIN))
	ui.text(TOP + "/Panel/Image/Text (TMP)", tr("win_title"))
	ui.text("Panel/WinPanel/BG/RewardGroup/RewardsText", tr("win_subtitle")).name = "SubtitleLabel"
	_build_rewards()
	_build_lb()
	_build_progress()
	ui.relayout(TOP)
	_build_buttons()
	Sfx.play("sfx_win")
	_animate_in.call_deferred()


# --- rewards (VictoryPanel.InitRewards: one Reward.prefab per item) ---

func _build_rewards() -> void:
	# The gold Reward.prefab (CoinIcon, RewardLabel) is a node of the scene. VictoryPanel's RankPoint reward is left
	# out: rank points show only on the player's leaderboard card.
	_reward = %GoldReward.get_node("RewardLabel")
	UnityUI.set_text(_reward, tr("win_reward") % _shown)
	ui.relayout(REWARDS)


# --- leaderboard card (UILeaderboardUserCard of the player) ---

## args.lb = Game.on_level_won().lb: total points count up, old rank counts to the new one; a promotion shows the new
## league in the name slot. Hidden when the level had no pieces.
func _build_lb() -> void:
	var lb: Dictionary = _args.get("lb", {})
	ui.show(CARD, not lb.is_empty())
	if lb.is_empty():
		return
	ui.node(CARD).name = "LbRow"
	ui.show(CARD + "/Gift", false)
	var cos: Dictionary = Game.s.get("cos", {}) if Game.s.get("cos") is Dictionary else {}
	var avatar := str(cos.get("avatar", Config.COSMETICS.default_avatar))
	var frame := str(cos.get("frame", Config.COSMETICS.default_frame))
	if ThemeKit.has_real_icon(avatar):
		ui.texture(CARD + "/Avatar", ThemeKit.icon(avatar))
	if ThemeKit.has_real_icon(frame):
		ui.texture(CARD + "/Avatar/Frame", ThemeKit.icon(frame))
	_lb_rank = ui.label(CARD + "/RankNumberTxt")
	_lb_rank.name = "LbRankLabel"
	_set_lb_rank(float(lb.get("rank_before", 0)))
	_lb_name = ui.text(CARD + "/PlayerName", LbKit.display_name({"me": true}))
	_lb_name.name = "LbNameLabel"
	_lb_total = ui.label(CARD + "/PointPanel/PointText")
	_lb_total.name = "LbTotalLabel"
	_set_lb_total(float(lb.get("before", 0)))


func _animate_lb() -> void:
	var lb: Dictionary = _args.get("lb", {})
	if lb.is_empty() or _lb_total == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_set_lb_total, float(lb.get("before", 0)), float(lb.get("after", 0)), 0.6)
	tw.tween_method(_set_lb_rank, float(lb.get("rank_before", 0)), float(lb.get("rank_after", 0)), 0.9).set_trans(Tween.TRANS_SINE)
	if not (lb.get("promoted", []) as Array).is_empty():
		_lb_name.scale = Vector2(0.3, 0.3)
		ui.text(CARD + "/PlayerName", tr("lb_league") % LbKit.league_name(str(lb.get("league_id", ""))))
		tw.tween_property(_lb_name, "scale", Vector2.ONE, 0.4).set_delay(0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_lb_total(v: float) -> void:
	if is_instance_valid(_lb_total):
		UnityUI.set_text(_lb_total, LbKit.fmt_int(roundi(v)))


## Rank number on the medal; the medal sprite follows the rank like the card's ImageStateKeeper.
func _set_lb_rank(v: float) -> void:
	if not is_instance_valid(_lb_rank):
		return
	var r := roundi(v)
	_lb_rank.text = str(r)
	var medal := CARD + "/RankNumberTxt/Image"
	ui.show(medal, r >= 1 and r <= MEDALS.size())
	if r >= 1 and r <= MEDALS.size():
		ui.sprite(medal, MEDALS[r - 1])


# --- next feature (VictoryPanel mechanic progress) ---

## Thanh tiến trình tới tính năng kế tiếp (Unlocks.feature_progress). Ẩn khi hết tính năng để mở.
func _build_progress() -> void:
	var p: Dictionary = _args.get("progress", {})
	ui.show(FEATURE, bool(p.get("has_next", false)))
	if not bool(p.get("has_next", false)):
		return
	ui.node(FEATURE).name = "FeatureProgress"
	_prog_before = float(p.before)
	_prog_after = float(p.after)
	_prog_unlocked = _prog_after >= 1.0
	var names: PackedStringArray = []
	for f in p.features:
		names.append(tr("feature_" + str(f)))
	_feature_names = ", ".join(names)
	ui.text(FEATURE + "/RewardsText", tr("feature_next") % _feature_names).name = "FeatureLabel"
	_bar = ui.node(FEATURE + "/Slider")
	_bar.name = "FeatureBar"
	_pct = ui.label(FEATURE + "/Slider/ProgressText")
	_pct.name = "FeaturePercent"
	_set_progress(0.0)
	var first := str(p.features[0]) if not (p.features as Array).is_empty() else ""
	var icon := str(FEATURE_ICONS.get(first, "mech_" + first))
	var feature_image := FEATURE + "/Slider/Image/FeatureImage"
	var real := icon != "" and ThemeKit.has_real_icon(icon)
	ui.show(feature_image, real)
	if real:
		ui.texture(feature_image, ThemeKit.icon(icon))
		UnityUI.image_of(ui.node(feature_image)).preserve_aspect = true


## Smooth step from the value before this win to the value after, like AnimateProgressFill.
func _animate_progress() -> void:
	if _bar == null:
		return
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, float(ui.field("progressAnimDuration", "VictoryPanel")))
	if _prog_unlocked:
		tw.tween_callback(_show_unlocked)


func _set_progress(t: float) -> void:
	if _bar == null or not is_instance_valid(_bar):
		return
	var v := lerpf(_prog_before, _prog_after, t * t * (3.0 - 2.0 * t))
	UnityUI.set_slider(_bar, v)
	UnityUI.set_text(_pct, "%d%%" % roundi(v * 100.0))


## Đạt 100%: thay dòng "Mở khoá tiếp" bằng thông báo đã mở.
func _show_unlocked() -> void:
	var l := find_child("FeatureLabel", true, false) as Label
	if l == null:
		return
	UnityUI.set_text(l, tr("feature_unlocked") % _feature_names)
	l.scale = Vector2.ZERO
	create_tween().tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("sfx_coin")


# --- buttons ---

func _build_buttons() -> void:
	var cont: Button = ui.button(ROW + "/ContinueBtn")
	cont.name = "ContinueButton"
	ui.text(ROW + "/ContinueBtn/Text (TMP)", tr("win_continue"))
	cont.connect("clicked", _on_continue_pressed)
	if bool(_args.get("x2_available", false)):
		var free := bool(_args.get("x2_free", false))
		# SetupButtonState: FreeBtn on the first claim, ClaimBtn (video) after; both show the doubled gold.
		var keep := "FreeBtn" if free else "ClaimBtn"
		ui.show(ROW + ("/ClaimBtn" if free else "/FreeBtn"), false)
		ui.show(ROW + "/" + keep, true)
		_x2_path = ROW + "/" + keep
		_x2_btn = ui.button(_x2_path)
		_x2_btn.name = "X2Button"
		_x2_label = ui.text(ROW + "/" + keep + "/Text (TMP)", tr("win_x2_free") if free else tr("win_x2"))
		if not free:
			# The game's label is longer than "Claim": keep it clear of the TV icon on the top-right corner.
			var r: Dictionary = _x2_label.get_meta("u_rect")
			r.pos = Vector2(-30, (r.pos as Vector2).y)
			r.size = Vector2(236, (r.size as Vector2).y)
			UnityUI.apply_rect(_x2_label)
		_x2_amount = ui.label(ROW + "/" + keep + "/GameObject (1)/Text (TMP)")
		_x2_amount.text = LbKit.fmt_int(_shown * 2)
		ui.relayout(ROW + "/" + keep + "/GameObject (1)")
		_x2_btn.connect("clicked", _on_x2_pressed)
		if free:
			var hint := _line("X2HintLabel", tr("tut_x2"), 604.0)
			hint.get_parent().move_child(hint, (%MessageLabel as Control).get_index())
		else:
			Game.offer_video(X2_PLACEMENT)
	else:
		ui.show(ROW + "/FreeBtn", false)
		ui.show(ROW + "/ClaimBtn", false)
	ui.relayout(ROW)
	_msg = %MessageLabel
	_msg.visible = false


## White outlined line under the button row (RewardsText style), centred, y = centre below the BG top.
func _line(node_name: String, text: String, y: float) -> Label:
	var s := UnityKit.spec("EndGameUILayer", "Panel/WinPanel/BG/RewardGroup/RewardsText")
	s.n = node_name
	s.r = [0.5, 1, 0.5, 1, 0, -y, 800, 80, 0.5, 0.5]
	s.txt.s = text
	s.txt.fs = 40.0
	s.txt.auto = [18.0, 40.0]
	s.txt.w = true
	s.txt.st = 0
	return UnityKit.add(ui.node("Panel/WinPanel/BG"), s).root as Label


# --- animation ---

func _animate_in() -> void:
	if ui == null or not is_inside_tree():
		return
	# VictoryPanel.PlayShowAnimation: canvas group alpha 0.3 -> 1 in 1 s, OutBack.
	var win: Control = ui.node(WIN)
	win.modulate.a = 0.3
	create_tween().tween_property(win, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for e in ui.scripts:
		if str(e.cs.get("name", "")) == "CurveDrivenImageScaler" and bool(int(e.cs.get("playOnStart", "1"))):
			_curve_scale(e.node, e.cs)
	_animate_progress()
	_animate_lb()
	if _move_gold_left:
		create_tween().tween_callback(_fly_move_gold).set_delay(MOVE_GOLD_DELAY)


# --- gold MOVES thừa (CoinFx từ chip lượt của màn level vào ô gold) ---

func _fly_move_gold() -> void:
	if not _move_gold_left or not is_inside_tree():
		return
	var chip: Variant = _args.get("moves_chip")
	if not is_instance_valid(chip) or not (chip as Control).is_inside_tree():
		_finish_move_gold()
		return
	_lift_chip(chip)
	var icon: Control = %GoldReward.get_node("CoinIcon")
	_coin_fx = CoinFx.new()
	_coin_fx.name = "MoveGoldFx"
	_coin_fx.z_index = CHIP_Z + 1
	add_child(_coin_fx)
	_coin_fx.start(chip, icon, _coin_texture(icon), _moves(), _move_coins(), _on_move_coin_launch, _on_move_coin_land)


## Cả khung chip lượt hiện trên nền tối và bảng của thẻ, sáng dần từ độ tối của nền.
func _lift_chip(chip: Control) -> void:
	if _chip_lifted:
		return
	_chip_lifted = true
	_chip_z = chip.z_index
	chip.z_index = CHIP_Z
	chip.modulate.a = _chip_dim()
	_chip_tw = chip.create_tween()
	_chip_tw.tween_property(chip, "modulate:a", 1.0, CHIP_FADE)


## Chip lượt mờ lại rồi về dưới nền tối. Tween nằm trên chip nên chạy nốt cả khi thẻ đã đóng; `now` (thẻ rời cây giữa
## chừng) thì trả ngay.
func _drop_chip(now: bool = false) -> void:
	if not _chip_lifted:
		return
	_chip_lifted = false
	if _chip_tw != null and _chip_tw.is_valid():
		_chip_tw.kill()
	_chip_tw = null
	var chip: Variant = _args.get("moves_chip")
	if not is_instance_valid(chip):
		return
	var c := chip as Control
	if now or not c.is_inside_tree():
		c.z_index = _chip_z
		c.modulate.a = 1.0
		return
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", _chip_dim(), CHIP_FADE)
	tw.tween_callback(c.set_z_index.bind(_chip_z))
	tw.tween_property(c, "modulate:a", 1.0, 0.0)


## Độ sáng chip lượt khi nằm dưới nền tối Bg của thẻ.
func _chip_dim() -> float:
	var bg: Control = ui.node("Panel/Bg") if ui != null and ui.has("Panel/Bg") else null
	return 1.0 - (bg.get("color") as Color).a if bg != null else 1.0


## Hình đồng gold của ô thưởng (u_image: atlas và vùng cắt).
func _coin_texture(icon: Control) -> Texture2D:
	var tex: Texture2D = icon.get("tex")
	var region: Rect2 = icon.get("region")
	if tex == null or not region.has_area():
		return tex
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at


func _on_move_coin_launch(moves: int) -> void:
	if _move_gold_left:
		_send_moves(moves)


func _on_move_coin_land(gold: int, last: bool) -> void:
	if not _move_gold_left:
		return
	_set_shown(_shown + gold)
	_punch_reward(1.35 if last else 1.15)
	Sfx.play("sfx_coin")
	if last:
		_finish_move_gold(true)


## Báo màn level `n` lượt đã đổi ra gold để chip lượt giảm theo.
func _send_moves(n: int) -> void:
	_moves_sent += n
	var cb: Variant = _args.get("on_move_cashed")
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(n)


## Cộng nốt phần chưa bay: chip lượt về 0, ô gold hiện đủ coins. Bỏ qua giữa chừng thì xoá hiệu ứng; đồng cuối vừa
## chạm (`landed`) thì để hiệu ứng chạy nốt vòng sóng rồi tự xoá.
func _finish_move_gold(landed: bool = false) -> void:
	if not _move_gold_left:
		return
	if _moves() > _moves_sent:
		_send_moves(_moves() - _moves_sent)
	_move_gold_left = false
	_set_shown(_coins())
	_drop_chip()
	if not landed and is_instance_valid(_coin_fx):
		_coin_fx.queue_free()
	_coin_fx = null


func _exit_tree() -> void:
	_drop_chip(true)


func _set_shown(n: int) -> void:
	_shown = n
	UnityUI.set_text(_reward, tr("win_reward") % n)
	if _x2_amount != null and not _x2_taken:
		_x2_amount.text = LbKit.fmt_int(n * 2)
		ui.relayout(_x2_path + "/GameObject (1)")


func _punch_reward(k: float) -> void:
	if _reward_tw != null and _reward_tw.is_valid():
		_reward_tw.kill()
	var icon: Control = %GoldReward.get_node("CoinIcon")
	_reward.scale = Vector2(k, k)
	icon.scale = Vector2(k, k)
	_reward_tw = create_tween().set_parallel(true)
	for n in [_reward, icon]:
		_reward_tw.tween_property(n, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- gold x2 bay lên thanh trên (CoinFx từ ô gold của thẻ vào chip gold của HubTop) ---

func _fly_x2_gold() -> void:
	var total := _coins() * 2
	if total <= 0 or not is_inside_tree():
		_close()
		return
	_top = HubTop.create()
	_top.set_meta("u_rt", true)
	_top.hide_side_buttons()
	add_child(_top)
	# Gold of this win is already in the wallet: the chip starts from the balance before the win and counts up to it.
	_top_gold = maxi(int(Game.s.coins) - total, 0)
	_top.gold_shown = _top_gold
	var s := size.x / HubTop.DESIGN_W
	_top.size = Vector2(size.x, HubTop.DESIGN_H * s)
	_top.position = Vector2(0, -HubTop.DESIGN_H * s)
	_top.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_top, "position:y", X2_TOP_Y * s, X2_TOP_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_top, "modulate:a", 1.0, X2_TOP_IN * 0.6)
	tw.chain().tween_callback(_start_x2_fx)


func _start_x2_fx() -> void:
	if not is_instance_valid(_top) or not is_inside_tree():
		_close()
		return
	var icon: Control = %GoldReward.get_node("CoinIcon")
	var fx: Control = CoinFx.new()
	fx.name = "X2GoldFx"
	add_child(fx)
	fx.start(icon, _top.gold_icon, _coin_texture(icon), CoinFx.MAX_COINS, _coins() * 2, Callable(), _on_x2_coin_land)


func _on_x2_coin_land(gold: int, last: bool) -> void:
	if not is_instance_valid(_top):
		return
	_top_gold += gold
	_top.gold_shown = -1 if last else _top_gold
	var icon: Control = _top.gold_icon
	var k := 1.35 if last else 1.15
	icon.pivot_offset = icon.size * 0.5
	icon.scale = Vector2(k, k)
	create_tween().tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("sfx_coin")
	if last:
		create_tween().tween_callback(_close).set_delay(X2_HOLD)


## CurveDrivenImageScaler (not in unity_ui.gd): scale x/y from AnimationCurves, loopCount cycles from startOffset.
func _curve_scale(c: Control, cs: Dictionary) -> void:
	var kx := _curve_keys(cs.get("scaleXCurve", {}))
	var ky := _curve_keys(cs.get("scaleYCurve", {}))
	if kx.is_empty() or ky.is_empty():
		return
	var dur := maxf(0.01, float(cs.get("duration", "1")))
	var loops := 1000 if bool(int(cs.get("infiniteLoop", "0"))) else maxi(1, int(cs.get("loopCount", "1")))
	var sign_x := signf(c.scale.x) if c.scale.x != 0.0 else 1.0
	var step := func(t: float) -> void:
		if is_instance_valid(c):
			var u := fposmod(t, dur) / dur
			c.scale = Vector2(UAnim.evaluate(kx, u) * sign_x, UAnim.evaluate(ky, u))
	c.create_tween().tween_method(step, float(cs.get("startOffset", "0")) * dur, loops * dur - 0.001, loops * dur - float(cs.get("startOffset", "0")) * dur)


## Unity AnimationCurve m_Curve -> u_anim keys [time, value, in_slope, out_slope] (infinite slope = stepped).
static func _curve_keys(curve: Variant) -> Array:
	var out: Array = []
	if not (curve is Dictionary):
		return out
	for k in (curve as Dictionary).get("m_Curve", []):
		var ins := float(k.get("inSlope", "0"))
		var outs := float(k.get("outSlope", "0"))
		out.append([float(k.get("time", "0")), float(k.get("value", "0")), ins if is_finite(ins) else null, outs if is_finite(outs) else null])
	return out


## VictoryPanel turns the WinPanel CanvasGroup on (interactable, blocksRaycasts) when it shows; unity_ui.gd bakes the
## prefab's off state into the subtree at build time, so give each node back the input it would have had.
static func _enable_group(c: Control) -> void:
	var spec: Dictionary = c.get_meta("u", {})
	if c is UButton:
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		(c as UButton).set_interactable(bool((spec.get("btn", spec.get("tog", {})) as Dictionary).get("inter", true)))
	elif c is Label:
		c.mouse_filter = Control.MOUSE_FILTER_PASS if bool((spec.get("txt", {}) as Dictionary).get("rt", false)) else Control.MOUSE_FILTER_IGNORE
	elif spec.has("img") or spec.has("raw"):
		c.mouse_filter = Control.MOUSE_FILTER_PASS if bool((spec.get("img", spec.get("raw", {})) as Dictionary).get("rt", false)) else Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control and ch.has_meta("u"):
			_enable_group(ch)


# --- actions ---

func _set_busy(v: bool) -> void:
	_busy = v
	for b in [ui.node(ROW + "/ContinueBtn"), _x2_btn]:
		if b != null:
			(b as UButton).set_interactable(not v)
	if not v and _x2_taken and _x2_btn != null:
		(_x2_btn as UButton).set_interactable(false)


func _on_x2_pressed() -> void:
	if _busy or _x2_taken:
		return
	_finish_move_gold()
	_set_busy(true)
	var ok: bool = await Game.claim_x2()
	if not is_inside_tree():
		return
	if ok:
		_x2_taken = true
		UnityUI.set_text(_reward, tr("win_reward") % (_coins() * 2))
		var pulse := create_tween()
		pulse.tween_property(_reward, "scale", Vector2(1.25, 1.25), 0.12)
		pulse.tween_property(_reward, "scale", Vector2.ONE, 0.18)
		# AnimScaleButton.StopAnim (the loop OnDisplayLayout started).
		ui.stop(_x2_path)
		UnityUI.set_text(_x2_label, tr("win_x2_done"))
		_msg.visible = false
		Sfx.play("sfx_coin")
		# Buttons stay locked: the gold flies up to the top bar, then the card closes by itself.
		_fly_x2_gold()
		return
	match Game.last_ad_reason:
		"not_ready":
			UnityUI.set_text(_msg, tr("ads_not_available"))
		"closed":
			UnityUI.set_text(_msg, tr("ads_closed_early"))
		_:
			UnityUI.set_text(_msg, tr("ads_failed"))
	_msg.visible = true
	_set_busy(false)


func _on_continue_pressed() -> void:
	if _busy:
		return
	_finish_move_gold()
	_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	closed.emit({
		"x2_offered": bool(_args.get("x2_available", false)),
		"x2_taken": _x2_taken,
		"rate_prompt": bool(_args.get("rate_prompt", false)),
		"coins": _coins() * (2 if _x2_taken else 1),
	})
