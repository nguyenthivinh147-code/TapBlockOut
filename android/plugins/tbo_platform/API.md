# API plugin `TboPlatform` (Task 10.1)

Plugin Godot Android v2 viết bằng Kotlin. Singleton: `Engine.get_singleton("TboPlatform")`, có khi `Engine.has_singleton("TboPlatform")`. Phiên bản plugin: `plugin_version()` trả `"1.0.0"`.

Quy ước chung:
- Mọi hàm an toàn khi thiếu cấu hình hoặc khoá lỗi: mô-đun tự tắt, hàm không làm gì, không crash, chỉ `Log.i`/`Log.w` ngắn (tag `TboPlatform`). Bọc mọi hàm trong `try/catch`.
- Hàm bất đồng bộ không trả giá trị, kết quả qua signal. Kể cả khi mô-đun tắt vẫn phát signal kết quả "thất bại" để `await` của GDScript không treo (trừ `review_done` luôn phát, `consent_ready` phát khi MAX tắt).
- Dữ liệu phức tạp là chuỗi JSON UTF-8. Thời gian là giây unix.
- Hàm chạy trên luồng Godot gọi vào; việc nặng được chuyển sang luồng UI của Android. Signal phát từ luồng Android, Godot đưa vào hàng đợi (nối bằng `connect` bình thường).
- Kiểu GDScript của tham số/trả về: `String`, `bool`, `PackedStringArray` (chỉ `lost_rewarded`).

## Khởi tạo và cấu hình

Thứ tự khuyến nghị cho backend GDScript (Task 10.3):

```gdscript
var p := Engine.get_singleton("TboPlatform")
# connect các signal bên dưới trước
if FileAccess.file_exists("res://android_config.json"):
	p.set_config(FileAccess.get_file_as_string("res://android_config.json"))
p.init_sdks()
```

Lý do `set_config`: `res://` nằm trong PCK, mã Java không mở được. Thiếu file thì bỏ qua `set_config`, plugin sẽ thử `assets/android_config.json` trong APK rồi meta-data `tbo.<khoá>` trong manifest, thiếu hết thì mọi mô-đun tắt.

| Hàm | Trả về | Mô tả |
| --- | --- | --- |
| `set_config(json: String)` | void | Nội dung `android_config.json`. Gọi trước `init_sdks()`. JSON hỏng thì coi như rỗng. |
| `init_sdks()` | void | Khởi tạo Firebase, Adjust, Play Games, MAX (kèm luồng đồng ý). Chạy một lần (gọi lại không làm gì). Xong thì phát `consent_ready` rồi `sdk_ready`. |
| `module_status()` | String (JSON) | `{"ads":bool,"ads_ready":bool,"rewarded":bool,"inter":bool,"firebase":bool,"analytics":bool,"rc":bool,"crashlytics":bool,"adjust":bool,"cloud":bool,"notif":bool}`. `ads` = MAX được cấu hình; `ads_ready` = SDK MAX đã khởi tạo xong; `notif` = người dùng đang cho phép thông báo. |
| `plugin_version()` | String | `"1.0.0"` |

### Khoá cấu hình (`android/config/platform_config.example.json`)

Khoá thiếu, rỗng, hoặc bắt đầu bằng `YOUR_` / `REPLACE` / `<` / `TODO` coi là thiếu. Có thể đặt thay bằng meta-data manifest tên `tbo.<khoá>`.

| Khoá | Dùng cho | Thiếu thì |
| --- | --- | --- |
| `applovin_sdk_key`, `rewarded_unit`, `interstitial_unit` | MAX. Cần khoá SDK và ít nhất một ad unit | MAX tắt: `ready_*` false, `show_*` phát kết quả thất bại |
| `privacy_policy_url`, `terms_url` | Luồng đồng ý GDPR của MAX (UMP). Cần `privacy_policy_url` | không bật luồng đồng ý; `terms_url` không bắt buộc |
| `consent_debug_geography` | `"gdpr"` hoặc `"other"`, chỉ để test | bỏ qua |
| `adjust_app_token`, `adjust_environment` (`sandbox`/`production`, mặc định `sandbox`) | Adjust | Adjust tắt |
| `adjust_events` | Map tên sự kiện game → token Adjust. `log_event(name, ...)` có trong map thì gửi thêm cho Adjust | không gửi sự kiện Adjust |
| `play_games_app_id` | App ID Play Games (chỉ chữ số). Cần cho cả addon lúc export (ghi manifest) | cloud save tắt |
| `billing_public_key` | Không dùng trong plugin, để Task 10.3 đọc | không ảnh hưởng |
| `firebase_app_id`, `firebase_api_key`, `firebase_project_id` | Khởi tạo Firebase bằng code nếu không dùng `google-services.json` | nếu cũng không có `google-services.json`: Firebase, Analytics, RC, Crashlytics tắt |
| `rc_defaults` | Map khoá → giá trị mặc định của Remote Config (đều thành chuỗi) | không đặt mặc định |
| `rc_min_fetch_interval_s` | Số giây tối thiểu giữa hai lần fetch (mặc định 3600) | 3600 |

## Quảng cáo (AppLovin MAX)

| Hàm | Trả về | Mô tả |
| --- | --- | --- |
| `ready_rewarded()` | bool | Có quảng cáo rewarded sẵn sàng. |
| `ready_inter()` | bool | Có interstitial sẵn sàng. |
| `load_ads()` | void | Nạp lại các quảng cáo chưa sẵn sàng. MAX tự nạp lại sau mỗi lần hiện/lỗi (lùi dần tối đa 64 giây), hàm này chỉ để kích thêm. |
| `show_rewarded(placement: String)` | void | Hiện rewarded. Kết quả qua `ad_rewarded_done`. Ghi placement vào bộ nhớ bền trước khi hiện. |
| `show_inter(placement: String)` | void | Hiện interstitial. Kết quả qua `ad_interstitial_done`. |
| `has_privacy()` | bool | true nếu người dùng ở vùng GDPR (cần nút Privacy settings). |
| `open_privacy()` | void | Mở lại màn đồng ý. Xong phát `privacy_done`. |
| `open_debugger()` | void | Mở Mediation Debugger của MAX (menu tester). |
| `lost_rewarded()` | PackedStringArray | Placement rewarded đang hiện thì app bị đóng ở phiên trước (mất). Chụp lúc plugin được tạo, không đổi trong phiên. Game trao lại theo luật của mình. |
| `lost_done()` | void | Báo đã xử lý xong; lần sau `lost_rewarded()` trả rỗng. |

Placement truyền vào MAX làm tên placement (báo cáo). Chỉ thưởng khi `ad_rewarded_done` có `ok == true`.

## Analytics, Adjust, Crashlytics

| Hàm | Trả về | Mô tả |
| --- | --- | --- |
| `log_event(name: String, json: String)` | void | Gửi Firebase Analytics, và Adjust nếu `name` có trong `adjust_events`. `json` là object phẳng `{"khoa":giá_trị}`: số nguyên → long, số thực → double, bool → 0/1, chuỗi cắt còn 100 ký tự, bỏ `null`, tối đa 25 tham số. Tên sự kiện/tham số tự chuyển về `a-z0-9_`, bắt đầu bằng chữ, tối đa 40 ký tự. Firebase tắt thì không làm gì. |
| `set_user_props(json: String)` | void | Object phẳng `{"khoa":"giá_trị"}` thành user property (giá trị cắt 36 ký tự) và custom key của Crashlytics; khoá `user_id` đặt luôn user id Crashlytics. |
| `crash_log(message: String)` | void | Breadcrumb cho Crashlytics. |

Plugin tự gửi sự kiện chuẩn `ad_impression` (nền tảng, nguồn, định dạng, đơn vị, doanh thu USD) lên Firebase mỗi khi MAX báo doanh thu. Không gửi sự kiện nào khác: `earn`, `spend`, `rv_*`... do GDScript gọi `log_event`.

## Remote Config

| Hàm | Trả về | Mô tả |
| --- | --- | --- |
| `rc_fetch()` | void | Fetch và activate. Kết quả qua `rc_fetched`. |
| `rc_get_all()` | String (JSON) | Object `{"khoa":"chuỗi"}` giá trị đang hiệu lực (mặc định + đã activate). `"{}"` nếu RC tắt. Mọi giá trị luôn là chuỗi. |

## Đánh giá trong app

| Hàm | Mô tả |
| --- | --- |
| `review()` | Gọi Google In-App Review. Luôn phát `review_done` khi xong, kể cả lỗi hay Play không hiện hộp (hạn mức). |

## Cloud save (Play Games Saved Games, snapshot tên `tbo_save`)

| Hàm | Mô tả |
| --- | --- |
| `cloud_load()` | Đăng nhập Play Games nếu chưa (có thể hiện giao diện đăng nhập), đọc snapshot. Kết quả qua `cloud_loaded`. |
| `cloud_save(json: String)` | Ghi toàn bộ chuỗi JSON (tối đa vài trăm KB). Kết quả qua `cloud_saved`. Nếu có xung đột lúc mở, giữ bản "chơi nhiều hơn" rồi ghi đè bằng `json`. |

Nếu JSON có số ở khoá gốc `play_ms`, `level` thì được ghi vào metadata snapshot (thời gian chơi, tiến độ).

Giải quyết xung đột lúc `cloud_load()`: chọn bản thắng theo thứ tự `play_ms`, rồi `runs`, rồi `level` (khoá gốc của JSON save, so sánh số, thiếu = -1), hoà thì bản sửa sau. Bản thua được phát qua `cloud_conflict` ngay trước `cloud_loaded`. GDScript gộp (ví dụ danh sách `buys`) rồi gọi `cloud_save` bản đã gộp.

## Thông báo local

| Hàm | Trả về | Mô tả |
| --- | --- | --- |
| `notif_ask()` | void | Android 13+: xin quyền `POST_NOTIFICATIONS` (nếu chưa có), kết quả qua `notif_permission`. Dưới 13 hoặc đã có quyền: phát ngay `notif_permission(enabled)`. Người dùng đã từ chối hai lần thì hệ thống không hiện hộp, kết quả `false`. |
| `notif_enabled()` | bool | Người dùng đang cho phép thông báo của app. |
| `notif_schedule(json_items: String)` | void | **Thay toàn bộ** kế hoạch: huỷ lịch cũ, đặt lại. Mảng JSON `[{"at":<giây unix>,"kind":"daily_gift","title":"...","body":"..."}]`. Bỏ mục `at` đã qua, tối đa 60 mục. Lưu bền, tự đặt lại sau khi khởi động máy hoặc cập nhật app. |
| `notif_cancel_all()` | void | Huỷ mọi thông báo đã hẹn. |

Cài đặt: `AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP)` (báo thức không chính xác, lệch có thể vài phút, không cần quyền `SCHEDULE_EXACT_ALARM`). Kênh thông báo `tbo_reminders`. Biểu tượng nhỏ lấy drawable `ic_stat_notify` của app nếu có, không thì icon app. Chạm vào thông báo mở app. Luật lịch (khung giờ 8:00 đến 22:00, tần suất) do GDScript (`notif_plan.gd`) lo, plugin chỉ đặt giờ. `kind` chỉ lưu kèm, chưa dùng.

## Signal

| Signal | Tham số | Khi nào |
| --- | --- | --- |
| `sdk_ready` | `status: String` (JSON như `module_status()`) | `init_sdks()` xong (kể cả khi MAX tắt: phát ngay) |
| `consent_ready` | không | SDK MAX khởi tạo xong, nghĩa là luồng đồng ý đã chạy xong; phát ngay nếu MAX tắt. Không đợi lâu hơn thời gian khởi tạo SDK. |
| `privacy_done` | `ok: bool` | Sau `open_privacy()` |
| `ad_rewarded_done` | `placement: String, ok: bool, reason: String` | Sau `show_rewarded`. `reason` là `""` khi `ok`, ngược lại `"closed"` (đóng khi chưa xem hết), `"not_ready"` (chưa có quảng cáo hoặc MAX tắt) hoặc `"error"` (lỗi hiển thị hoặc đang có quảng cáo khác) |
| `ad_interstitial_done` | `placement: String, shown: bool` | Sau `show_inter`: `shown` true khi quảng cáo đã hiện rồi đóng |
| `rc_fetched` | `json: String` | Sau `rc_fetch()`: `{"ok":bool,"values":{"khoa":"chuỗi"}}` (`ok` false nếu lỗi mạng hoặc RC tắt; `values` vẫn là giá trị hiệu lực) |
| `cloud_loaded` | `json: String, ok: bool` | Sau `cloud_load()`. `ok` true và `json == ""` nghĩa là chưa có bản lưu trên cloud. `ok` false: lỗi, chưa đăng nhập hoặc mô-đun tắt |
| `cloud_saved` | `ok: bool` | Sau `cloud_save()` |
| `cloud_conflict` | `loser_json: String` | Trước `cloud_loaded` khi có xung đột, kèm bản thua |
| `notif_permission` | `granted: bool` | Sau `notif_ask()` |
| `review_done` | không | Sau `review()` |

## Phiên bản dependency (kiểm trên Maven ngày 2026-11-01)

| Thư viện | Phiên bản | Nguồn |
| --- | --- | --- |
| `org.godotengine:godot` (compileOnly) | `4.7.2.stable` (đúng bản có trên Maven Central) | Maven Central |
| Kotlin / `kotlin-stdlib` | 2.1.21 (cùng bản với Godot 4.7.2) | Maven Central / Gradle plugin portal |
| Android Gradle Plugin | 8.6.1 (cùng bản với template Godot 4.7.2) | Google Maven |
| Gradle (wrapper, kiểm sha256 công bố) | 8.11.1, sha256 `f397b287...51c6` | services.gradle.org |
| compileSdk / minSdk | 36 / 24 (cùng template Godot) | Google (`platforms;android-36`) |
| `com.applovin:applovin-sdk` | 13.7.0 | Maven Central |
| `com.google.android.ump:user-messaging-platform` | 4.0.0 | Google Maven |
| `com.google.firebase:firebase-bom` | 35.1.0 → analytics 24.0.0, config 24.0.1, crashlytics 21.0.1 | Google Maven |
| `com.adjust.sdk:adjust-android` | 5.8.1 | Maven Central |
| `com.google.android.gms:play-services-ads-identifier` | 18.2.0 | Google Maven |
| `com.android.installreferrer:installreferrer` | 2.2 | Google Maven |
| `com.google.android.play:review` | 2.0.2 | Google Maven |
| `com.google.android.gms:play-services-games-v2` | 22.1.0 | Google Maven |

Ghi chú build:
- Firebase 35 có metadata Kotlin 2.4, nên Kotlin 2.1.21 cần cờ `-Xskip-metadata-version-check` (chỉ đọc API Java, an toàn). Đã đặt trong `build.gradle.kts`.
- `minCompileSdk` lớn nhất trong các AAR phụ thuộc là 34 (kiểm bằng `aar-metadata.properties`), và không AAR nào khai báo `minAgpVersion`.
- Addon `tbo_platform/export_plugin.gd` liệt kê các dependency trực tiếp với phiên bản đã chốt (BoM không dùng được qua `_get_android_dependencies`). Đổi phiên bản trong `build.gradle.kts` thì đổi cả `DEPENDENCIES` trong `export_plugin.gd`.
- Không thêm adapter mạng mediation nào (chỉ AppLovin tự có). Horus gửi cấu hình xong thêm adapter thành dependency và khai báo ở `export_plugin.gd`.
- Không có tuỳ chọn tắt tạm mô-đun nào: mọi dependency đều giải quyết được từ nguồn chính thức.

## Việc cần ở bước build Gradle của game (Task 10.4)

1. **Android Auto Backup.** Template Godot đặt `android:allowBackup="false"`. Trong `android/build/AndroidManifest.xml` sửa thẻ `<application>`: `android:allowBackup="true"`, `android:fullBackupContent="@xml/tbo_backup_rules"`, `android:dataExtractionRules="@xml/tbo_data_extraction_rules"` (hai file XML nằm trong AAR của plugin, sao lưu thư mục `files/` tức `user://`, loại SharedPreferences `tbo_platform`). Không khai báo trong manifest của plugin vì sẽ xung đột khi merge.
2. **Firebase.** Hai cách, chọn một: (a) đặt `google-services.json` vào `android/build/` và áp plugin `com.google.gms.google-services` cho module app; (b) điền `firebase_app_id`, `firebase_api_key`, `firebase_project_id` trong `platform_config.json` và plugin khởi tạo bằng code (không cần plugin gradle). Crashlytics không cần plugin gradle vì AAR đã kèm id build cố định, nhưng có plugin thì mapping/ký hiệu native mới được tải lên.
3. **Play Games.** Điền `play_games_app_id` (số). Addon tự thêm meta-data `APP_ID` vào manifest và ghi `android/build/res/values/tbo_platform.xml` ở `_export_begin` (cần thư mục `android/build/` của template đã cài). Nếu thứ tự export lệch làm file chưa kịp có lúc Gradle chạy, ghi file này trong `tools/export_release.sh`.
4. **`android_config.json`** chép vào gốc project trước khi export và xoá sau khi export (đã nêu trong plan). Nội dung nó vào PCK nên **không chứa bí mật thật**: SDK key MAX và token Adjust vốn nằm trong app, nhưng không đặt khoá riêng tư nào.
5. **Quyền** đã có trong manifest của plugin: `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `AD_ID`. Khai báo Data safety / Advertising ID trên Play Console theo đó.
6. Kích hoạt addon `res://addons/tbo_platform/plugin.cfg` trong `project.godot` (`editor_plugins/enabled`, giữ `godot_ai`) để export plugin nạp AAR và dependency. Chỉ preset bật `gradle_build/use_gradle_build` mới nhận chúng.

## Chưa kiểm được (cần máy thật, mục 4 của plan)

Plugin mới được biên dịch, chưa chạy trên thiết bị: luồng đồng ý GDPR, rewarded/interstitial thật, Firebase, Adjust, Saved Games, thông báo. Mọi mô-đun đã bọc `try/catch(Throwable)`.
