# makeaudio

Turn a **case-study PDF** or a **webpage** into a clean, narrated MP3 you can
listen to on the go.

For HBS-style case PDFs it strips the page furniture (running headers, "For the
exclusive use…" lines, footnote numbers, exhibit tables, endnotes) and reads the
**main narrative**. For webpages it pulls just the **article body** (no nav, ads,
or comments). Both are narrated with Microsoft Edge's neural TTS voices.

## What it does

```
PDF ──pdftotext───> raw text ──clean_case.py──> clean script ─┐
URL ──trafilatura──> article  ──clean_web.py ──> clean script ─┴─edge-tts─> MP3
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
- [`trafilatura`](https://github.com/adbar/trafilatura) (webpage mode) — `pip3 install trafilatura lxml_html_clean`
- `pdftotext` (PDF mode, from Poppler) — `brew install poppler`
- `python3` and `bash`

## Usage

The first argument decides the mode: an `http(s)://` URL → **web mode**, anything
else → **PDF mode**.

### PDF mode

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

### Web mode

```bash
make_audio.sh <URL> ["<Output name or title override>"] ["<Voice>"]
```

| Argument | Required | Notes |
|----------|----------|-------|
| `URL` | yes | The article URL (`http(s)://…`). |
| `Output name / title` | optional | If it contains spaces it's read aloud as the title; otherwise it's used as the output filename. Omit to auto-derive both from the page. |
| `Voice` | optional | An edge-tts voice. Default: `en-US-AndrewNeural`. |

Outputs land in the **current directory**: `<name>_clean.txt`, `<name>.mp3`.
The title and byline are detected from the page automatically.

> **Tip:** Web mode reads the static HTML. Paywalled or JavaScript-only pages may
> extract little or nothing — save the page as HTML and pass the file path instead,
> or paste the text into a `.txt` and run `edge-tts --file file.txt --write-media out.mp3`.

### Examples

```bash
# PDF
make_audio.sh Wendys.pdf \
  "Dynamic Pricing at Wendy's: Where's the Beef? An HBS case by Ofek, Dadlani, and Hostetter." \
  "Things were off to an"

# Webpage — auto title + filename
make_audio.sh https://example.com/the-future-of-ai

# Webpage — custom filename and voice
make_audio.sh https://example.com/the-future-of-ai future-of-ai en-US-AriaNeural
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
