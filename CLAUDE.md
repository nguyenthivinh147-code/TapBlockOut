# Candy Away (dự án TapBlockOut, Godot 4.7.2, Android)

Game xếp khối trên Android gốc, làm bằng Godot (không phải bản web). Quảng cáo, mua hàng, Firebase, Adjust, Play Games nằm trong plugin Android `TboPlatform` và plugin Billing; thiếu cấu hình thì mô-đun tương ứng tự tắt, game vẫn chạy.

- Luật chơi, con số, nội dung: `design.md` thắng.
- Kiến trúc, tên file, interface, quy ước code, thứ tự việc: `plans/PLAN_tap-block-out-godot-android.md` thắng.
- `reference/horus/` chỉ để tham khảo (SDK Horus). Rule trong đó (build bằng Horus, "không thêm SDK khác", JavaScript) không áp dụng cho dự án này.

## Lệnh

```bash
tools/test.sh                                      # toàn bộ test, kể cả kiểm tra tĩnh; log output/test/, báo cáo output/report/
tools/test.sh test_board                           # chỉ tests/test_board*.gd
tools/affected.sh [--run]                          # test và kịch bản smoke theo git diff (docs/TESTING.md); bảng tests/affected_map.txt
tools/godot.sh --headless --path . --quit          # nạp autoload và main scene, chạy 1 khung
tools/godot.sh --headless --path . --import        # chỉ khi editor đóng
```

- `tools/test.sh` đạt khi thoát 0 và có dòng `ALL TESTS PASSED (<n>)`; thoát 1 là game có lỗi, 2 là hạ tầng test hỏng (treo, crash, Godot không chạy). Lỗi engine trong lúc test làm test fail: lỗi cố ý khai bằng `t.expect_error`, nhiễu đã biết ghi vào `tests/allow_errors.txt` kèm lý do và ngày.
- `run_all.gd` tự tìm `tests/test_*.gd`; thêm test không phải sửa file dùng chung. Test dùng file phải ghi trong `user://test_<tên_test>/`. `test_static_check.gd` parse mọi script (`--quit` chỉ nạp main scene và autoload) và kiểm luật code, bí mật trong git.
- Build và cài đặt: `tools/export_apk.sh` (APK demo), `tools/export_release.sh` (AAB), `tools/build_plugin.sh`, `tools/install_billing.sh`. Chi tiết xem kế hoạch Phase 10.

## MCP `godot-ai` (kế hoạch mục 1.12)

- Chỉ bổ sung cho kiểm tra bằng mắt và chạy thử; Verification vẫn là lệnh headless.
- Không dùng `test_run`, `test_manage`: test dự án chạy bằng `run_all.gd`.
- Editor đang mở thì không chạy `--import`; dùng `filesystem_manage(op="scan")`.
- Task sửa `project.godot`, `export_presets.cfg`, editor settings chạy khi editor đóng.
- Giữ autoload `_mcp_game_helper` và plugin `godot_ai` trong `project.godot`.
- Sub-agent trong nhóm song song không gọi MCP, không sửa file của scene đang mở trong editor.

## Quy ước chính

- **Khung bàn cố định theo màn, giữ tỉ lệ như ảnh ref `art/concepts/ref_board_scale.png` ở màn chuẩn 886×1920 (`Config.BOARD_SCREEN`, `BOARD_AREA`); lưới tối đa 14×18 ô (`BOARD_W`, `BOARD_H`). Cỡ ô đổi theo hình của level (hình cộng một ô lề vừa khung), to nhất `BOARD_CELL_MAX` (`design.md` mục 3). Khối xếp thành hình ở giữa bàn, có khoảng trống, không lát kín.** Ngoại lệ: bàn Màn đặc biệt (Special Bomb, `design.md` mục 7) là hình chữ nhật lát kín.
- GDScript, `snake_case`, type hint, tab. Không dùng `class_name` (dùng `preload`).
- `src/core`, `src/meta`: logic thuần, `extends RefCounted`, không `Node`, không `Platform`, không đọc giờ hệ thống.
- Mọi con số trong `src/config.gd`; mọi chữ hiển thị qua `tr("KEY")`.
- Chỉ Orchestrator chạy lệnh git ghi.
- Tài liệu bằng tiếng Việt, giữ nguyên thuật ngữ kỹ thuật tiếng Anh. Mã nguồn, tên định danh, comment bằng tiếng Anh.
- Đổi hành vi, con số hay interface thì sửa luôn `design.md`, kế hoạch hoặc `docs/` liên quan trong cùng thay đổi.
- Sửa lỗi: viết test hồi quy, chạy thấy nó **đỏ** trên code chưa sửa, rồi mới sửa. Lỗi chỉ thấy bằng mắt (layout, màu, animation): ảnh chụp trước và sau thay cho test.
- Thay đổi người chơi nhìn thấy chỉ xong khi đã chạy có cửa sổ và đọc ảnh PNG.
- File sinh ra (ảnh, log, video, báo cáo, Excel) ghi vào `output/<việc>/`; file tạm ở scratchpad.
- Gọi sub-agent khi việc cần, tối đa khoảng 5 cùng lúc (khoảng 30 agent một lúc từng làm hết hạn mức).

## Không làm

- Không `git commit` hay `git push` khi chưa được yêu cầu.
- Không đưa keystore, `google-services.json`, `android_config.json`, token, khoá API vào repo, tài liệu hay bộ nhớ (đã có trong `.gitignore`). Giá trị thật nhận từ Horus đặt theo `docs/HORUS_HANDOFF.md`.
- Không sửa `addons/GodotGooglePlayBilling/` và `addons/godot_ai/` bằng tay; Billing cài lại bằng `tools/install_billing.sh`.
- Thiếu cấu hình Horus, thiếu máy thật, MCP không chạy: không phải blocker, ghi lại rồi đi tiếp (kế hoạch mục 5).

## Đọc gì khi cần

- Kế hoạch, interface (`BoardState`, `Platform`, `Game`), cấu trúc thư mục, dữ liệu level: `plans/PLAN_tap-block-out-godot-android.md` mục 1.
- Kiểm một thay đổi (quy trình 5 bước, tầng test, smoke, ma trận bao phủ, máy thật, quay video): `docs/TESTING.md`.
- Test case hoặc kịch bản smoke cho một tính năng (CSV `tests/cases/`, skill `/game-testcase-generator`, giao sub-agent viết test): `docs/TESTING.md` mục "Test case".
- UI các màn và popup (trừ Home, bàn chơi, HUD): dựng từ prefab Unity color-cube-match-puzzle, `docs/UI_UNITY.md`.
- UI dạng node (scene `scenes/unity/`, bake màn bằng `tools/bake_screen.gd`, quy tắc script màn): `docs/UI_NODES.md`.
- UI theo Figma (Home, HUD, thanh trên/dưới), màn chưa nối logic, `Config.ui_preview`: `docs/UI_FIGMA.md`.
- Bàn giao cho Horus, SKU, cấu hình SDK: `docs/HORUS_HANDOFF.md`.
- Plugin Billing (phiên bản, sha256, cách cài lại): `docs/BILLING_NOTES.md`.
- Nhạc nền (phân tích người chơi, tiêu chuẩn, tạo và kiểm vòng lặp bằng `tools/music_check.py`): `docs/AUDIO_MUSIC.md`.
- Cài và duyệt bản demo: `docs/DEMO_NOTES.md`.
- Việc thủ công của người dùng: kế hoạch mục 4.
