#!/usr/bin/env bash
#
# make_audio.sh — turn a case-study PDF into a narrated MP3 with edge-tts.
#
# Usage:
#   make_audio.sh <Case.pdf> "<Spoken title>" ["<Start phrase>"] ["<Voice>"]
#
# Examples:
#   make_audio.sh Wendys.pdf \
#     "Dynamic Pricing at Wendy's. An HBS case by Ofek, Dadlani, and Hostetter." \
#     "Things were off to an"
#
#   make_audio.sh Meta.pdf "Meta: Digital Marketing and AI." "On April 30, 2025" en-US-AriaNeural
#
# Output (next to the PDF): <Case>_raw.txt, <Case>_clean.txt, <Case>.mp3
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: make_audio.sh <Case.pdf> \"<Spoken title>\" [\"<Start phrase>\"] [\"<Voice>\"]" >&2
  exit 1
fi

PDF="$1"
TITLE="$2"
START="${3:-}"
VOICE="${4:-en-US-AndrewNeural}"

# Resolve this script's directory so we can find clean_case.py beside it.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for tool in pdftotext python3 edge-tts; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: '$tool' not found in PATH" >&2; exit 1; }
done
[[ -f "$PDF" ]] || { echo "error: PDF not found: $PDF" >&2; exit 1; }

dir="$(cd "$(dirname "$PDF")" && pwd)"
base="$(basename "$PDF")"; base="${base%.*}"
raw="$dir/${base}_raw.txt"
clean="$dir/${base}_clean.txt"
out="$dir/${base}.mp3"

echo "==> Extracting text from $PDF"
pdftotext -layout "$PDF" "$raw"

echo "==> Cleaning text"
python3 "$SCRIPT_DIR/clean_case.py" "$raw" "$clean" "$TITLE" "$START"

echo "==> Synthesizing speech (voice: $VOICE)"
edge-tts --file "$clean" --voice "$VOICE" --write-media "$out"

echo "==> Done: $out"
command -v afinfo >/dev/null 2>&1 && afinfo "$out" 2>/dev/null | grep -i "estimated duration" || true
