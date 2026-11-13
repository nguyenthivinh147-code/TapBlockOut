#!/usr/bin/env bash
# Chọn test và kịch bản smoke cho thay đổi hiện tại (docs/TESTING.md mục "Chọn test theo thay đổi").
#   tools/affected.sh                     thay đổi so với HEAD: đã stage, chưa stage, file mới
#   tools/affected.sh main                so với merge-base với main, cộng phần chưa commit
#   tools/affected.sh --files a.gd b.gd:12-30   các file (và dòng) này thay cho git diff
#   tools/affected.sh --run               chạy luôn test (có đo độ phủ) rồi smoke headless; thoát 1 khi hàm đã sửa
#                                         chưa có test nào chạy tới (tests/untested_allow.txt miễn trừ)
#   tools/affected.sh -v | --json         in đủ lý do | dạng JSON
#   tools/affected.sh --check             kiểm tests/affected_map.txt
#   tools/affected.sh --coverage          đo test nào chạy qua hàm nào → output/coverage/map.json; có bản đo thì
#                                         chọn test theo nó (--static: theo đồ thị tĩnh)
# Mã thoát: 0; 1 (--check có lỗi, --run có test hay kịch bản đỏ); 2 hạ tầng hỏng.
cd "$(dirname "$0")/.." || exit 2
command -v node > /dev/null 2>&1 || { echo "tools/affected.sh cần Node (node --version)"; exit 2; }
exec node tools/affected.mjs "$@"
