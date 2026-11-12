extends RefCounted
## Mọi con số kinh tế, quảng cáo, mở khoá, offer. Số theo design.md mục 3-7.
## Remote Config ghi đè bằng apply_remote(); reset() trả về mặc định (dùng trong test).
## Gold trong code tên `coins`.

const _ECON := {
	"start_coins": 1000,
	"win_coins": 40,
	## Gold per MOVES left on the board at a win, added to the win reward (x2 doubles it too).
	"win_move_coins": 10,
	## Main levels below this one skip the win card (design.md mục 4 "Thẻ thắng và thẻ thua"): the gold still goes to
	## the wallet, there is no x2, no rate prompt and no trip Home; the level screen goes straight to the next level.
	## The first card (this level) has the free x2.
	"win_card_from_level": 11,
	"booster_price": {"hint": 900, "move": 1900, "smash": 2900},
	"refill_coins": 900,
	"refill_lives": 5,
	"shop_video_coins": 200,
	"shop_video_max": 5,
	"rescue_prices": [1900, 2200, 2500, 2800],
	"rescue_moves": 3,
	"rescue_video_max": 4,
	## Popup cứu lượt kèm Helper Pack (wireframe 4.7): lần cứu đầu của ván khi đây là lần hết MOVES thứ
	## helper_pack_fail liên tiếp ở level đó và kho hết +3 Move; gói bán là SKU helper_pack_sku.
	"helper_pack_fail": 3,
	"helper_pack_sku": "helper_great",
	"challenge_coins": 100,
}

const _LIVES := {
	"max": 10,
	"regen_sec": 300,
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

## Level the feature opens at (design.md mục 4 "Mở khoá theo level"). 2026-11-10 (user): shop 5 -> 11, leaderboard
## 8 -> 70, road_trip 70 -> 95, win_streak 40 -> 45, chain 40 -> 45, layer 55 -> 65, fog 70 -> 85, pulse 90 -> 115,
## frost 110 -> 165, ribbon 130 -> 350, choco 150 -> 300.
const _UNLOCK := {
	"daily_gift": 14, "hint": 5, "shop": 11, "move": 12, "smash": 17,
	"lives": 10, "starter": 10, "review": 10, "challenge": 50, "leaderboard": 70, "road_trip": 95, "win_streak": 45,
	"special_bomb": 50,
	"stone": 14, "ice": 30, "chain": 45, "layer": 65, "fog": 85, "pulse": 115, "frost": 165, "ribbon": 350,
	"choco": 300, "pop": 220,
}

## On/off switch per Config.UNLOCK feature (missing key = on). Off: Unlocks.is_open is false at every level, the win
## card neither announces nor counts it, and Home hides its icon. Remote Config: `features_<name>` ("1" / "0").
## Daily Challenge is off since 2026-11-08 (design.md mục 4 "Phạm vi"), Win Streak since 2026-11-11 (design.md mục 7
## "Win Streak"; an event started before the switch stops counting too, WinStreak.is_running).
const _FEATURES := {
	"challenge": false,
	"win_streak": false,
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

## avatar_01..N và frame_01..N. *_00 miễn phí và luôn có; món còn lại không bán gold, chỉ mở bằng video, Road Trip hay thưởng league.
const _COSMETICS := {
	"avatar_count": 12,
	"frame_count": 12,
	"default_avatar": "avatar_00",
	"default_frame": "frame_00",
}

## usd, consumable, gold, inv (booster), inf_min (phút mạng vô hạn), inf_forever (mạng vô hạn vĩnh viễn), no_ads. Gói sale là SKU riêng đuôi `_sale`.
const _SKUS := {
	"gold_pack_1": {"usd": 1.99, "consumable": true, "gold": 1000},
	"gold_pack_2": {"usd": 7.99, "consumable": true, "gold": 5000},
	"gold_pack_3": {"usd": 14.99, "consumable": true, "gold": 11000},
	"gold_pack_4": {"usd": 29.99, "consumable": true, "gold": 25000},
	"gold_pack_5": {"usd": 49.99, "consumable": true, "gold": 50000},
	"gold_pack_6": {"usd": 99.99, "consumable": true, "gold": 120000},
	# Pack 1 keeps its price on sale and doubles the gold (badge "x2"); the others halve the price (badge "-50%").
	"gold_pack_1_sale": {"usd": 1.99, "consumable": true, "gold": 2000},
	"gold_pack_2_sale": {"usd": 3.99, "consumable": true, "gold": 5000},
	"gold_pack_3_sale": {"usd": 7.49, "consumable": true, "gold": 11000},
	"gold_pack_4_sale": {"usd": 14.99, "consumable": true, "gold": 25000},
	"gold_pack_5_sale": {"usd": 24.99, "consumable": true, "gold": 50000},
	"gold_pack_6_sale": {"usd": 49.99, "consumable": true, "gold": 120000},
	# Like the reference game's No Ads (cube.sort.color.ads.1): no ads only.
	"remove_ads": {"usd": 5.99, "consumable": false, "no_ads": true},
	# inf_forever: infinite lives for good (user request 2026-11-10).
	"starter_pack": {"usd": 6.99, "consumable": false, "gold": 6000,
		"inv": {"hint": 1, "move": 1, "smash": 1}, "inf_forever": true},
	# One-time packs (consumable false, user request 2026-11-10): Google Play sells them once and Restore gives them
	# back; the Shop hides a bought card. level_pack, gold, weekly_pass, chain_pack_* and helper_great stay repeatable.
	"rescue_pack": {"usd": 0.99, "consumable": false, "inv": {"move": 1}},
	"level_pack": {"usd": 4.99, "consumable": true, "gold": 3000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	# Mua lại được mỗi tuần nên consumable; trạng thái VIP nằm ở s.weekly.vip.
	"weekly_pass": {"usd": 4.99, "consumable": true, "weekly_vip": true},
	# special_pack and its _sale count as one purchase (Config.PACKS purchase_limit 1, PackConditions.purchases).
	"special_pack": {"usd": 10.99, "consumable": false, "gold": 12000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	"special_pack_sale": {"usd": 5.49, "consumable": false, "gold": 12000,
		"inv": {"hint": 2, "move": 2, "smash": 2}},
	# Bước Pay của Chain Offer: thưởng lấy từ chính gói.
	"chain_pack_1": {"usd": 0.99, "consumable": true, "gold": 1500},
	"chain_pack_2": {"usd": 2.99, "consumable": true, "gold": 3000,
		"inv": {"hint": 1, "move": 1}},
	# No Ads Bundle (popup 2.4 and the Shop), like the reference game's cube.sort.color.ads.3: no ads plus gold and
	# 3 of each booster. Owning either no_ads SKU hides both (Shop section, Home icon, popup).
	"remove_ads_bundle": {"usd": 9.99, "consumable": false, "gold": 3000, "no_ads": true,
		"inv": {"hint": 3, "move": 3, "smash": 3}},
	# helper_great is the Helper Pack of the out-of-moves popup 4.7 only (not sold in the Shop), bought any number of
	# times; it also gives infinite lives for good (user requests 2026-11-10). helper_epic: one-time, hidden.
	"helper_great": {"usd": 3.99, "consumable": true, "inv": {"hint": 2, "move": 2, "smash": 1}, "inf_forever": true},
	"helper_epic": {"usd": 4.99, "consumable": false, "inv": {"hint": 3, "move": 2, "smash": 1}},
	# Shop Bundles (one-time, hidden from the Shop): gold, boosters and minutes of infinite lives (inf_min).
	"bundle_sweet": {"usd": 4.99, "consumable": false, "gold": 3000,
		"inv": {"hint": 1, "move": 1, "smash": 1}, "inf_min": 60},
	"bundle_tasty": {"usd": 9.99, "consumable": false, "gold": 7000,
		"inv": {"hint": 2, "move": 2, "smash": 2}, "inf_min": 180},
	"bundle_yummy": {"usd": 14.99, "consumable": false, "gold": 12000,
		"inv": {"hint": 3, "move": 3, "smash": 3}, "inf_min": 360},
}

## Điều kiện hiện gói (PackConditionSO). level_appear: từ level này; purchase_limit: 0 = không giới hạn;
## required: phải đã mua đủ các gói này; exclude: đã sở hữu gói nào trong đây thì ẩn.
const _PACKS := {
	"special_pack": {"sku": "special_pack", "level_appear": 16, "purchase_limit": 1,
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
	"level_unlock": 130,
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
## (theo độ khó); phá một khối được 1 mảnh = 1 điểm, cộng khi thắng. League theo điểm của tuần, chỉ lên trong tuần.
## Tuần dài `week_days` ngày, tính từ lúc mở khoá; hết tuần thì điểm về 0, về league đầu, thưởng league nhận lại được.
## leagues: {id, min, reward {coins, items, inf_min}, bot_base, players}. League đầu có min 0 và không có thưởng;
## reward nhận khi vào league. min là đề xuất, đặt khi trung bình 2,3 mảnh/level; từ 2026-11-10 còn 1,3 mảnh/level
## nên cần khoảng 33 level/ngày tới Platinum, 104 level/ngày tới One Above All.
## bot_base: điểm tăng cơ bản mỗi ngày của bot; players: số người chơi mô phỏng của league, dùng cho Top %.
## Bot tăng điểm mỗi ngày lúc `grow_hour` giờ ở múi GMT+`grow_tz_hours`:
## tăng = bot_base + round(randi_range(bot_rand) * randf_range(bot_var)). Vắng lâu thì chỉ bù tối đa `grow_max_days` ngày.
## BXH `board_size` người (người chơi + bot), UI hiện `view_size` người quanh người chơi. League cuối không có trần:
## bot rải trong [min, min + top_span]. Avatar, frame của bot: `*_default_pct`% dùng mặc định, còn lại random đều.
## `cosmetics`: avatar, frame chỉ có từ thưởng league (không bán, không mở bằng video). reward.cos_random: số món
## random trong `cosmetics` (món chưa có, chưa nằm trong thưởng chờ), chọn lúc vào league; hết món thì không có gì
## thay. Bot ở league dưới league đầu tiên có cos_random không đeo các món này.
const _LEADERBOARD := {
	"enabled": true,
	"board_size": 100,
	"view_size": 50,
	"pieces_normal": 1,
	"pieces_hard": 2,
	"pieces_very_hard": 3,
	"grow_tz_hours": 7,
	"grow_hour": 7,
	"grow_max_days": 14,
	"bot_rand": [0, 4],
	"bot_var": [0.5, 1.5],
	"bot_avatar_default_pct": 80,
	"bot_frame_default_pct": 85,
	"carry_max": 10,
	"top_span": 950,
	"world_size": 50,
	"week_days": 7,
	"cosmetics": ["avatar_08", "avatar_09", "avatar_10", "avatar_11", "avatar_12",
		"frame_08", "frame_09", "frame_10", "frame_11", "frame_12"],
	"leagues": [
		{"id": "silver", "min": 0, "reward": {"coins": 0, "items": {}}, "bot_base": 6, "players": 48000},
		{"id": "gold", "min": 150, "reward": {"coins": 300, "items": {"hint": 1}}, "bot_base": 7, "players": 24000},
		{"id": "platinum", "min": 300, "reward": {"coins": 500, "items": {"move": 1}, "cos_random": 1}, "bot_base": 8, "players": 14000},
		{"id": "emerald", "min": 450, "reward": {"coins": 800, "items": {"smash": 1}, "cos_random": 1}, "bot_base": 9, "players": 8000},
		{"id": "diamond", "min": 600, "reward": {"coins": 1200, "items": {"hint": 1, "move": 1}, "cos_random": 1}, "bot_base": 10, "players": 4000},
		{"id": "immortal", "min": 770, "reward": {"coins": 2000, "items": {"hint": 1, "move": 1, "smash": 1}, "cos_random": 1}, "bot_base": 11, "players": 1600},
		{"id": "one_above_all", "min": 950, "reward": {"coins": 5000, "items": {"hint": 2, "move": 2, "smash": 2}, "inf_min": 60, "cos_random": 1}, "bot_base": 12, "players": 400},
	],
}

## Win Streak (design.md mục 7 "Win Streak", ME_WinStreakConfig của color-cube-match-puzzle). active_days: thứ theo
## quy ước Godot (0 = Chủ nhật), các ngày khác chỉ nhận quà. Mốc là chuỗi thực (tổng Gap của Unity); thưởng {coins,
## items, inf_min}. Gold Unity nhân 6 theo giá refill (150 -> 900); AutoFill, Storage, Capacity -> Gợi ý, +3 Move,
## Phá khối; InfiniteHeart theo phút của HeartConfigSO. Mở từ Config.UNLOCK.win_streak (45; LevelAppear của Unity là 40).
const _WIN_STREAK := {
	"active_days": [5, 6, 0],
	"milestones": [
		{"streak": 2, "reward": {"inf_min": 15}},
		{"streak": 4, "reward": {"items": {"hint": 1}}},
		{"streak": 7, "reward": {"inf_min": 20}},
		{"streak": 10, "reward": {"items": {"move": 1}}},
		{"streak": 14, "reward": {"inf_min": 20, "items": {"hint": 1}}},
		{"streak": 18, "reward": {"coins": 300, "items": {"move": 1}}},
		{"streak": 23, "reward": {"inf_min": 20, "items": {"smash": 1}}},
		{"streak": 28, "reward": {"coins": 300, "inf_min": 45, "items": {"move": 1}}},
		{"streak": 34, "reward": {"coins": 600, "inf_min": 20, "items": {"hint": 1}}},
		{"streak": 40, "reward": {"coins": 1500, "inf_min": 60, "items": {"smash": 2}}},
	],
}

## Offer. min_secs: không popup trong N giây đầu phiên đầu; gap_runs: cách nhau ít nhất N lượt.
## starter_pack: mở khi level > after_level hoặc runs >= at_run.
## level_pack: mốc đầu ở level first_level (level sắp chơi), rồi cứ every_levels level một mốc (60, 110, 160, …).
## enabled (tuỳ chọn, thiếu là bật): false thì offer không hiện và Shop ẩn thẻ của nó; Remote Config
## `offers_<id>_enabled` bật lại được. rescue_pack tắt theo yêu cầu người dùng (2026-11-10); SKU vẫn giữ trong SKUS.
const _OFFERS := {
	"min_secs": 300,
	"gap_runs": 3,
	"starter_pack": {"sku": "starter_pack", "after_level": 10, "at_run": 12, "hours": 48},
	"remove_ads": {"sku": "remove_ads", "after_inter_today": 3, "per_day": 1, "max_total": 3},
	"rescue_pack": {"sku": "rescue_pack", "enabled": false, "fail_streak": 3, "cooldown_hours": 24},
	"level_pack": {"sku": "level_pack", "first_level": 60, "every_levels": 50, "hours": 72},
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

## Road Trip (design.md mục 7 "Road Trip"): đường 400 level riêng (data/road_trip), mở từ UNLOCK.road_trip.
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

## Avatar, frame tặng thêm ở hộp Road Trip: số thứ tự hộp (đếm từ 1) -> id. Các món này chỉ có từ Road Trip: Profile
## không bán, không mở bằng video. Đã có sẵn thì hộp chỉ trao booster. Dict nên Remote Config không ghi đè được.
const ROAD_TRIP_COSMETICS := {3: "avatar_05", 6: "avatar_06", 9: "avatar_07", 12: "frame_06", 16: "frame_07"}

## Màn đặc biệt (design.md mục 7 "Màn đặc biệt"; logic src/meta/special_bomb.gd, src/core/special_board.gd), mở từ
## UNLOCK.special_bomb. Vé: ngăn chờ giữ tối đa 1 vé, hồi sau timer_sec kể từ lúc dùng; ngăn thưởng +ticket_hard /
## +ticket_very_hard mỗi lần thắng level chính Hard / VeryHard, bonus_cap vé (0 = không giới hạn).
## Bàn: `boards` bàn sinh sẵn trong data/special (tools/gen_special.gd), hình chữ nhật rect_w_* x rect_h_* lát kín,
## cells_per_block_* ô mỗi khối, số lượt dọn bàn nhắm rounds_share x số khối, trọng số khối bị chặn mũ blocked_power;
## moves = số khối + slack (slack_plus1_share bàn +1, slack_plus2_share bàn +2).
## Bom: bombs_start + số trận thắng / bombs_every quả, tối đa bombs_max. Khối mang bom có số lần chạm để gỡ trong
## [max(bomb_min_taps, bomb_min_share x số khối), bomb_max_share x số khối] (2026-11-10: sàn 0,4 và trần 0,9 để bom nằm
## sâu hơn, trước là [4, 0,8 x số khối]); số giây = bomb_time_share x (bomb_base_sec + bomb_sec_per_tap x số khối
## phải chạm), làm tròn lên (cộng dồn theo thứ tự gỡ; 19 + số lần chạm là số đo của game tham khảo, bomb_time_share
## 0,8 làm bom khó hơn 20%, 2026-11-10). Còn warn_sec giây thì ngòi cháy và tích tắc; nổ xong boom_popup_sec giây thì
## hiện popup "Bùm!".
## Thắng: 1 booster rút đều trong mảng reward_kinds, lặp tên để đặt tỉ lệ (x2 bằng rewarded `special_x2`).
const _SPECIAL := {
	"boards": 100,
	"timer_sec": 7200,
	"ticket_hard": 1,
	"ticket_very_hard": 1,
	"bonus_cap": 0,
	"rect_w_min": 10,
	"rect_w_max": 12,
	"rect_h_min": 14,
	"rect_h_max": 16,
	"cells_per_block_min": 3.0,
	"cells_per_block_max": 3.4,
	"rounds_share": 0.45,
	"blocked_power": 2,
	"slack": 3,
	"slack_plus1_share": 0.1,
	"slack_plus2_share": 0.02,
	"bombs_start": 1,
	"bombs_every": 20,
	"bombs_max": 6,
	"bomb_min_taps": 4,
	"bomb_min_share": 0.4,
	"bomb_max_share": 0.9,
	"bomb_base_sec": 19,
	"bomb_sec_per_tap": 1.0,
	"bomb_time_share": 0.8,
	"bomb_scale": 1.3,
	"warn_sec": 3,
	"boom_popup_sec": 1.0,
	"boom_haptic_ms": 120,
	# Drawn uniformly from the array, so repeats set the odds: hint 60%, move 30%, smash 10%.
	"reward_kinds": ["hint", "hint", "hint", "hint", "hint", "hint", "move", "move", "move", "smash"],
}

const _CONTENT := {
	"demo_max_level": 20,
	"release_pregen_level": 500,
	"loop_start_level": 51,
	# Spare MOVES on top of the solver's min taps (Solver.slack_for, design.md section 3): levels up to slack_easy_until
	# get slack_easy, up to slack_intro_until slack_intro, up to slack_early_until slack_early. Then by tag: up to
	# slack_mid_until slack_normal_mid / slack_hard_mid / slack_very_hard_mid, after that slack_normal / slack_hard /
	# slack_very_hard (2026-11-12, user: closer to the reference game, which gives harder levels more spare moves; later
	# the same day, user: one less on L101-150 and two less from L151, so the mid tier runs to L150).
	"slack_easy": 7,
	"slack_easy_until": 3,
	"slack_intro": 5,
	"slack_intro_until": 10,
	"slack_early": 4,
	"slack_early_until": 13,
	"slack_mid_until": 150,
	"slack_normal_mid": 5,
	"slack_hard_mid": 4,
	"slack_very_hard_mid": 5,
	"slack_normal": 4,
	"slack_hard": 3,
	"slack_very_hard": 4,
	# From this displayed level (the content loop after L500) every HARD level shows as VeryHard.
	"very_hard_from_level": 501,
	"hard_banner_sec": 1.2,
	"think_clap_sec": 8,
	# Thắng: khối cuối nghiền xong qua thanh (và mảnh crystal đã tới chip) thì chờ chừng này giây rồi mới hiện thẻ
	# thắng (level.gd _settle), cho vụn của khối cuối kịp bắn ra.
	"win_card_delay_sec": 0.25,
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
	# Every phone vibration (Platform.haptic) lasts its ms (Sfx.HAPTIC_MS, Game.haptic callers) times this.
	"haptic_scale": 1.5,
	"build": "v1",
	"support_email": "support@horusvn.com",
	# Privacy Policy and Terms of Service rows in Settings (PrivacyPolicyControl of color-cube-match-puzzle: the same
	# hardcoded pages on every platform). Yes in the confirm popup opens them in the browser.
	"privacy_url": "https://horusent.com/privacy-policy/",
	"terms_url": "https://horusent.com/term-conditions/",
	# Popup cập nhật lúc mở game (popup_update.gd): phiên bản app (application/config/version) thấp hơn
	# latest_version thì mời cập nhật, có Để sau; thấp hơn min_version thì bắt buộc, không có Để sau. Trống là tắt.
	# Remote Config `content_latest_version`, `content_min_version`. Nút Cập nhật mở store_url.
	"latest_version": "",
	"min_version": "",
	"store_url": "https://play.google.com/store/apps/details?id=com.tungcv2.tapblockout",
	# Kiểm có mạng (net_check.gd) trước khi mua hàng hoặc xem video: GET net_check_url, chờ tối đa net_check_sec.
	"net_check_url": "https://www.google.com/generate_204",
	"net_check_sec": 3.0,
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
## Level shapes by chapter (design.md section 4 "Hình dạng level", user request 2026-11-11): from CHAPTER_FROM levels
## come in chapters of CHAPTER_LEN levels (the first one ends at CHAPTER_FIRST_TO); each chapter draws its shapes from
## one theme of Motifs.THEMES, in turn.
const CHAPTER_FROM := 14
const CHAPTER_FIRST_TO := 20
const CHAPTER_LEN := 10
## Cắt khối: mỗi cách gộp có trọng số TILE_SINGLE_BIAS ^ (số khối 1 ô được gộp) x hệ số hình / cỡ khối sau gộp ^
## TILE_SIZE_POW, nên khối 1 ô được gộp trước và còn ít khối 1 ô. Mỗi khối tối đa BLOCK_MAX_CELLS ô.
## Hệ số hình (2026-11-10, người dùng: nhiều khối L, ít khối thẳng, khoảng 30% mỗi loại; design.md mục 4 "Hình dạng
## level") theo khối sau gộp: chữ L (một hàng và một cột ở mép khung bao, kể cả L 3 ô) TILE_L_WEIGHT khi cắt đối xứng
## (level thường, gộp nhiều cặp mỗi lần quét nên cần hệ số lớn) và TILE_L_WEIGHT_FREE khi cắt tự do (Màn đặc biệt, Road
## Trip), khối thẳng (một hàng hoặc một cột, kể cả khối 2 ô) TILE_STRAIGHT_WEIGHT, hình khác 1. Trước đó không có hệ số
## hình, TILE_SINGLE_BIAS 1.5 và TILE_SIZE_POW 2.
const TILE_SINGLE_BIAS := 4.0
const TILE_SIZE_POW := 3.5
const TILE_L_WEIGHT := 16.0
const TILE_L_WEIGHT_FREE := 4.0
const TILE_STRAIGHT_WEIGHT := 0.25
const BLOCK_MAX_CELLS := 7
## L5..EARLY_SHAPE_UNTIL (2026-11-10, người dùng: khối dồn vào giữa, khối to hơn; 10-11 khối theo
## DifficultyCurve.EARLY_SHAPE_BLOCKS): chỉ hình vẽ tay đặc, một trục đối xứng (không ô trống kín bên trong, số ô ít
## nhất EARLY_SOLID_MIN khung bao, tối đa EARLY_TIPS_MAX ô đầu nhọn), số ô chia số khối trong EARLY_FILL_MIN..
## EARLY_FILL_MAX thay cho MOTIF_FILL_*, cắt kiểu đối xứng tự do, mũ cỡ khối EARLY_SIZE_POW thay cho TILE_SIZE_POW.
const EARLY_SHAPE_UNTIL := 10
const EARLY_FILL_MIN := 3.5
const EARLY_FILL_MAX := 4.5
const EARLY_SOLID_MIN := 0.7
const EARLY_TIPS_MAX := 2
const EARLY_SIZE_POW := 1.5
## Level mechanics (design.md section 4, "Cơ chế sau bản demo"): at most LEVEL_MECH_MAX kinds per level. From the
## first unlock, a level with id % LEVEL_REST_EVERY == LEVEL_REST_AT is a rest level with none (teaching levels keep
## theirs); other levels draw 1, 2 or 3 kinds with weights LEVEL_MECH_WEIGHTS, always including a kind unlocked within
## the last LEVEL_MECH_FRESH levels.
const LEVEL_MECH_MAX := 3
const LEVEL_MECH_WEIGHTS := [0.35, 0.4, 0.25]
const LEVEL_REST_EVERY := 4
const LEVEL_REST_AT := 3
const LEVEL_MECH_FRESH := 10
## At most this share of a level's blocks carry a mechanic (cover, fog, chain lock or key, paper box, ribbon, candy
## bomb; each block counted once), floor(blocks * share) (design.md section 4, user request 2026-11-11).
const LEVEL_MECH_BLOCK_SHARE := 0.5
## Blocks that can act on the first tap (exit or peel, as the hint's "Available Block" counts them). L1-10 exactly
## EXIT_EARLY_LEVELS (the reference game's first levels; L1-4 are hand-made to match); from EXIT_RANGE_FROM: (min, max)
## EXIT_RANGE_EARLY up to EXIT_RANGE_EARLY_UNTIL, then by tag (VeryHard, Hard, normal and rest levels). The generator
## widens the range by 1 on each side every EXIT_RELAX_EVERY failed attempts (design.md section 4; 2026-11-11 user
## request, before that 1-17, mean 6.5; 2026-11-12 user request: closer to the reference game, normal levels from L20
## +2-3 on average, Hard and VeryHard +4-5).
const EXIT_EARLY_LEVELS := [4, 2, 3, 3, 2, 3, 4, 4, 4, 5]
const EXIT_RANGE_FROM := 14
const EXIT_RANGE_EARLY_UNTIL := 19
const EXIT_RANGE_EARLY := Vector2i(2, 4)
const EXIT_RANGE_NORMAL := Vector2i(6, 8)
const EXIT_RANGE_HARD := Vector2i(7, 9)
const EXIT_RANGE_VERY_HARD := Vector2i(6, 8)
const EXIT_RELAX_EVERY := 10
## From EXIT_RANGE_FROM, when the generator gives blocks their colour (exit side), each neighbouring block that already
## took a colour multiplies that colour's weight by COLOR_MIX, so colours mix instead of whole areas of the shape
## leaving through the nearest side (design.md section 4 "Hình dạng level", user request 2026-11-11). On L14-500
## same-colour neighbours went from 49% to 33% of neighbouring pairs (reference game 31%); stronger mixing barely
## lowers it because many blocks have a single way out.
const COLOR_MIX := 0.01
## Cover mechanics, pudding (`ice`) and ice (`frost`), never both in one level (design.md section 4): a block's `ice`
## field is its layer count, 0..COVER_MAX_LAYERS; each neighbouring block that leaves the board strips one layer.
## Share of covered blocks: COVER_SHARE_LO -> COVER_SHARE_HI over COVER_SHARE_OVER levels from the kind's unlock. From
## COVER_DOUBLE_AFTER levels past the unlock, COVER_DOUBLE_LO -> COVER_DOUBLE_HI of the covered blocks (over
## COVER_DOUBLE_OVER levels) get 2 layers; a 2-layer block needs at least 2 neighbouring blocks.
const COVER_MAX_LAYERS := 2
const COVER_SHARE_LO := 0.10
const COVER_SHARE_HI := 0.28
const COVER_SHARE_OVER := 60
const COVER_DOUBLE_AFTER := 10
const COVER_DOUBLE_LO := 0.2
const COVER_DOUBLE_HI := 0.5
const COVER_DOUBLE_OVER := 60
## Ribbon (design.md section 4): a block wears 1..RIBBON_MAX_LAYERS ribbons over its candy (`ribbons`, outer first);
## each ribbon peels like the paper box shell. Max ribbons by block size: RIBBON_CELL_CAP[mini(cells, size - 1)] (1 cell
## none, 2 cells 2). Regular levels: up to mini(RIBBON_COUNT_MAX, 1 + (id - unlock) / RIBBON_COUNT_EVERY) ribbon blocks,
## each with 1..mini(RIBBON_MAX_LAYERS, RIBBON_LAYERS_START + (id - unlock) / RIBBON_LAYERS_EVERY) ribbons. Teaching
## level: RIBBON_TEACH_SMALL (min, max) blocks with 1..RIBBON_TEACH_SMALL_LAYERS ribbons, plus one block of 3+ cells
## with RIBBON_TEACH_BIG (min, max) ribbons, late in the solve order.
const RIBBON_MAX_LAYERS := 4
const RIBBON_CELL_CAP := [0, 0, 2, 4]
const RIBBON_COUNT_MAX := 5
const RIBBON_COUNT_EVERY := 15
const RIBBON_LAYERS_START := 2
const RIBBON_LAYERS_EVERY := 30
const RIBBON_TEACH_SMALL := Vector2i(3, 5)
const RIBBON_TEACH_SMALL_LAYERS := 2
const RIBBON_TEACH_BIG := Vector2i(3, 4)
## Chocolate (design.md section 4): melted chocolate covers one exit bar (`choco_sides`); the bar takes nothing until
## its layers are gone. Every piece that grinds through another bar (block exit, paper box shell, ribbon) or a Smash
## melts one layer. Regular levels draw CHOCO_LAYERS_MIN..mini(CHOCO_MAX_LAYERS, CHOCO_LAYERS_START + (id - unlock) /
## CHOCO_LAYERS_EVERY) layers (2 up to L319, 2-3 up to L339, 2-4 from L340). Teaching level: CHOCO_TEACH_LAYERS layers
## and at least CHOCO_TEACH_FREE blocks that exit at once through other bars.
const CHOCO_MAX_LAYERS := 4
const CHOCO_LAYERS_MIN := 2
const CHOCO_LAYERS_START := 2
const CHOCO_LAYERS_EVERY := 20
const CHOCO_TEACH_LAYERS := 2
const CHOCO_TEACH_FREE := 2
## Candy bomb (design.md section 4, `pop`): a block that, when it leaves the board (exit or Smash), strips every
## pudding/ice layer and clears the fog of each block with a cell within POP_RADIUS cells (Chebyshev) of one of its
## cells. Generator: only in levels that also have pudding, ice or fog (POP_PARTNERS); a plain block, not in the first
## clear round, with at least POP_MIN_TARGETS covered or hidden blocks in its zone when it leaves in solve order;
## POP_COUNT_ONE_UNTIL and below get 1 bomb, later levels 1..POP_COUNT_MAX. Teaching level: taught with POP_TEACH_WITH,
## the bomb exits at once and its zone holds at least POP_TEACH_TARGETS covered blocks, one of them with 2 layers.
const POP_RADIUS := 2
const POP_MIN_TARGETS := 3
const POP_COUNT_ONE_UNTIL := 249
const POP_COUNT_MAX := 2
const POP_PARTNERS := ["ice", "frost", "fog"]
const POP_TEACH_WITH := "ice"
const POP_TEACH_TARGETS := 4
## Candy bomb look (design.md section 4 and 8): the fuse sprite leans POP_FUSE_ANGLE degrees counter-clockwise, is
## POP_FUSE_SIZE cells tall after the turn, and its centre sits POP_FUSE_INSET cells inside the top-left corner of the
## block's top-left cell (leftmost cell of the top row); shadow offset POP_FUSE_SHADOW cells. Blast: blocks in the zone
## break from near to far, POP_STAGGER seconds per distance step; at most POP_SFX_MAX break sounds, POP_SFX_DB quieter.
const POP_FUSE_ANGLE := 35.0
const POP_FUSE_SIZE := 1.6
const POP_FUSE_INSET := 0.06
const POP_FUSE_SHADOW := Vector2(0.05, 0.06)
const POP_STAGGER := 0.06
const POP_SFX_MAX := 4
const POP_SFX_DB := -6.0
## Clear rounds (Solver.clear_rounds) of a generated level stay within max(LEVEL_ROUNDS_TOL_MIN,
## LEVEL_ROUNDS_TOL * target) of DifficultyCurve.wave_count. The generator widens that by 1 every few failed attempts,
## never past max(LEVEL_ROUNDS_TOL_MIN_CAP, ceil(LEVEL_ROUNDS_TOL_CAP * target)) (2026-11-11: with the cap on blocks that
## exit at once, shallow wide levels went 60% deeper than the curve; past the cap the exit range widens instead).
const LEVEL_ROUNDS_TOL := 0.1
const LEVEL_ROUNDS_TOL_MIN := 1
const LEVEL_ROUNDS_TOL_CAP := 0.25
const LEVEL_ROUNDS_TOL_MIN_CAP := 2
## Level screen HUD (restart, settings, 3 boosters, MOVES frame, piece chip frame, difficulty pill): the candy sprites
## (purple; the pill is red on Hard) are toned down by src/ui/hud_tone.gdshader (design.md "HUD level"). HUD_TONE_GLOSS
## pulls the pale purple gloss sheen toward the body color (0 keeps it, 1 removes it); then HSV saturation and value are
## multiplied by HUD_TONE_SAT, HUD_TONE_VAL. Child nodes (labels, count badge, lock, hint bulb) keep their colors; the
## difficulty pill draws its own text, which is toned.
const HUD_TONE_SAT := 0.8
const HUD_TONE_VAL := 0.97
const HUD_TONE_GLOSS := 0.5

## Last-move warning (level screen): with 1 move left a red vignette (src/ui/low_moves.gdshader) rims the screen and the
## MOVES chip pulses. LOW_MOVES_PERIOD is one pulse cycle in seconds, LOW_MOVES_CHIP_SCALE the chip's peak scale,
## LOW_MOVES_REACH how far the glow reaches in from the screen edge (canvas px), LOW_MOVES_ALPHA its peak opacity,
## LOW_MOVES_FADE the fade in/out time in seconds.
const LOW_MOVES := 1
const LOW_MOVES_PERIOD := 0.9
const LOW_MOVES_CHIP_SCALE := 1.12
const LOW_MOVES_REACH := 80.0
const LOW_MOVES_ALPHA := 0.5
const LOW_MOVES_FADE := 0.3

## Close X of every Unity popup (btnTurnOff, ExitButton, ...; UnityUI.CLOSE_NAMES), 2026-11-08: the art is drawn
## CLOSE_ART_SCALE times its prefab size around its own center, and the touch target is CLOSE_HIT_SCALE times the
## prefab one (art grown to UButton.MIN_HIT). Both are side lengths: a 64 px X draws at 128 px, its 96 px target is 211 px.
## A grown X that would leave the screen moves in to stay CLOSE_EDGE_GAP canvas units from the edge.
const CLOSE_ART_SCALE := 2.0
const CLOSE_HIT_SCALE := 2.2
const CLOSE_EDGE_GAP := 8.0

## "Tap to continue" of the new booster / new mechanic popup (booster_unlocked, 2026-11-10): canvas units from the
## bottom of the screen to the bottom of the line (reference screen 886x1920).
const TAP_CONTINUE_BOTTOM := 90.0

## Player nickname length (design.md mục 5 "Biệt danh"), counted after trimming spaces at both ends. NAME_MAX matches the
## characterLimit of the input field in PopupEditNameLayer.
const NAME_MIN := 3
const NAME_MAX := 14
## Default nickname of a save that has none: the game code then NAME_CODE_DIGITS random digits ("CD_042917").
const NAME_CODE := "CD_"
const NAME_CODE_DIGITS := 6

## Ngày sale theo Time.get_datetime_dict_from_unix_time().weekday (0 = Chủ nhật, 6 = thứ Bảy).
const _SALE_WEEKDAYS := [5, 6, 0]
## Weekend sale cho ai: 1 = mọi người chơi, 2 = chỉ người chưa mua gói nào, 3 = tắt.
## Remote Config: `weekend_sale_mode`.
const _SALE_MODE := 1
## Số % ghi trên nhãn sale của gói `_sale` rẻ hơn gói thường (chỉ để hiển thị; giá thật do SKU `_sale` quyết định).
## Gói `_sale` cùng giá mà nhiều gold hơn thì nhãn ghi số lần gold (Shop.sale_tag), không dùng số này.
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
static var SPECIAL: Dictionary = _SPECIAL.duplicate(true)
static var WIN_STREAK: Dictionary = _WIN_STREAK.duplicate(true)
static var CONTENT: Dictionary = _CONTENT.duplicate(true)
static var SALE_WEEKDAYS: Array = _SALE_WEEKDAYS.duplicate(true)
static var SALE_MODE: int = _SALE_MODE
static var SALE_PERCENT: int = _SALE_PERCENT


## Bộ ảnh giao diện (ThemeKit chỉ chứa màu vẽ bằng code): "" ảnh gốc, "pastel" concept A sữa dâu oải hương
## (assets/themes/pastel/, docs/UI_THEME_PASTEL.md). src/ui/theme_assets.gd đọc giá trị này lúc khởi động.
const UI_THEME := "pastel"


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


## Tester phones (Unity DeviceIdTesting): OS.get_unique_id() of each, the USERID in the subject of a support mail sent
## from that phone. Their support mail carries the SDK status, also in release builds (support_mail.gd is_tester).
const TESTER_DEVICES: Array[String] = []


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
	SPECIAL = _SPECIAL.duplicate(true)
	WIN_STREAK = _WIN_STREAK.duplicate(true)
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


## Ghi đè từ Remote Config. Khoá `<nhóm>_<khoá>` (chữ thường, ví dụ `econ_win_coins`,
## `econ_booster_price_hint`, `skus_starter_pack_usd`, `content_ftue_steps`); giá trị là chuỗi
## được ép về đúng kiểu cũ (mảng: các phần tử cách nhau bằng dấu phẩy). Khoá lạ, giá trị hỏng,
## số âm và chuỗi rỗng bị bỏ qua. `DAILY` (mảng ô) không ghi đè được.
static func apply_remote(values: Dictionary) -> void:
	var groups := {
		"econ": ECON, "lives": LIVES, "ads": ADS, "unlock": UNLOCK, "features": FEATURES,
		"cosmetics": COSMETICS, "skus": SKUS, "offers": OFFERS,
		"notif": NOTIF, "content": CONTENT, "weekly": WEEKLY, "chain": CHAIN,
		"leaderboard": LEADERBOARD, "road_trip": ROAD_TRIP, "win_streak": WIN_STREAK, "special": SPECIAL,
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


## PopupRemoveAds plain card: x and width (prefab units) of the two description lines, inside the cream panel.
const REMOVE_ADS_TEXT_X := 165.0
const REMOVE_ADS_TEXT_W := 330.0
