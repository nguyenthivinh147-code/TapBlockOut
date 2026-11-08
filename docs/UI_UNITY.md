# UI theo prefab Unity của color-cube-match-puzzle

Mọi màn trừ bàn chơi, HUD trong level và Home dựng theo cách setup UI của `E:/PROJECT HORUS/color-cube-match-puzzle` (Unity). Gồm bố cục, sprite, chữ TMP, nút và animation. Logic, luồng màn và nội dung chữ vẫn là của game này.

## Dữ liệu

- `tools/unity_ui_export.mjs` đọc prefab trong `Assets/_Game/Prefabs/Layers`, `Assets/_Game/Layer/Prefab`, `Assets/_Game/Prefabs/UI`, `Assets/_Game/Prefabs/Components`. Prefab lồng được trải phẳng kèm override. Không xuất `MainMenuUILayer`, `GamePlayUILayer`, `BannerAds`, `IngameAdsBar`.
- Component dựng sẵn có khoá riêng trong node: `img` (Image, CutoutMaskUI thêm `cut`), `txt`, `btn`/`tog`, `lay`, `fit`, `mask`, `scroll`, `slider`, `input` (TMP_InputField). Script khác nằm trong `cs`.
- Kết quả:
  - `data/ui_unity/<Prefab>.json`: cây node.
  - `_sprites.json`: sprite → texture, vùng cắt, viền 9-slice, ppu.
  - `_materials.json`: material TMP.
  - `_anims.json`: clip mặc định của Animator.
  - `_assets.json`: ScriptableObject nhỏ, ví dụ `RewardItemSO`, `VersionDataSO`.
- Texture copy sang `assets/ui/cc/`. File `.import` mang `process/size_limit` bằng cỡ tối đa Android mà Unity đặt (ví dụ `light1.png` 256), nên trên máy thật ảnh có cùng độ phân giải với Unity.
- Chạy lại: `node tools/unity_ui_export.mjs`, rồi `tools/godot.sh --headless --path . -s res://tools/compress_textures.gd` (ảnh lớn sang WebP lossy, kế hoạch mục 1.3), rồi để editor tự import (hoặc `--import` khi editor đóng). Không sửa tay file trong `data/ui_unity/` và `assets/ui/cc/`.
- Mỗi layout được bake thành scene node `scenes/unity/<Prefab>.tscn` (`tools/bake_unity_ui.gd`); game dựng từ scene này, không từ JSON. Bake lại sau mỗi lần xuất (ghi đè chỉnh sửa trong editor). Xem `docs/UI_NODES.md`.
- Xem cây một prefab: `node tools/unity_ui_tree.mjs PopupOkLayer --all` in đường dẫn UView, anchor, kích thước, sprite, chữ, script và field.
- Bảng sprite có nhãn: `tools/godot.sh --path . --resolution 1600x1600 -s res://tools/unity_sprite_sheet.gd -- --filter=Maincenter`, ảnh ra `tests/shots/sprites.png`.

## Tỉ lệ co và đơn vị

- `UnityUI.build()` dùng node `Canvas` của layer (có sẵn trong scene màn, hoặc instance `scenes/unity/<Prefab>.tscn`), co theo `CustomCanvasScaler`: reference 886×1920; khớp chiều cao khi rộng/cao > 0.45, ngược lại khớp chiều rộng. Ở 720×1280, 1 đơn vị Unity bằng 0.667 px; ở 720×1560, bằng 0.8125 px.
- Mọi số trong code (vị trí, kích thước, cỡ chữ, viền) là đơn vị Unity, đọc thẳng từ prefab.
- RectTransform chuyển sang anchor/offset của Godot (`UnityUI.apply_rect`, meta `u_rect`). Pivot dùng `pivot_offset_ratio`.

## Builder (`src/ui/unity_ui.gd`)

- Image (`u_image.gd`): Simple, Sliced (viền theo ppu và `pixelsPerUnitMultiplier`, tự co khi rect nhỏ hơn viền), Tiled, Filled ngang/dọc, preserveAspect theo pivot. Image tắt component thì không vẽ, con vẫn hiện.
- TextMeshPro: Label dùng `assets/fonts/baloo.res` (`tools/gen_baloo_font.gd`: atlas TMP chỉ giữ glyph dùng, fallback Baloo 2, Jua và M PLUS subset theo kế hoạch mục 1.3) với shader `tmp_text.gdshader`. Shader chép công thức face, outline, underlay của TMP Distance Field theo material trong `_materials.json`. Builder còn mô phỏng:
  - `normalSpacingOffset` -2, `characterSpacing`, `lineSpacing`;
  - auto size (`fit_text`), chữ hoa (`fontStyle` 16);
  - căn lề, margin, overflow tràn theo hướng căn.
- Button/Toggle (`u_button.gd`):
  - Tint theo `ColorTint` lên target graphic.
  - `UIHoldAnim_Pulse` (phóng khi giữ), `PressEffect`.
  - Âm thanh `Sfx.play("button")` khi prefab có `AudioUIController`; rung `Game.haptic(20)` khi có `ClickVibrationEffect`.
  - Hình nút đúng cỡ prefab, vùng chạm nới tới 96 px viewport (`hit_size()`).
  - Nút X đóng popup (tên prefab trong `UnityUI.CLOSE_NAMES`, đọc từ meta `u` nên code đổi tên node vẫn khớp): lúc nối (`_wire`, không chạy khi bake), `_grow_close` phóng nút và hình prefab bên trong `Config.CLOSE_ART_SCALE` lần quanh tâm nút. Vùng chạm là `CLOSE_HIT_SCALE` lần vùng chạm cũ (`UButton.art_scale`, `hit_scale`). Meta `u_close` đánh dấu nút đã phóng (bản chép giữ meta, nên không phóng hai lần). Sau khi popup xếp xong, `_keep_on_canvas` dịch X vào trong canvas, cách mép `CLOSE_EDGE_GAP`. Scene vẫn lưu cỡ prefab.
  - Code màn nghe tín hiệu `clicked`. Test vẫn dùng `pressed.emit()`; `clicked` bỏ qua cú bấm đã bị ScrollRect kéo.
  - Toggle có `ToggleGroup` (ButtonGroup) và `ToggleAnimator`.
- Layout: `HorizontalLayoutGroup`, `VerticalLayoutGroup`, `GridLayoutGroup`, `LayoutElement`, `ContentSizeFitter` chạy như Unity khi `build()` và khi gọi `relayout()`. Con của layout group lưu ở 0,0 trong prefab, Unity xếp lúc chạy.
- Auto size đo cỡ preferred (ContentSizeFitter, layout group điều khiển cỡ con) ở `fontSizeMax` như `TMP_Text.GetPreferredWidth`, rồi `fit_text` co chữ trong rect đó.
- Chữ trên nút luôn best fit, gọn trong khung nút (`fit_text`):
  - Áp cho nhãn TMP nằm trong `UButton`, trừ nút phủ từ 90% rộng và 50% cao canvas trở lên (dim, "chạm để tiếp tục"): chữ trong đó là nội dung popup.
  - Prefab không bật auto size thì dùng khoảng [18, `fontSize`]. Chữ loại này được tràn rect theo chiều dọc như TMP, chỉ khung giới hạn chiều cao (giá cạnh icon gold có rect thấp hơn chữ).
  - Khung là Image có hình gần nhất phía trên nhãn chứa tâm nhãn (pill giá, huy hiệu "+5"); không có thì là chính nút. Vùng tính theo phần hình thực vẽ (`UImage.drawn_rect()`): sprite Simple bật `preserveAspect` trên nút bị kéo rộng vẫn giữ hình gốc.
  - Chữ chỉ được nằm trong `ThemeKit.button_text_area` của khung: mỗi bên bớt min(0.3 × cao, 0.12 × rộng) (`BUTTON_TEXT_INSET_H`, `BUTTON_TEXT_INSET_W`) để chữ và viền chữ không chạm đầu bo tròn. Phần rect nhãn vượt vùng này thành lề thêm của nhãn (meta `u_inset`), chỉ ở phía vượt, nên chữ cạnh icon (nút video) không mất chỗ phía icon.
  - Nhãn mà cả nó lẫn nhóm chứa nó (hàng icon + giá) không cắt qua giữa khung, như số đếm ở góc, giữ nguyên.
  - Fit không ngắt giữa từ: chữ co tới khi từ dài nhất vừa một dòng. Nhãn một dòng mà ở cỡ tối thiểu vẫn không vừa thì được xuống dòng giữa các từ (meta `u_wrapped`, lần fit sau trả về một dòng rồi xét lại).
- Dim của popup: Image đen, không sprite, không material, chặn raycast, phủ kín cha (anchor 0..1, offset 0) lấy alpha `ThemeKit.POPUP_DIM_ALPHA` (85%) thay cho alpha trong prefab, để mọi popup cùng độ tối. Popup dựng tay (`PopupKit`, `StubUI`) dùng `ThemeKit.SCRIM` cùng alpha đó.
- Mask: `clip_children`. RectMask2D: `clip_contents`. CanvasGroup: alpha bằng `modulate.a`; `blocksRaycasts` và `interactable` áp xuống cây con.
- CutoutMaskUI (Image có stencil NotEqual, chỉ vẽ ngoài hình của Mask cha): Mask cha thôi `clip_children`, graphic của nó ẩn khi `showMaskGraphic` tắt, shader `cutout_mask.gdshader` khoét sprite của Mask khỏi ảnh. Mask có cả con thường lẫn CutoutMaskUI thì con thường không bị cắt (có cảnh báo).
- ScrollRect (`u_scroll.gd`): kéo, đàn hồi (`SmoothDamp`), quán tính (`decelerationRate`). Nút trong content đổi sang `MOUSE_FILTER_PASS` để kéo được.
- Slider: `Slider.UpdateVisuals` theo `direction`, `min`/`max`, `wholeNumbers`. Fill kiểu Filled nhận `fillAmount`, fill thường nhận anchor; handle đặt anchor tại giá trị. Lúc build áp giá trị lưu trong prefab.
- TMP_InputField: LineEdit (một dòng) hoặc TextEdit (nhiều dòng) phủ Text Area, dùng font, cỡ, màu, căn lề và material TMP của nhãn Text. Lấy `characterLimit`, màu caret, màu chọn, nhịp nháy, `readOnly` từ prefab. Placeholder hiện khi ô trống.
- Animation:
  - `DialogueReveal` và `ShowPopupAnimation`: panel phóng 0→1, dim mờ dần vào, 0.4s OutBack. Tự chạy khi build.
  - `UIAnim_ScaleAppear`, `UIAnim_Pulse`, `UIAnimationGroup`, `SimpleUIRotator`, `UIAnimScale`, `AnimScaleButton` (`PlayAnim`/`StopAnim`).
  - Persistent call chạy khi build như `UICoreLayer.SetShow`: `OnDisplayLayout` trước, `OnShowLayer` sau. Hỗ trợ `PlayAnimation`, `PlayAnim`, `StopAnim`, `PlayAllAnimationsSync`, `SetActive`, `set_enabled` (Animator, hoặc chữ).
  - Animator (`u_anim.gd`): clip mặc định, đường cong Hermite như `AnimationCurve`. Animator tắt sẵn trong prefab vẫn được dựng nhưng chưa chạy, cho tới khi `enabled = true`.
  - Anim thêm của game, không có trong prefab (`src/ui/ui_motion.gd`, node con `Motion` có meta `u_rt`). `adopt` tự gắn theo sprite node vẽ, không gắn khi bake:
    - Tia sáng, quầng sáng (`fx_1`, `light1`) phập phồng: scale 1 → 1.1 → 1, chu kỳ 1.4 s, sine. Vẫn xoay theo `SimpleUIRotator`.
    - Icon video ads (TV `Resources_moved_UI_Maincenter:UI_Maincenter_5`, clapper `Resources_UI_Maincenter:UI_Maincenter_7`) nhảy rung theo nhịp 2 s: nhún, bật lên 15% chiều cao, co giãn khi tiếp đất, lắc ±12° ba lần rồi đứng yên. Lần đầu sau 0.5 s, chờ popup hiện xong. `Resources_moved_UI_Maincenter:UI_Maincenter_7` là đồng hồ, không nhảy.
    - Icon `art_lose` trong khung thẻ thua (`lose_card` thay tranh `Popup_Lose` của prefab, tự gắn `UiMotion.SOB`) nấc như đang khóc theo nhịp 1.8 s: 0.9 s đầu kéo dài lên trên 3 lần (cao thêm tới 6%, hẹp lại một nửa mức đó, mỗi lần yếu đi 15%), phần còn lại đứng yên. Chân (80% chiều cao icon, y 408 của ảnh 512) giữ nguyên chỗ nên icon không dời, không co xuống, không nghiêng. Lần đầu sau 0.3 s.
    - Giọt nước mắt là node `Tear` riêng (ảnh `art_lose_tear`, con của icon nên nhấp nhô theo; `tools/split_tear.gd` tách nó khỏi `art_lose`), `UiMotion.TEAR` cùng nhịp với tiếng nấc: ứa ra dưới mi mắt (0.35 s, từ 30% cỡ, hiện dần), đọng tới 0.55 s, chảy xuống má 2.2 lần chiều cao giọt (nhanh dần, dài ra tới 18%), mờ dần từ 1.3 s, tắt hẳn ở 1.55 s, ẩn tới tiếng nấc sau. Motion này giữ alpha của node.
    - Shop (`src/ui/shop_fx.gd`, node `ShopFx` con cuối của màn, gắn thêm ba kiểu motion dưới đây). `attach(c, kind, delay)` lùi vòng đầu `delay` giây nên các node cùng kiểu chạy lệch nhau, lan từ trên xuống:
      - `FLOAT`: icon gold của các ô (`BG/Icon`, cả ô ADS Daily) nổi lên 5% chiều cao rồi về chỗ cũ, chu kỳ 2.4 s, không chìm dưới chỗ cũ. Ô sau trễ 0.3 s.
      - `WOBBLE`: nhãn `SellBadge` (-50%) lắc mỗi 2.6 s: 0.6 s đầu nghiêng 2.5 lượt (tới 12°, nhỏ dần) và phồng tới 10%, rồi đứng yên. Nhãn sau trễ 0.15 s.
      - `SHINE`: vệt sáng xiên (`src/ui/shine.gdshader`, gắn làm material của node) quét qua nút mua (`Button_Purchase`, `Button_Ads`, phần `image`) và nền gói gold lớn trong 0.65 s, mỗi 3.2 s. Node đã có material riêng thì giữ nguyên, không loé. Nút đang khoá (đã sở hữu, đang mua, hết video) không loé; host là chính nút (nút Chơi ở Home) thì xét nút đó. Nút sau trễ 0.12 s.
      - Vòng đầu của cả ba bắt đầu sau 0.7 s, lúc các thẻ đã hiện xong.
    - Motion cộng lên vị trí, scale, góc của chính node. Giá trị do nơi khác ghi (layout, xoay, reveal, nhún nút) thành gốc mới nên không trôi. Node ẩn thì dừng và trả về gốc.
  - Đóng popup thì ẩn ngay, như `HideLastStackLayer`.
- SafeAreaUIAdjuster: anchor theo `DisplayServer.get_display_safe_area()`.
- `build()` nhiều lần vào cùng một owner được: mọi canvas của owner co lại khi owner đổi cỡ.
- Chưa hỗ trợ: Animator nhiều state, ShinyEffect, UIParticle, CurvedTextMeshPro (script hỏng trong Unity, không có hiệu ứng), rich text TMP, kéo Slider bằng tay.

## API cho màn

```gdscript
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

ui = UnityUI.build(self, "PopupOkLayer")              # reveal tự chạy; {"reveal": false} để tắt
ui.text("Panel/Image/txtHeader", tr("ads_notice_title")) # đặt chữ, chạy lại auto size
ui.on_click("Panel/Content/Button/Ok", _send.bind("ok"))
ui.show("Panel/Content/Button/Cancel", false)
ui.sprite("Panel/Image", "Resources_moved_UI_Maincenter:UI_Maincenter_60")
ui.texture("Panel/Icon", ThemeKit.icon("booster_hint"))  # texture của game vào một Image
for b in ui.field("closeButtons", "PopupOkUICoreLayer"):   # node theo field script Unity
	b.connect("clicked", _send.bind("close"))
var item = ui.clone("Panel/Content/ItemReward")          # bản sao item mẫu (pool), trả UView con
item.text("Quantity", "40")
ui.relayout("Panel")                                     # chạy lại layout group và fitter
ui.slider("Slider", 0.5)                                 # Slider.value; node rời: UnityUI.set_slider(node, v)
var name_edit := ui.input(INPUT) as LineEdit             # ô nhập của TMP_InputField
ui.input_text(INPUT, "Mia")                              # đặt chữ, placeholder theo; ô rời: UnityUI.set_input_text(e, s)
UnityUI.input_field(ui, ui.node(INPUT), true)            # đổi sang TextEdit nhiều dòng
ui.animator("GameObject/Step1").enabled = true           # bật Animator prefab để tắt sẵn
ui.stop("Panel/WinPanel/BG/GameObject/FreeBtn")          # StopAnim (AnimScaleButton)
```

- Đường dẫn là tên GameObject tính từ gốc layer. Anh em trùng tên dùng `Ten#2`. `ui.find(name)` tìm theo tên ở mọi cấp. `ui.node("")` là gốc layer.
- Màn stub (`extends stub_ui.gd`) ghi đè `_build()`, gán `ui = UnityUI.build(...)` để tắt "chạm đâu cũng đóng" của lớp nền. Phát kết quả bằng `_send(action)`, vì nút prefab đã tự phát âm thanh.
- Test tìm node theo tên (`ClaimButton`, `LeagueCard`…): đặt lại `node.name` cho node tương ứng sau khi build.

## Màn không có prefab

Dùng `UnityKit`. Mỗi mảnh là bản sao node thật của `PopupOkLayer`:

- `UnityKit.popup(owner, title, Vector2(w, h), on_close)`: dim, khung `Popup2`, mũ tiêu đề, nút X. Nội dung đặt vào `v.node("Panel/Content")`.
- `UnityKit.button(parent, "green", text, Rect2(x, y, 280, 120), cb)`. Màu: `green`, `blue`, `cyan`, `red`, `yellow`, `purple`, `gray`.
- `UnityKit.gold_price(btn, price)`: biến nút thành nút mua bằng gold (xem quy tắc dưới). `gold_pill(btn)`, `gold_coin(img)` chỉ đổi sprite khi nút đã có sẵn icon và giá.
- `UnityKit.label(parent, text, rect, 40)`: chữ thân xanh mực `1C4A83`. Chữ trắng viền đen dùng `mat = "Baloo Outline - Black"`.
- `UnityKit.well(parent, rect)`: ô kem `UI_Maincenter_68`.
- `UnityKit.sprite(parent, key, rect, tex)`: ảnh giữ tỉ lệ.
- `UnityKit.spec(layer, path)` + `UnityKit.add(parent, spec, rect)`: lấy bất kỳ node nào của prefab khác (ô thưởng, hàng bảng xếp hạng…) rồi sửa chỗ cần.
- Rect tính từ góc trên trái của parent, đơn vị Unity. Khoảng cách và cỡ lấy theo các prefab gần nhất, không tự đặt số mới khi prefab đã có.

Sprite hay dùng (`m:` là `Resources_moved_UI_Maincenter:`):

| Sprite | Dùng cho |
|---|---|
| `Popup2` | Khung popup tím, sliced |
| `m:UI_Maincenter_60` | Mũ tiêu đề tím |
| `m:UI_Maincenter_20` | Nút X đỏ 64×64 |
| `m:UI_Maincenter_68` | Ô nội dung kem, sliced |
| `m:UI_Maincenter_48/51/52/49/50/79/74` | Nút pill xanh lá, xanh dương, cyan, đỏ, vàng, tím, xám |
| `m:UI_Maincenter_3` | Icon gold (RewardItemSO) |
| `m:UI_Maincenter_5` | TV video |
| `m:UI_Maincenter_13/15/16` | No Ads, tim, tim vô hạn |

## Ánh xạ màn ↔ prefab

| Màn Godot | Prefab |
|---|---|
| `popup_notice` | `PopupOkLayer` |
| `popup_reward` | `PopupRewardLayer` |
| `popup_update` | `CheckUpdateLayer` |
| `download_data`, `splash` | `DownloadDataLayer`; `Loadingscreen` và `CandySort_logo` thay bằng `assets/ui/loading_bg.png` (9:16) và `assets/ui/loading_logo.png` (tên game có sẵn trong logo); cả hai đặt theo khung boot splash (`Splash.boot_rect`, logo ở `Splash.LOGO_RECT` của ảnh), không theo rect prefab của `LogoGame` |
| `select_account` | `SelectAccountLayer` |
| `popup_no_internet` | `MaintainInternetLayer` |
| `tutorial_intro` | `MainTutorialLayer` |
| `popup_mechanic` | `MechanicTutorialLayer` |
| `booster_unlocked`, `booster_soon` | `BoosterTutorialLayer` |
| `speedup_tutorial` | `SpeedUpTutorialLayer` |
| `load_transition` | `LoadLevelProcessVer2` |
| `popup_help` | `PopupFeedBack` |
| `popup_change_name` | `PopupEditNameLayer` |
| `popup_rate` | `PopupRatingLayer` |
| `popup_keep_playing` | `PopupKeepPlaying` |
| `popup_rescue` | `PopupReviveLayer` |
| `win_card`, `lose_card` | `EndGameUILayer` (`WinPanel`, `LossPanel`) |
| Dải cảnh báo độ khó trong level | `WarningHardLevelLayer` |
| `popup_ingame_settings` | `SettingInGameLayer` |
| `settings` | `SettingMainMenuLayer` |
| `popup_language` | `SettingLanguage` |
| `profile` | `ProfileLayer` |
| `shop` | `ShopCashLayer`; nền `BG (2)` ẩn, thay bằng node `Background` ở gốc màn với `assets/bg/bg_shop.png` (theme kẹo, 2026-11-08: sọc kẹo chéo hồng và tím nhạt như giấy gói quà, rắc cốm thưa, giữa sáng `#FEE8FD`, viền tối dần về tím `#E1B4E9`; chọn phương án 4 trong 5 phương án `art/concepts/bg_shop_v2/`; vẽ đủ màu, không phủ `self_modulate`; kéo giãn phủ kín màn). Nền cũ là dải xanh Figma node `22:16980` (`assets/ui/figma/bg_shop.png`, không còn dùng) |
| `no_lives` | `PopupMoreHeartLayer` |
| `popup_heart_bundle` | `PopupBundleHeart` |
| `popup_helper_pack`, `popup_heart_support` | `SupportPackLayer` |
| `popup_offer` | `PopupOfferLayer`, `PopupStarterPack`, `PopupSpecialPack`, `PopupFlashPack` |
| `chain_offer` | `PopupChainOffer`; mũi tên `UIRay` xoay 180° lúc dựng: prefab cho chúng chỉ ngược về `ChainOfferPack` (chiều các ô trượt), còn ở đây chuỗi đi xuôi từ `ChainOfferPack` (đã nhận → nhận được → khoá) nên mũi tên chỉ sang bước kế. Prefab luôn để bước hiện tại ở `ChainOfferPack (1)` (nền vàng `UI_Shop_Packs_Atlas_9`); ở đây cửa sổ đứng yên nên nền vàng đi theo ô nhận được, các ô khác nền hồng `UI_Shop_Packs_Atlas_8`. Ảnh tiêu đề `Panel/Top/Image` đổi lúc dựng từ `ic_EndlessTreasure` sang `assets/ui/art_chain_offer.png`: cùng rương vàng, ba booster của game Unity (nam châm, mũi tên, thẻ khối) thay bằng hint, move, smash của game (`tools/compose_chain_offer_art.py`, chạy lại khi đổi icon booster; file trong `assets/ui/cc/` giữ nguyên) |
| `popup_remove_ads` | `PopupRemoveAds` |
| `popup_ads_daily` | `DailyRewardAdLayer` |
| `leaderboard` | `LeaderboardLayer` |
| `popup_lb_howto` | `LeaderboardDescriptionLayer` |
| `popup_lb_result` | `LeaderboardWeeklyResultLayer` |
| `popup_streak_intro` | `PopupWinStreakInstruction` |
| `streak_main` | `PopupWinStreakMain` |
| `popup_streak_rewards` | `PopupWinStreakInfo` |
| `popup_streak_end` | `PopupWinStreakEnd` |
| `popup_streak_keep` | `PopupKeepPlayingWinstreak` |
| `ad_loading`, `popup_free_pick`, `popup_bonus`, `popup_daily`, `shop_mini`, `weekly_pass`, `popup_weekly_tutorial`, `popup_weekly_upsell`, `challenge`, `popup_leagues`, `popup_lb_player` | Không có prefab: `UnityKit` |

Home, `level` (bàn chơi, HUD) và thanh trên/dưới dùng chung (`hub_top.gd`, `hub_nav.gd`) giữ nguyên.

## Quy tắc khi nối màn

- Bố cục lấy từ prefab. Nội dung (chữ qua `tr()`, số, icon vật phẩm của game, các nút hành động) là của game. Mục game có mà prefab không có thì dựng bằng bản sao node của prefab (`UnityKit.spec`), đặt theo nhịp của prefab. Mục prefab có mà game không có thì ẩn.
- Không dùng sprite có chữ in sẵn. Ribbon tiêu đề trong prefab là ảnh trơn, chữ do TMP vẽ.
- Mọi nút mua bằng gold (cứu lượt, nạp mạng, mua booster, booster mới, gói trợ giúp, avatar và frame) dùng pill vàng `pill_yellow` và icon `big_coin` của `assets/ui/figma/atlas_main.png`, chỉ có icon gold rồi đến giá, không chữ "Mua"; hàng icon + giá là `Price` của `GoldBtn` trong `PopupReviveLayer`. Thiếu gold thì nút vẫn vàng: popup cứu lượt ghi dòng thiếu gold, hộp mua booster làm mờ nút (alpha 0.6) như nút gold của `no_lives`. Huy hiệu "+N tim" trên nút nạp mạng giữ nguyên.
- Giữ signal, `setup()`, hành vi và tên node mà test dùng.
