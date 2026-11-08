extends RefCounted
## Mọi con số kinh tế, quảng cáo, mở khoá, offer. Số theo design.md mục 3-7.
## Remote Config ghi đè bằng apply_remote(); reset() trả về mặc định (dùng trong test).
## Gold trong code tên `coins`.

const _ECON := {
	"start_coins": 1000,
	"win_coins": 40,
	## Gold per MOVES left on the board at a win, added to the win reward (x2 doubles it too).
	"win_move_coins": 10,
	"booster_price": {"hint": 900, "move": 1900, "smash": 2900},
	"refill_coins": 900,
	"refill_lives": 5,
	"shop_video_coins": 200,
	"shop_video_max": 5,
	"rescue_prices": [1900, 2200, 2500, 2800],
	"rescue_moves": 3,
	"rescue_video_max": 4,
	"challenge_coins": 100,
}

const _LIVES := {
	"max": 10,
	"regen_sec": 900,
	"from_level": 10,
}

const _ADS := {
	"inter_from_run": 4,
	"inter_every": 2,
	"inter_cooldown": 120,
	"session_warmup": 90,
	"rewarded_grace": 45,
	"first_session_block_until_level": 10,
}

const _UNLOCK := {
	"daily_gift": 4, "hint": 5, "shop": 5, "move": 12, "smash": 17,
	"lives": 10, "starter": 10, "review": 10, "challenge": 50, "leaderboard": 8, "road_trip": 2,
	"stone": 14, "ice": 30, "chain": 40, "layer": 55, "fog": 70, "pulse": 90,
}

## On/off switch per Config.UNLOCK feature (missing key = on). Off: Unlocks.is_open is false at every level, the win
## card neither announces nor counts it, and Home hides its icon. Remote Config: `features_<name>` ("1" / "0").
## Daily Challenge is off since 2026-11-08 (design.md mục 4 "Phạm vi").
const _FEATURES := {
	"challenge": false,
}

## 28 ô quà. Tổng: 6.650 gold, 5 hint, 5 move, 4 smash.
const _DAILY := [
	{"coins": 50, "items": {}},
	{"coins": 100, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 200, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 300, "items": {}},
	{"coins": 500, "items": {"smash": 1}},
	{"coins": 100, "items": {}},
	{"coins": 150, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 250, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 350, "items": {}},
	{"coins": 600, "items": {"smash": 1}},
	{"coins": 150, "items": {}},
	{"coins": 200, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 300, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 400, "items": {}},
	{"coins": 700, "items": {"smash": 1}},
	{"coins": 200, "items": {}},
	{"coins": 250, "items": {}},
	{"coins": 0, "items": {"hint": 1}},
	{"coins": 350, "items": {}},
	{"coins": 0, "items": {"move": 1}},
	{"coins": 500, "items": {}},
	{"coins": 1000, "items": {"smash": 1, "hint": 1, "move": 1}},
]

## avatar_01..N và frame_01..N; giá xoay vòng theo `prices`. *_00 miễn phí và luôn có.
const _COSMETICS := {
	"avatar_count": 12,
	"frame_count": 12,
	"prices": [50, 75, 100],
	"default_avatar": "avatar_00",
	"default_frame": "frame_00",
}

## usd, consumable, gold, inv (booster), no_ads. Gói sale là SKU riêng đuôi `_sale`.
const _SKUS := {
	"gold_pack_1": {"usd": 1.99, "consumable": true, "gold": 1000},
	"gold_pack_2": {"usd": 7.99, "consumable": true, "gold": 5000},
	"gold_pack_3": {"usd": 14.99, "consumable": true, "gold": 10000},
	"gold_pack_4": {"usd": 29.99, "consumable": true, "gold": 25000},
	"gold_pack_5": {"usd": 49.99, "consumable": true, "gold": 50000},
	"gold_pack_6": {"usd": 99.99, "consumable": true, "gold": 100000},
	"gold_pack_1_sale": {"usd": 0.99, "consumable": true, "gold": 2000},
	"gold_pack_2_sale": {"usd": 3.99, "consumable": true, "gold": 5000},
	"gold_pack_3_sale": {"usd": 7.49, "consumable": true, "gold": 10000},
	"gold_pack_4_sale": {"usd": 14.99, "consumable": true, "gold": 25000},
	"gold_pack_5_sale": {"usd": 24.99, "consumable": true, "gold": 50000},
	"gold_pack_6_sale": {"usd": 49.99, "consumable": true, "gold": 100000},
	"remove_ads": {"usd": 4.99, "consumable": false, "gold": 500, "no_ads": true},
	"starter_pack": {"usd": 6.99, "consumable": false, "gold": 6000,
		"inv": {"hint": 1, "move": 1, "smash": 1}},
	"rescue_pack": {"usd": 0.99, "consumable": true, "inv": {"move": 1}},
	"level_pack": {"usd": 4.99, "consumable": true, "gold": 2000,
		"inv": {"hint": 1, "move": 1, "smash": 1}},
	# Mua lại được mỗi tuần nên consumable; trạng thái VIP nằm ở s.weekly.vip.
	"weekly_pass": {"usd": 4.99, "consumable": true, "weekly_vip": true},
	"special_pack": {"usd": 10.99, "consumable": true, "gold": 12000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	"special_pack_sale": {"usd": 5.49, "consumable": true, "gold": 12000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	# Bước Pay của Chain Offer: thưởng lấy từ chính gói.
	"chain_pack_1": {"usd": 0.99, "consumable": true, "gold": 1500},
	"chain_pack_2": {"usd": 2.99, "consumable": true, "gold": 3000,
		"inv": {"hint": 1, "move": 1}},
}

## Điều kiện hiện gói (PackConditionSO). level_appear: từ level này; purchase_limit: 0 = không giới hạn;
## required: phải đã mua đủ các gói này; exclude: đã sở hữu gói nào trong đây thì ẩn.
const _PACKS := {
	"special_pack": {"sku": "special_pack", "level_appear": 16, "purchase_limit": 0,
		"required": ["starter_pack"], "exclude": []},
}

## Weekly Pass. Chu kỳ: thứ Hai 06:00 -> thứ Hai 00:00 tuần sau (giờ máy); thứ Hai 00:00-06:00 là Waiting.
## points: điểm key theo độ khó; unlock_hard_index: mở sau level HARD thứ N.
## main: mỗi mốc {points, free, vip} với thưởng {coins, items, inf_min}; inf_min là số phút mạng vô hạn. Mốc đầu có points = 0 (mốc khởi đầu,
## nhận được ngay, là phần thưởng "đầu tiên" mà tutorial chỉ vào). bank: sau mốc cuối,
## mỗi `bank_step` key thừa được 1 mốc, tối đa `bank_max` mốc, mỗi mốc là `bank_reward`.
const _WEEKLY := {
	"enabled": true,
	"sku": "weekly_pass",
	"unlock_hard_index": 2,
	"start_hour": 6,
	"vip_bonus_hearts": 3,
	"points_normal": 1,
	"points_hard": 3,
	"points_very_hard": 5,
	"bank_step": 15,
	"bank_max": 10,
	"bank_reward_coins": 400,
	"main": [
		{"points": 0, "free": {"coins": 0, "items": {}, "inf_min": 15}, "vip": {"coins": 150, "items": {}}},
		{"points": 3, "free": {"coins": 100, "items": {}}, "vip": {"coins": 200, "items": {}, "inf_min": 30}},
		{"points": 8, "free": {"coins": 0, "items": {"hint": 1}}, "vip": {"coins": 300, "items": {"hint": 1}}},
		{"points": 15, "free": {"coins": 150, "items": {}}, "vip": {"coins": 400, "items": {}}},
		{"points": 25, "free": {"coins": 0, "items": {"move": 1}}, "vip": {"coins": 0, "items": {"move": 2}}},
		{"points": 38, "free": {"coins": 200, "items": {}}, "vip": {"coins": 600, "items": {}}},
		{"points": 52, "free": {"coins": 0, "items": {"smash": 1}}, "vip": {"coins": 0, "items": {"smash": 2}}},
		{"points": 68, "free": {"coins": 300, "items": {}}, "vip": {"coins": 800, "items": {}}},
		{"points": 85, "free": {"coins": 0, "items": {"hint": 1, "move": 1}}, "vip": {"coins": 500, "items": {"hint": 2, "move": 2}}},
		{"points": 105, "free": {"coins": 400, "items": {}}, "vip": {"coins": 1000, "items": {}}},
		{"points": 130, "free": {"coins": 500, "items": {"smash": 1}}, "vip": {"coins": 2000, "items": {"smash": 2}}},
	],
}

## Chain Offer. days_to_existence: sống bấy nhiêu ngày từ lúc bật; days_to_reset: nghỉ bấy nhiêu ngày
## sau khi hết hạn; level_unlock: từ level này; require_lose: -1 = xét sau mọi ván, khác -1 = chỉ sau
## khi thua ở level không HARD. Chuỗi xoay vòng theo thứ tự. Bước: type free | ad | pay.
const _CHAIN := {
	"days_to_existence": 1,
	"days_to_reset": 3,
	"level_unlock": 24,
	"require_lose": -1,
	"window": 6,
	"sequences": [
		{"id": "chain_a", "steps": [
			{"type": "free", "coins": 300, "items": {}},
			{"type": "ad", "coins": 0, "items": {"hint": 1}},
			{"type": "free", "coins": 500, "items": {}},
			{"type": "pay", "sku": "chain_pack_1"},
			{"type": "ad", "coins": 0, "items": {"move": 1}},
			{"type": "free", "coins": 800, "items": {"smash": 1}},
			{"type": "pay", "sku": "chain_pack_2"},
			{"type": "ad", "coins": 1000, "items": {}},
		]},
		{"id": "chain_b", "steps": [
			{"type": "free", "coins": 0, "items": {"move": 1}},
			{"type": "ad", "coins": 400, "items": {}},
			{"type": "free", "coins": 0, "items": {"hint": 1, "smash": 1}},
			{"type": "pay", "sku": "chain_pack_2"},
			{"type": "ad", "coins": 600, "items": {}},
			{"type": "free", "coins": 1000, "items": {}},
			{"type": "pay", "sku": "chain_pack_1"},
			{"type": "ad", "coins": 0, "items": {"smash": 1}},
		]},
	],
}

## Leaderboard theo league (design.md mục 7). Level từ Config.UNLOCK.leaderboard có `pieces_*` khối đặc biệt
## (theo độ khó); phá một khối được 1 mảnh = 1 điểm, cộng khi thắng. League theo tổng điểm, chỉ lên không xuống.
## leagues: {id, min, reward {coins, items, inf_min}, bot_base, players}. League đầu có min 0; reward nhận khi vào league.
## bot_base: điểm tăng cơ bản mỗi ngày của bot; players: số người chơi mô phỏng của league, dùng cho Top %.
## Bot tăng điểm mỗi ngày lúc `grow_hour` giờ ở múi GMT+`grow_tz_hours`:
## tăng = bot_base + round(randi_range(bot_rand) * randf_range(bot_var)). Vắng lâu thì chỉ bù tối đa `grow_max_days` ngày.
## BXH `board_size` người (người chơi + bot), UI hiện `view_size` người quanh người chơi. League cuối không có trần:
## bot rải trong [min, min + top_span]. Avatar, frame của bot: `*_default_pct`% dùng mặc định, còn lại random đều.
const _LEADERBOARD := {
	"enabled": true,
	"board_size": 100,
	"view_size": 50,
	"pieces_normal": 2,
	"pieces_hard": 3,
	"pieces_very_hard": 4,
	"grow_tz_hours": 7,
	"grow_hour": 7,
	"grow_max_days": 14,
	"bot_rand": [0, 4],
	"bot_var": [0.5, 1.5],
	"bot_avatar_default_pct": 80,
	"bot_frame_default_pct": 85,
	"carry_max": 10,
	"top_span": 1000,
	"world_size": 50,
	"leagues": [
		{"id": "silver", "min": 0, "reward": {"coins": 100, "items": {}}, "bot_base": 1, "players": 48000},
		{"id": "gold", "min": 30, "reward": {"coins": 300, "items": {"hint": 1}}, "bot_base": 2, "players": 24000},
		{"id": "platinum", "min": 80, "reward": {"coins": 500, "items": {"move": 1}}, "bot_base": 3, "players": 14000},
		{"id": "emerald", "min": 180, "reward": {"coins": 800, "items": {"smash": 1}}, "bot_base": 4, "players": 8000},
		{"id": "diamond", "min": 330, "reward": {"coins": 1200, "items": {"hint": 1, "move": 1}}, "bot_base": 5, "players": 4000},
		{"id": "immortal", "min": 550, "reward": {"coins": 2000, "items": {"hint": 1, "move": 1, "smash": 1}}, "bot_base": 7, "players": 1600},
		{"id": "one_above_all", "min": 1000, "reward": {"coins": 5000, "items": {"hint": 2, "move": 2, "smash": 2}, "inf_min": 60}, "bot_base": 10, "players": 400},
	],
}

## Offer. min_secs: không popup trong N giây đầu phiên đầu; gap_runs: cách nhau ít nhất N lượt.
## starter_pack: mở khi level > after_level hoặc runs >= at_run.
const _OFFERS := {
	"min_secs": 300,
	"gap_runs": 3,
	"starter_pack": {"sku": "starter_pack", "after_level": 10, "at_run": 12, "hours": 48},
	"remove_ads": {"sku": "remove_ads", "after_inter_today": 3, "per_day": 1, "max_total": 3},
	"rescue_pack": {"sku": "rescue_pack", "fail_streak": 3, "cooldown_hours": 24},
	"level_pack": {"sku": "level_pack", "every_levels": 10, "hours": 72},
}

## Lịch thông báo (theo GAME-GUIDE mục 15). Giờ theo giờ máy.
const _NOTIF := {
	"first_week_days": 7,
	"first_week_per_day": 3,
	"lead_min": 15,
	"daily_until_day": 14,
	"sparse_days": [16, 18, 21, 24, 27, 30],
	"earliest_hour": 8,
	"latest_hour": 22,
	"quiet_after_ignored": 9,
	"ask_after_run": 2,
	# Thông báo buổi tối mỗi ngày (notif_plan.gd): phút trong ngày (1200 = 20:00) và lập trước bao nhiêu ngày (0 = tắt)
	"evening_minute": 1200,
	"evening_days": 30,
}

## Road Trip (design.md mục 7 "Road Trip"): đường 400 level riêng (data/road_trip, bộ MoreColor), mở từ UNLOCK.road_trip.
## Chơi không tốn mạng, thắng không cộng gold; thưởng là hộp quà ở level trong `boxes` (hộp thứ i cho
## ROAD_TRIP_REWARDS[i]). Hết bước: xem quảng cáo +revive_moves, tối đa revive_max lần mỗi lượt chơi.
const _ROAD_TRIP := {
	"levels": 400,
	"boxes": [15, 35, 69, 89, 123, 143, 163, 197, 217, 251, 271, 291, 325, 345, 379, 400],
	"revive_moves": 5,
	"revive_max": 3,
}

## Thưởng 16 hộp Road Trip theo tb_roadtripreward_config (Hint = hint, Hammer = smash, StepCount = move).
## Tổng 12 hint, 10 smash, 8 move. Mảng dict nên Remote Config không ghi đè được.
const ROAD_TRIP_REWARDS := [
	{"hint": 1}, {"smash": 1}, {"move": 1}, {"hint": 1, "move": 1},
	{"hint": 1, "smash": 1}, {"smash": 1, "move": 1}, {"hint": 2}, {"hint": 1, "move": 1},
	{"hint": 1, "smash": 1}, {"smash": 1, "move": 1}, {"hint": 1, "smash": 1}, {"hint": 1, "move": 1},
	{"hint": 1, "smash": 1}, {"smash": 1, "move": 1}, {"hint": 1, "smash": 1}, {"hint": 1, "smash": 1, "move": 1},
]

const _CONTENT := {
	"demo_max_level": 20,
	"release_pregen_level": 500,
	"loop_start_level": 51,
	# Spare MOVES on top of the solver's min taps (Solver.slack_for): levels up to slack_easy_until get slack_easy,
	# up to slack_early_until slack_early, after that slack_normal; HARD levels (VeryHard too) get slack_hard.
	"slack_easy": 5,
	"slack_easy_until": 3,
	"slack_early": 3,
	"slack_early_until": 13,
	"slack_normal": 4,
	"slack_hard": 3,
	# From this displayed level (the content loop after L500) every HARD level shows as VeryHard.
	"very_hard_from_level": 501,
	"hard_banner_sec": 1.2,
	"think_clap_sec": 8,
	# Nhắc Gợi ý (level.gd): đang chơi mà không chạm màn hình idle_hint_sec giây thì nút Gợi ý lắc, bóng đèn sáng
	# vàng và bong bóng "Available Block : N" hiện idle_hint_show_sec giây (chạm là tắt).
	"idle_hint_sec": 15,
	"idle_hint_show_sec": 2.0,
	# Màn loading khi mở game: thanh chạy tới splash_hold trong ít nhất splash_min_sec giây (đứng đó nếu boot chưa
	# xong), rồi đầy trong splash_fill_sec giây và vào Home.
	"splash_min_sec": 1.5,
	"splash_hold": 0.9,
	"splash_fill_sec": 0.3,
	# Màn chuyển cảnh khi vào level (level_curtain.gd): mỗi cánh trượt vào curtain_slide_sec (giảm tốc dần khi tới
	# giữa), cánh hồng xuất phát
	# khi cánh tím đã chạy curtain_pink_at thời gian của nó; logo bật từ mờ tới rõ trong curtain_logo_sec, giữ thêm
	# curtain_hold_sec, rồi hai cánh trượt ra trong curtain_open_sec.
	"curtain_slide_sec": 0.45,
	"curtain_pink_at": 0.6,
	"curtain_logo_sec": 0.4,
	"curtain_hold_sec": 0.35,
	"curtain_open_sec": 0.3,
	# Màn chuyển cảnh nắp hộp quà của Road Trip (gift_curtain.gd): thân hộp trượt lên trong gift_slide_sec (giảm tốc
	# dần), nắp rơi xuống (nhanh dần) trong gift_lid_sec, xuất phát khi thân đã đi được gift_lid_at quãng đường của nó;
	# chạm thân thì nắp nhún và nơ bẹp rồi nảy lại trong gift_bump_sec. Logo nằm trên nắp, rơi theo nắp, bật từ mờ tới
	# rõ trong curtain_logo_sec khi nắp đã rơi được gift_logo_at quãng đường, rõ hẳn thì giữ curtain_hold_sec, rồi nắp
	# nhấc lên, thân rơi xuống trong gift_open_sec.
	"gift_slide_sec": 0.45,
	"gift_lid_at": 0.3,
	"gift_logo_at": 0.5,
	"gift_lid_sec": 0.32,
	"gift_bump_sec": 0.18,
	"gift_open_sec": 0.3,
	# Màn chuyển cảnh kẹo rơi (candy_curtain.gd) khi Home bấm Chơi và nạp mạng xong, mỗi lần một loại kẹo ngẫu
	# nhiên: mỗi hàng candy_curtain_cols viên, viên to candy_curtain_size lần khoảng cột, hàng cách nhau
	# candy_curtain_row_gap lần khoảng cột. Từng viên rơi từ trên màn như trọng lực (rơi hết chiều cao màn trong
	# candy_curtain_fall_sec) xuống chỗ của nó, hàng đáy trước nên đống kẹo đầy dần từ dưới lên; cứ
	# candy_curtain_drop_sec có một viên chạm chỗ, mỗi viên lệch thêm tới candy_curtain_jitter_sec. Phủ kín thì giữ
	# candy_curtain_hold_sec, rồi cả đống rơi qua đáy màn (hàng trên trễ candy_curtain_out_row_sec so với hàng dưới,
	# rơi hết màn trong candy_curtain_out_fall_sec).
	"candy_curtain_cols": 4,
	"candy_curtain_size": 1.6,
	"candy_curtain_row_gap": 0.82,
	"candy_curtain_fall_sec": 0.45,
	"candy_curtain_drop_sec": 0.025,
	"candy_curtain_jitter_sec": 0.03,
	"candy_curtain_hold_sec": 0.05,
	"candy_curtain_out_row_sec": 0.01,
	"candy_curtain_out_fall_sec": 0.65,
	# Chạm màn hình (tap_fx.gd): ở điểm chạm một vòng tròn nở tới bán kính tap_fx_ring_px và tap_fx_stars sao nhỏ
	# toả ra chừng tap_fx_star_px, mờ dần trong tap_fx_sec giây. Số px tính ở màn chuẩn 886×1920.
	"tap_fx_sec": 0.4,
	"tap_fx_ring_px": 25,
	"tap_fx_star_px": 40,
	"tap_fx_stars": 5,
	# Background music (sfx.gd): a track fades in over music_fade_in_sec; on a track change the old one first fades out
	# over music_fade_out_sec.
	"music_fade_in_sec": 1.0,
	"music_fade_out_sec": 0.5,
	"build": "v1",
	"support_email": "support@horusvn.com",
	"ftue_steps": ["open", "first_tap", "first_win", "first_x2", "first_booster", "run_2", "run_5", "level_10"],
}

## Bàn cờ (design.md mục 3): khung đứng yên và giữ tỉ lệ so với màn như ảnh ref `art/concepts/ref_board_scale.png`;
## số px tính ở màn chuẩn BOARD_SCREEN, màn khác thì nhân theo min(rộng, cao) so với màn chuẩn.
## BOARD_AREA: vùng khung bao quanh (mặt trong các thanh cách mép vùng này CandyFrame.gap), BOARD_FRAME_UNIT: đơn vị đo
## bề dày thanh, ống góc của khung (CandyFrame).
## Lưới level tối đa BOARD_W x BOARD_H ô. Cỡ ô đổi theo level: hình (khối và thùng sắt) cộng một ô lề mỗi phía nằm vừa
## BOARD_AREA, to nhất BOARD_CELL_MAX (cỡ khối trong ảnh ref).
const BOARD_SCREEN := Vector2(886, 1920)
const BOARD_AREA := Vector2(724, 982)
const BOARD_FRAME_UNIT := 51.7
const BOARD_W := 14
const BOARD_H := 18
const BOARD_CELL_MAX := 80
## Dòng chú thích trên bàn (hướng dẫn cơ chế, chọn khối để đập): đáy cách mép trên khung chừng này px ở màn chuẩn, chữ
## xuống dòng thì mọc lên trên, không đè thanh khung.
const BOARD_CAPTION_GAP := 12
## Hình dạng level: dưới SHAPE_MIN_BLOCKS khối thì xếp hình chữ nhật vì quá ít ô để nhận ra dạng; cao tối đa SHAPE_MAX_ASPECT
## lần rộng; khoét SHAPE_ROUGHEN số ô rìa để hình không quá đều, như ảnh ref.
const SHAPE_MIN_BLOCKS := 6
const SHAPE_MAX_ASPECT := 1.9
const SHAPE_ROUGHEN := 0.06
## Từ DifficultyCurve.MOTIF_FROM khối xếp theo hình vẽ tay trong `src/core/motifs.gd`: chọn cỡ hình có số ô (trừ đá) chia
## số khối trong khoảng MOTIF_FILL_MIN..MOTIF_FILL_MAX (khoảng 3 ô mỗi khối như Road Trip, 2026-11-08); khối cắt đối xứng
## theo trục của hình, không khoét rìa.
const MOTIF_FILL_MIN := 2.5
const MOTIF_FILL_MAX := 3.4
## Cắt khối: mỗi cách gộp có trọng số TILE_SINGLE_BIAS ^ (số khối 1 ô được gộp) / cỡ khối sau gộp, nên khối 1 ô được
## gộp trước và còn ít khối 1 ô (1.0 là trọng số 1/cỡ của bản trước). Mỗi khối tối đa BLOCK_MAX_CELLS ô.
const TILE_SINGLE_BIAS := 1.5
const BLOCK_MAX_CELLS := 7
## Level mechanics (design.md section 4, "Cơ chế sau bản demo"): at most LEVEL_MECH_MAX kinds per level. From the
## first unlock, a level with id % LEVEL_REST_EVERY == LEVEL_REST_AT is a rest level with none (teaching levels keep
## theirs); other levels draw 1, 2 or 3 kinds with weights LEVEL_MECH_WEIGHTS, always including a kind unlocked within
## the last LEVEL_MECH_FRESH levels.
const LEVEL_MECH_MAX := 3
const LEVEL_MECH_WEIGHTS := [0.35, 0.4, 0.25]
const LEVEL_REST_EVERY := 4
const LEVEL_REST_AT := 3
const LEVEL_MECH_FRESH := 10
## Clear rounds (Solver.clear_rounds) of a generated level stay within max(LEVEL_ROUNDS_TOL_MIN,
## LEVEL_ROUNDS_TOL * target) of DifficultyCurve.wave_count.
const LEVEL_ROUNDS_TOL := 0.1
const LEVEL_ROUNDS_TOL_MIN := 1
## Level screen HUD (restart, settings, 3 boosters, MOVES frame, piece chip frame, HARD pill): the candy-purple sprites
## are toned down by src/ui/hud_tone.gdshader (design.md "HUD level"). HUD_TONE_GLOSS pulls the pale gloss sheen toward
## the body color (0 keeps it, 1 removes it); then HSV saturation and value are multiplied by HUD_TONE_SAT, HUD_TONE_VAL.
## Child nodes (labels, count badge, lock, hint bulb) keep their colors; the HARD pill draws its own text, which is toned.
const HUD_TONE_SAT := 0.8
const HUD_TONE_VAL := 0.97
const HUD_TONE_GLOSS := 0.5

## Close X of every Unity popup (btnTurnOff, ExitButton, ...; UnityUI.CLOSE_NAMES), 2026-11-08: the art is drawn
## CLOSE_ART_SCALE times its prefab size around its own center, and the touch target is CLOSE_HIT_SCALE times the
## prefab one (art grown to UButton.MIN_HIT). Both are side lengths: a 64 px X draws at 128 px, its 96 px target is 211 px.
## A grown X that would leave the screen moves in to stay CLOSE_EDGE_GAP canvas units from the edge.
const CLOSE_ART_SCALE := 2.0
const CLOSE_HIT_SCALE := 2.2
const CLOSE_EDGE_GAP := 8.0

## Player nickname length (design.md mục 5 "Biệt danh"), counted after trimming spaces at both ends. NAME_MAX matches the
## characterLimit of the input field in PopupEditNameLayer.
const NAME_MIN := 3
const NAME_MAX := 14

## Ngày sale theo Time.get_datetime_dict_from_unix_time().weekday (0 = Chủ nhật, 6 = thứ Bảy).
const _SALE_WEEKDAYS := [5, 6, 0]
## Weekend sale cho ai: 1 = mọi người chơi, 2 = chỉ người chưa mua gói nào, 3 = tắt.
## Remote Config: `weekend_sale_mode`.
const _SALE_MODE := 1
## Số % ghi trên nhãn sale (chỉ để hiển thị; giá thật do SKU `_sale` quyết định).
const _SALE_PERCENT := 50

static var ECON: Dictionary = _ECON.duplicate(true)
static var LIVES: Dictionary = _LIVES.duplicate(true)
static var ADS: Dictionary = _ADS.duplicate(true)
static var UNLOCK: Dictionary = _UNLOCK.duplicate(true)
static var FEATURES: Dictionary = _FEATURES.duplicate(true)
static var DAILY: Array = _DAILY.duplicate(true)
static var COSMETICS: Dictionary = _COSMETICS.duplicate(true)
static var SKUS: Dictionary = _SKUS.duplicate(true)
static var OFFERS: Dictionary = _OFFERS.duplicate(true)
static var NOTIF: Dictionary = _NOTIF.duplicate(true)
static var PACKS: Dictionary = _PACKS.duplicate(true)
static var WEEKLY: Dictionary = _WEEKLY.duplicate(true)
static var CHAIN: Dictionary = _CHAIN.duplicate(true)
static var LEADERBOARD: Dictionary = _LEADERBOARD.duplicate(true)
static var ROAD_TRIP: Dictionary = _ROAD_TRIP.duplicate(true)
static var CONTENT: Dictionary = _CONTENT.duplicate(true)
static var SALE_WEEKDAYS: Array = _SALE_WEEKDAYS.duplicate(true)
static var SALE_MODE: int = _SALE_MODE
static var SALE_PERCENT: int = _SALE_PERCENT


## Công tắc cho test: -1 theo OS.has_feature("demo"), 0 ép bản phát hành, 1 ép bản demo.
## reset() trả về -1.
static var demo_override: int = -1


static func is_demo() -> bool:
	if demo_override >= 0:
		return demo_override > 0
	return OS.has_feature("demo")


## Màn đã dựng UI nhưng chưa nối logic chỉ mở ở bản debug. Bản phát hành ẩn hết.
## Test ép bằng ui_preview_override: -1 theo bản build, 0 tắt, 1 bật. reset() trả về -1.
static var ui_preview_override: int = -1


static func ui_preview() -> bool:
	if ui_preview_override >= 0:
		return ui_preview_override > 0
	return OS.is_debug_build()


## Account editing in the tester menu (gold, level, boosters, delete account): debug builds only, like ui_preview.
## Tests force it with account_tool_override: -1 follows the build, 0 off, 1 on. reset() sets -1.
static var account_tool_override: int = -1


static func account_tool() -> bool:
	if account_tool_override >= 0:
		return account_tool_override > 0
	return OS.is_debug_build()


## Trả mọi nhóm về mặc định (test dùng sau khi apply_remote).
static func reset() -> void:
	demo_override = -1
	ui_preview_override = -1
	account_tool_override = -1
	ECON = _ECON.duplicate(true)
	LIVES = _LIVES.duplicate(true)
	ADS = _ADS.duplicate(true)
	UNLOCK = _UNLOCK.duplicate(true)
	FEATURES = _FEATURES.duplicate(true)
	DAILY = _DAILY.duplicate(true)
	COSMETICS = _COSMETICS.duplicate(true)
	SKUS = _SKUS.duplicate(true)
	OFFERS = _OFFERS.duplicate(true)
	NOTIF = _NOTIF.duplicate(true)
	PACKS = _PACKS.duplicate(true)
	WEEKLY = _WEEKLY.duplicate(true)
	CHAIN = _CHAIN.duplicate(true)
	LEADERBOARD = _LEADERBOARD.duplicate(true)
	ROAD_TRIP = _ROAD_TRIP.duplicate(true)
	CONTENT = _CONTENT.duplicate(true)
	SALE_WEEKDAYS = _SALE_WEEKDAYS.duplicate(true)
	SALE_MODE = _SALE_MODE
	SALE_PERCENT = _SALE_PERCENT


## Mọi id avatar hoặc frame (kind: "avatar" | "frame"), gồm cả *_00 mặc định ở đầu.
static func cosmetic_ids(kind: String) -> Array:
	var ids: Array = []
	var n: int = int(COSMETICS.get(kind + "_count", 0))
	for i in range(0, n + 1):
		ids.append("%s_%02d" % [kind, i])
	return ids


## Giá gold của một món; *_00 hoặc id lạ trả 0.
static func cosmetic_price(id: String) -> int:
	var parts := id.rsplit("_", true, 1)
	if parts.size() != 2 or not parts[1].is_valid_int():
		return 0
	var n: int = int(parts[1])
	var prices: Array = COSMETICS.get("prices", [])
	if n < 1 or prices.is_empty():
		return 0
	return int(prices[(n - 1) % prices.size()])


## Ghi đè từ Remote Config. Khoá `<nhóm>_<khoá>` (chữ thường, ví dụ `econ_win_coins`,
## `econ_booster_price_hint`, `skus_starter_pack_usd`, `content_ftue_steps`); giá trị là chuỗi
## được ép về đúng kiểu cũ (mảng: các phần tử cách nhau bằng dấu phẩy). Khoá lạ, giá trị hỏng,
## số âm và chuỗi rỗng bị bỏ qua. `DAILY` (mảng ô) không ghi đè được.
static func apply_remote(values: Dictionary) -> void:
	var groups := {
		"econ": ECON, "lives": LIVES, "ads": ADS, "unlock": UNLOCK, "features": FEATURES,
		"cosmetics": COSMETICS, "skus": SKUS, "offers": OFFERS,
		"notif": NOTIF, "content": CONTENT, "weekly": WEEKLY, "chain": CHAIN,
		"leaderboard": LEADERBOARD, "road_trip": ROAD_TRIP,
	}
	for raw_key in values:
		var key := str(raw_key).to_lower()
		var raw: Variant = values[raw_key]
		if not (raw is String):
			continue
		if key == "sale_weekdays":
			var arr: Variant = _coerce(SALE_WEEKDAYS, raw)
			if arr != null:
				SALE_WEEKDAYS = arr
			continue
		if key == "weekend_sale_mode":
			var mode: Variant = _coerce(SALE_MODE, raw)
			if mode != null and int(mode) >= 1 and int(mode) <= 3:
				SALE_MODE = int(mode)
			continue
		if key == "sale_percent":
			var pct: Variant = _coerce(SALE_PERCENT, raw)
			if pct != null and int(pct) <= 99:
				SALE_PERCENT = int(pct)
			continue
		for g in groups:
			if key.begins_with(g + "_"):
				_set_path(groups[g], key.substr(g.length() + 1), raw)
				break


static func _set_path(d: Dictionary, path: String, raw: String) -> bool:
	if d.has(path):
		if d[path] is Dictionary:
			return false
		var v: Variant = _coerce(d[path], raw)
		if v == null:
			return false
		d[path] = v
		return true
	for k in d:
		if d[k] is Dictionary and path.begins_with(str(k) + "_"):
			if _set_path(d[k], path.substr(str(k).length() + 1), raw):
				return true
	return false


## Ép chuỗi `raw` về kiểu của `old`. Trả null nếu hỏng.
static func _coerce(old: Variant, raw: String) -> Variant:
	var s := raw.strip_edges()
	if s.is_empty():
		return null
	match typeof(old):
		TYPE_INT:
			if not s.is_valid_int() or int(s) < 0:
				return null
			return int(s)
		TYPE_FLOAT:
			if not s.is_valid_float() or float(s) < 0.0:
				return null
			return float(s)
		TYPE_BOOL:
			var low := s.to_lower()
			if low == "1" or low == "true":
				return true
			if low == "0" or low == "false":
				return false
			return null
		TYPE_STRING:
			return s
		TYPE_ARRAY:
			var arr: Array = old
			if arr.is_empty() or typeof(arr[0]) == TYPE_DICTIONARY or typeof(arr[0]) == TYPE_ARRAY:
				return null
			var out: Array = []
			for part in s.split(",", false):
				var e: Variant = _coerce(arr[0], part)
				if e == null:
					return null
				out.append(e)
			if out.is_empty():
				return null
			return out
	return null


## UI: how many recently opened scenes (screens, popups, Unity layers) src/ui/scene_cache.gd keeps loaded, so opening
## one again skips parsing it and decoding its textures. Each held scene keeps its textures in memory
## (docs/UI_NODES.md, "Cache scene"); 0 turns the cache off.
const SCENE_CACHE := 8
