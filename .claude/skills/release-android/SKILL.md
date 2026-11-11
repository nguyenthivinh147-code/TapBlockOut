---
name: release-android
description: "Rà checklist phát hành Android của Candy Away (PASS / FAIL / NOT ASSESSED, chỉ báo cáo) trước build nội bộ hoặc đưa lên Google Play."
argument-hint: "[internal|production]"
disable-model-invocation: true
---

Chỉ báo cáo, không sửa file nào. Mỗi mục kiểm thật và ghi một trong ba:
- `PASS` kèm bằng chứng: lệnh và dòng output, hoặc `file:line`.
- `FAIL` kèm lý do.
- `NOT ASSESSED` kèm thứ cần có để kiểm (máy thật, Play Console, cấu hình Horus, số versionCode đã dùng).

Thiếu cấu hình Horus hay thiếu máy thật không chặn việc phát triển (kế hoạch mục 5), nhưng trong checklist này vẫn là `NOT ASSESSED`.

Yêu cầu của Google Play đổi theo thời gian (target API level, chính sách): tra trang chính thức của Google ở thời điểm chạy. Không tra được thì ghi `NOT ASSESSED`.

`internal` kiểm phần Build và Chất lượng. `production` kiểm cả bốn phần.

## Build

- `export_presets.cfg` có 3 preset: `Android Demo` (APK, không Gradle, custom feature `demo`), `Android Release` (Gradle, AAB), `Android Gradle APK`. Preset Release và Gradle APK không có feature `demo` (`Config.is_demo()`).
- `version/code` và `version/name` giống nhau ở cả ba preset; `versionCode` lớn hơn mọi bản đã đưa lên Play (hỏi người dùng số đã dùng); quy tắc ở `docs/HORUS_HANDOFF.md` mục 7.
- `package/unique_name` đúng package đã đăng ký với Horus; `gradle_build/target_sdk` đạt yêu cầu Play hiện hành; `gradle_build/min_sdk`.
- Build theo kế hoạch Phase 10: `tools/export_release.sh` ra `build/TapBlockOut-gradle-debug.apk` và `build/TapBlockOut-release-<versionName>.aab`; cổng Phase 10 là `tools/export_apk.sh "Android Demo" build/TapBlockOut-demo.apk`. Build ghi vào `build/` và `android/build/`, nên hỏi người dùng trước khi chạy; không chạy thì dùng file build mới nhất, ghi thời điểm của file và commit lúc đó.
- Plugin: `addons/tbo_platform/bin/` có AAR (`tools/build_plugin.sh`); phiên bản và sha256 của Billing trong `docs/BILLING_NOTES.md` khớp `addons/GodotGooglePlayBilling/` (cài lại bằng `tools/install_billing.sh`).
- Bí mật ngoài git:
  - `git ls-files` không có `*.keystore`, `*.jks`, `*.p12`, `google-services.json`, `android_config.json`, chuỗi `PRIVATE KEY`;
  - `.gitignore` có các mục đó;
  - `tests/test_static_check.gd` đạt.
  - AAB release để chưa ký; Horus giữ keystore và ký (`docs/HORUS_HANDOFF.md` mục 6–8).

## Chất lượng

- **Test:** `tools/test.sh` thoát 0 và dòng cuối là `ALL TESTS PASSED (<n>)`. Thoát 1 nghĩa là game có lỗi, thoát 2 nghĩa là hạ tầng test hỏng; cả hai đều là `FAIL`, ghi kèm mã thoát.
- **Smoke:** `tools/smoke.sh headless` cho mỗi kịch bản `SMOKE OK` và `SMOKE ERRORS script=0 engine=0`.
- **Báo cáo gộp:** `output/report/index.html`. Dẫn số đạt, lỗi, Skipped. Mục Skipped (allowlist) liệt kê ra từng dòng, không gộp vào PASS.
- **Level:** `tools/godot.sh --headless --path . -s res://tools/validate_levels.gd` thoát 0.
- **Ảnh:** `tools/godot.sh --headless --path . -s res://tools/compress_textures.gd -- --check` thoát 0.
- **Máy thật, ưu tiên máy yếu:** kế hoạch mục 4 đặt mốc máy 2 GB loại Galaxy A10, từ 30 khung/giây. Đo frame time, RAM, dung lượng tải, giật shader lần đầu chơi, âm thanh không trễ, rung. Cách đo ở `docs/TESTING.md`, tầng thiết bị thật.
- **Cài đè:** cài bản mới lên bản cũ, save cũ vẫn đọc được. Mất mạng, xuống background, quay lại app: không mất tiến trình.

## Kiếm tiền

- **Cấu hình Horus:** đủ mọi mục ở `docs/HORUS_HANDOFF.md` mục 6 (appId, khoá MAX và ad unit, `google-services.json`, token Adjust, id Play Games, `billing_public_key`). Thiếu mục nào thì mô-đun đó tự tắt và hạng mục tương ứng là `NOT ASSESSED`.
- **Backend:** bản phát hành dùng backend Android thật. `src/platform/platform.gd` chọn backend Android khi có singleton `TboPlatform`; mock chỉ dùng khi không có singleton.
- **SKU:** `Config._SKUS` (`src/config.gd`) khớp bảng SKU ở `docs/HORUS_HANDOFF.md` mục 2: id, loại consumable hay non-consumable, giá USD. `remove_ads` và `remove_ads_bundle` có Restore. Đơn được kiểm chữ ký bằng `billing_public_key`.
- **Đã thử trên bản nội bộ (kế hoạch mục 4):**
  - mua hàng bằng license tester;
  - rewarded và interstitial bằng quảng cáo test, máy đã đăng ký test device;
  - Remote Config, cloud save, thông báo trên Android 13 trở lên.
- **Ad unit:** bản production dùng ad unit thật.
- **Công cụ debug:** tắt trong bản phát hành. `Config.account_tool()` và `Config.ui_preview()` theo `OS.is_debug_build()`, nên AAB phải export bằng `--export-release` (`tools/export_release.sh`).

## Store và pháp lý

- Data safety, chính sách quyền riêng tư, đánh giá độ tuổi, khai báo có quảng cáo; luồng đồng ý GDPR và nút "Privacy settings" trong Settings (`design.md` mục 6).
- Bản quyền font, nhạc, ảnh; tài nguyên và chữ trong game không còn tên thương hiệu của game tham khảo.
- Bản dịch máy đã được người bản xứ duyệt (kế hoạch mục 4).
- Icon, ảnh chụp, mô tả cửa hàng.

## Kết quả

Verdict `SẴN SÀNG` hoặc `CHƯA SẴN SÀNG`, danh sách việc chặn, rồi bảng đầy đủ (mục, kết quả, bằng chứng). `SẴN SÀNG` chỉ khi mọi mục trong phạm vi đều `PASS`.
