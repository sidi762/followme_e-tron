#!/usr/bin/env python3
"""Build the English and Chinese engineering manual PDFs from Markdown.

    pip install -r dev/tyre-model/requirements.txt
    python3 dev/tyre-model/manual_figures.py     # if the model changed
    python3 dev/tyre-model/manual_pdf.py

Converts Docs/ESC/tc-esc-engineering-manual.md and
Docs/ESC/tc-esc-engineering-manual-zh.md to HTML with python-markdown (including
offline typeset math and figure blocks) and prints them to A4 PDFs with a
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
MANUALS = [
    (REPO / "Docs" / "ESC" / "tc-esc-engineering-manual.md", "en"),
    (REPO / "Docs" / "ESC" / "tc-esc-engineering-manual-zh.md", "zh"),
]

CHROME_CANDIDATES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
]

CSS = """
@page {
  size: A4;
  margin: 16mm 15mm 16mm 15mm;
  @bottom-center { content: counter(page) " / " counter(pages); font: 8pt "Helvetica Neue", Arial, sans-serif;
                   color: #7b8794; }
  @top-right { content: "__HEADER__"; font: 8pt "Helvetica Neue", "PingFang SC", Arial,
               sans-serif; color: #7b8794; }
}
@page :first { @top-right { content: none; } }
html { font: 9.4pt/1.46 "Helvetica Neue", Helvetica, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", Arial, sans-serif;
       color: #1f2933; }
body { margin: 0; }
h1 { font-size: 18.5pt; line-height: 1.22; margin: 0 0 4pt 0; color: #102a43; }
.subtitle { color: #52606d; font-size: 9.5pt; margin-bottom: 14pt; border-bottom: 1.5pt solid #2f6db3;
            padding-bottom: 7pt; }
h2 { font-size: 13.5pt; margin: 16pt 0 6pt 0; color: #1f3f66; border-bottom: 0.5pt solid #d9e2ec;
     padding-bottom: 2pt; break-after: avoid; }
h3 { font-size: 10.8pt; margin: 11pt 0 4pt 0; color: #1f3f66; break-after: avoid; }
hr { border: none; border-top: 0.5pt solid #e4e7eb; margin: 12pt 0; }
p { margin: 0 0 6pt 0; }
ul, ol { margin: 0 0 6pt 0; padding-left: 16pt; }
li { margin: 0 0 2.5pt 0; }
code { font: 8.4pt Menlo, Consolas, monospace; background: #f2f4f7; padding: 0.5pt 2.5pt; border-radius: 2pt; }
pre { background: #f2f4f7; padding: 6pt 8pt; border-radius: 3pt; overflow-x: hidden; white-space: pre-wrap;
      break-inside: avoid; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; width: 100%; margin: 5pt 0 10pt 0; font-size: 8.1pt; line-height: 1.34; }
th, td { border: 0.6pt solid #cbd2d9; padding: 3.2pt 5pt; vertical-align: top; text-align: left; }
th { background: #eef2f7; font-weight: 600; }
tr { break-inside: avoid; }
figure { margin: 8pt 0 12pt 0; break-inside: avoid; text-align: center; }
figure img { max-width: 100%; max-height: 115mm; }
figcaption { font-size: 8.3pt; color: #3e4c59; text-align: left; margin-top: 4pt; line-height: 1.36; }
figcaption b { color: #1f2933; }
.math-display { display: block; text-align: center; margin: 7pt 0; padding: 4pt 6pt; background: #f8fafc;
                border-left: 2pt solid #2f6db3; font-family: "Times New Roman", "STIXGeneral", Georgia, serif;
                font-size: 10.2pt; break-inside: avoid; }
.math-inline { font-family: "Times New Roman", "STIXGeneral", Georgia, serif; font-size: 9.8pt; white-space: nowrap; }
.math-inline i, .math-display i { font-style: italic; }
.math-rm { font-style: normal; font-family: "Helvetica Neue", "PingFang SC", Arial, sans-serif; font-size: 0.92em; }
.frac { display: inline-block; vertical-align: middle; text-align: center; margin: 0 1.5pt; }
.frac > span { display: block; padding: 0 2pt; }
.frac .num { border-bottom: 0.6pt solid #1f2933; padding-bottom: 1pt; }
.frac .den { padding-top: 1pt; }
.cases { display: inline-table; vertical-align: middle; border-left: 1.2pt solid #1f2933; padding-left: 4pt;
         margin-left: 2pt; text-align: left; }
.cases-row { display: table-row; }
.cases-cell { display: table-cell; padding: 1pt 4pt; }
"""

FIGURE = re.compile(r'<p><img alt="(?P<alt>[^"]*)" src="(?P<src>[^"]+)" ?/?></p>\s*'
                    r'<p><em>(?P<label>Figure|图)\s*(?P<num>\d+)\.\s*(?P<caption>.*?)</em></p>', re.S)

SYMBOLS = {
    r"\omega": "<i>&omega;</i>",
    r"\kappa": "<i>&kappa;</i>",
    r"\mu": "<i>&mu;</i>",
    r"\delta": "<i>&delta;</i>",
    r"\beta": "<i>&beta;</i>",
    r"\sigma": "<i>&sigma;</i>",
    r"\tau": "<i>&tau;</i>",
    r"\psi": "<i>&psi;</i>",
    r"\Delta": "&Delta;",
    r"\sum": "&Sigma;",
    r"\le": "&le;",
    r"\ge": "&ge;",
    r"\ne": "&ne;",
    r"\approx": "&approx;",
    r"\sim": "&sim;",
    r"\times": "&times;",
    r"\div": "&divide;",
    r"\cdot": "&middot;",
    r"\in": "&isin;",
    r"\to": "&rarr;",
    r"\pm": "&plusmn;",
    r"\infty": "&infin;",
    r"\qquad": "&emsp;&emsp;",
    r"\quad": "&emsp;",
    r"\;": "&ensp;",
    r"\,": "&#8239;",
    r"\!": "",
    r"\left": "",
    r"\right": "",
    r"\{": "{",
    r"\}": "}",
}


def _match_brace(s, pos):
    """Given s[pos] == '{', return the index of the matching '}'."""
    depth = 0
    for i in range(pos, len(s)):
        if s[i] == "{" and (i == 0 or s[i - 1] != "\\"):
            depth += 1
        elif s[i] == "}" and (i == 0 or s[i - 1] != "\\"):
            depth -= 1
            if depth == 0:
                return i
    return len(s) - 1


def _render_latex(tex):
    """Convert the subset of LaTeX math used in the manuals into clean offline HTML."""
    s = tex.strip()
    s = s.replace(r"\_", "\uFF3F").replace(r"\%", "%").replace(r"\|", "|")
    s = s.replace(r"\left", "").replace(r"\right", "")

    # Handle \begin{cases} ... \end{cases}
    while r"\begin{cases}" in s:
        a = s.index(r"\begin{cases}")
        b = s.index(r"\end{cases}", a)
        inner = s[a + len(r"\begin{cases}"):b].strip()
        rows = []
        for row in inner.split(r"\\"):
            cells = [c.strip() for c in row.split("&")]
            row_html = "".join(f'<span class="cases-cell">{_render_latex(c)}</span>' for c in cells)
            rows.append(f'<span class="cases-row">{row_html}</span>')
        s = s[:a] + f'<span class="cases">{"".join(rows)}</span>' + s[b + len(r"\end{cases}"):]

    # Handle \text{...} and \operatorname{...} and \mathbf{...}
    for cmd, tag in ((r"\text", "span class=\"math-rm\""), (r"\operatorname", "span class=\"math-rm\""),
                     (r"\mathbf", "b")):
        while cmd + "{" in s:
            idx = s.index(cmd + "{")
            start = idx + len(cmd)
            end = _match_brace(s, start)
            inner = html.escape(s[start + 1:end])
            close = tag.split()[0]
            s = s[:idx] + f"<{tag}>{inner}</{close}>" + s[end + 1:]

    # Handle \dot{x}
    while r"\dot{" in s:
        idx = s.index(r"\dot{")
        start = idx + 4
        end = _match_brace(s, start)
        inner = s[start + 1:end]
        s = s[:idx] + f"<i>{inner}&#775;</i>" + s[end + 1:]

    # Handle \sqrt{...}
    while r"\sqrt{" in s:
        idx = s.index(r"\sqrt{")
        start = idx + 5
        end = _match_brace(s, start)
        inner = _render_latex(s[start + 1:end])
        s = s[:idx] + f"&radic;<span style=\"border-top:0.5pt solid #1f2933;padding-top:0.5pt\">{inner}</span>" + s[end + 1:]

    # Handle \frac{a}{b}
    while r"\frac{" in s:
        idx = s.index(r"\frac{")
        s1 = idx + 5
        e1 = _match_brace(s, s1)
        s2 = e1 + 1
        if s2 < len(s) and s[s2] == "{":
            e2 = _match_brace(s, s2)
            num = _render_latex(s[s1 + 1:e1])
            den = _render_latex(s[s2 + 1:e2])
            s = s[:idx] + f'<span class="frac"><span class="num">{num}</span><span class="den">{den}</span></span>' + s[e2 + 1:]
        else:
            break

    # Handle ^{\circ} or ^\circ
    s = s.replace(r"^{\circ}", "&deg;").replace(r"^\circ", "&deg;")

    # Handle _{...} and ^{...}, plus single-token _x or _\mu
    for op, tag in (("_", "sub"), ("^", "sup")):
        while op + "{" in s:
            idx = s.index(op + "{")
            start = idx + 1
            end = _match_brace(s, start)
            inner = _render_latex(s[start + 1:end])
            s = s[:idx] + f"<{tag}>{inner}</{tag}>" + s[end + 1:]
        pat = (r"\^" if op == "^" else r"_") + r"(\\[A-Za-z]+|[A-Za-z0-9])"
        s = re.sub(pat, lambda m: f"<{tag}>{_render_latex(m.group(1))}</{tag}>", s)

    for k, v in sorted(SYMBOLS.items(), key=lambda kv: -len(kv[0])):
        s = s.replace(k, v)
    for fn in ("min", "max", "sin", "cos", "tan", "atan", "arctan", "exp", "log"):
        s = s.replace("\\" + fn, f'<span class="math-rm">{fn}</span>')
    s = s.replace("--", "&ndash;")
    return s


def chrome():
    for candidate in [os.environ.get("CHROME")] + CHROME_CANDIDATES:
        if candidate and (Path(candidate).exists() or shutil.which(candidate)):
            return candidate
    sys.exit("no Chrome or Chromium found; set CHROME")


MODEL = ["Systems/tyre-model.xml", "dev/tyre-model/generate.py"]


def revision(lang="en"):
    """The commit of the model the figures and numbers describe, and whether it has local changes."""
    try:
        commit = subprocess.run(["git", "-C", str(REPO), "log", "-1", "--format=%h", "--"] + MODEL,
                                capture_output=True, text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", str(REPO), "status", "--porcelain", "--"] + MODEL,
                               capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "未知模型版本" if lang == "zh" else "an unknown model revision"
    if lang == "zh":
        return "提交 %s%s" % (commit, "（含本地修改）" if dirty else "")
    return "the model of commit %s%s" % (commit, " with local changes" if dirty else "")


def to_html(text, source_path, lang="en"):
    title, _, body = text.partition("\n")
    title = title.lstrip("# ").strip()

    # Protect math spans from markdown's underscore/asterisk parsing
    math_store = []

    def stash_display(m):
        idx = len(math_store)
        math_store.append(f'<div class="math-display">{_render_latex(m.group(1)).replace("\uFF3F", "_")}</div>')
        return f"@@MATH_{idx}@@"

    def stash_inline(m):
        idx = len(math_store)
        math_store.append(f'<span class="math-inline">{_render_latex(m.group(1)).replace("\uFF3F", "_")}</span>')
        return f"@@MATH_{idx}@@"

    body = re.sub(r"\$\$(.+?)\$\$", stash_display, body, flags=re.S)
    body = re.sub(r"(?<!\$)\$(?!\$)([^$]+?)\$(?!\$)", stash_inline, body, flags=re.S)

    content = markdown.markdown(body, extensions=["tables", "fenced_code", "sane_lists"])
    for idx, rendered in enumerate(math_store):
        content = content.replace(f"<p>@@MATH_{idx}@@</p>", rendered)
        content = content.replace(f"@@MATH_{idx}@@", rendered)

    content = FIGURE.sub(
        lambda m: '<figure><img alt="%s" src="%s"><figcaption><b>%s %s.</b> %s</figcaption></figure>'
                  % (m["alt"], m["src"], m["label"], m["num"], m["caption"]),
        content,
    )
    today = datetime.date.today().isoformat()
    if lang == "zh":
        subtitle = "Follow Me EV 轮胎动力学模型原型 &middot; %s 生成（对应%s）" % (
            today, html.escape(revision("zh")))
        header = "Follow Me EV：牵引力与车身稳定性控制系统工程手册"
    else:
        subtitle = "Follow Me EV tyre model prototype &middot; generated %s for %s" % (
            today, html.escape(revision("en")))
        header = "Follow Me EV: traction and stability control"
    css = CSS.replace("__HEADER__", header)
    return ('<!doctype html><html lang="%s"><head><meta charset="utf-8"><base href="%s/"><title>%s</title>'
            "<style>%s</style></head><body><h1>%s</h1><div class=\"subtitle\">%s</div>%s</body></html>"
            % (lang, source_path.parent.as_uri(), html.escape(title), css, html.escape(title), subtitle, content))


def main():
    chrome_bin = chrome()
    with tempfile.TemporaryDirectory() as tmp:
        for idx, (source, lang) in enumerate(MANUALS):
            if not source.exists():
                continue
            target = source.with_suffix(".pdf")
            page = Path(tmp) / f"manual_{idx}.html"
            page.write_text(to_html(source.read_text(encoding="utf-8"), source, lang), encoding="utf-8")
            subprocess.run([chrome_bin, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                            "--allow-file-access-from-files", "--print-to-pdf=%s" % target, page.as_uri()],
                           check=True, capture_output=True)
            print("wrote", target.relative_to(REPO))


if __name__ == "__main__":
    main()
