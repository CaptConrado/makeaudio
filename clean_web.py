#!/usr/bin/env python3
"""Extract a webpage's main article text into TTS-ready narration text.

Usage:
    clean_web.py <URL|file.html> OUT_TXT ["Spoken title override"]

Uses trafilatura to pull just the article body (no nav, ads, comments, or
boilerplate), prepends a spoken title (page title + site/author when available),
strips leftover URLs/markdown, and collapses whitespace into clean paragraphs.
"""
import re
import sys
import warnings

warnings.filterwarnings("ignore")  # silence LibreSSL/urllib3 notices

import trafilatura

if len(sys.argv) < 3:
    sys.exit('usage: clean_web.py <URL|file.html> OUT_TXT ["Title override"]')

src, out_txt = sys.argv[1], sys.argv[2]
title_override = sys.argv[3] if len(sys.argv) > 3 else None

# Fetch (URL) or read (local HTML file).
if re.match(r"https?://", src):
    html = trafilatura.fetch_url(src)
    if not html:
        sys.exit(f"error: could not fetch {src}")
else:
    with open(src, encoding="utf-8", errors="ignore") as f:
        html = f.read()

body = trafilatura.extract(
    html,
    include_comments=False,
    include_tables=False,
    include_images=False,
    include_links=False,
    favor_precision=True,
)
if not body or len(body.split()) < 30:
    sys.exit("error: little or no article text extracted (paywall or JS-only page?)")

# Title line: override > page metadata > nothing.
meta = trafilatura.extract_metadata(html)
title = title_override
if not title and meta:
    page_title = (meta.title or "").strip()
    site = (meta.sitename or "").strip()
    # Strip a trailing " - Site" / " | Site" suffix from the headline.
    if site:
        page_title = re.sub(r"\s*[\-|–—]\s*" + re.escape(site) + r"\s*$", "", page_title)
    bits = [page_title]
    author = (meta.author or "").strip()
    # Use author only if it looks like a real byline (short, not boilerplate).
    if author and len(author.split()) <= 6 and not re.search(r"(?i)authority|database|wikipedia", author):
        bits.append("By " + author)
    elif site:
        bits.append("From " + site)
    title = ". ".join(b for b in bits if b)

text = (title + ".\n\n" + body) if title else body

# Tidy for narration.
text = re.sub(r"https?://\S+", "", text)          # drop stray URLs
text = re.sub(r"\[[0-9]+\]", "", text)            # drop [12] reference markers
text = re.sub(r"[ \t]+", " ", text)
text = re.sub(r" *\n", "\n", text)
text = re.sub(r"\n{3,}", "\n\n", text)
text = re.sub(r"\s+([,.;:?!])", r"\1", text).strip()

with open(out_txt, "w", encoding="utf-8") as f:
    f.write(text + "\n")

print(f"title: {title or '(none detected)'}")
print(f"words: {len(text.split())}")
print("--- head ---\n" + text[:500])
print("--- tail ---\n" + text[-300:])
