# tbo_platform (addon)

Export plugin của Godot cho plugin Android Kotlin `TboPlatform` (mã ở `android/plugins/tbo_platform/`).

- Build AAR: `tools/build_plugin.sh` (ra `bin/tbo_platform-debug.aar` và `bin/tbo_platform-release.aar`).
- Bật addon: Project Settings > Plugins > TboPlatform (hoặc thêm `res://addons/tbo_platform/plugin.cfg` vào `editor_plugins/enabled` trong `project.godot`).
- Chỉ preset export có `gradle_build/use_gradle_build=true` nhận AAR và dependency; preset APK thường (Android Demo) không đổi.
- Lúc export, nếu `res://android_config.json` có `play_games_app_id` (số), addon thêm meta-data `com.google.android.gms.games.APP_ID` vào manifest và (khi có `android/build/`) ghi `android/build/res/values/tbo_platform.xml` chứa App ID.
- Mọi preset Android: lớp `DeflatedScenes` trong `plugin.gd` xuất mỗi scene `.tscn` thành binary `<đường_dẫn>.tscn.res` thay cho `.scn` của Godot, vì bộ export Android để `.scn` không nén trong APK. Cảnh UI trong APK giảm từ 2,6 MB còn 0,56 MB, tốc độ nạp như `.scn`. Addon phải bật thì mới có bước này.
- Lúc chạy game, `Engine.has_singleton("TboPlatform")` mới có plugin. Xem `android/plugins/tbo_platform/API.md`.
