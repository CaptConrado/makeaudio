#!/usr/bin/env python3
"""Clean an HBS-style case PDF text dump into TTS-ready narration text.

Usage:
    clean_case.py RAW_TXT OUT_TXT "Spoken title line." ["Start anchor phrase"]

- Cuts off everything from the first real Exhibit *heading* (number + 2+ spaces +
  title) or an "Endnotes" line onward, so tables/citations aren't narrated.
- Strips repeated page headers/footers (identified by the NNN-NNN document id),
  "For the exclusive use" / authorization boilerplate, REV lines, and bare page
  numbers.
- Removes inline footnote/endnote superscript numbers, while leaving decimals
  like "$42.3 billion" untouched.
- Rejoins wrapped lines into paragraphs.

The start anchor is optional: when given, narration begins at that phrase (most
reliable). When omitted, the script keeps everything after the boilerplate.
"""
import re
import sys

if len(sys.argv) < 4:
    sys.exit("usage: clean_case.py RAW_TXT OUT_TXT \"Title.\" [\"Start phrase\"]")

raw_txt, out_txt, spoken_title = sys.argv[1:4]
start_anchor = sys.argv[4] if len(sys.argv) > 4 else None

with open(raw_txt, encoding="utf-8") as f:
    lines = f.readlines()

# Cut from the first real Exhibit HEADING (number + 2+ spaces + title) or Endnotes.
# This excludes inline references like "Exhibit 6),".
body = []
for line in lines:
    if re.match(r"\s*Exhibit \d+\s{2,}\S", line) or re.match(r"\s*Endnotes\s*$", line):
        break
    body.append(line)
text = "".join(body)

# Drop repeated header/footer + boilerplate lines.
junk_patterns = [
    r"^\s*For the exclusive use of .*$",
    r"^\s*This document is authorized for use only by .*$",
    r"^\s*\d{3}-\d{3}\b.*$",       # footer/header beginning with the doc id
    r"^.*\b\d{3}-\d{3}\s*$",       # footer/header ending with the doc id
    r"^\s*9-\d{3}-\d{3}\s*$",      # full doc id on its own line
    r"^\s*REV:.*$",
    r"^\s*\d{1,3}\s*$",            # bare page numbers
]
junk_re = re.compile("|".join(junk_patterns), re.IGNORECASE)
text = "\n".join(ln for ln in text.split("\n") if not junk_re.match(ln))

# Anchor the start at the opening sentence; always prepend the clean spoken title.
if start_anchor:
    m = re.search(re.escape(start_anchor), text)
    text = text[m.start():] if m else text
text = spoken_title + "\n\n" + text

# Strip inline footnote/endnote superscript numbers after end punctuation/quotes.
# Require whitespace before the number so decimals such as "$42.3" are never hit.
text = re.sub(r'(?<=[\.\?\!\"”’\)])\s+\d{1,3}(?=\s|$)', "", text)

# Normalize whitespace, then rejoin wrapped lines into paragraphs (blank = break).
text = re.sub(r"[ \t]+", " ", text)
paragraphs, buf = [], ""
for raw in text.split("\n"):
    s = raw.strip()
    if not s:
        if buf:
            paragraphs.append(buf.strip()); buf = ""
        continue
    buf = (buf + " " + s).strip() if buf else s
if buf:
    paragraphs.append(buf.strip())

clean = "\n\n".join(paragraphs)
clean = re.sub(r"\s+([,.;:?!])", r"\1", clean)
clean = re.sub(r"\n{3,}", "\n\n", clean)

with open(out_txt, "w", encoding="utf-8") as f:
    f.write(clean + "\n")

print(f"words: {len(clean.split())}")
print("--- head ---\n" + clean[:500])
print("--- tail ---\n" + clean[-300:])
