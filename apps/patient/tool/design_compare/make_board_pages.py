"""Build the design board as plain pages Chrome can render offline, with the app's own font files.

  python3 tool/design_compare/make_board_pages.py <work dir>

Writes <work>/board/splash.html (N00Splash at 390x844, opening into Welcome) and
<work>/board/welcome_390x844.html, welcome_360x640.html (N01Welcome). It regenerates N00Splash with
docs/design/kalighat-pop/gen/splash.py and checks the result is byte-identical to the committed board.
Needs: pip install uharfbuzz fonttools brotli
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys

from fontTools.ttLib import TTFont

APP = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(os.path.dirname(APP))
KP = os.path.join(REPO, 'docs', 'design', 'kalighat-pop')
FONTS = os.path.join(APP, 'assets', 'fonts')
work = os.path.abspath(sys.argv[1])

# splash.py expects <root>/gen/splash.py next to <root>/project/{N01Welcome.dc.html,kp.css}
root = os.path.join(work, 'kp')
os.makedirs(os.path.join(root, 'gen'), exist_ok=True)
os.makedirs(os.path.join(root, 'project'), exist_ok=True)
shutil.copy(os.path.join(KP, 'gen', 'splash.py'), os.path.join(root, 'gen'))
for f in ('N01Welcome.dc.html', 'kp.css'):
    shutil.copy(os.path.join(KP, f), os.path.join(root, 'project'))
subprocess.run([sys.executable, '-I', os.path.join(root, 'gen', 'splash.py'), os.path.join(FONTS, 'KaushanScript-Regular.ttf')],
               check=True, cwd=work)
digest = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
assert digest(os.path.join(root, 'project', 'N00Splash.dc.html')) == digest(os.path.join(KP, 'N00Splash.dc.html')), \
    'regenerated board differs from docs/design/kalighat-pop/N00Splash.dc.html'

# the same Anek Latin files the app bundles, as WOFF2 for the browser
fonts = os.path.join(work, 'fonts')
os.makedirs(fonts, exist_ok=True)
for src, dst in (('AnekLatin-Variable.ttf', 'anek-latin.woff2'), ('AnekLatinExt-Variable.ttf', 'anek-latinext.woff2')):
    f = TTFont(os.path.join(FONTS, src))
    f.flavor = 'woff2'
    f.save(os.path.join(fonts, dst))
fontface = (
    "@font-face{font-family:'Anek Latin';src:url(../fonts/anek-latin.woff2) format('woff2');font-weight:100 800;font-stretch:75% 125%;"
    "unicode-range:U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD}"
    "@font-face{font-family:'Anek Latin';src:url(../fonts/anek-latinext.woff2) format('woff2');font-weight:100 800;font-stretch:75% 125%;"
    "unicode-range:U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C4,U+2113,U+2C60-2C7F,U+A720-A7FF}")

board = os.path.join(work, 'board')
os.makedirs(board, exist_ok=True)
html = open(os.path.join(work, 'r_N00Splash.html')).read()
html = re.sub(r'<link rel="stylesheet" href="https://fonts.googleapis.com[^>]*>', '', html)
fit = (".board{width:390px!important;height:844px!important;padding:0!important;background:none!important}"
       ".phone{width:390px!important;height:844px!important;border:0!important;border-radius:0!important}")
html = html.replace('<head>', '<head><style>' + fontface + '</style>', 1).replace('</head>', '<style>' + fit + '</style></head>', 1)
open(os.path.join(board, 'splash.html'), 'w').write(html)

w = open(os.path.join(KP, 'N01Welcome.dc.html')).read()
kp = open(os.path.join(KP, 'kp.css')).read()
style = re.search(r'<style>(.*?)</style>', w, re.S).group(1)
body = w[w.index('<div class="screen w"'):w.rindex('</x-dc>')]
for W, H in ((390, 844), (360, 640)):
    page = (f'<html><head><style>{fontface}</style><style>{kp}</style><style>{style}</style>'
            f'<style>.screen{{width:{W}px!important;height:{H}px!important}}</style></head><body>{body}</body></html>')
    open(os.path.join(board, f'welcome_{W}x{H}.html'), 'w').write(page)
print('board pages in', board)
