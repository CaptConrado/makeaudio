#!/usr/bin/env python3
"""Normalize a Word-doc text dump (from `textutil -convert txt`) for TTS.

Usage:
    clean_doc.py RAW_TXT OUT_TXT ["Spoken title override"]

Word docs are already mostly clean prose, so this just tidies bullet markers,
tabs, and blank lines, and optionally prepends a spoken title.
"""
import re
import sys

if len(sys.argv) < 3:
    sys.exit('usage: clean_doc.py RAW_TXT OUT_TXT ["Title override"]')

raw_txt, out_txt = sys.argv[1], sys.argv[2]
title_override = sys.argv[3] if len(sys.argv) > 3 else None

with open(raw_txt, encoding="utf-8", errors="ignore") as f:
    text = f.read()

# Turn list markers (•, tab-bullet-tab, leading dashes/stars) into clean phrases.
lines = []
for ln in text.split("\n"):
    s = ln.replace("\t", " ").strip()
    s = re.sub(r"^[•▪●⁃∙*\-–—]\s*", "", s)  # drop a leading bullet
    lines.append(s)
text = "\n".join(lines)

# Prepend a spoken title if given (otherwise the doc's own first line stands).
if title_override:
    text = title_override + ".\n\n" + text

text = re.sub(r"[ \t]+", " ", text)
text = re.sub(r" *\n", "\n", text)
text = re.sub(r"\n{3,}", "\n\n", text)
text = re.sub(r"\s+([,.;:?!])", r"\1", text).strip()

with open(out_txt, "w", encoding="utf-8") as f:
    f.write(text + "\n")

print(f"words: {len(text.split())}")
print("--- head ---\n" + text[:400])
print("--- tail ---\n" + text[-300:])
