# UI dạng node

UI của mọi màn nằm trong scene (`.tscn`) dưới dạng node, mở trong editor là thấy và sửa được. Script của màn không dựng UI tĩnh nữa: nó tìm node có sẵn, điền chữ qua `tr()`, điền dữ liệu, nối signal. Chỉ phần đổi theo dữ liệu (dòng danh sách, ô theo số phần tử, khối trên bàn, hiệu ứng) còn sinh lúc chạy.

## Layout Unity: `scenes/unity/<Layer>.tscn`

- Mỗi layout `data/ui_unity/<Layer>.json` (xuất từ prefab, `tools/unity_ui_export.mjs`) có một scene `scenes/unity/<Layer>.tscn`: gốc `Canvas` (meta `u_canvas`, `u_layer`), con là gốc prefab. Node giữ đủ thuộc tính prefab: anchor, offset, sprite (`u_image.gd` có `@export`, `@tool` nên vẽ được trong editor), chữ, material TMP, màu nút (`u_button.gd`).
- Sinh lại bằng `tools/godot.sh --headless --path . -s res://tools/bake_unity_ui.gd [-- Layer ...]`. Lệnh này ghi đè scene, mất chỉnh sửa trong editor; chỉ chạy khi có bản xuất prefab mới.
- `UnityUI.build(owner, layer)` dùng `Canvas` của layer đó nếu scene của màn đã có sẵn (chưa dựng), không thì instance `scenes/unity/<Layer>.tscn`. Thiếu scene mới dựng từ JSON. Sau đó `UnityUI.adopt` chỉ nối phần runtime: tra node theo đường dẫn Unity, auto size chữ, Animator, ScrollRect, slider, input field, cutout, màu nút, script prefab. Thuộc tính đã lưu trong scene không bị ghi đè.
- Rect Unity (meta `u_rect`) đọc ngược từ anchor và offset của node lúc nối, nên node kéo trong editor giữ chỗ. Con của layout group (Horizontal, Vertical, Grid) và node có ContentSizeFitter vẫn do layout xếp, như Unity.
- `UView.clone(path)` chép template từ bản gốc chưa nối của layer (gồm chỉnh sửa trong editor); template do scene của màn thêm vào thì chép từ chính node đó.
- Mảnh thêm bằng `UnityKit.add` (và `button`, `label`, `well`, `sprite`) mang meta `u_sub`; khi nằm sẵn trong scene, view cha nối nó thành view riêng (`UView.subs`, `UView.sub(node)`), như lúc nó được dựng.

## Scene của màn

- `scenes/<tên>.tscn` instance layer của màn (node `Canvas`, `editable path="Canvas"` khi màn thêm node bên trong) và chứa mọi node tĩnh script từng thêm: mảnh UnityKit, nền ThemeKit, nhãn, nút.
- Node script cần tới đặt tên rõ và bật `unique_name_in_owner`; script dùng `%Tên`.
- Script đặt lại mọi chữ bằng `tr()` lúc chạy (chữ trong scene chỉ để xem trước, ngôn ngữ đổi được), và đặt rõ cả hai chiều cho mọi `visible` phụ thuộc trạng thái game.
- Popup khung PopupOkLayer đã lưu cỡ và phần ẩn trong scene thì gọi `UnityKit.frame(self, title, on_close)` thay cho `UnityKit.popup`.

## Home, thanh hub, main

- `scenes/home.tscn` chứa mọi node của Home; `HubTop`, `NavBar` là instance của `scenes/hub_top.tscn`, `scenes/hub_nav.tscn`. Shop và Leaderboard tạo thanh bằng `HubTop.create()`, `HubNav.create(tab)`.
- Toạ độ Figma của node FigmaBox nằm trong meta `fb_rect`, `fb_bottom`, `fb_font`; `FigmaBox.adopt(root)` đọc lại và co theo bề rộng thật. Muốn dời node Home hay hub thì sửa meta đó, kéo node trong editor không có tác dụng lúc chạy.
- `scenes/main.tscn` có `Background` (instance `scenes/background.tscn`) và `PopupLayer`.
- `main.go()` giữa Shop, Home, Leaderboard trượt màn (`docs/UI_FIGMA.md`, mục chuyển tab): màn cũ còn trong cây thêm 0.33 s rồi mới bị xoá. `HubTop`, `HubNav` của màn được ghim tại chỗ, nên mỗi màn phải có đúng script đó trên thanh của mình (tìm theo script).
- Level: HUD là node trong `scenes/level.tscn`, bàn chơi là instance `scenes/board_view.tscn` (khung kẹo và các lớp); khối, hiệu ứng, popup sự kiện vẫn sinh lúc chạy.

## Chuyển một màn từ code sang node

1. Trong code dựng cũ: đặt `name` và `unique_name_in_owner = true` cho node tĩnh cần dùng; node sinh theo dữ liệu thì `set_meta("u_rt", true)` để không lưu.
2. Bake: `tools/godot.sh --headless --path . -s res://tools/bake_screen.gd -- <tên> ['{"view": ...}']`. Công cụ bật `UnityUI.baking` (không reveal, Animator, auto size, ScrollRect, nối nút), đặt save sạch level 30 và đồng hồ cố định, gọi `setup(args)`, bỏ node `u_rt` và bản clone, rồi ghi đè `scenes/<tên>.tscn`.
3. Xoá code dựng tĩnh; script chỉ tìm node, điền chữ, dữ liệu, signal. Phần theo dữ liệu vẫn sinh trong code.
4. Chạy test của màn và kiểm không có node bị dựng hai lần (tên `@Label@…` hay số con tăng gấp đôi).

Bake chạy code dựng cũ trên scene hiện có: bake lại một scene đã bake sẽ nhân đôi node tĩnh. Muốn bake lại thì trả scene về bản chỉ có `Canvas` trước.

## Lưu ý

- Script gắn lên node trong scene không đặt thuộc tính có sẵn của Godot trong `_init()`: khi nạp scene, thuộc tính có sẵn được gán trước script, `_init()` chạy sau sẽ ghi đè giá trị đã lưu. Đặt ở nơi tạo node.
- Màn tự dựng lại (xoá con rồi dựng) không được xoá node của scene; làm mới nội dung thay vì dựng lại.
- Scene của màn không lưu được thay đổi trên node của layer instance khi giá trị mới bằng mặc định của Godot (`visible = true` trên node prefab ẩn, `clip_children = DISABLED`, `autowrap_mode = OFF`), cũng không đổi tên hay xoá được node đó. Những việc này vẫn làm trong code. Đổi tên node prefab lúc bake làm hỏng đường dẫn trong scene: bọc bằng `if not UnityUI.baking`.
- `bake_screen.gd` luôn bật editable children cho `Canvas` của layer Unity (để lưu thay đổi trên node prefab). Màn instance một màn khác đã chuyển (level chứa board_view) chỉ bật cho instance có node thêm vào bên trong, nên con của scene kia không bị chép thành override.
- `bake_screen.gd` gọi `setup(Dictionary)`. Màn có `setup` khác kiểu (board_view nhận `BoardState`) thì viết script tạm dựng phần tĩnh rồi gọi `BakeScreen.save(screen, path)`.
- Override `layout_mode` trên node của layer instance làm lệch offset khi nạp (nút X 128 thay vì 64): `bake_screen.gd` tự bỏ dòng đó trong phần override.
- Animation chạy trễ (tween, `call_deferred`) của màn phải bọc `if not UnityUI.baking`, kẻo scale, modulate giữa chừng bị lưu.
