extends RefCounted
## Dữ liệu mẫu cho các màn đã dựng UI nhưng chưa nối logic (xem docs/UI_FIGMA.md).
## Số ở đây lấy từ wireframe, không phải luật chơi. Khi nối logic, truyền setup({"view": ...}) thật
## rồi xoá khoá tương ứng ở đây; Config.ui_preview giữ các màn này khỏi bản phát hành cho tới lúc đó.

const SHOP_HEARTS := [
	{"count": 5, "price": "$1.99"},
	{"count": 15, "price": "$2.99"},
	{"infinite": true, "hours": 1, "price": "$3.99"},
]
const SHOP_HELPERS := [
	{"title": "shop_helper_great", "price": "$3.99"},
	{"title": "shop_helper_epic", "price": "$4.99"},
]
const SHOP_BUNDLES := [
	{"title": "shop_bundle_sweet", "price": "$4.99"},
	{"title": "shop_bundle_tasty", "price": "$9.99"},
	{"title": "shop_bundle_yummy", "price": "$14.99"},
]

const SPLASH := {"percent": 60, "version": "v1.0.0"}
const DOWNLOAD := {"percent": 35, "done_mb": 17, "total_mb": 48}
const ACCOUNTS := {"accounts": [
	{"name": "Player_2692", "level": 120, "avatar": "avatar_01"},
	{"name": "Player_8812", "level": 24, "avatar": "avatar_04"},
]}
const ADS_DAILY := {"watched": 2, "total": 5, "rewards": [1, 2, 3, 4]}
const REMOVE_ADS := {"price": "$4.99", "bundle_price": "$7.99"}
const TRANSITION := {"level": 2}
const MECHANIC := {"mech": "ice"}
const BOOSTER_UNLOCK := {"count": 3, "price": 100}
const BONUS := {"coins": 40, "multipliers": [2, 3, 5, 3, 2], "result": 200}
const HELPER_PACK := {"gold": 900, "price": "$3.99", "moves": 3}
const HEART_BUNDLE := {"ends_in": "23:59:52", "rows": [
	{"hours": 1, "price": "$0.99"},
	{"hours": 3, "price": "$1.99"},
	{"hours": 24, "price": "$3.99"},
]}
const HEART_SUPPORT := {"price": "$2.99"}
const WEEKLY_UPSELL := {"price": "$4.99", "ends_in": "6d"}
const STREAK_INTRO := {"ends_in": "2d 11h"}
const STREAK_MAIN :={"ends_in": "2d 11h", "streak": 3, "milestones": [6, 4, 2, 0]}
const STREAK_REWARDS := {"rows": [
	{"streak": 2, "kind": "gold", "amount": 200},
	{"streak": 4, "kind": "hint", "amount": 2},
	{"streak": 6, "kind": "heart", "amount": 1},
	{"streak": 8, "kind": "chest", "amount": 1},
]}
const STREAK_END := {"streak": 5, "gold": 200, "hint": 2}
const STREAK_KEEP := {"streak": 5}
const PROFILE_NAME := {"name": "FP_2692e", "error": true}
const LANGUAGES := {"current": "en", "rows": ["en", "vi", "pt_BR", "tr", "de", "fr", "id", "es", "ru", "ko", "ja", "hi", "uk", "it"]}
const REWARD := {"gold": 40}
