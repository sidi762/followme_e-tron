#!/usr/bin/env python3
"""Build Docs/ESC/tc-esc-engineering-manual.pdf from the Markdown manual.

    pip install -r dev/tyre-model/requirements.txt
    python3 dev/tyre-model/manual_figures.py     # if the model changed
    python3 dev/tyre-model/manual_pdf.py

Converts the Markdown to HTML with python-markdown and prints it to A4 with a
headless Google Chrome (or Chromium). Set CHROME to its executable if it is not
in the usual place.
"""
import datetime
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import markdown

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "Docs" / "ESC" / "tc-esc-engineering-manual.md"
TARGET = SOURCE.with_suffix(".pdf")

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
]

CSS = """
@page {
  size: A4;
  margin: 18mm 16mm 18mm 16mm;
  @bottom-center { content: counter(page) " / " counter(pages); font: 8pt "Helvetica Neue", Arial, sans-serif;
                   color: #7b8794; }
  @top-right { content: "Follow Me EV: traction and stability control"; font: 8pt "Helvetica Neue", Arial,
               sans-serif; color: #7b8794; }
}
@page :first { @top-right { content: none; } }
html { font: 9.6pt/1.42 "Helvetica Neue", Helvetica, Arial, sans-serif; color: #1f2933; }
body { margin: 0; }
h1 { font-size: 20pt; line-height: 1.2; margin: 0 0 4pt 0; }
.subtitle { color: #52606d; font-size: 10pt; margin-bottom: 16pt; border-bottom: 1.5pt solid #2f6db3;
            padding-bottom: 8pt; }
h2 { font-size: 14pt; margin: 18pt 0 6pt 0; color: #1f3f66; break-after: avoid; }
h3 { font-size: 11pt; margin: 12pt 0 4pt 0; color: #1f3f66; break-after: avoid; }
p { margin: 0 0 6pt 0; }
ul, ol { margin: 0 0 6pt 0; padding-left: 16pt; }
li { margin: 0 0 2pt 0; }
code { font: 8.6pt Menlo, Consolas, monospace; background: #f2f4f7; padding: 0 2pt; border-radius: 2pt; }
pre { background: #f2f4f7; padding: 6pt 8pt; border-radius: 3pt; overflow-x: hidden; white-space: pre-wrap;
      break-inside: avoid; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 4pt 0 10pt 0; font-size: 8.3pt; line-height: 1.32; }
th, td { border: 0.6pt solid #cbd2d9; padding: 3pt 5pt; vertical-align: top; text-align: left; }
th { background: #eef2f7; }
tr { break-inside: avoid; }
figure { margin: 8pt 0 12pt 0; break-inside: avoid; text-align: center; }
figure img { max-width: 100%; max-height: 112mm; }
figcaption { font-size: 8.4pt; color: #3e4c59; text-align: left; margin-top: 4pt; }
figcaption b { color: #1f2933; }
"""

FIGURE = re.compile(r'<p><img alt="(?P<alt>[^"]*)" src="(?P<src>[^"]+)" ?/?></p>\s*'
                    r'<p><em>Figure (?P<num>\d+)\.\s*(?P<caption>.*?)</em></p>', re.S)


def chrome():
    for candidate in [os.environ.get("CHROME")] + CHROME_CANDIDATES:
        if candidate and (Path(candidate).exists() or shutil.which(candidate)):
            return candidate
    sys.exit("no Chrome or Chromium found; set CHROME")


MODEL = ["Systems/tyre-model.xml", "dev/tyre-model/generate.py"]


def revision():
    """The commit of the model the figures and numbers describe, and whether it has local changes."""
    try:
        commit = subprocess.run(["git", "-C", str(REPO), "log", "-1", "--format=%h", "--"] + MODEL,
                                capture_output=True, text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", str(REPO), "status", "--porcelain", "--"] + MODEL,
                               capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "an unknown model revision"
    return "the model of commit %s%s" % (commit, " with local changes" if dirty else "")


def to_html(text):
    title, _, body = text.partition("\n")
    title = title.lstrip("# ").strip()
    content = markdown.markdown(body, extensions=["tables", "fenced_code", "sane_lists"])
    content = FIGURE.sub(lambda m: '<figure><img alt="%s" src="%s"><figcaption><b>Figure %s.</b> %s'
                                   '</figcaption></figure>' % (m["alt"], m["src"], m["num"], m["caption"]), content)
    subtitle = "Follow Me EV tyre model prototype &middot; generated %s for %s" % (
        datetime.date.today().isoformat(), html.escape(revision()))
    return ('<!doctype html><html><head><meta charset="utf-8"><base href="%s/"><title>%s</title>'
            "<style>%s</style></head><body><h1>%s</h1><div class=\"subtitle\">%s</div>%s</body></html>"
            % (SOURCE.parent.as_uri(), html.escape(title), CSS, html.escape(title), subtitle, content))


def main():
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "manual.html"
        page.write_text(to_html(SOURCE.read_text(encoding="utf-8")), encoding="utf-8")
        subprocess.run([chrome(), "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                        "--allow-file-access-from-files", "--print-to-pdf=%s" % TARGET, page.as_uri()],
                       check=True, capture_output=True)
    print("wrote", TARGET.relative_to(REPO))


if __name__ == "__main__":
    main()
