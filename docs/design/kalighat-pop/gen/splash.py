"""N00 Splash: tap the ApneDoctors icon on the home screen and the app opens.

Beats (one 6 s timeline, everything keyed to it):
  0.00  the icon tile grows into the whole screen (warm paper); the "a" rides with it to the centre
  0.20  the "a" closes its eyes happily (you touched it)
  0.45  an alpana blooms around it: a vermilion dot ring, an 8-petal lotus (ashtadal) drawn by a finger,
        turmeric dots, an outer ring of fine ink dots (the Kalighat dot border)
  1.35  the "a" opens its eyes, blinks, glances left
  1.95  the alpana lifts away; the "a" glides on one soft curve to become the first letter
  2.50  "pne" (vermilion) and "Doctors" (ink) write themselves behind a gliding nib; the "a" watches
  4.05  a tapered turmeric brushstroke sweeps under the name and ends in a vermilion bindi
  4.25  the "a" smiles and blushes; three loading dots breathe

Glyphs are Kaushan Script outlines (HarfBuzz + fontTools), so no web font is needed for the name.
Run: python3 newlook/gen/splash.py fontdl/KaushanScript-Regular.ttf
"""
import math, os, sys
import uharfbuzz as hb
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

FONT = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'project', 'N00Splash.dc.html')
TEST = os.path.join(HERE, '..', '..', 'r_N00Splash.html')

PAPER, RED, INK, TURMERIC = '#FBF7EF', '#C8302B', '#1A1410', '#EFB12A'
W, SH = 390, 844
T = 9.2  # master timeline (s): splash, then the hand-off into Welcome


def f(v):
    return ('%.2f' % v).rstrip('0').rstrip('.')


# ---------- cubic-bezier helpers (to time glyphs against the eased wipe) ----------
def bez(p1x, p1y, p2x, p2y):
    def coord(t, a, b):
        return 3 * a * t * (1 - t) ** 2 + 3 * b * t * t * (1 - t) + t ** 3

    def y_at_x(x):
        lo, hi = 0.0, 1.0
        for _ in range(40):
            m = (lo + hi) / 2
            if coord(m, p1x, p2x) < x:
                lo = m
            else:
                hi = m
        return coord((lo + hi) / 2, p1y, p2y)

    def x_at_y(y):  # inverse: progress y -> time fraction x
        lo, hi = 0.0, 1.0
        for _ in range(40):
            m = (lo + hi) / 2
            if y_at_x(m) < y:
                lo = m
            else:
                hi = m
        return (lo + hi) / 2
    return y_at_x, x_at_y


WRITE_EASE = (.42, .1, .58, .92)
_, write_time_for = bez(*WRITE_EASE)

# ---------- the "a" (A4 logo), local coords: bowl centre at the origin ----------
# bowl r45 stroke16; stem M45 -44 V26 Q45 46 64 46 (same shape as Buddy.tsx, shifted by -230,-130)
A_BODY = (f'<circle r="45" fill="none" stroke="{RED}" stroke-width="16"/>'
          f'<path d="M45 -44 V26 Q45 46 64 46" fill="none" stroke="{RED}" stroke-width="16" stroke-linecap="round"/>')
A_BBOX = (-53, -52, 72, 54)  # x0 y0 x1 y1 incl. stroke
A_CX = (A_BBOX[0] + A_BBOX[2]) / 2   # 9.5
A_CY = (A_BBOX[1] + A_BBOX[3]) / 2   # 1

# icon on the home screen: 60 px tile at (IX, IY); the shipped icon puts the bowl at (28.53, 30) at scale .2461
IX, IY, IS = 211, 276, 60
ICON_S = 4.2 * IS / 1024
ICON_BX, ICON_BY = IX + (230 * 4.2 - 479.2) * IS / 1024, IY + (130 * 4.2 - 34) * IS / 1024

# hero: the a's bounding box centred on the alpana centre
CX, CY = 195, 404
HERO_S = 1.4
HERO_BX, HERO_BY = CX - A_CX * HERO_S, CY - A_CY * HERO_S

# ---------- wordmark: "pne" vermilion + "Doctors" ink, Kaushan Script outlines ----------
SIZE, BASE = 54, 432
blob = hb.Blob.from_file_path(FONT)
face = hb.Face(blob)
font = hb.Font(face)
upm = face.upem
tt = TTFont(FONT)
gs = tt.getGlyphSet()
order = tt.getGlyphOrder()
k = SIZE / upm
TEXT = 'pneDoctors'
buf = hb.Buffer()
buf.add_str(TEXT)
buf.guess_segment_properties()
hb.shape(font, buf, {'kern': True, 'liga': True, 'calt': True})
text_w = sum(p.x_advance for p in buf.glyph_positions) * k

FIN_S = 0.92 * SIZE / 106          # bowl height = 0.8 em, a touch taller than the capitals
logo_w = (A_BBOX[2] - A_BBOX[0]) * FIN_S
GAP = 0.5
total = logo_w + GAP + text_w
X = (W - total) / 2
FIN_BX = X - A_BBOX[0] * FIN_S
FIN_BY = BASE + 1 - 53 * FIN_S       # bowl sits on the baseline
X0 = X + logo_w + GAP                # text start
X1 = X0 + text_w

glyphs = []
x = X0
for i, (info, pos) in enumerate(zip(buf.glyph_infos, buf.glyph_positions)):
    name = order[info.codepoint]
    ox, oy = x + pos.x_offset * k, BASE - pos.y_offset * k
    t = (k, 0, 0, -k, ox, oy)
    pen = SVGPathPen(gs)
    gs[name].draw(TransformPen(pen, t))
    bp = BoundsPen(gs)
    gs[name].draw(TransformPen(bp, t))
    bx0 = bp.bounds[0] if bp.bounds else ox
    glyphs.append((pen.getCommands(), RED if i < 3 else INK, bx0))
    x += pos.x_advance * k

# ---------- timeline ----------
EXPAND = 0.55
EYES_SHUT = (0.18, 0.28)
WAKE = 1.35
BLINK = 1.78
MOVE = (1.95, 2.80)
WRITE = (2.50, 4.20)
FEATHER = 22
SWASH = (4.02, 4.62)
SMILE = 4.24
DOTS = 5.0
# hand-off into Welcome (N01): the name fades, the a stays, glides to the centre, and the Welcome
# content rises from below and pushes it up into the doorway, which then paints itself around it
H = 5.55                    # hand-off starts
GLIDE = (H + 0.1, H + 0.95)
SWAP = GLIDE[1] + 0.02      # the overlay a hands over to Welcome's own a (same place, same size)
RISE = H + 0.8              # Welcome copy starts rising from below
ARCH = H + 1.85             # doorway paints itself around the a
WEL_S = 1.05                # Welcome's a: arch at (25, 66.72), a at translate(80 176) scale(1.05)
WEL_BX, WEL_BY = 25 + 80 + (230 - 156) * 1.05, 66.72 + 176 + (130 - 50) * 1.05   # 182.7, 326.72
MID_BY = 432                # where the a waits, centred, before it is pushed up
PUSH = MID_BY - WEL_BY


def pct(t):
    return f(100 * t / T) + '%'


def keyframes(name, frames):
    """frames: [(t, 'css decls', 'easing to next' or None)]"""
    out = []
    for t, decl, ease in frames:
        e = f';animation-timing-function:{ease}' if ease else ''
        out.append(f'{pct(t)}{{{decl}{e}}}')
    return f'@keyframes {name}{{' + ''.join(out) + '}'


EXP_EASE = 'cubic-bezier(.22,.8,.22,1)'
css = []
# tile: icon -> full screen
css.append(keyframes('sp-tile', [
    (0, f'left:{IX}px;top:{IY}px;width:{IS}px;height:{IS}px;border-radius:14px', EXP_EASE),
    (EXPAND, 'left:0;top:0;width:390px;height:844px;border-radius:0', None),
    (T, 'left:0;top:0;width:390px;height:844px;border-radius:0', None)]))
# the a: x, y and scale on separate groups so the glide is one soft curve
xe, ye = 'cubic-bezier(.62,0,.24,1)', 'cubic-bezier(.36,0,.16,1)'
xe2, ye2 = 'cubic-bezier(.3,0,.25,1)', 'cubic-bezier(.6,0,.25,1)'  # hand-off: lifts first, then slides over
css.append(keyframes('sp-ax', [
    (0, f'transform:translateX({f(ICON_BX)}px)', EXP_EASE),
    (EXPAND, f'transform:translateX({f(HERO_BX)}px)', None),
    (MOVE[0], f'transform:translateX({f(HERO_BX)}px)', xe),
    (MOVE[1], f'transform:translateX({f(FIN_BX)}px)', None),
    (GLIDE[0], f'transform:translateX({f(FIN_BX)}px)', ye2),
    (GLIDE[1], f'transform:translateX({f(WEL_BX)}px)', None),
    (T, f'transform:translateX({f(WEL_BX)}px)', None)]))
css.append(keyframes('sp-ay', [
    (0, f'transform:translateY({f(ICON_BY)}px)', EXP_EASE),
    (EXPAND, f'transform:translateY({f(HERO_BY)}px)', None),
    (MOVE[0], f'transform:translateY({f(HERO_BY)}px)', ye),
    (MOVE[1], f'transform:translateY({f(FIN_BY)}px)', None),
    (GLIDE[0], f'transform:translateY({f(FIN_BY)}px)', xe2),
    (GLIDE[1], f'transform:translateY({f(MID_BY)}px)', None),
    (T, f'transform:translateY({f(MID_BY)}px)', None)]))
css.append(keyframes('sp-as', [
    (0, f'transform:scale({ICON_S:.4f})', EXP_EASE),
    (EXPAND, f'transform:scale({HERO_S})', None),
    (MOVE[0], f'transform:scale({HERO_S})', xe),
    (MOVE[1], f'transform:scale({FIN_S:.4f})', None),
    (GLIDE[0], f'transform:scale({FIN_S:.4f})', 'cubic-bezier(.5,0,.2,1)'),
    (GLIDE[1], f'transform:scale({WEL_S})', None),
    (T, f'transform:scale({WEL_S})', None)]))
# little life moments on the body: wake pop, inhale before the glide, happy hop
css.append(keyframes('sp-pop', [
    (0, 'transform:none', None),
    (WAKE, 'transform:none', 'cubic-bezier(.3,1.6,.5,1)'),
    (WAKE + .22, 'transform:scale(1.05)', 'ease-in-out'),
    (WAKE + .42, 'transform:none', None),
    (MOVE[0] - .2, 'transform:none', 'ease-out'),
    (MOVE[0], 'transform:scale(1.03) translateY(-2px)', 'ease-in'),
    (MOVE[0] + .25, 'transform:none', None),
    (SMILE, 'transform:none', 'cubic-bezier(.3,0,.6,1)'),
    (SMILE + .16, 'transform:translateY(-9px)', 'cubic-bezier(.4,0,.7,1.4)'),
    (SMILE + .40, 'transform:none', None),
    (H, 'transform:none', 'ease-out'),
    (H + .12, 'transform:translateY(3px) scale(1.05,.93)', 'ease-in-out'),
    (H + .32, 'transform:none', None),
    (T, 'transform:none', None)]))
css.append('@keyframes sp-breathe{0%,100%{transform:scale(1)}50%{transform:scale(1.035)}}')
# eyes: open dots (with lids, blink and gaze) and the happy curves
css.append(keyframes('sp-open', [
    (0, 'opacity:1', None), (EYES_SHUT[0], 'opacity:1', None), (EYES_SHUT[0] + .04, 'opacity:0', None),
    (WAKE - .01, 'opacity:0', None), (WAKE, 'opacity:1', None),
    (SMILE - .02, 'opacity:1', None), (SMILE + .03, 'opacity:0', None),
    (H + .06, 'opacity:0', None), (H + .1, 'opacity:1', None), (T, 'opacity:1', None)]))
css.append(keyframes('sp-lid', [
    (0, 'transform:scaleY(1)', 'ease-in'), (EYES_SHUT[0], 'transform:scaleY(.15)', None),
    (WAKE, 'transform:scaleY(.12)', 'cubic-bezier(.2,.9,.3,1.25)'), (WAKE + .2, 'transform:scaleY(1)', None),
    (BLINK, 'transform:scaleY(1)', 'ease-in'), (BLINK + .07, 'transform:scaleY(.1)', 'ease-out'),
    (BLINK + .16, 'transform:scaleY(1)', None), (T, 'transform:scaleY(1)', None)]))
css.append(keyframes('sp-gaze', [
    (0, 'transform:none', None), (WAKE + .25, 'transform:none', 'ease-in-out'),
    (WAKE + .4, 'transform:translate(-3px,-1px)', None),                     # looks at you, a tiny bit up-left
    (MOVE[0] - .15, 'transform:translate(-3px,-1px)', 'ease-in-out'),
    (MOVE[0] + .05, 'transform:translate(-7px,1px)', None),                  # glances where it is going
    (MOVE[1] - .1, 'transform:translate(-7px,1px)', 'ease-in-out'),
    (WRITE[0] + .25, 'transform:translate(3px,1px)', 'cubic-bezier(.42,.1,.58,.92)'),
    (WRITE[1], 'transform:translate(8px,2px)', None),                        # follows the nib along its name
    (H + .08, 'transform:translate(0,-3px)', 'ease-in-out'),                 # looks up as it lifts off
    (GLIDE[1] - .2, 'transform:none', None),
    (T, 'transform:none', None)]))
css.append(keyframes('sp-happy', [
    (0, 'opacity:0', None), (EYES_SHUT[0] + .02, 'opacity:0', None), (EYES_SHUT[1], 'opacity:1', None),
    (WAKE - .03, 'opacity:1', None), (WAKE, 'opacity:0', None),
    (SMILE, 'opacity:0', None), (SMILE + .06, 'opacity:1', None),
    (H + .06, 'opacity:1', None), (H + .1, 'opacity:0', None), (T, 'opacity:0', None)]))
css.append(keyframes('sp-blush', [
    (0, 'opacity:0', None), (SMILE + .05, 'opacity:0', 'ease-out'), (SMILE + .5, 'opacity:1', None), (H, 'opacity:1', 'ease-in'), (H + .25, 'opacity:0', None), (T, 'opacity:0', None)]))
# alpana
css.append(keyframes('sp-alp', [
    (0, 'opacity:1;transform:none', None),
    (MOVE[0] - .05, 'opacity:1;transform:rotate(6deg)', 'cubic-bezier(.4,0,.8,.6)'),
    (MOVE[0] + .45, 'opacity:0;transform:rotate(10deg) scale(1.14)', None),
    (T, 'opacity:0;transform:scale(1.14)', None)]))
css.append('@keyframes sp-ring{from{opacity:0;transform:rotate(-50deg) scale(.86)}to{opacity:1;transform:none}}')
css.append('@keyframes sp-ring-r{from{opacity:0;transform:rotate(50deg) scale(.9)}to{opacity:1;transform:none}}')
css.append('@keyframes sp-draw{from{stroke-dashoffset:1}to{stroke-dashoffset:0}}')
css.append('@keyframes sp-fill{from{fill-opacity:0}to{fill-opacity:1}}')
css.append('@keyframes sp-in{from{opacity:0}to{opacity:1}}')
css.append('@keyframes sp-out{from{opacity:1}to{opacity:0}}')
css.append('@keyframes sp-dot{0%{opacity:0;transform:scale(0)}70%{opacity:1;transform:scale(1.25)}100%{opacity:1;transform:scale(1)}}')
# writing: feathered wipe + nib
wipe_w = text_w + 2 * FEATHER
we = 'cubic-bezier(%s)' % ','.join(str(v) for v in WRITE_EASE)
css.append(f'@keyframes sp-wipe{{from{{transform:translateX(0)}}to{{transform:translateX({f(wipe_w)}px)}}}}')
css.append(f'@keyframes sp-nib{{from{{transform:translateX({f(X0 - FEATHER / 2)}px)}}to{{transform:translateX({f(X1 + 1.5 * FEATHER)}px)}}}}')
css.append('@keyframes sp-pulse{0%,100%{opacity:.25;transform:scale(.8)}50%{opacity:1;transform:scale(1)}}')

C = []
C.append('.sp-root{position:absolute;inset:0;z-index:5}')
C.append(f'.sp-tile{{position:absolute;background:{PAPER};animation:sp-tile {T}s linear both}}')
for n in ('ay', 'as'):
    C.append(f'.sp-{n}{{transform-box:view-box;transform-origin:0 0;animation:sp-{n} {T}s linear both}}')
C.append(f'.sp-ax{{transform-box:view-box;transform-origin:0 0;animation:sp-ax {T}s linear both,sp-hide .01s linear {SWAP:.2f}s both}}')
C.append(f'.sp-fadeword{{animation:sp-out .4s cubic-bezier(.4,0,1,1) {H:.2f}s both}}')
C.append(f'.sp-dots{{animation:sp-leave .3s ease-in {H:.2f}s both}}')
css.append('@keyframes sp-hide{to{opacity:0}}@keyframes sp-show{from{opacity:0}to{opacity:1}}')
css.append('@keyframes sp-leave{from{opacity:1;transform:none}to{opacity:0;transform:translateY(6px)}}')
C.append(f'.sp-pop{{transform-box:view-box;transform-origin:0 53px;animation:sp-pop {T}s linear both}}')

C.append(f'.sp-open{{animation:sp-open {T}s linear both}}')
C.append(f'.sp-gaze{{transform-box:view-box;transform-origin:0 0;animation:sp-gaze {T}s linear both}}')
C.append(f'.sp-lid{{transform-box:view-box;transform-origin:0 -6px;animation:sp-lid {T}s linear both}}')
C.append(f'.sp-happy{{animation:sp-happy {T}s linear both}}')
C.append(f'.sp-blush{{animation:sp-blush {T}s linear both}}')
C.append(f'.sp-alp{{transform-box:view-box;transform-origin:{CX}px {CY}px;animation:sp-alp {T}s linear both}}')
C.append(f'.sp-ring{{transform-box:view-box;transform-origin:{CX}px {CY}px;animation:sp-ring .8s cubic-bezier(.2,.8,.2,1) .5s both}}')
C.append(f'.sp-ring-r{{transform-box:view-box;transform-origin:{CX}px {CY}px;animation:sp-ring-r .9s cubic-bezier(.2,.8,.2,1) .7s both}}')
C.append('.sp-petal{stroke-dasharray:1 1;fill-opacity:0}')
C.append('.sp-pdot{transform-box:fill-box;transform-origin:50% 50%}')
C.append('.sp-g{stroke-dasharray:1 1;fill-opacity:0}')
C.append(f'.sp-wipe{{animation:sp-wipe {WRITE[1] - WRITE[0]}s {we} {WRITE[0]}s both}}')
C.append(f'.sp-nib{{transform-box:view-box;transform-origin:0 0;animation:sp-nib {WRITE[1] - WRITE[0]}s {we} {WRITE[0]}s both,'
         f'sp-in .18s ease {WRITE[0] - .1}s both,sp-out .3s ease {WRITE[1] - .05}s forwards}}')
C.append(f'.sp-swash{{stroke-dasharray:1 1;animation:sp-draw {SWASH[1] - SWASH[0]}s cubic-bezier(.3,.1,.3,1) {SWASH[0]}s both}}')
C.append(f'.sp-bindi{{transform-box:fill-box;transform-origin:50% 50%;animation:sp-dot .42s cubic-bezier(.3,1.5,.5,1) {SWASH[1] - .06}s both}}')
C.append('.sp-dots{position:absolute;left:0;right:0;bottom:84px;display:flex;justify-content:center;gap:12px}')
C.append('.sp-dots i{width:8px;height:8px;border-radius:50%;display:block}')
for i, col in enumerate((RED, TURMERIC, INK)):
    C.append(f'.sp-dots i:nth-child({i + 1}){{background:{col};animation:sp-in .3s ease {DOTS + i * .1:.2f}s both,'
             f'sp-pulse 1.2s ease-in-out {DOTS + .3 + i * .18:.2f}s infinite}}')
C.append('@media (prefers-reduced-motion: reduce){.sp-root *{animation-delay:0s!important;animation-duration:1ms!important;animation-iteration-count:1!important}}')

# ---------- alpana (all in screen coords around CX, CY) ----------
alp = []
r_in, r_out = 124, 180
alp.append(f'<circle class="sp-ring" cx="{CX}" cy="{CY}" r="{r_in}" fill="none" stroke="{RED}" stroke-width="5.5" '
           f'stroke-linecap="round" stroke-dasharray="0 {f(2 * math.pi * r_in / 36)}"/>')
alp.append(f'<circle class="sp-ring-r" cx="{CX}" cy="{CY}" r="{r_out}" fill="none" stroke="{INK}" stroke-opacity=".55" stroke-width="3" '
           f'stroke-linecap="round" stroke-dasharray="0 {f(2 * math.pi * r_out / 72)}"/>')
# eight lotus petals, pointing out, drawn by a finger one after another (clockwise from the top)
PETAL = 'M0 0 C 21 -6 23 -30 0 -47 C -23 -30 -21 -6 0 0 Z'
SMALL = 'M0 0 C 10 -5 11 -17 0 -27 C -11 -17 -10 -5 0 0 Z'
VEIN = 'M0 -9 C 10 -13 11 -26 0 -35 C -11 -26 -10 -13 0 -9 Z'
for i in range(8):
    a = i * 45
    d0 = 0.78 + i * 0.07
    tr = f'rotate({a} {CX} {CY}) translate({CX} {CY - 132})'
    alp.append(f'<g transform="{tr}">'
               f'<path class="sp-petal" pathLength="1" d="{PETAL}" fill="{PAPER}" stroke="{RED}" stroke-width="3.4" stroke-linejoin="round" '
               f'style="animation:sp-draw .5s cubic-bezier(.4,0,.2,1) {d0:.2f}s both,sp-fill .3s ease {d0 + .35:.2f}s both"/>'
               f'<path class="sp-petal" pathLength="1" d="{VEIN}" fill="none" stroke="{RED}" stroke-width="2" stroke-linejoin="round" '
               f'style="animation:sp-draw .35s ease-out {d0 + .28:.2f}s both"/>'
               f''
               f'</g>')
    # turmeric dot between petals, and a small vermilion dot just outside it
    b = a + 22.5
    alp.append(f'<g transform="rotate({b} {CX} {CY})">'
               f'<g transform="translate({CX} {CY - 130})"><path class="sp-pdot" d="{SMALL}" fill="{TURMERIC}" style="animation:sp-dot .4s cubic-bezier(.3,1.5,.5,1) {1.12 + i * .05:.2f}s both"/></g>'
               f'<circle class="sp-pdot" cx="{CX}" cy="{CY - 166}" r="3" fill="{RED}" style="animation:sp-dot .35s cubic-bezier(.3,1.5,.5,1) {1.3 + i * .045:.2f}s both"/>'
               f'</g>')
alp_svg = f'<g class="sp-alp">{"".join(alp)}</g>'

# ---------- the a, layered for motion ----------
EYES_OPEN = f'<g fill="{INK}"><circle cx="-16" cy="-6" r="8"/><circle cx="16" cy="-6" r="8"/></g>'
EYES_HAPPY = (f'<path d="M-25 -3 Q-16 -14 -7 -3 M7 -3 Q16 -14 25 -3" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>')
BLUSH = f'<g fill="{RED}" fill-opacity=".22"><ellipse cx="-25" cy="12" rx="8" ry="4.5"/><ellipse cx="25" cy="12" rx="8" ry="4.5"/></g>'
a_svg = (f'<g class="sp-ax"><g class="sp-ay"><g class="sp-as"><g class="sp-pop"><g class="sp-breathe">'
         f'{A_BODY}'
         f'<g class="sp-blush">{BLUSH}</g>'
         f'<g class="sp-open"><g class="sp-gaze"><g class="sp-lid">{EYES_OPEN}</g></g></g>'
         f'<g class="sp-happy">{EYES_HAPPY}</g>'
         f'</g></g></g></g></g>')

# ---------- writing ----------
mask = (f'<mask id="sp-mask" maskUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{SH}">'
        f'<linearGradient id="sp-feather"><stop offset="0" stop-color="#fff"/><stop offset="{f(1 - FEATHER / wipe_w)}" stop-color="#fff"/>'
        f'<stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>'
        f'<rect class="sp-wipe" x="{f(X0 - wipe_w)}" y="{BASE - 70}" width="{f(wipe_w)}" height="110" fill="url(#sp-feather)"/></mask>')
g_out = []
dur = WRITE[1] - WRITE[0]
for d, col, bx0 in glyphs:
    frac = max(0.0, min(1.0, (bx0 - X0 + FEATHER * .5) / wipe_w))
    t0 = WRITE[0] + write_time_for(frac) * dur
    g_out.append(f'<path class="sp-g" pathLength="1" d="{d}" fill="{col}" stroke="{col}" stroke-width="1.1" stroke-linejoin="round" '
                 f'style="animation:sp-draw .6s ease-out {t0:.2f}s both,sp-fill .4s ease {t0 + .22:.2f}s both"/>')
word_svg = f'<g mask="url(#sp-mask)">{"".join(g_out)}</g>'
nib_svg = (f'<g class="sp-nib"><circle cx="0" cy="{BASE - 14}" r="9" fill="{TURMERIC}" fill-opacity=".22"/>'
           f'<circle cx="0" cy="{BASE - 14}" r="4.2" fill="{TURMERIC}"/></g>')

# ---------- swash: one tapered brushstroke, heavier toward its end (like a Kalighat outline) ----------
P0 = (X0 + 0.17 * text_w, BASE + 27)
P1 = (X0 + 0.45 * text_w, BASE + 41)
P2 = (X0 + 0.86 * text_w, BASE + 39)
P3 = (X1 + 1, BASE + 25)


def cub(t, a, b, c, d):
    return (1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * d


pts = []
N = 48
for i in range(N + 1):
    t = i / N
    x_ = cub(t, P0[0], P1[0], P2[0], P3[0])
    y_ = cub(t, P0[1], P1[1], P2[1], P3[1])
    pts.append((x_, y_))
left, right = [], []
for i, (px, py) in enumerate(pts):
    qx, qy = pts[min(i + 1, N)]
    rx, ry = pts[max(i - 1, 0)]
    dx, dy = qx - rx, qy - ry
    L = math.hypot(dx, dy) or 1
    nx, ny = -dy / L, dx / L
    t = i / N
    w = 5.4 * (math.sin(math.pi * min(1, t * 1.08)) ** 0.7) * (0.55 + 0.45 * t) + 0.35
    left.append((px + nx * w, py + ny * w))
    right.append((px - nx * w, py - ny * w))
shape = 'M' + ' L'.join(f'{f(a)} {f(b)}' for a, b in left) + ' L' + ' L'.join(f'{f(a)} {f(b)}' for a, b in reversed(right)) + ' Z'
centre = f'M{f(P0[0])} {f(P0[1])} C{f(P1[0])} {f(P1[1])} {f(P2[0])} {f(P2[1])} {f(P3[0])} {f(P3[1])}'
swash_svg = (f'<mask id="sp-swm" maskUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{SH}">'
             f'<path class="sp-swash" pathLength="1" d="{centre}" fill="none" stroke="#fff" stroke-width="16" stroke-linecap="round"/></mask>'
             f'<path d="{shape}" fill="{TURMERIC}" mask="url(#sp-swm)"/>'
             f'<circle class="sp-bindi" cx="{f(P3[0] + 10)}" cy="{f(P3[1] - 6)}" r="5.5" fill="{RED}"/>')

splash_svg = (f'<svg viewBox="0 0 {W} {SH}" width="{W}" height="{SH}" role="img" aria-label="ApneDoctors" '
              f'style="position:absolute;left:0;top:0;overflow:visible"><defs>{mask}</defs>'
              f'{alp_svg}<g class="sp-fadeword">{word_svg}{swash_svg}{nib_svg}</g>{a_svg}</svg>')


# ---------- the Welcome screen (N01), mounted under the splash and brought in by the hand-off ----------
import re as _re


def lockup(size, x, base, ids=''):
    """the logo a + "pne" (vermilion) + "Doctors" (ink): the ApneDoctors lockup, as SVG elements"""
    s_ = 0.92 * size / 106
    kk = size / upm
    b_ = hb.Buffer(); b_.add_str('pneDoctors'); b_.guess_segment_properties()
    hb.shape(font, b_, {'kern': True, 'liga': True, 'calt': True})
    lw = (A_BBOX[2] - A_BBOX[0]) * s_
    bx, by = x - A_BBOX[0] * s_, base + 1 - 53 * s_
    out = [f'<g transform="translate({f(bx)} {f(by)}) scale({s_:.4f})">{A_BODY}'
           f'<g fill="{INK}"><circle cx="-16" cy="-6" r="8"/><circle cx="16" cy="-6" r="8"/></g></g>']
    xx = x + lw + GAP * size / SIZE
    red, ink = SVGPathPen(gs), SVGPathPen(gs)
    for i_, (inf, po) in enumerate(zip(b_.glyph_infos, b_.glyph_positions)):
        gs[order[inf.codepoint]].draw(TransformPen(red if i_ < 3 else ink, (kk, 0, 0, -kk, xx + po.x_offset * kk, base - po.y_offset * kk)))
        xx += po.x_advance * kk
    out.append(f'<path d="{red.getCommands()}" fill="{RED}"/><path d="{ink.getCommands()}" fill="{INK}"/>')
    return ''.join(out), xx - x


BAR_SIZE = 25
bar_inner, bar_w = lockup(BAR_SIZE, 0, 31)
BAR_LOCKUP = (f'<svg class="brandmark" width="{f(bar_w + 2)}" height="44" viewBox="0 0 {f(bar_w + 2)} 44" role="img" aria-label="ApneDoctors">{bar_inner}</svg>')

wsrc = open(os.path.join(HERE, '..', 'project', 'N01Welcome.dc.html')).read()
WEL_CSS = _re.search(r'<style>(.*?)</style>', wsrc, _re.S).group(1).replace('body{margin:0}', '')
WEL_CSS = WEL_CSS.replace(".w .brandname{font-family:'Kaushan Script',cursive;font-weight:400;font-size:27px;line-height:1;color:#C8302B;transform:translateY(2px)}",
                          '.w .brandmark{display:block;margin-left:-1px}')
assert '.w .brandmark' in WEL_CSS
wbody = wsrc[wsrc.index('<div class="screen w"'):wsrc.rindex('</x-dc>')].strip()
wbody = _re.sub(r'<span class="brandname">ApneDoctors</span>|<svg class="brandmark".*?</svg>', lambda m_: BAR_LOCKUP, wbody, count=1, flags=_re.S)
assert 'brandmark' in wbody
# keep the Welcome board (N01) in step: its top bar shows the same lockup
_wfix = _re.sub(r'<span class="brandname">ApneDoctors</span>|<svg class="brandmark".*?</svg>', lambda m_: BAR_LOCKUP, wsrc, count=1, flags=_re.S)
_wfix = _wfix.replace(".w .brandname{font-family:'Kaushan Script',cursive;font-weight:400;font-size:27px;line-height:1;color:#C8302B;transform:translateY(2px)}",
                      '.w .brandmark{display:block;margin-left:-1px}')
open(os.path.join(HERE, '..', 'project', 'N01Welcome.dc.html'), 'w').write(_wfix)
_old = '<g class="open"><g class="eyes"><g class="lids"><circle cx="214" cy="124" r="8" fill="#1A1410"></circle><circle cx="246" cy="124" r="8" fill="#1A1410"></circle></g></g></g>'
assert _old in wbody
wbody = wbody.replace(_old, '<g class="open"><g class="peek">' + _old[len('<g class="open">'):] + '</g>')
WELCOME = f'<div class="hand">{wbody}</div>'


def spring(d, zeta=.8, omega=11.5, dur=1.1, n=34):
    """offset (px) from d down to 0 along a gently damped spring"""
    wd = omega * math.sqrt(1 - zeta * zeta)
    out = []
    for i_ in range(n + 1):
        t_ = dur * i_ / n
        x_ = 1 - math.exp(-zeta * omega * t_) * (math.cos(wd * t_) + zeta * omega / wd * math.sin(wd * t_))
        out.append((i_ / n, d * (1 - x_)))
    out[-1] = (1.0, 0.0)
    return out


RISE_D, RISE_DUR = 540, 1.1
h1_spring = spring(RISE_D, dur=RISE_DUR)
hand = ['.hand{position:absolute;left:0;top:0;width:390px;height:844px}',
        '.hand .screen.w{background:transparent}',
        '.hand .rise{animation:none}']


def kf_offsets(name, pts):
    return f'@keyframes {name}{{' + ''.join(f'{f(100 * p_)}%{{transform:translateY({f(o_)}px)}}' for p_, o_ in pts) + '}'


hand.append(kf_offsets('wl-rise', h1_spring))
# the hero rides on the headline: it waits at PUSH until the headline reaches it, then moves with it
hand.append(kf_offsets('wl-hero', [(p_, min(PUSH, o_)) for p_, o_ in h1_spring]))
hand.append(f'.hand .h1{{animation:wl-rise {RISE_DUR}s linear {RISE:.2f}s both}}')
hand.append(f'.hand .hero{{animation:wl-hero {RISE_DUR}s linear {RISE:.2f}s both}}')
for sel, lag in (('.lede', .06), ('.online', .12), ('.actions', .17)):
    hand.append(f'.hand {sel}{{animation:wl-rise {RISE_DUR}s linear {RISE + lag:.2f}s both}}')
# Welcome's own a appears exactly where the overlay a is, then glances down at the words pushing it
hand.append(f'.hand .arch .a-in{{animation:sp-show .01s linear {SWAP:.2f}s both}}')
hand.append('@keyframes wl-peek{0%,100%{transform:none}25%,70%{transform:translateY(4px)}}')
hand.append(f'.hand .arch .peek{{animation:wl-peek 1.3s ease-in-out {SWAP + .05:.2f}s both}}')
# then the doorway paints itself around it, and the usual Welcome life begins
A = ARCH
hand += [f'.hand .arch .band{{animation-delay:{A:.2f}s}}', f'.hand .arch .shade{{animation-delay:{A + .05:.2f}s}}',
         f'.hand .arch .inside{{animation-delay:{A + .2:.2f}s}}', f'.hand .arch .shadow{{animation-delay:{A:.2f}s}}',
         f'.hand .arch .dots{{animation-delay:{A + .95:.2f}s,{A + .95:.2f}s}}', f'.hand .arch .finial{{animation-delay:{A + .9:.2f}s}}',
         f'.hand .arch .toran{{animation-delay:{A + 1.05:.2f}s,{A + 1.05:.2f}s}}',
         f'.hand .arch .a-bow,.hand .arch .eyes,.hand .arch .happy,.hand .arch .open{{animation-delay:{A + 1.4:.2f}s}}',
         f'.hand .arch .lids{{animation-delay:{A + 1.9:.2f}s}}',
         f'.hand .arch .say2{{animation-delay:{A + 1.55:.2f}s,{A + 1.55:.2f}s}}',
         f'.hand .glow{{opacity:0;animation:sp-in .9s ease {A + .2:.2f}s both}}',
         f'.hand .bar{{animation:wl-bar .5s cubic-bezier(.2,.8,.2,1) {A + .1:.2f}s both}}',
         '@keyframes wl-bar{from{opacity:0;transform:translateY(-10px)}to{opacity:1;transform:none}}',
         f'.hand .btn .shine{{animation-delay:{A + 2.5:.2f}s}}']
WELCOME_CSS = WEL_CSS + '\n'.join(hand)

overlay = (f'<div class="sp-root"><div class="sp-tile"></div>{WELCOME}{splash_svg}'
           f'<div class="sp-dots" aria-hidden="true"><i></i><i></i><i></i></div></div>')

# ---------- home screen (the phone, before the tap) ----------
ICON_SVG = (f'<svg viewBox="0 0 1024 1024" width="{IS}" height="{IS}" aria-hidden="true"><g transform="translate(-479.2 -34.0) scale(4.2)">'
            f'<g stroke="{RED}" stroke-width="16" stroke-linecap="round" fill="none"><circle cx="230" cy="130" r="45"/><path d="M275 86 V156 Q275 176 294 176"/></g>'
            f'<circle cx="214" cy="124" r="8" fill="{INK}"/><circle cx="246" cy="124" r="8" fill="{INK}"/></g></svg>')
cols = [27, 119, 211, 303]
rows = [84, 186, 288 - 12, 378]
rows = [84, 180, 276, 372, 468]
home = []
for ri, ry in enumerate(rows):
    for ci, cx in enumerate(cols):
        if (cx, ry) == (IX, IY):
            continue
        lw = [34, 26, 40, 30, 22, 38][(ri * 4 + ci) % 6]
        home.append(f'<div class="hm-ic" style="left:{cx}px;top:{ry}px"></div>'
                    f'<div class="hm-lb" style="left:{cx + 30 - lw / 2}px;top:{ry + 70}px;width:{lw}px"></div>')
home_html = (
    '<div class="hm">'
    '<div class="hm-status"><span>9:41</span><svg width="64" height="12" viewBox="0 0 64 12" aria-hidden="true">'
    '<g fill="#FBF7EF"><rect x="0" y="7" width="3" height="5" rx="1"/><rect x="5" y="5" width="3" height="7" rx="1"/><rect x="10" y="2.5" width="3" height="9.5" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/>'
    '<rect x="38" y="1" width="22" height="10" rx="3" fill="none" stroke="#FBF7EF" stroke-opacity=".5"/><rect x="40" y="3" width="15" height="6" rx="1.5"/><rect x="61" y="4" width="2" height="4" rx="1" fill-opacity=".5"/></g></svg></div>'
    + ''.join(home) +
    f'<button class="hm-app" aria-label="Open ApneDoctors" onClick="{{{{openApp}}}}" style="left:{IX}px;top:{IY}px">'
    f'<span class="hm-tile">{ICON_SVG}</span><span class="hm-name">ApneDoctors</span></button>'
    '<div class="hm-hint">Tap ApneDoctors to open</div>'
    '<div class="hm-dock"><i></i><i></i><i></i><i></i></div>'
    '</div>')

HOME_CSS = f'''
.board{{width:560px;height:1020px;box-sizing:border-box;padding:40px 0;background:#EFE6D6;display:flex;flex-direction:column;align-items:center;gap:22px;font-family:'Anek Latin',sans-serif;color:{INK}}}
.phone{{width:410px;height:864px;box-sizing:border-box;border:10px solid {INK};border-radius:54px;position:relative;overflow:hidden;background:#21283F}}
.hm{{position:absolute;inset:0;background:radial-gradient(120% 70% at 50% 8%,#4A5C9C 0%,#2A3358 46%,{INK} 100%)}}
.hm::after{{content:'';position:absolute;left:50%;top:560px;width:420px;height:420px;margin-left:-210px;border-radius:50%;
  background:radial-gradient(circle,rgba(239,177,42,.18),rgba(239,177,42,0) 62%)}}
.hm-status{{position:absolute;left:30px;right:26px;top:16px;display:flex;justify-content:space-between;align-items:center;color:{PAPER};font-size:15px;font-weight:700;font-family:system-ui,-apple-system,sans-serif}}
.hm-ic{{position:absolute;width:60px;height:60px;border-radius:14px;background:rgba(251,247,239,.13)}}
.hm-lb{{position:absolute;height:5px;border-radius:3px;background:rgba(251,247,239,.2)}}
.hm-app{{position:absolute;z-index:2;width:60px;border:0;padding:0;margin:0;background:none;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:6px;font:inherit}}
.hm-app:focus-visible{{outline:3px solid {TURMERIC};outline-offset:6px;border-radius:16px}}
.hm-tile{{display:block;width:60px;height:60px;border-radius:14px;background:{PAPER};overflow:hidden;box-shadow:0 6px 18px rgba(0,0,0,.28);animation:hm-hint 2s ease-in-out infinite}}
.hm-name{{display:block;width:84px;text-align:center;font-family:system-ui,-apple-system,sans-serif;font-size:11px;line-height:14px;font-weight:500;color:{PAPER};white-space:nowrap}}
@keyframes hm-hint{{0%,100%{{box-shadow:0 6px 18px rgba(0,0,0,.28),0 0 0 0 rgba(239,177,42,0)}}50%{{box-shadow:0 6px 18px rgba(0,0,0,.28),0 0 0 8px rgba(239,177,42,.45)}}}}
.hm-hint{{position:absolute;left:0;right:0;bottom:132px;text-align:center;font-size:17px;font-weight:600;color:{PAPER};opacity:.85}}
.hm-dock{{position:absolute;left:14px;right:14px;bottom:18px;height:90px;border-radius:32px;background:rgba(251,247,239,.12);display:flex;justify-content:space-around;align-items:center}}
.hm-dock i{{width:60px;height:60px;border-radius:14px;background:rgba(251,247,239,.14)}}
.ctl{{display:flex;gap:12px}}
.ctl button{{height:48px;padding:0 22px;border-radius:24px;font:inherit;font-size:17px;font-weight:700;cursor:pointer}}
.ctl .go{{border:0;background:{RED};color:{PAPER}}}
.ctl .back{{border:1.5px solid {INK};background:transparent;color:{INK}}}
.ctl button:focus-visible{{outline:3px solid {TURMERIC};outline-offset:3px}}
@media (prefers-reduced-motion: reduce){{.hm-tile{{animation:none}}}}
'''

STYLE = HOME_CSS + '\n'.join(css) + '\n' + '\n'.join(C) + '\n' + WELCOME_CSS

dc = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Opening into Welcome</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="kp.css">
</head>
<body>
<x-dc>
<helmet>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Anek+Latin:wdth,wght@75..125,400..800&amp;display=swap">
<style>body{{margin:0}}{STYLE}</style>
</helmet>
<div class="board">
<div class="phone">
{home_html}
<sc-if value="{{{{open}}}}" hint-placeholder-val="{{{{ false }}}}">
{overlay}
</sc-if>
</div>
<div class="ctl"><button class="go" onClick="{{{{replay}}}}">Replay opening</button><button class="back" onClick="{{{{home}}}}">Back to home screen</button></div>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"start":{{"editor":"enum","options":["Home screen","Opening"],"default":"Home screen"}},"$preview":{{"width":560,"height":1020}}}}'>
class Component extends DCLogic {{
state = {{ open: null }};
componentWillUnmount() {{ clearTimeout(this._t); }}
renderVals() {{
const s = this.state && this.state.open;
const open = s === null || s === undefined ? (this.props.start === 'Opening') : s;
return {{
open: !!open,
openApp: () => this.setState({{ open: true }}),
replay: () => {{ clearTimeout(this._t); this.setState({{ open: false }}); this._t = setTimeout(() => this.setState({{ open: true }}), 60); }},
home: () => {{ clearTimeout(this._t); this.setState({{ open: false }}); }}
}};
}}
}}
</script>
</body>
</html>
'''
open(OUT, 'w').write(dc)

# local render: board with the overlay mounted (animations start on load)
KP = open(os.path.join(HERE, '..', 'project', 'kp.css')).read()
test = (f'<html><head><style>{KP}</style><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Anek+Latin:wdth,wght@75..125,400..800&display=swap">'
        f'<style>body{{margin:0}}{STYLE}</style></head><body><div class="board"><div class="phone">'
        f'{home_html.replace("{{openApp}}", "")}{overlay}</div></div></body></html>')
open(TEST, 'w').write(test)
print('text_w', round(text_w, 1), 'X0', round(X0, 1), 'X1', round(X1, 1), 'fin', round(FIN_BX, 1), round(FIN_BY, 1), round(FIN_S, 3))
