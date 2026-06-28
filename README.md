# makeaudio

Turn a case-study PDF into a clean, narrated MP3 you can listen to on the go.

Built for Harvard Business School (HBS) style case PDFs: it extracts the text,
strips the page furniture (running headers, "For the exclusive use…" lines,
footnote numbers, exhibit tables, endnotes), and reads the **main narrative**
aloud with Microsoft Edge's neural text-to-speech voices.

## What it does

```
PDF ──pdftotext──> raw text ──clean_case.py──> clean script ──edge-tts──> MP3
```

1. **Extract** — `pdftotext -layout` pulls the text out of the PDF.
2. **Clean** — `clean_case.py` removes everything that reads badly aloud:
   - repeated page headers/footers (detected by the `NNN-NNN` document id)
   - `For the exclusive use…` / `This document is authorized…` boilerplate
   - bare page numbers and `REV:` lines
   - exhibit **tables** and the **endnotes/citations** section
   - inline footnote superscript numbers — while leaving decimals like
     `$42.3 billion` and `10.6%` untouched
   - rejoins wrapped lines back into flowing paragraphs
3. **Narrate** — `edge-tts` synthesizes the cleaned text to an MP3.

## Requirements

- [`edge-tts`](https://github.com/rany2/edge-tts) — `pip3 install edge-tts`
- `pdftotext` (from Poppler) — `brew install poppler`
- `python3` and `bash`

## Usage

```bash
make_audio.sh <Case.pdf> "<Spoken title>" ["<Start phrase>"] ["<Voice>"]
```

| Argument | Required | Notes |
|----------|----------|-------|
| `Case.pdf` | yes | Path to the source PDF. |
| `Spoken title` | yes | Read aloud first, e.g. the title + authors. |
| `Start phrase` | recommended | The first few words of the case body (e.g. `"Things were off to an"`). Narration starts here, skipping the cover/author block. Omit to keep everything after the boilerplate. |
| `Voice` | optional | An edge-tts voice. Default: `en-US-AndrewNeural`. |

Outputs land next to the PDF: `<Case>_raw.txt`, `<Case>_clean.txt`, `<Case>.mp3`.

### Examples

```bash
make_audio.sh Wendys.pdf \
  "Dynamic Pricing at Wendy's: Where's the Beef? An HBS case by Ofek, Dadlani, and Hostetter." \
  "Things were off to an"

make_audio.sh Meta.pdf \
  "Meta: Digital Marketing and AI at Facebook and Instagram." \
  "On April 30, 2025, Mark Zuckerberg" \
  en-US-AriaNeural
```

### Picking a voice

List the available voices:

```bash
edge-tts --list-voices | grep en-US
```

Good narration voices: `en-US-AndrewNeural` (default), `en-US-BrianNeural`,
`en-US-AriaNeural`, `en-US-EmmaNeural`.

## Alias

If you ran the included setup, `~/.zshrc` has:

```bash
alias makeaudio="$HOME/Code/makeaudio/make_audio.sh"
```

so you can just run `makeaudio Case.pdf "Title." "Start phrase"` from anywhere.

## Tuning the cleaner

`clean_case.py` is tuned for the common HBS layout. If a different publisher's
case leaves artifacts in `<Case>_clean.txt`, edit that file by hand before
re-running edge-tts on it, or adjust the regexes in `clean_case.py`. Always skim
`<Case>_clean.txt` once — it's the exact script that gets read aloud.

## Notes

- Long cases produce long audio (a ~5,000-word case ≈ 35–45 minutes).
- `edge-tts` requires an internet connection (it uses Microsoft's online TTS).
