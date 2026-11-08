# UI dạng node

UI của mọi màn nằm trong scene (`.tscn`) dưới dạng node, mở trong editor là thấy và sửa được. Script của màn không dựng UI tĩnh nữa: nó tìm node có sẵn, điền chữ qua `tr()`, điền dữ liệu, nối signal. Chỉ phần đổi theo dữ liệu (dòng danh sách, ô theo số phần tử, khối trên bàn, hiệu ứng) còn sinh lúc chạy.

## Layout Unity: `scenes/unity/<Layer>.tscn`

- Mỗi layout `data/ui_unity/<Layer>.json` (xuất từ prefab, `tools/unity_ui_export.mjs`) có một scene `scenes/unity/<Layer>.tscn`: gốc `Canvas` (meta `u_canvas`, `u_layer`), con là gốc prefab. Node giữ đủ thuộc tính prefab: anchor, offset, sprite (`u_image.gd` có `@export`, `@tool` nên vẽ được trong editor), chữ, material TMP, màu nút (`u_button.gd`).
- Sinh lại bằng `tools/godot.sh --headless --path . -s res://tools/bake_unity_ui.gd [-- Layer ...]`. Lệnh này ghi đè scene, mất chỉnh sửa trong editor; chỉ chạy khi có bản xuất prefab mới.
- `UnityUI.build(owner, layer)` dùng `Canvas` của layer đó nếu scene của màn đã có sẵn (chưa dựng), không thì instance `scenes/unity/<Layer>.tscn`. Thiếu scene mới dựng từ JSON. Sau đó `UnityUI.adopt` chỉ nối phần runtime: tra node theo đường dẫn Unity, auto size chữ, Animator, ScrollRect, slider, input field, cutout, màu nút, script prefab. Thuộc tính đã lưu trong scene không bị ghi đè.
- Rect Unity (meta `u_rect`) đọc ngược từ anchor và offset của node lúc nối, nên node kéo trong editor giữ chỗ. Con của layout group (Horizontal, Vertical, Grid) và node có ContentSizeFitter vẫn do layout xếp, như Unity.
- `UView.clone(path)` chép template từ bản gốc chưa nối của layer (gồm chỉnh sửa trong editor); template do scene của màn thêm vào thì chép từ chính node đó.
- Mảnh thêm bằng `UnityKit.add` (và `button`, `label`, `well`, `sprite`) mang meta `u_sub`; khi nằm sẵn trong scene, view cha nối nó thành view riêng (`UView.subs`, `UView.sub(node)`), như lúc nó được dựng.

## Scene gọn: metadata và StyleBox

- Scene chỉ lưu phần spec mà code đọc sau khi node đã có: `UnityUI.SPEC_KEEP` cho meta `u` (id, tên, script prefab `cs`, layout group, Animator, scroll, slider, input, mask, và vài khoá của `img`, `raw`, `txt`, `btn`, `tog`), `UnityUI.TXT_KEEP` cho meta `u_txt`. Phần còn lại (rect `r`, màu, kiểu ảnh, transition nút, chữ gốc...) chỉ để `_make` dựng node, mà node trong scene đã mang kết quả. `bake_unity_ui.gd` và `bake_screen.gd` gọi `UnityUI.slim` trước khi lưu.
- Code mới đọc một khoá spec khác trên node đã bake: thêm khoá vào `SPEC_KEEP` hoặc `TXT_KEEP`. Khoá đã bỏ không còn trong scene cũ, nên phải bake lại layer (`bake_unity_ui.gd` ghi đè chỉnh sửa trong editor) hoặc đọc khoá từ JSON (`UnityKit.spec(layer, path)`).
- Mọi `UButton` và label Unity vẽ box chung `UnityUI.empty_box(margins)`; scene lưu một sub-resource cho mỗi bộ margin thay vì một cái cho mỗi node. Không sửa tại chỗ box lấy từ `get_theme_stylebox`: gọi `empty_box` với margin mới, hoặc `duplicate()` trước khi sửa như `theme_kit.gd`.
- Scene đã có sẵn thì gọn bằng `tools/godot.sh --headless --path . -s res://tools/slim_scenes.gd [-- res://scenes/<tên>.tscn ...]`. Công cụ sửa text của scene, không bake lại: chỉnh sửa trong editor, uid, `unique_id` và override giữ nguyên; meta `u`, `u_txt` được cắt như trên, `StyleBoxEmpty` giống nhau gộp làm một. Chạy lại không đổi gì. Chạy khi editor đóng.
- Bake màn khi layer của nó chưa gọn thì meta gọn của node layer thành override trong scene màn: chạy `slim_scenes.gd` trước.
- `tests/test_unity_slim.gd` dựng mọi layer hai lần, spec đủ và spec gọn, rồi so từng node sau khi nối; nó cũng báo scene nào chưa gọn. Khoá chỉ script màn đọc (`img.ppu`, `txt.rt`, `btn.inter`) chỉ được test của màn đó kiểm.

## Cache scene

- `src/ui/scene_cache.gd` giữ các PackedScene mở gần nhất. Nạp qua nó:
  - `main.go`, `main.open_popup`. Popup trong level cũng đi qua `open_popup`.
  - `UnityUI.instance`: layer dựng lúc chạy, và bản gốc mà `UView.clone` chép template ra.

  Popup mở thẳng bằng `load()` (howto Weekly Pass, đổi tên, help) không qua cache.
- Giữ một PackedScene là giữ luôn sub-resource, các scene nó instance và texture của chúng, nên mở lại không phải parse scene hay decode texture. Màn clone template từ layer chỉ nạp layer một lần, thay vì hai lần mỗi lượt mở.
- `Config.SCENE_CACHE` (mặc định 8) là số scene giữ tối đa. Đầy thì bỏ scene mở lâu nhất; 0 là tắt.
- Số đo một phiên chơi mẫu, bản binary trên desktop, ngày 2026-11-08. Mỗi vòng mở 13 lần: Home, chain offer, daily, level, rescue, lose card, offer, settings trong level, win card, Home, settings, shop, Home.

  | `SCENE_CACHE` | Vòng đầu | Vòng sau | RAM thêm |
  |---|---|---|---|
  | 0 | 1490 ms | 430 ms | 0 |
  | 4 | 1064 ms | 417 ms | 26 MB |
  | 8 | 1013 ms | 358 ms | 35 MB |
  | 16 | 978 ms | 249 ms | 67 MB |
- Mọi instance của một scene đang giữ dùng chung sub-resource của scene đó. Material, StyleBox, font, animation lấy từ node của scene thì `duplicate()` trước khi sửa, hoặc đặt `resource_local_to_scene` như material khung trong `board_view.tscn`. Sửa tại chỗ thì lần mở sau thấy luôn giá trị đã sửa.
- `tests/test_scene_cache.gd` mở mọi màn và popup từ scene đang giữ, rồi báo resource dùng chung nào bị đổi và scene nào sở hữu nó.
- Thẻ thắng: level vẫn tự nạp nền và giữ riêng (`_warm_result_card`), không phụ thuộc cache.

## Scene của màn

- `scenes/<tên>.tscn` instance layer của màn (node `Canvas`, `editable path="Canvas"` khi màn thêm node bên trong) và chứa mọi node tĩnh script từng thêm: mảnh UnityKit, nền ThemeKit, nhãn, nút.
- Node script cần tới đặt tên rõ và bật `unique_name_in_owner`; script dùng `%Tên`.
- Script đặt lại mọi chữ bằng `tr()` lúc chạy (chữ trong scene chỉ để xem trước, ngôn ngữ đổi được), và đặt rõ cả hai chiều cho mọi `visible` phụ thuộc trạng thái game.
- Popup khung PopupOkLayer đã lưu cỡ và phần ẩn trong scene thì gọi `UnityKit.frame(self, title, on_close)` thay cho `UnityKit.popup`.

## Home, thanh hub, main

- `scenes/home.tscn` chứa mọi node của Home; `HubTop`, `NavBar` là instance của `scenes/hub_top.tscn`, `scenes/hub_nav.tscn`. Shop và Leaderboard tạo thanh bằng `HubTop.create()`, `HubNav.create(tab)`. Thẻ thắng cũng tạo `HubTop` (meta `u_rt`), nhưng chỉ khi gold x2 bay lên thanh; trong lúc đó `gold_shown` giữ số gold đang đếm thay cho số trong ví.
- Toạ độ Figma của node FigmaBox nằm trong meta `fb_rect`, `fb_bottom`, `fb_font`; `FigmaBox.adopt(root)` đọc lại và co theo bề rộng thật. Muốn dời node Home hay hub thì sửa meta đó, kéo node trong editor không có tác dụng lúc chạy.
- `scenes/main.tscn` có `Background` (instance `scenes/background.tscn`) và `PopupLayer`.
- `main.go()` giữa Shop, Home, Road Trip trượt màn (`docs/UI_FIGMA.md`, mục chuyển tab): màn cũ còn trong cây thêm 0.33 s rồi mới bị xoá. `HubTop`, `HubNav` của màn được ghim tại chỗ, nên mỗi màn phải có đúng script đó trên thanh của mình (tìm theo script).
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
- Scene không được lưu tên tự sinh `@Class@N`. Godot đặt tên đó cho node thêm vào mà không có tên hoặc trùng tên anh em (hai `SmallPack` của prefab Unity). Số N lấy từ một bộ đếm chung của cả lần chạy, và Godot không kiểm tên mới có trùng với node đã nạp không. Khi bộ đếm chạm đúng N lúc thêm node vào cùng cha, cha mất dấu node đã lưu. Cha bị free thì node đó vẫn sống với con trỏ cha treo, rồi crash ở lần layout sau. Đây là crash signal 11 của `test_ui_shop` trước ngày 2026-11-08. `bake_screen.gd` và `bake_unity_ui.gd` gọi `UnityUI.readable_names` trước khi lưu, đổi `@Control@71` thành `Control_71`. `tests/test_scene_names.gd` báo lỗi khi scene nào còn tên bắt đầu bằng `@`. Sửa scene bằng tay thì cũng không đặt tên có `@`.
