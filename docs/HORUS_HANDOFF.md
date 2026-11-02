# Bàn giao cho đội Horus: Tap Block Out (Android, Godot 4.7.2)

Cập nhật 2026-11-01. Game là app Android gốc làm bằng Godot (không phải bản web, không dùng Horus SDK JavaScript). Quảng cáo dùng AppLovin MAX, mua hàng dùng Google Play Billing, Firebase (Analytics, Remote Config, Crashlytics), Adjust, Play Games Saved Games, In-App Review, thông báo local: tất cả nằm trong plugin Android tự viết `TboPlatform` và plugin Godot Google Play Billing 3.3.0. Mã nguồn ghép cấu hình lúc build, thiếu cấu hình thì mô-đun tương ứng tự tắt, game vẫn chạy (không crash).

Gói tên: `com.tungcv2.tapblockout` (đổi theo `appId` Horus cấp: sửa `package/unique_name` trong `export_presets.cfg`, cả ba preset).

## 1. Việc Horus làm và việc phía game làm

| Việc | Ai |
| --- | --- |
| Ký AAB, đưa lên Play, bản nội bộ để test | Horus |
| `appId`, đăng ký SKU trong Play Console | Horus |
| Cấu hình AppLovin MAX, Firebase, Adjust, Play Games | Horus gửi, đặt theo mục 5 |
| Build AAB, APK test | Phía game, bằng Godot (mục 6) |

## 2. SKU (đăng ký trong Play Console, loại "In-app product")

Nguồn: `src/config.gd` (`Config.SKUS`). Giá USD là giá gốc; Play tự quy đổi tiền địa phương. Gói gold sale là SKU riêng (đuôi `_sale`), game dùng giá sale vào thứ Bảy và Chủ nhật theo lịch của máy.

| SKU | Giá USD | Loại | Nội dung |
| --- | --- | --- | --- |
| `gold_pack_1` | 1.99 | consumable | 1.000 gold |
| `gold_pack_2` | 7.99 | consumable | 5.000 gold |
| `gold_pack_3` | 14.99 | consumable | 10.000 gold |
| `gold_pack_4` | 29.99 | consumable | 25.000 gold |
| `gold_pack_5` | 49.99 | consumable | 50.000 gold |
| `gold_pack_6` | 99.99 | consumable | 100.000 gold |
| `gold_pack_1_sale` | 0.99 | consumable | 2.000 gold |
| `gold_pack_2_sale` | 3.99 | consumable | 5.000 gold |
| `gold_pack_3_sale` | 7.49 | consumable | 10.000 gold |
| `gold_pack_4_sale` | 14.99 | consumable | 25.000 gold |
| `gold_pack_5_sale` | 24.99 | consumable | 50.000 gold |
| `gold_pack_6_sale` | 49.99 | consumable | 100.000 gold |
| `remove_ads` | 4.99 | **không consumable** (có Restore) | bỏ interstitial + 500 gold |
| `starter_pack` | 6.99 | **không consumable** (mua một lần) | 6.000 gold + 1 hint, 1 move, 1 smash |
| `rescue_pack` | 0.99 | consumable | 1 booster +3 Move |
| `level_pack` | 4.99 | consumable | 2.000 gold + 1 hint, 1 move, 1 smash |

Giao hàng: game cộng hàng và lưu trước, rồi mới consume (consumable) hoặc acknowledge (không consumable). Mỗi `purchase token` giao một lần; lúc mở game giao hết đơn còn treo; `remove_ads` có nút Restore. Game kiểm chữ ký đơn bằng `billing_public_key`; đơn sai chữ ký bị coi là `invalid`, không thưởng.

## 3. Placement quảng cáo (AppLovin MAX, không banner)

Tên placement gửi vào MAX (chữ thường, không dấu):

- Rewarded: `x2_coins`, `booster_free`, `continue_moves`, `refill_life`, `shop_coins`, `daily_next`, `cosmetic_unlock`.
- Interstitial: `result_exit`.

Chỉ thưởng khi xem hết (`ok == true`). Cần ít nhất một ad unit rewarded và một interstitial. Có luồng đồng ý GDPR (UMP, cần `privacy_policy_url`), nút "Privacy settings" trong Settings và Mediation Debugger. Plugin chưa gắn adapter mạng mediation nào (chỉ AppLovin); Horus gửi danh sách adapter thì thêm vào `DEPENDENCIES` của `addons/tbo_platform/export_plugin.gd` (và `build.gradle.kts` của plugin).

## 4. Remote Config

Định dạng khoá: `<nhóm>_<khoá>` chữ thường (đọc `Config.apply_remote`). Giá trị luôn là chuỗi; mảng viết các phần tử cách nhau bằng dấu phẩy; số âm, chuỗi rỗng và khoá lạ bị bỏ qua; mặc định nằm trong code nên không đặt RC vẫn chạy. Không ghi đè được bảng quà 28 ngày (`DAILY`).

| Khoá | Mặc định |
| --- | --- |
| `econ_start_coins` | 1000 |
| `econ_win_coins` | 40 |
| `econ_booster_price_hint` / `_move` / `_smash` | 900 / 1900 / 2900 |
| `econ_refill_coins` | 900 |
| `econ_refill_lives` | 5 |
| `econ_shop_video_coins` | 200 |
| `econ_shop_video_max` | 5 |
| `econ_rescue_prices` | 1900,2200,2500,2800 |
| `econ_rescue_moves` | 3 |
| `econ_rescue_video_max` | 4 |
| `econ_challenge_coins` | 100 |
| `lives_max` / `lives_regen_sec` / `lives_from_level` | 10 / 900 / 10 |
| `ads_inter_from_run` | 4 |
| `ads_inter_every` | 2 |
| `ads_inter_cooldown` (giây) | 120 |
| `ads_session_warmup` (giây) | 90 |
| `ads_rewarded_grace` (giây) | 45 |
| `ads_first_session_block_until_level` | 10 |
| `unlock_daily_gift`, `unlock_hint`, `unlock_shop`, `unlock_move`, `unlock_smash`, `unlock_lives`, `unlock_starter`, `unlock_review`, `unlock_challenge`, `unlock_stone`, `unlock_ice`, `unlock_chain`, `unlock_layer`, `unlock_fog`, `unlock_pulse` | 4, 5, 5, 12, 17, 10, 10, 10, 50, 14, 30, 40, 55, 70, 90 (level mở khoá) |
| `cosmetics_avatar_count`, `cosmetics_frame_count` | 12, 12 |
| `cosmetics_prices` | 50,75,100 |
| `cosmetics_default_avatar`, `cosmetics_default_frame` | avatar_00, frame_00 |
| `offers_min_secs` / `offers_gap_runs` | 300 / 3 |
| `offers_starter_pack_sku`, `_after_level`, `_at_run`, `_hours` | starter_pack, 10, 12, 48 |
| `offers_remove_ads_sku`, `_after_inter_today`, `_per_day`, `_max_total` | remove_ads, 3, 1, 3 |
| `offers_rescue_pack_sku`, `_fail_streak`, `_cooldown_hours` | rescue_pack, 3, 24 |
| `offers_level_pack_sku`, `_every_levels`, `_hours` | level_pack, 10, 72 |
| `notif_first_week_days`, `_first_week_per_day`, `_lead_min`, `_daily_until_day` | 7, 3, 15, 14 |
| `notif_sparse_days` | 16,18,21,24,27,30 |
| `notif_earliest_hour`, `_latest_hour`, `_quiet_after_ignored`, `_ask_after_run` | 8, 22, 9, 2 |
| `content_demo_max_level`, `content_release_pregen_level` (level cuối có file), `content_loop_start_level` (sau level cuối lặp lại từ đây) | 20, 100, 51 |
| `content_slack_easy`, `_slack_easy_until`, `_slack_hard`, `_slack_min`, `_slack_pct` | 3, 5, 1, 2, 10 |
| `content_think_clap_sec` | 8 |
| `content_build`, `content_support_email` | v1, support@horusvn.com |
| `content_ftue_steps` | open,first_tap,first_win,first_x2,first_booster,run_2,run_5,level_10 |
| `sale_weekdays` (0 = Chủ nhật, 6 = thứ Bảy) | 6,0 |
| `skus_<sku>_usd`, `skus_<sku>_gold`, `skus_<sku>_consumable` (ví dụ `skus_starter_pack_usd`) | theo bảng mục 2 |

Ghi chú: đổi `skus_*_usd` chỉ đổi số hiển thị/logic trong game; giá thật do Play Console quyết định. Plugin còn đọc `rc_defaults` và `rc_min_fetch_interval_s` trong `platform_config.json` (mặc định fetch tối thiểu 3600 giây).

## 5. Sự kiện analytics (Firebase Analytics, và Adjust nếu có trong `adjust_events`)

Tên và tham số chữ thường, `snake_case`, phẳng. Mọi sự kiện do game gửi có thêm tham số `build` (giá trị `content_build`, mặc định `v1`). Plugin tự gửi thêm `ad_impression` (doanh thu quảng cáo từ MAX).

| Sự kiện | Tham số |
| --- | --- |
| `boot` | ms, level, sessions |
| `ftue` | step, idx |
| `level_start` / `challenge_start` | level, runs, moves, lives (challenge thêm day) |
| `level_end` / `challenge_end` | level, won (0/1), taps, moves_left, ms, coins, runs |
| `rv_offer` | pl |
| `rv_start` | pl |
| `rv_done` | pl (có thể kèm credit = 1) |
| `rv_cancel` / `rv_fail` | pl, why |
| `rv_unavailable` | pl |
| `ad_reward_recovered` | pl |
| `inter_show` | pl, level, runs |
| `booster_use` | kind, level |
| `rescue_show` | level, price, remaining, index |
| `rescue_use` | level, method, price, index |
| `daily_claim` | idx, coins, next (0/1) |
| `cos_buy` | id, price, how (gold/video) |
| `shop_open` | source, level |
| `offer_show` | id, level |
| `offer_buy` | id, sku |
| `earn` | currency (gold), amount, source |
| `spend` | currency (gold), amount, sink |

`pl` là placement ở mục 3. User property: `build`, `level`, `sessions`. Game không gửi sự kiện riêng cho doanh thu IAP: doanh thu mua hàng lấy từ Play Console; sự kiện gần nhất là `offer_buy` (chỉ cho mua qua offer). Nếu Horus cần sự kiện doanh thu cho mọi lần mua trong Firebase/Adjust, báo lại để thêm.

Adjust: trong `platform_config.json`, `adjust_events` ánh xạ tên sự kiện của game sang token Adjust. Mẫu `platform_config.example.json` ghi `level_end`, `offer_buy`, `rv_done`, đều là tên sự kiện game thật gửi (`level_end` gồm cả thắng và thua, thắng khi `won=1`). Điền token Adjust vào đúng các khoá này.

## 6. File cấu hình Horus cần gửi và nơi đặt

Tất cả bị `.gitignore` (không commit). Không dán bí mật vào repo, log hay chat công khai.

| File / giá trị | Đặt ở đâu |
| --- | --- |
| `platform_config.json` (theo mẫu `android/config/platform_config.example.json`) | `android/config/platform_config.json`. `tools/export_release.sh` chép thành `android_config.json` ở gốc project lúc build rồi xoá; nội dung vào APK/AAB nên **không đặt khoá riêng tư** |
| Khoá AppLovin MAX: `applovin_sdk_key`, `rewarded_unit`, `interstitial_unit` | trong `platform_config.json` |
| `privacy_policy_url` (bắt buộc cho luồng đồng ý GDPR), `terms_url` | trong `platform_config.json` |
| Token Adjust: `adjust_app_token`, `adjust_environment` (`sandbox` khi test, `production` khi phát hành), `adjust_events` | trong `platform_config.json` |
| Play Games App ID (chỉ chữ số): `play_games_app_id` | trong `platform_config.json`; script build ghi vào `android/build/res/values/tbo_platform.xml` |
| Public key Billing (base64, trong Play Console > Monetization setup): `billing_public_key` | trong `platform_config.json` |
| Firebase, cách A (khuyến nghị): `google-services.json` | `android/config/google-services.json`; script chép vào `android/build/` và bật plugin Gradle `com.google.gms.google-services` (4.4.4) |
| Firebase, cách B (không có file): `firebase_app_id`, `firebase_api_key`, `firebase_project_id` | trong `platform_config.json` |
| `appId` / tên gói | `package/unique_name` trong `export_presets.cfg` |
| Keystore upload / ký Play | Horus giữ. Repo này không chứa và không cần keystore thật |

Thiếu khoá nào thì mô-đun đó tắt, không crash. Google-services: nếu `package_name` trong file không khớp `package/unique_name` thì Gradle báo lỗi.

## 7. Cách build

```
tools/export_release.sh        # APK debug có plugin + AAB bản phát hành chưa ký
tools/export_apk.sh "Android Demo" build/TapBlockOut-demo.apk   # APK demo nhanh, không Gradle
```

- Chạy khi editor Godot đóng. Cần JDK 21 (`JAVA_HOME` mặc định `/usr/lib/jvm/java-21-openjdk-amd64`), Android SDK ở `~/Android/Sdk`, export templates 4.7.2, Gradle tự tải từ nguồn chính thức (services.gradle.org, Maven Central, Google Maven) ở lần đầu.
- `export_release.sh`: cài Android build template nếu thiếu (`android/build/`, không commit), vá manifest (Auto Backup: `allowBackup="true"`, `fullBackupContent`, `dataExtractionRules`), chép cấu hình nếu có, xuất rồi xoá `android_config.json` tạm. Idempotent.
- Đầu ra: `build/TapBlockOut-gradle-debug.apk` (preset `Android Gradle APK`, ký bằng debug keystore mặc định của Godot) và `build/TapBlockOut-release-<versionName>.aab` (preset `Android Release`, **không ký**, không debuggable; Horus ký). Preset `Android Demo` (không Gradle, custom feature `demo`, dừng ở L20) giữ nguyên.
- `targetSdk` = 36 (Android 16), `minSdk` = 24, đặt trong `export_presets.cfg`. Nguồn: https://developer.android.com/google/play/requirements/target-sdk, đọc ngày 2026-11-01 (trang cập nhật 2026-10-28): từ 2026-08-31 app mới và bản cập nhật phải target Android 16 (API 36) trở lên. `minSdk 24` là mức template Godot 4.7.2 và plugin dùng; build merge thành công nghĩa là không dependency nào (MAX 13.7.0, Firebase BoM 35.1.0, Play Games v2 22.1.0, Billing 9.1.0) đòi cao hơn.
- Quy tắc version: sửa `version/code` và `version/name` ở **cả ba** preset trong `export_presets.cfg` (giữ giống nhau). `versionCode` là số nguyên phải tăng mỗi lần đưa lên Play (kể cả bản nội bộ), không bao giờ dùng lại. `versionName` dạng `MAJOR.MINOR.PATCH`; tên file AAB lấy từ `versionName` của preset `Android Release`.

## 8. Rủi ro và điều chưa kiểm được

- Plugin `TboPlatform` mới biên dịch và vào được AAB/APK (đã kiểm manifest, dex), **chưa chạy trên máy thật** (không có thiết bị): luồng đồng ý GDPR, rewarded/interstitial thật, Firebase, Adjust, Saved Games, thông báo.
- AAR billing 3.3.0 build với Godot 4.5.1, **chưa kiểm trên 4.7.2** (plugin Android v2 ổn định từ 4.2, nên không có lý do chặn, nhưng cần thử mua hàng bằng license tester ở bản nội bộ).
- Thứ tự chạy của hai export plugin với Gradle mới kiểm bằng build trên máy này (cả hai plugin có trong manifest và dex); chưa chạy thật trên thiết bị. `play_games_app_id` được ghi cả bởi export plugin lẫn `export_release.sh` để không phụ thuộc thứ tự.
- Cloud save (Saved Games) giải quyết xung đột theo `play_ms`, `runs`, `level`; khôi phục khi cài lại còn dựa vào Android Auto Backup (đã bật, loại SharedPreferences `tbo_platform`). Auto Backup của Google có hạn mức và có thể không chạy trên mọi máy.
- AAB hiện chưa ký: Play Console chỉ nhận AAB đã ký bằng khoá upload, do Horus ký.
- Quyền trong manifest (từ plugin và Godot): VIBRATE, INTERNET, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, AD_ID (`com.google.android.gms.permission.AD_ID`), cùng quyền Billing/MAX/Firebase tự thêm (WAKE_LOCK, ACCESS_WIFI_STATE, BILLING, install referrer, ADSERVICES). Thông báo local dùng báo thức không chính xác nên **không** cần `SCHEDULE_EXACT_ALARM`. Khai báo Data safety và Advertising ID trên Play Console theo danh sách này.
- Dung lượng: AAB khoảng 63 MB, APK debug Gradle khoảng 172 MB (hai ABI, bản debug, có phụ thuộc quảng cáo).

## 9. Việc thủ công còn lại (mục 4 của kế hoạch)

- [ ] Cài APK demo trên máy 2 GB (loại Galaxy A10): chạy từ 30 khung/giây trở lên, âm thanh không trễ, rung nhẹ, lưu game sau khi tắt app.
- [ ] Duyệt cảm giác chơi và các số trong `design.md` mục 5.
- [ ] Nhận từ Horus: `appId`, khoá MAX và ad unit, `google-services.json`, token Adjust, id Play Games, public key Billing; đặt theo mục 6.
- [ ] Có cấu hình rồi: test rewarded, interstitial, mua hàng bằng license tester, Remote Config, cloud save, thông báo trên bản nội bộ.
- [ ] Thông báo trên máy thật, Android 13 trở lên.
