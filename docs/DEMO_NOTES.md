# Ghi chú bản demo Candy Away

Dành cho người duyệt bản thử. Không cần biết lập trình.

- File cài: `build/TapBlockOut-demo.apk` (khoảng 61 MB, bản debug, ký bằng khoá debug).
- Tên gói: `com.tungcv2.tapblockout`, phiên bản `0.1.0` (mã 1), chỉ chạy dọc màn hình, cần Android 7.0 trở lên.
- APK nặng vì chứa cả hai kiểu chip (arm64 và armeabi-v7a) và bản engine debug. Phần hình và âm thanh của game chỉ khoảng 6 MB. Bản phát hành (AAB) sẽ nhẹ hơn nhiều.

## 1. Cài lên điện thoại

1. Trên điện thoại: Cài đặt, Giới thiệu điện thoại, bấm 7 lần vào "Số bản dựng" để bật Tuỳ chọn nhà phát triển. Vào Tuỳ chọn nhà phát triển, bật **Gỡ lỗi USB**.
2. Cắm cáp USB vào máy tính, chọn "Cho phép gỡ lỗi USB" trên điện thoại.
3. Chạy:
   ```
   ~/Android/Sdk/platform-tools/adb devices
   ~/Android/Sdk/platform-tools/adb install -r build/TapBlockOut-demo.apk
   ```
   Nếu `adb devices` không liệt kê máy nào (danh sách rỗng) thì máy chưa kết nối: đổi cáp hoặc cổng, kiểm tra lại gỡ lỗi USB, bấm "Cho phép" trên điện thoại. Hiện máy dev chưa có thiết bị nào cắm.
4. Có thể thay cách cài: chép file APK vào điện thoại rồi mở bằng trình quản lý file (cho phép cài từ nguồn không rõ).

## 2. Phạm vi demo

- Chơi được **Level 1 đến 20**. Sau Level 20 màn hình hiện "Sắp có level mới".
- Nút **Daily Challenge** ở Home bị khoá ("Unlocked at Level 50").
- Mở khoá theo level: quà 28 ngày sau khi thắng Level 3; gợi ý, +3 Move, phá khối ở Level 4, 6, 9; shop và video gold ở Level 5; mạng và Starter Pack từ Level 10. Popup A và B, avatar và frame có từ đầu.
- Chưa có cơ chế mới (đá, băng, xích, hai lớp, sương mù, cổng nhịp): thuộc bản phát hành sau.
- Không có banner, nhiệm vụ ngày hay quà quay lại (đã bỏ khỏi thiết kế).

## 3. Quảng cáo và mua hàng chỉ là giả lập

- Chưa có cấu hình từ Horus (khoá quảng cáo, Firebase, Adjust, Play Billing). Mọi thứ dùng bản giả lập.
- Khi xem video hoặc quảng cáo xen kẽ sẽ hiện overlay **"Quảng cáo giả lập"** với nút Xem hết hoặc Đóng. Bấm "Xem hết" mới được thưởng.
- Khi mua hàng sẽ hiện overlay **"Mua giả lập"** với nút Mua hoặc Huỷ. Không trừ tiền thật.
- Analytics, Remote Config, lưu đám mây và thông báo cũng là bản giả lập (không gửi gì ra ngoài). Lưu game cục bộ trên máy thì chạy thật.

## 3b. Menu tester (sửa tài khoản)

- Mở: vào Cài đặt, chạm nhanh 10 lần vào số phiên bản dưới góc popup. Chạy trên máy tính thì bấm **F1** ở màn nào cũng được.
- Sửa gold, level, số booster (gợi ý, +3 Move, phá khối) rồi bấm **Save**: game về Home với số mới. Ô nhập sai (chữ, số âm, level 0) tô đỏ và không lưu.
- **Xoá tài khoản**: chạm hai lần (lần đầu nút đổi thành "Chạm lần nữa để xoá"). Game quay về như mới cài: Level 1, gold ban đầu, cài đặt mặc định, món mua giả lập bị quên.
- Chỉ có ở bản debug (như APK demo này). Bản phát hành chỉ còn nút mediation debugger.

## 4. Việc cần duyệt trên máy thật

- [ ] Cài trên máy 2 GB RAM (loại Galaxy A10): chạy từ 30 khung/giây trở lên.
- [ ] Âm thanh không bị trễ khi chạm khối.
- [ ] Rung nhẹ hoạt động (có nút tắt trong Cài đặt).
- [ ] Lưu game: chơi vài level, mua thử, tắt hẳn app rồi mở lại, tiến độ vẫn còn.
- [ ] Cảm giác chơi và các số kinh tế trong `design.md` mục 5 (giá, thưởng, quà 28 ngày, mạng).
- [ ] Thông báo trên Android 13 trở lên (xin quyền, hiện đúng giờ). Lưu ý bản demo dùng thông báo giả lập, mục này kiểm đầy đủ ở bản có plugin thật.

## 5. Còn là placeholder hoặc chưa hoàn thiện

| Phần | Tình trạng |
| --- | --- |
| Icon gói gold `shop_<sku>` trong shop, `shop_mini`, `popup_offer` | Vẫn là vòng tròn placeholder vẽ bằng code |
| Thẻ win, lose, no_lives | Chưa dùng ảnh `art_win`, `art_lose`, `art_no_lives` |
| Hình `mech_*` (đá, băng, xích, chìa, sương mù) và 6 âm thanh cơ chế | Hoãn tới Phase 9, demo không dùng |
| Nhạc nền `bgm_home`, `bgm_level` | Chưa ai nghe bằng tai, mới kiểm bằng số liệu. Cần người nghe duyệt |
| `sfx_clap`, `sfx_smash` | Nhỏ hơn các tiếng khác khoảng 6 đến 10 dB, cần cân lại |
| Layout Level 14 và 20 | Chuỗi chặn nông hơn mục tiêu thiết kế |
| Layout Level 6 đến 8 | Bàn hẹp |
| Icon app ở 48 px | Chưa xem trên máy thật |
| Icon đơn sắc (themed icon Android 13) | Chưa có |
| `booster_hint`, `booster_move`, `booster_smash` | Icon mới (AI từ bố cục SVG), chưa xem trên máy thật |

## 6. Lệch so với kế hoạch

- Preset `Android Demo` dùng build không Gradle (APK debug), nên chưa có plugin Android nào (quảng cáo, Billing, Firebase...). Plugin thuộc Phase 10.
- Kích thước APK 61 MB là do hai ABI và template debug, không phải do assets (tests và `addons/godot_ai` đã được loại khỏi gói).
- Các level 21 trở lên không có trong bản này, nên bản demo không thể thử bộ sinh level hay Daily Challenge.
