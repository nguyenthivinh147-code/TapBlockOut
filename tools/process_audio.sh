#!/usr/bin/env bash
# Xu ly am thanh goc (art/audio/*.flac) thanh file dung trong game, chi dung GStreamer + Python chuan.
#   sfx_*.flac -> assets/sfx/<ten>.wav  (mono 44.1 kHz 16-bit, cat lang, can am luong, cat do dai toi da)
#   bgm_*.flac -> assets/music/<ten>.ogg (stereo, loop cat theo o nhip trong MUSIC, LUFS dich, Ogg Vorbis q~0.3)
# Dung: tools/process_audio.sh [ten ...]   (khong tham so thi xu ly het)
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=art/audio
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p assets/sfx assets/music

# do dai toi da (giay) cua hieu ung, theo design.md
declare -A MAXSEC=(
  [sfx_button]=0.2 [sfx_tap]=0.2 [sfx_exit]=0.4 [sfx_blocked]=0.3 [sfx_shatter]=0.7 [sfx_bump]=0.3
  [sfx_coin]=1.0 [sfx_hint]=1.0 [sfx_moves]=1.0 [sfx_smash]=1.0 [sfx_life_lost]=1.0
  [sfx_win]=3.0 [sfx_lose]=3.0 [sfx_clap]=3.0
)

# Music loops (docs/AUDIO_MUSIC.md): start=, len= (whole bars, starting on a downbeat) and xfade= in seconds of the
# source, lufs= target, shelf=<gain_db>@<hz> low shelf. A track missing here loops the whole file at -18 LUFS.
declare -A MUSIC=(
  [bgm_home]="start=15.261 len=67.19989 xfade=0.6 lufs=-18"
  [bgm_level]="start=53.986 len=84.00025 xfade=0.75 lufs=-20 shelf=-5@200"
)

decode() { # flac -> wav 16-bit stereo 44.1 kHz
  gst-launch-1.0 -q filesrc location="$1" ! flacparse ! flacdec ! audioconvert ! audioresample \
    ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! wavenc ! filesink location="$2"
}

encode_ogg() { # wav -> ogg vorbis
  gst-launch-1.0 -q filesrc location="$1" ! wavparse ! audioconvert ! audioresample \
    ! vorbisenc quality=0.3 ! oggmux ! filesink location="$2"
}

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  for f in "$SRC"/*.flac; do names+=("$(basename "$f" .flac)"); done
fi

for n in "${names[@]}"; do
  in="$SRC/$n.flac"
  [ -f "$in" ] || { echo "thieu $in" >&2; continue; }
  decode "$in" "$TMP/$n.raw.wav"
  case "$n" in
    sfx_*)
      printf '%s ' "$n"
      python3 -I tools/process_audio.py sfx "$TMP/$n.raw.wav" "assets/sfx/$n.wav" "${MAXSEC[$n]:-1.0}"
      ;;
    bgm_*)
      printf '%s ' "$n"
      # shellcheck disable=SC2086 # options are separate words
      python3 -I tools/process_audio.py music "$TMP/$n.raw.wav" "$TMP/$n.loop.wav" ${MUSIC[$n]:-}
      encode_ogg "$TMP/$n.loop.wav" "assets/music/$n.ogg"
      ;;
    *) echo "bo qua $n" >&2 ;;
  esac
done
