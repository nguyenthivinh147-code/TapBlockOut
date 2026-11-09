extends RefCounted
## Dữ liệu mẫu cho danh sách xem trước UI (ui_gallery.gd, docs/UI_FIGMA.md): các màn chưa nối logic (Hearts trong
## Shop, 5.2, 5.3, 2.3) và vài màn đã nối mà dữ liệu thật thường trống lúc xem trước (chọn bản lưu, popup thưởng).
## Số ở đây lấy từ wireframe, không phải luật chơi. Config.ui_preview giữ các màn chưa nối khỏi bản phát hành.

const SHOP_HEARTS := [
	{"count": 5, "price": "$1.99"},
	{"count": 15, "price": "$2.99"},
	{"infinite": true, "hours": 1, "price": "$3.99"},
]

const SPLASH := {"percent": 60, "version": "v1.0.0"}
const ACCOUNTS := {"accounts": [
	{"name": "Player_2692", "level": 120, "avatar": "avatar_01"},
	{"name": "Player_8812", "level": 24, "avatar": "avatar_04"},
]}
const ADS_DAILY := {"watched": 2, "total": 5, "rewards": [1, 2, 3, 4]}
const TRANSITION := {"level": 2}
const BOOSTER_UNLOCK := {"kind": "hint", "count": 1}
const HELPER_PACK := {"gold": 1900}
const HEART_BUNDLE := {"ends_in": "23:59:52", "rows": [
	{"hours": 1, "price": "$0.99"},
	{"hours": 3, "price": "$1.99"},
	{"hours": 24, "price": "$3.99"},
]}
const HEART_SUPPORT := {"price": "$2.99"}
const REWARD := {"gold": 40}
