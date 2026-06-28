#!/usr/bin/env bash
#
# make_audio.sh — turn a case-study PDF or a webpage into a narrated MP3 with edge-tts.
#
# PDF mode:
#   make_audio.sh <Case.pdf> "<Spoken title>" ["<Start phrase>"] ["<Voice>"]
# Web mode (first arg is an http(s) URL):
#   make_audio.sh <URL> ["<Output name or title override>"] ["<Voice>"]
#
# Examples:
#   make_audio.sh Wendys.pdf \
#     "Dynamic Pricing at Wendy's. An HBS case by Ofek, Dadlani, and Hostetter." \
#     "Things were off to an"
#   make_audio.sh https://example.com/some-article
#   make_audio.sh https://example.com/some-article "my-article" en-US-AriaNeural
#
# Output: <name>_raw.txt (PDF only), <name>_clean.txt, <name>.mp3
#   - PDF mode writes next to the PDF; web mode writes to the current directory.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage:" >&2
  echo "  make_audio.sh <Case.pdf> \"<Spoken title>\" [\"<Start phrase>\"] [\"<Voice>\"]" >&2
  echo "  make_audio.sh <URL> [\"<Output name or title override>\"] [\"<Voice>\"]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Narration speed passed to edge-tts (e.g. +5% = 5% faster). Override with MAKEAUDIO_RATE.
RATE="${MAKEAUDIO_RATE:-+5%}"

for tool in python3 edge-tts; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: '$tool' not found in PATH" >&2; exit 1; }
done

# ---------------------------------------------------------------- web mode ----
if [[ "$1" =~ ^https?:// ]]; then
  URL="$1"
  NAME_OR_TITLE="${2:-}"
  VOICE="${3:-en-US-AndrewNeural}"

  # Decide an output basename: explicit arg (slugified) > last URL path segment > host.
  if [[ -n "$NAME_OR_TITLE" ]]; then
    base="$(printf '%s' "$NAME_OR_TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-60)"
  else
    seg="${URL%%\?*}"; seg="${seg%/}"; seg="${seg##*/}"
    base="$(printf '%s' "$seg" | sed -E 's/\.[a-z]+$//; s/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-60)"
  fi
  [[ -z "$base" ]] && base="webpage"

  clean="$PWD/${base}_clean.txt"
  out="$PWD/${base}.mp3"

  # Pass a title override only if the arg doesn't look like a slug/filename.
  title_arg=()
  [[ "$NAME_OR_TITLE" == *" "* ]] && title_arg=("$NAME_OR_TITLE")

  echo "==> Fetching and extracting article from $URL"
  python3 "$SCRIPT_DIR/clean_web.py" "$URL" "$clean" ${title_arg[@]+"${title_arg[@]}"}

  echo "==> Synthesizing speech (voice: $VOICE, rate: $RATE)"
  edge-tts --file "$clean" --voice "$VOICE" --rate "$RATE" --write-media "$out"

  echo "==> Done: $out"
  command -v afinfo >/dev/null 2>&1 && afinfo "$out" 2>/dev/null | grep -i "estimated duration" || true
  exit 0
fi

# -------------------------------------------------------------- Word doc mode -
if [[ "$1" == *.docx || "$1" == *.doc ]]; then
  command -v textutil >/dev/null 2>&1 || { echo "error: 'textutil' not found (macOS only)" >&2; exit 1; }
  DOC="$1"
  TITLE="${2:-}"
  VOICE="${3:-en-US-AndrewNeural}"
  [[ -f "$DOC" ]] || { echo "error: doc not found: $DOC" >&2; exit 1; }

  dir="$(cd "$(dirname "$DOC")" && pwd)"
  base="$(basename "$DOC")"; base="${base%.*}"
  raw="$dir/${base}_raw.txt"
  clean="$dir/${base}_clean.txt"
  out="$dir/${base}.mp3"

  echo "==> Extracting text from $DOC"
  textutil -convert txt "$DOC" -output "$raw"

  echo "==> Cleaning text"
  title_arg=(); [[ -n "$TITLE" ]] && title_arg=("$TITLE")
  python3 "$SCRIPT_DIR/clean_doc.py" "$raw" "$clean" ${title_arg[@]+"${title_arg[@]}"}

  echo "==> Synthesizing speech (voice: $VOICE, rate: $RATE)"
  edge-tts --file "$clean" --voice "$VOICE" --rate "$RATE" --write-media "$out"

  echo "==> Done: $out"
  command -v afinfo >/dev/null 2>&1 && afinfo "$out" 2>/dev/null | grep -i "estimated duration" || true
  exit 0
fi

# ---------------------------------------------------------------- PDF mode ----
if [[ $# -lt 2 ]]; then
  echo "usage: make_audio.sh <Case.pdf> \"<Spoken title>\" [\"<Start phrase>\"] [\"<Voice>\"]" >&2
  exit 1
fi

command -v pdftotext >/dev/null 2>&1 || { echo "error: 'pdftotext' not found in PATH" >&2; exit 1; }

PDF="$1"
TITLE="$2"
START="${3:-}"
VOICE="${4:-en-US-AndrewNeural}"

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

echo "==> Synthesizing speech (voice: $VOICE, rate: $RATE)"
edge-tts --file "$clean" --voice "$VOICE" --rate "$RATE" --write-media "$out"

echo "==> Done: $out"
command -v afinfo >/dev/null 2>&1 && afinfo "$out" 2>/dev/null | grep -i "estimated duration" || true
