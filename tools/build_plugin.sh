#!/usr/bin/env bash
# Build plugin Android tbo_platform (Kotlin) va chep AAR vao addons/tbo_platform/bin/.
# Dung: tools/build_plugin.sh [debug|release|all]   (mac dinh all)
# Bien moi truong: JAVA_HOME (JDK 17+), ANDROID_HOME hoac ANDROID_SDK_ROOT.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/android/plugins/tbo_platform"
BIN="$ROOT/addons/tbo_platform/bin"
MODE="${1:-all}"

if [[ -z "${JAVA_HOME:-}" && -d /usr/lib/jvm/java-21-openjdk-amd64 ]]; then
	export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
fi
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
if [[ ! -d "$ANDROID_HOME/platforms/android-36" ]]; then
	echo "Thieu platforms;android-36 trong $ANDROID_HOME (sdkmanager \"platforms;android-36\")" >&2
	exit 1
fi

case "$MODE" in
	debug) TASKS=(assembleDebug) ;;
	release) TASKS=(assembleRelease) ;;
	all) TASKS=(assembleDebug assembleRelease) ;;
	*) echo "Dung: $0 [debug|release|all]" >&2; exit 2 ;;
esac

cd "$PLUGIN"
./gradlew --no-daemon -q "${TASKS[@]}"

mkdir -p "$BIN"
for variant in debug release; do
	src="$PLUGIN/build/outputs/aar/tbo_platform-$variant.aar"
	if [[ -f "$src" ]]; then
		cp "$src" "$BIN/tbo_platform-$variant.aar"
	fi
done
echo "OK: AAR o $BIN"
