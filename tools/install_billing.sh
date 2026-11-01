#!/usr/bin/env bash
# Cài plugin Godot Google Play Billing vào addons/GodotGooglePlayBilling/.
# Nguồn duy nhất: GitHub Releases của godot-sdk-integrations/godot-google-play-billing.
# Idempotent: đã cài đúng phiên bản thì không làm gì (thêm --force để cài lại).
# Cần: curl, python3, sha256sum.
set -euo pipefail

TAG="3.3.0"
# sha256 của godot-google-play-billing.zip, lấy từ trường "digest" của GitHub Releases API.
ZIP_SHA256="20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568"
URL="https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/${TAG}/godot-google-play-billing.zip"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/addons/GodotGooglePlayBilling"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ $FORCE -eq 0 && -f "$DEST/plugin.cfg" && -f "$DEST/BillingClient.gd" \
      && -f "$DEST/bin/release/GodotGooglePlayBilling-release.aar" \
      && -f "$DEST/bin/debug/GodotGooglePlayBilling-debug.aar" ]] \
   && grep -q "^version=\"${TAG}\"" "$DEST/plugin.cfg"; then
	echo "GodotGooglePlayBilling ${TAG} đã cài, bỏ qua (dùng --force để cài lại)."
	exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Tải ${URL}"
curl -fsSL --retry 3 -o "$TMP/billing.zip" "$URL"

ACTUAL="$(sha256sum "$TMP/billing.zip" | cut -d' ' -f1)"
if [[ "$ACTUAL" != "$ZIP_SHA256" ]]; then
	echo "LỖI: sha256 không khớp. Mong đợi $ZIP_SHA256, nhận $ACTUAL" >&2
	exit 1
fi
echo "sha256 khớp: $ACTUAL"

mkdir -p "$TMP/x"
python3 -I - "$TMP/billing.zip" "$TMP/x" <<'PY'
import sys, zipfile, os
zf, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(zf) as z:
    for n in z.namelist():
        # chặn đường dẫn thoát khỏi thư mục giải nén
        p = os.path.normpath(os.path.join(out, n))
        if not p.startswith(os.path.abspath(out) + os.sep):
            sys.exit("đường dẫn không an toàn trong zip: " + n)
    z.extractall(out)
PY

[[ -f "$TMP/x/GodotGooglePlayBilling/plugin.cfg" ]] || { echo "LỖI: zip thiếu plugin.cfg" >&2; exit 1; }

mkdir -p "$ROOT/addons"
rm -rf "$DEST"
cp -r "$TMP/x/GodotGooglePlayBilling" "$DEST"
echo "Đã cài GodotGooglePlayBilling ${TAG} vào addons/GodotGooglePlayBilling/"
