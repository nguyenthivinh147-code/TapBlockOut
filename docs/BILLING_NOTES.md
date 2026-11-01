# Ghi chú plugin Billing (cho Task 10.3)

- Plugin: Godot Google Play Billing (`godot-sdk-integrations/godot-google-play-billing`)
- Tag/phiên bản: **3.3.0** (phát hành 2026-07-27, "Latest" trên GitHub Releases, đã kiểm ngày 2026-11-01)
- Nguồn: https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip
- sha256 của zip: `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568` (trùng trường `digest` của GitHub Releases API; repo không công bố file checksum riêng)
- sha256 AAR trong bản đã cài:
  - `bin/release/GodotGooglePlayBilling-release.aar`: `b667b4ae3ecf91d7dea90bebd4ba5a7aef56cfc2cd7de4787aeb51a1927dcef7`
  - `bin/debug/GodotGooglePlayBilling-debug.aar`: `f7f8f3f1c8099e58127332c8c27f353a7eea079e749682d2ebd83d1bd4bd6f3d`
- Cài/cài lại: `tools/install_billing.sh` (idempotent, kiểm sha256, `--force` để cài lại).
- Billing Library bên dưới: `com.android.billingclient:billing-ktx:9.1.0`.

## 1. Tương thích Godot 4.7.2

Release ghi "Godot 4.2+". AAR build với `org.godotengine:godot:4.5.1.stable`, nhưng là plugin Android v2 (API ổn định từ 4.2), nên không có lý do chặn 4.7.2. **Chưa chạy thử trên máy thật** (không có thiết bị); phải kiểm ở bản nội bộ (mục 4 của kế hoạch). Không phải blocker.

## 2. Cấu trúc file đã cài

```
addons/GodotGooglePlayBilling/
  plugin.cfg            # script="export_plugin.gd", version="3.3.0"
  export_plugin.gd      # EditorExportPlugin: thêm AAR + dependency Maven khi export Android
  BillingClient.gd      # Node bọc singleton, có `class_name BillingClient`
  bin/debug|release/*.aar
  LICENSE
```

- `export_plugin.gd` chỉ hoạt động khi plugin được bật trong `project.godot` (`editor_plugins/enabled` thêm `res://addons/GodotGooglePlayBilling/plugin.cfg`, giữ `godot_ai`). Task 10.3 làm việc này, khi editor đóng.
- Export plugin trả `_get_android_libraries` (AAR theo debug/release) và `_get_android_dependencies` (`billing-ktx:9.1.0`, tải từ Google Maven lúc Gradle build).

## 3. Yêu cầu Gradle và Android

- **Bắt buộc `gradle_build/use_gradle_build=true`** (plugin v2 và dependency Maven không chạy với build APK không Gradle). Hệ quả: preset `Android Demo` (APK nhanh, không Gradle) **không có billing**; đúng ý vì bản demo dùng mock. `Platform` chọn backend theo singleton `TboPlatform`, nhưng `android_iap` phải tự kiểm `Engine.has_singleton("GodotGooglePlayBilling")` (xem mục 4) vì có thể có `TboPlatform` mà không có billing.
- minSdk của plugin: 23 (Godot 4.7 đặt minSdk của template cao hơn, không xung đột). compileSdk của plugin: 36. Template Gradle cần compileSdk >= 36; kiểm khi chạy Task 10.4.
- Cần Internet lúc build để Gradle lấy `billing-ktx:9.1.0` từ Google Maven (nguồn chính thức).
- Quyền Internet bật trong preset. Package name phải trùng app trên Play Console. Phải ký bằng keystore phát hành thì Play mới trả sản phẩm (Horus ký AAB).
- Muốn mua thử: tài khoản license tester + bản đã upload lên track nội bộ.

## 4. API thực tế

Singleton Android tên **`GodotGooglePlayBilling`** (không phải `TboPlatform`). Dùng qua wrapper `BillingClient.gd` (lớp `Node`).

Khởi tạo, **không dựa vào `class_name`** (quy ước dự án không dùng global class cache): 

```gdscript
const BillingClientScript := preload("res://addons/GodotGooglePlayBilling/BillingClient.gd")
var _bc  # BillingClientScript

func _init_billing() -> bool:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return false              # desktop, hoặc build không kèm plugin: coi là thiếu cấu hình
	_bc = BillingClientScript.new()   # _init() gọi singleton.initPlugin() và nối signal
	add_child(_bc)
	_bc.connected.connect(_on_connected)
	...
	_bc.start_connection()
	return true
```

Khi không có singleton, mọi hàm của `BillingClient.gd` là no-op và **không bao giờ phát signal** (chỉ in lỗi nếu là bản template). Nên đặt timeout cho mọi `await` signal, nếu không coroutine treo mãi.

Enum dùng qua `BillingClientScript.BillingResponseCode.OK` ... (hằng của script đã preload).

### Hàm (wrapper -> singleton)

| Hàm | Ghi chú |
| --- | --- |
| `start_connection()` | Kết quả qua `connected` hoặc `connect_error`. Client bật `enableAutoServiceReconnection()`. |
| `end_connection()` | Sau đó không dùng lại client. |
| `is_ready() -> bool`, `get_connection_state() -> int` | `ConnectionState`: DISCONNECTED 0, CONNECTING 1, CONNECTED 2, CLOSED 3. |
| `query_product_details(ids: PackedStringArray, type)` | `type = ProductType.INAPP` (0) hoặc `SUBS`. **Phải gọi và đợi kết quả trước `purchase`**, nếu không `purchase` trả `DEVELOPER_ERROR` ("productId not found!"). |
| `query_purchases(type, include_suspended_subs=false)` | Trả đơn **chưa consume** (INAPP) hoặc sub đang hiệu lực. Dùng cho Restore và giao đơn treo lúc mở game. |
| `purchase(product_id, purchase_option_id="", offer_id="", is_offer_personalized=false) -> Dictionary` | Trả ngay `{response_code, debug_message}` cho biết **mở được luồng mua chưa**; kết quả mua thật qua `on_purchase_updated`. Game này chỉ truyền `product_id`. |
| `consume_purchase(token)` | Consume **và tự acknowledge**. Kết quả `consume_purchase_response`. |
| `acknowledge_purchase(token)` | Cho non-consumable. Kết quả `acknowledge_purchase_response`. |
| `set_obfuscated_account_id(id)`, `set_obfuscated_profile_id(id)` | Tuỳ chọn, chống gian lận. Gọi trước `purchase`. |
| `purchase_subscription`, `update_subscription`, `open_subscriptions_page` | Không dùng (không có sub). |

### Signal và dictionary

Mọi dictionary kết quả có `response_code: int` và `debug_message: String`.

| Signal | Tham số | Trường thêm |
| --- | --- | --- |
| `connected` | không | |
| `disconnected` | không | |
| `connect_error` | `(response_code: int, debug_message: String)` | |
| `query_product_details_response` | `(response: Dictionary)` | Chỉ khi OK: `product_details: Array`, `unfetched_products: Array` |
| `query_purchases_response` | `(response)` | Chỉ khi OK: `purchases: Array` |
| `on_purchase_updated` | `(response)` | Chỉ khi OK: `purchases: Array`. Lỗi/huỷ: không có `purchases` |
| `consume_purchase_response` | `(response)` | `token: String` |
| `acknowledge_purchase_response` | `(response)` | `token: String` |

**product_details[i]**: `product_id`, `title`, `name`, `description`, `product_type`, `one_time_purchase_offer_details_list: Array|null`, `subscription_offer_details: Array|null`. Giá hiển thị: `one_time_purchase_offer_details_list[0].formatted_price` (cũng có `price_amount_micros`, `price_currency_code`, `purchase_option_id`, `offer_id`, `offer_token`...). **unfetched_products[i]**: `product_id`, `product_type`, `status_code` (SKU chưa tạo/chưa active trên Play Console nằm ở đây, không báo lỗi).

**purchases[i]**: `order_id`, `purchase_token`, `package_name`, `purchase_state` (0 UNSPECIFIED, 1 PURCHASED, 2 PENDING), `purchase_time` (ms), `original_json` (String, chuỗi JSON gốc Play ký), `signature` (base64), `is_acknowledged: bool`, `is_auto_renewing`, `is_suspended`, `quantity`, `product_ids` (mảng chuỗi; duyệt như Array, lấy `[0]`; một đơn có thể gồm nhiều SKU về lý thuyết). Lưu ý `order_id` có thể rỗng với đơn PENDING.

### BillingResponseCode

`OK 0`, `USER_CANCELED 1`, `SERVICE_UNAVAILABLE 2`, `BILLING_UNAVAILABLE 3`, `ITEM_UNAVAILABLE 4`, `DEVELOPER_ERROR 5`, `ERROR 6`, `ITEM_ALREADY_OWNED 7`, `ITEM_NOT_OWNED 8`, `NETWORK_ERROR 12`, `SERVICE_DISCONNECTED -1`, `FEATURE_NOT_SUPPORTED -2`, `SERVICE_TIMEOUT -3`.

Ánh xạ gợi ý sang `Platform.iap.buy()`:

| Tình huống | `status` |
| --- | --- |
| `on_purchase_updated` OK, `purchase_state == 1`, chữ ký đúng | `ok` (kèm `sku`, `token`, `order_id`) |
| OK nhưng chữ ký sai hoặc `package_name` khác package app | `invalid` (không thưởng, không consume/ack) |
| `purchase_state == 2` | `pending` (không thưởng, không consume) |
| `USER_CANCELED` | `cancel` |
| `ITEM_ALREADY_OWNED` | `owned` (non-consumable đã mua; với consumable chưa consume thì giao qua `pending()`) |
| `purchase()` trả không-OK ngay, hoặc các mã khác | `error` |

`buy` nên: kiểm `is_ready()` (không thì `error`), gọi `purchase`, nếu `response_code != OK` trả `error` ngay (không đợi signal), còn lại `await on_purchase_updated`. Đợi tối đa vô hạn là chấp nhận được vì luồng mua có UI của Play, nhưng `Platform` nên chặn bấm đôi.

## 5. Kiểm chữ ký (làm được trong GDScript, offline)

Play ký **`original_json`** bằng RSA PKCS#1 v1.5 + **SHA-1** (`SHA1withRSA`); `signature` là base64. Public key lấy từ Play Console (Monetize > Monetization setup > Licensing), dạng base64 của DER X.509 SubjectPublicKeyInfo (một dòng).

Đã chạy thử với Godot 4.7.2 headless trên cặp khoá RSA 2048 tự sinh (`openssl dgst -sha1 -sign`): chữ ký đúng cho `true`, đổi một chữ trong JSON cho `false`.

```gdscript
func verify_purchase(original_json: String, signature_b64: String, public_key_b64: String) -> bool:
	if public_key_b64.is_empty() or signature_b64.is_empty():
		return false
	var pem := "-----BEGIN PUBLIC KEY-----\n" + public_key_b64 + "\n-----END PUBLIC KEY-----\n"
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:   # true = chỉ khoá công khai
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(original_json.to_utf8_buffer())      # đúng chuỗi gốc, không parse rồi dump lại
	return Crypto.new().verify(HashingContext.HASH_SHA1, ctx.finish(),
			Marshalls.base64_to_raw(signature_b64), key)
```

Lưu ý:
- Chuỗi `original_json` phải giữ nguyên từng byte; **không** `JSON.parse` rồi `stringify` trước khi verify. Sau khi verify mới parse để đọc `productId`, `purchaseToken`, `packageName`, `purchaseState`.
- Sau verify, đối chiếu thêm: `package_name` bằng package app, `product_ids[0]` thuộc danh sách SKU của game, `purchase_state == 1`.
- Public key lấy từ `res://android_config.json` (Task 10.4 chép vào lúc build; khoá `billing_public_key` do Orchestrator/10.3 đặt tên cho khớp `platform_config.example.json` của 10.1). **Thiếu public key**: cách an toàn cho demo/nội bộ là coi `ok` (không thể kiểm) và log cảnh báo; bản phát hành phải có khoá. Quyết định này thuộc 10.3, nên ghi vào test.
- Không cần Kotlin: không phải sửa plugin. Chữ ký này chỉ chặn đơn giả đơn giản; chống gian lận thật cần server (design.md mục 7 đã chốt: để sau).

## 6. Consumable và non-consumable

Quy tắc giao hàng (design.md mục 7): **lưu hàng vào save trước, xác nhận đơn sau; mỗi token giao một lần; mở game giao hết đơn treo.** Nếu app chết giữa chừng thì đơn vẫn chưa consume/ack, `query_purchases` trả lại và game giao tiếp (token đã ghi trong `buys` thì không cộng lần hai, chỉ xác nhận lại). Không acknowledge trong 3 ngày thì Play tự hoàn tiền.

| SKU | Loại | `Platform.iap.finish(p, consumable)` gọi |
| --- | --- | --- |
| `gold_pack_1..6` (và `_sale`), `rescue_pack`, `level_pack` | Consumable | `consume_purchase(token)` (đã gồm acknowledge), chờ `consume_purchase_response` |
| `remove_ads`, `starter_pack` | Non-consumable | `acknowledge_purchase(token)`, chờ `acknowledge_purchase_response`. Chỉ cần nếu `is_acknowledged == false` |

- `_sale` là SKU riêng nên cũng consumable.
- Non-consumable không bao giờ được consume (mất quyền sở hữu và Restore).
- `response_code` của consume/ack khác `OK` (kể cả `ITEM_NOT_OWNED` nếu đã consume) thì coi là chưa xong và thử lại ở lần mở game sau; nếu `ITEM_NOT_OWNED` thì có thể coi như đã xong.
- `finish` nên chạy nền, không chặn UI; thất bại không mất hàng vì hàng đã lưu.

## 7. Restore và đơn treo

- **Mở game / sau `connected`**: `query_purchases(INAPP)`. Với mỗi purchase `purchase_state == 1` và chữ ký đúng: đưa vào `pending()` (Platform trả mảng dictionary `{sku, token, order_id, ...}`; game giao rồi gọi `finish`). Purchase `purchase_state == 2` bỏ qua cho tới khi đổi trạng thái.
- **Restore (`remove_ads`)**: cũng là `query_purchases(INAPP)`; `remove_ads` đã ack nên vẫn nằm trong danh sách vì chưa từng consume. `restore() -> bool` trả `true` nếu thấy `remove_ads` hợp lệ (game tự đặt cờ, không cộng gold hai lần: token đã có trong `buys` thì bỏ qua phần gold 500). Tương tự `starter_pack` nếu cần.
- Consumable đã consume thì **không** xuất hiện lại trong `query_purchases`; đó là lý do phải ghi token vào `buys` và giao đủ trước khi consume.
- **Đơn PENDING** (thanh toán tiền mặt/chờ duyệt): `enablePendingPurchases` đã bật cho one-time products. `on_purchase_updated` ban đầu cho `purchase_state == 2`. Không thưởng. Khi hoàn tất, Play phát `on_purchase_updated` mới (nếu app đang chạy) hoặc đơn xuất hiện với `purchase_state == 1` ở lần `query_purchases` sau. Vì vậy cần `query_purchases` mỗi lần mở game và khi app resume.
- `on_purchase_updated` có thể đến **ngoài** lời gọi `buy` (đơn treo hoàn tất, mua từ nơi khác). Backend nên nối signal vĩnh viễn ở `_init`, đẩy đơn không có `buy` đang đợi vào hàng đợi `pending()`.

## 8. Việc cho Task 10.3 (tóm tắt)

1. Preload `BillingClient.gd`, kiểm `Engine.has_singleton("GodotGooglePlayBilling")`, đặt timeout cho mọi chờ signal, thiếu singleton thì `price()` trả chuỗi rỗng và `buy()` trả `error`.
2. Sau `connected`: `query_product_details(skus, INAPP)` (lưu `formatted_price` cho `price()`), rồi `query_purchases(INAPP)`.
3. `verify_purchase` như mục 5; ánh xạ trạng thái như mục 4; consume/ack theo mục 6.
4. `class_name BillingClient` nằm trong addon của bên thứ ba: không sửa file. Có thể gây cảnh báo trùng tên nếu ai đó khai báo `BillingClient` khác; tránh đặt tên đó trong `src/`.
5. Bật plugin trong `project.godot` (khi editor đóng), giữ `godot_ai`. Preset Release cần `use_gradle_build=true` (Task 10.4).
