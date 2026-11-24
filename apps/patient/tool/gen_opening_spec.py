"""Generate the opening's motion spec for Flutter from the same maths as the design board.

The design board docs/design/kalighat-pop/N00Splash.dc.html is written by gen/splash.py. This script
repeats that file's computations (same constants, same rounding, same Kaushan Script outlines via HarfBuzz)
and writes them as Dart, so the app and the board share one source of truth:

  lib/features/opening/opening_spec.g.dart   keyframe tracks, glyph outlines and start times, swash, springs
  lib/core/brand/lockup_glyphs.g.dart        the "a" + "pne" + "Doctors" lockup used in the Welcome top bar

Run from apps/patient:  python3 tool/gen_opening_spec.py
Needs: pip install uharfbuzz fonttools
"""
import math
import os
import re

import uharfbuzz as hb
from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
FONT = os.path.join(APP, 'assets', 'fonts', 'KaushanScript-Regular.ttf')
OUT_SPEC = os.path.join(APP, 'lib', 'features', 'opening', 'opening_spec.g.dart')
OUT_LOCKUP = os.path.join(APP, 'lib', 'core', 'brand', 'lockup_glyphs.g.dart')

W, SH = 390, 844
T = 9.2


def f(v):
    """splash.py's number format: 2 decimals, trailing zeros dropped. CSS reads these values."""
    return ('%.2f' % v).rstrip('0').rstrip('.')


def ff(v):
    return float(f(v))


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

    def x_at_y(y):
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

A_BBOX = (-53, -52, 72, 54)
A_CX = (A_BBOX[0] + A_BBOX[2]) / 2
A_CY = (A_BBOX[1] + A_BBOX[3]) / 2

IX, IY, IS = 211, 276, 60
ICON_S = 4.2 * IS / 1024
ICON_BX, ICON_BY = IX + (230 * 4.2 - 479.2) * IS / 1024, IY + (130 * 4.2 - 34) * IS / 1024
CX, CY = 195, 404
HERO_S = 1.4
HERO_BX, HERO_BY = CX - A_CX * HERO_S, CY - A_CY * HERO_S

SIZE, BASE = 54, 432
blob = hb.Blob.from_file_path(FONT)
face = hb.Face(blob)
font = hb.Font(face)
upm = face.upem
tt = TTFont(FONT)
gs = tt.getGlyphSet()
order = tt.getGlyphOrder()
k = SIZE / upm


def shape(text):
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf, {'kern': True, 'liga': True, 'calt': True})
    return buf


buf = shape('pneDoctors')
text_w = sum(p.x_advance for p in buf.glyph_positions) * k
FIN_S = 0.92 * SIZE / 106
logo_w = (A_BBOX[2] - A_BBOX[0]) * FIN_S
GAP = 0.5
X = (W - (logo_w + GAP + text_w)) / 2
FIN_BX = X - A_BBOX[0] * FIN_S
FIN_BY = BASE + 1 - 53 * FIN_S
X0 = X + logo_w + GAP
X1 = X0 + text_w


class OpsPen(BasePen):
    """Records a glyph as flat path ops: 0 M x y, 1 L x y, 2 Q x1 y1 x y, 3 C x1 y1 x2 y2 x y, 4 Z."""

    def __init__(self, glyphset):
        super().__init__(glyphset)
        self.ops = []

    def _moveTo(self, p):
        self.ops += [0, *p]

    def _lineTo(self, p):
        self.ops += [1, *p]

    def _qCurveToOne(self, p1, p2):
        self.ops += [2, *p1, *p2]

    def _curveToOne(self, p1, p2, p3):
        self.ops += [3, *p1, *p2, *p3]

    def _closePath(self):
        self.ops += [4]

    def _endPath(self):
        pass


glyphs = []
x = X0
for i, (info, pos) in enumerate(zip(buf.glyph_infos, buf.glyph_positions)):
    name = order[info.codepoint]
    ox, oy = x + pos.x_offset * k, BASE - pos.y_offset * k
    t = (k, 0, 0, -k, ox, oy)
    pen = OpsPen(gs)
    gs[name].draw(TransformPen(pen, t))
    bp = BoundsPen(gs)
    gs[name].draw(TransformPen(bp, t))
    bx0 = bp.bounds[0] if bp.bounds else ox
    glyphs.append((pen.ops, i < 3, bx0))
    x += pos.x_advance * k

# ---------- timeline (exactly splash.py) ----------
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
H = 5.55
GLIDE = (H + 0.1, H + 0.95)
SWAP = GLIDE[1] + 0.02
RISE = H + 0.8
ARCH = H + 1.85
WEL_S = 1.05
WEL_BX, WEL_BY = 25 + 80 + (230 - 156) * 1.05, 66.72 + 176 + (130 - 50) * 1.05
MID_BY = 432
PUSH = MID_BY - WEL_BY

EXP_EASE = 'cubic-bezier(.22,.8,.22,1)'
xe, ye = 'cubic-bezier(.62,0,.24,1)', 'cubic-bezier(.36,0,.16,1)'
xe2, ye2 = 'cubic-bezier(.3,0,.25,1)', 'cubic-bezier(.6,0,.25,1)'

TRACKS = {
    # name: (param schema, frames)
    'aX': ('tx', [
        (0, f'transform:translateX({f(ICON_BX)}px)', EXP_EASE),
        (EXPAND, f'transform:translateX({f(HERO_BX)}px)', None),
        (MOVE[0], f'transform:translateX({f(HERO_BX)}px)', xe),
        (MOVE[1], f'transform:translateX({f(FIN_BX)}px)', None),
        (GLIDE[0], f'transform:translateX({f(FIN_BX)}px)', ye2),
        (GLIDE[1], f'transform:translateX({f(WEL_BX)}px)', None),
        (T, f'transform:translateX({f(WEL_BX)}px)', None)]),
    'aY': ('ty', [
        (0, f'transform:translateY({f(ICON_BY)}px)', EXP_EASE),
        (EXPAND, f'transform:translateY({f(HERO_BY)}px)', None),
        (MOVE[0], f'transform:translateY({f(HERO_BY)}px)', ye),
        (MOVE[1], f'transform:translateY({f(FIN_BY)}px)', None),
        (GLIDE[0], f'transform:translateY({f(FIN_BY)}px)', xe2),
        (GLIDE[1], f'transform:translateY({f(MID_BY)}px)', None),
        (T, f'transform:translateY({f(MID_BY)}px)', None)]),
    'aScale': ('s', [
        (0, f'transform:scale({ICON_S:.4f})', EXP_EASE),
        (EXPAND, f'transform:scale({HERO_S})', None),
        (MOVE[0], f'transform:scale({HERO_S})', xe),
        (MOVE[1], f'transform:scale({FIN_S:.4f})', None),
        (GLIDE[0], f'transform:scale({FIN_S:.4f})', 'cubic-bezier(.5,0,.2,1)'),
        (GLIDE[1], f'transform:scale({WEL_S})', None),
        (T, f'transform:scale({WEL_S})', None)]),
    'pop': ('pop', [
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
        (T, 'transform:none', None)]),
    'open': ('o', [
        (0, 'opacity:1', None), (EYES_SHUT[0], 'opacity:1', None), (EYES_SHUT[0] + .04, 'opacity:0', None),
        (WAKE - .01, 'opacity:0', None), (WAKE, 'opacity:1', None),
        (SMILE - .02, 'opacity:1', None), (SMILE + .03, 'opacity:0', None),
        (H + .06, 'opacity:0', None), (H + .1, 'opacity:1', None), (T, 'opacity:1', None)]),
    'lid': ('sy', [
        (0, 'transform:scaleY(1)', 'ease-in'), (EYES_SHUT[0], 'transform:scaleY(.15)', None),
        (WAKE, 'transform:scaleY(.12)', 'cubic-bezier(.2,.9,.3,1.25)'), (WAKE + .2, 'transform:scaleY(1)', None),
        (BLINK, 'transform:scaleY(1)', 'ease-in'), (BLINK + .07, 'transform:scaleY(.1)', 'ease-out'),
        (BLINK + .16, 'transform:scaleY(1)', None), (T, 'transform:scaleY(1)', None)]),
    'gaze': ('txy', [
        (0, 'transform:none', None), (WAKE + .25, 'transform:none', 'ease-in-out'),
        (WAKE + .4, 'transform:translate(-3px,-1px)', None),
        (MOVE[0] - .15, 'transform:translate(-3px,-1px)', 'ease-in-out'),
        (MOVE[0] + .05, 'transform:translate(-7px,1px)', None),
        (MOVE[1] - .1, 'transform:translate(-7px,1px)', 'ease-in-out'),
        (WRITE[0] + .25, 'transform:translate(3px,1px)', 'cubic-bezier(.42,.1,.58,.92)'),
        (WRITE[1], 'transform:translate(8px,2px)', None),
        (H + .08, 'transform:translate(0,-3px)', 'ease-in-out'),
        (GLIDE[1] - .2, 'transform:none', None),
        (T, 'transform:none', None)]),
    'happy': ('o', [
        (0, 'opacity:0', None), (EYES_SHUT[0] + .02, 'opacity:0', None), (EYES_SHUT[1], 'opacity:1', None),
        (WAKE - .03, 'opacity:1', None), (WAKE, 'opacity:0', None),
        (SMILE, 'opacity:0', None), (SMILE + .06, 'opacity:1', None),
        (H + .06, 'opacity:1', None), (H + .1, 'opacity:0', None), (T, 'opacity:0', None)]),
    'blush': ('o', [
        (0, 'opacity:0', None), (SMILE + .05, 'opacity:0', 'ease-out'), (SMILE + .5, 'opacity:1', None),
        (H, 'opacity:1', 'ease-in'), (H + .25, 'opacity:0', None), (T, 'opacity:0', None)]),
    'alp': ('alp', [
        (0, 'opacity:1;transform:none', None),
        (MOVE[0] - .05, 'opacity:1;transform:rotate(6deg)', 'cubic-bezier(.4,0,.8,.6)'),
        (MOVE[0] + .45, 'opacity:0;transform:rotate(10deg) scale(1.14)', None),
        (T, 'opacity:0;transform:scale(1.14)', None)]),
}

DIMS = {'tx': 1, 'ty': 1, 's': 1, 'o': 1, 'sy': 1, 'txy': 2, 'pop': 4, 'alp': 3}


def parse_decl(schema, decl):
    props = dict(p.split(':', 1) for p in decl.split(';'))
    fns = re.findall(r'(\w+)\(([^)]*)\)', props.get('transform', 'none'))
    nums = [[float(v.replace('px', '').replace('deg', '')) for v in a.split(',')] for _, a in fns]
    names = [n for n, _ in fns]
    if schema == 'o':
        return [float(props['opacity'])]
    if schema in ('tx', 'ty', 's', 'sy'):
        return [nums[0][0]] if names else [1.0 if schema in ('s', 'sy') else 0.0]
    if schema == 'txy':
        return [nums[0][0], nums[0][1]] if names else [0.0, 0.0]
    if schema == 'pop':  # matrix = translate(pre) . scale(sx, sy) . translate(post)
        pre, sx, sy, post = 0.0, 1.0, 1.0, 0.0
        seen_scale = False
        for n, a in zip(names, nums):
            if n == 'scale':
                sx, sy = a[0], a[-1]
                seen_scale = True
            elif n == 'translateY':
                if seen_scale:
                    post = a[0]
                else:
                    pre = a[0]
        return [pre, sx, sy, post]
    if schema == 'alp':  # opacity, rotate(deg), scale
        rot, sc = 0.0, 1.0
        for n, a in zip(names, nums):
            if n == 'rotate':
                rot = a[0]
            elif n == 'scale':
                sc = a[0]
        return [float(props['opacity']), rot, sc]
    raise ValueError(schema)


NAMED = {'ease': (.25, .1, .25, 1), 'ease-in': (.42, 0, 1, 1), 'ease-out': (0, 0, .58, 1), 'ease-in-out': (.42, 0, .58, 1)}


def dart_curve(ease):
    if ease is None:
        return 'null'
    if ease in NAMED:
        a = NAMED[ease]
    else:
        a = [float(v) for v in re.match(r'cubic-bezier\(([^)]*)\)', ease).group(1).split(',')]
    return 'Cubic(%s)' % ', '.join(repr(float(v)) for v in a)


def num(v):
    r = repr(float(v))
    return r


def dart_track(name, schema, frames):
    offs, vals, curves = [], [], []
    for t, decl, ease in frames:
        offs.append(float(f(100 * t / T)) / 100)  # the board's keyframe percentages, as rounded in the CSS
        vals += parse_decl(schema, decl)
        curves.append(dart_curve(ease))
    return (f'  static final {name} = Keyframes(\n'
            f'    dim: {DIMS[schema]},\n'
            f'    offsets: [{", ".join(num(o) for o in offs)}],\n'
            f'    values: [{", ".join(num(v) for v in vals)}],\n'
            f'    curves: [{", ".join(curves)}],\n'
            f'  );\n')


# ---------- swash ----------
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
    pts.append((cub(t, P0[0], P1[0], P2[0], P3[0]), cub(t, P0[1], P1[1], P2[1], P3[1])))
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
swash_poly = [ff(v) for p in (left + list(reversed(right))) for v in p]
swash_centre = [ff(v) for v in (*P0, *P1, *P2, *P3)]
bindi = (ff(P3[0] + 10), ff(P3[1] - 6))

# ---------- glyph timing against the eased wipe ----------
wipe_w = text_w + 2 * FEATHER
dur = WRITE[1] - WRITE[0]
glyph_lines = []
for ops, red, bx0 in glyphs:
    frac = max(0.0, min(1.0, (bx0 - X0 + FEATHER * .5) / wipe_w))
    t0 = WRITE[0] + write_time_for(frac) * dur
    glyph_lines.append(
        f'    GlyphSpec(red: {"true" if red else "false"}, draw: {float("%.2f" % t0)}, fill: {float("%.2f" % (t0 + .22))}, '
        f'ops: [{", ".join(num(v) for v in ops)}]),')


# ---------- the Welcome rise springs ----------
def spring(d, zeta=.8, omega=11.5, dur=1.1, n=34):
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
rise_offs = [float(f(100 * p)) / 100 for p, _ in h1_spring]
rise_vals = [ff(o) for _, o in h1_spring]
hero_vals = [ff(min(PUSH, o)) for _, o in h1_spring]


def d2(v):
    return float('%.2f' % v)


petals = [(d2(.78 + i * .07), d2(.78 + i * .07 + .35), d2(.78 + i * .07 + .28)) for i in range(8)]
pdots = [(d2(1.12 + i * .05), d2(1.3 + i * .045)) for i in range(8)]
A_ = ARCH
hand = {
    'band': d2(A_), 'shade': d2(A_ + .05), 'inside': d2(A_ + .2), 'shadow': d2(A_), 'dots': d2(A_ + .95),
    'finial': d2(A_ + .9), 'toran': d2(A_ + 1.05), 'face': d2(A_ + 1.4), 'lids': d2(A_ + 1.9), 'say': d2(A_ + 1.55),
    'glow': d2(A_ + .2), 'bar': d2(A_ + .1), 'shine': d2(A_ + 2.5), 'aIn': d2(SWAP), 'peek': d2(SWAP + .05),
    'rise': d2(RISE), 'riseLede': d2(RISE + .06), 'riseOnline': d2(RISE + .12), 'riseActions': d2(RISE + .17),
}

spec = f'''// GENERATED by tool/gen_opening_spec.py from the design board's own maths (gen/splash.py). Do not edit.
// ignore_for_file: constant_identifier_names, prefer_const_constructors, lines_longer_than_80_chars
import 'package:flutter/animation.dart';

import '../../core/motion/keyframes.dart';

class GlyphSpec {{
  const GlyphSpec({{required this.red, required this.draw, required this.fill, required this.ops}});
  final bool red;
  final double draw;
  final double fill;
  final List<double> ops;
}}

/// Every number of the opening, in the board's 390 x 844 space.
abstract final class OpeningSpec {{
  static const double boardW = {num(W)};
  static const double boardH = {num(SH)};
  static const double duration = {num(T)};

  // beats (s)
  static const double expand = {num(EXPAND)};
  static const double wake = {num(WAKE)};
  static const double blink = {num(BLINK)};
  static const double moveStart = {num(MOVE[0])};
  static const double moveEnd = {num(MOVE[1])};
  static const double writeStart = {num(WRITE[0])};
  static const double writeEnd = {num(WRITE[1])};
  static const double swashStart = {num(SWASH[0])};
  static const double swashEnd = {num(SWASH[1])};
  static const double smile = {num(SMILE)};
  static const double dots = {num(DOTS)};
  static const double handoff = {num(H)};
  static const double glideStart = {num(GLIDE[0])};
  static const double glideEnd = {num(GLIDE[1])};
  static const double swap = {num(float('%.2f' % SWAP))};
  static const double rise = {num(RISE)};
  static const double arch = {num(ARCH)};

  // poses of the "a" (its bowl centre, in board space) and scale
  static const double iconBx = {f(ICON_BX)}, iconBy = {f(ICON_BY)}, iconS = {ICON_S:.4f};
  static const double heroBx = {f(HERO_BX)}, heroBy = {f(HERO_BY)}, heroS = {num(HERO_S)};
  static const double finBx = {f(FIN_BX)}, finBy = {f(FIN_BY)}, finS = {FIN_S:.4f};
  static const double welBx = {f(WEL_BX)}, welBy = {f(WEL_BY)}, welS = {num(WEL_S)};
  static const double midBy = {num(MID_BY)};
  static const double push = {num(PUSH)};

  // alpana
  static const double cx = {num(CX)}, cy = {num(CY)};
  static const double ringIn = 124, ringOut = 180;
  static const List<(double, double, double)> petals = [{", ".join(f"({a}, {b}, {c})" for a, b, c in petals)}];
  static const List<(double, double)> petalDots = [{", ".join(f"({a}, {b})" for a, b in pdots)}];

  // wordmark
  static const double base = {num(BASE)};
  static const double x0 = {num(X0)}, x1 = {num(X1)};
  static const double feather = {num(FEATHER)};
  static const double wipeW = {f(wipe_w)};
  static const double maskX = {f(X0 - wipe_w)}, maskY = {num(BASE - 70)}, maskH = 110;
  static const double featherStop = {f(1 - FEATHER / wipe_w)};
  static const double nibFrom = {f(X0 - FEATHER / 2)}, nibTo = {f(X1 + 1.5 * FEATHER)};
  static const writeCurve = Cubic({", ".join(num(v) for v in WRITE_EASE)});
  static const List<GlyphSpec> glyphs = [
{chr(10).join(glyph_lines)}
  ];

  // swash and bindi
  static const List<double> swashShape = [{", ".join(num(v) for v in swash_poly)}];
  static const List<double> swashCentre = [{", ".join(num(v) for v in swash_centre)}];
  static const double bindiX = {num(bindi[0])}, bindiY = {num(bindi[1])};

  // hand-off delays into Welcome (s)
{chr(10).join(f"  static const double hand{k_[0].upper()}{k_[1:]} = {num(v)};" for k_, v in hand.items())}

  // the Welcome copy rises on a sampled spring (CSS keyframes, linear between samples)
  static const List<double> riseOffsets = [{", ".join(num(v) for v in rise_offs)}];
  static const List<double> riseValues = [{", ".join(num(v) for v in rise_vals)}];
  static const List<double> heroValues = [{", ".join(num(v) for v in hero_vals)}];
  static const double riseDuration = {num(RISE_DUR)};
}}

/// The board's 9.2 s keyframe tracks (offsets are fractions of [OpeningSpec.duration]).
abstract final class OpeningTracks {{
{"".join(dart_track(n, s, fr) for n, (s, fr) in TRACKS.items())}}}
'''
os.makedirs(os.path.dirname(OUT_SPEC), exist_ok=True)
open(OUT_SPEC, 'w').write(spec)

# ---------- lockup for the Welcome top bar (BAR_SIZE 25, x 0, baseline 31) ----------
BAR_SIZE, BAR_BASE = 25, 31
s_ = 0.92 * BAR_SIZE / 106
kk = BAR_SIZE / upm
b_ = shape('pneDoctors')
lw = (A_BBOX[2] - A_BBOX[0]) * s_
bx, by = 0 - A_BBOX[0] * s_, BAR_BASE + 1 - 53 * s_
xx = lw + GAP * BAR_SIZE / SIZE
red, ink = OpsPen(gs), OpsPen(gs)
for i_, (inf, po) in enumerate(zip(b_.glyph_infos, b_.glyph_positions)):
    gs[order[inf.codepoint]].draw(TransformPen(red if i_ < 3 else ink, (kk, 0, 0, -kk, xx + po.x_offset * kk, BAR_BASE - po.y_offset * kk)))
    xx += po.x_advance * kk
bar_w = xx
lockup = f'''// GENERATED by tool/gen_opening_spec.py (Kaushan Script outlines via HarfBuzz). Do not edit.
// ignore_for_file: lines_longer_than_80_chars

/// The ApneDoctors lockup as drawn in the Welcome top bar: the logo "a" stands in for the capital A,
/// then "pne" (vermilion) and "Doctors" (ink). Units are CSS px of the 25 px lockup; the box is
/// [width] x 44 with the baseline at 31.
abstract final class LockupGlyphs {{
  static const double width = {f(bar_w + 2)};
  static const double height = 44;
  static const double logoX = {f(bx)}, logoY = {f(by)}, logoScale = {s_:.4f};
  static const List<double> pne = [{", ".join(num(v) for v in red.ops)}];
  static const List<double> doctors = [{", ".join(num(v) for v in ink.ops)}];
}}
'''
os.makedirs(os.path.dirname(OUT_LOCKUP), exist_ok=True)
open(OUT_LOCKUP, 'w').write(lockup)
import shutil
import subprocess

if shutil.which('dart'):
    subprocess.run(['dart', 'format', '-l', '120', OUT_SPEC, OUT_LOCKUP], check=False, capture_output=True)
print('ok: text_w %.1f X0 %.1f X1 %.1f fin %.1f %.1f %.3f push %.2f bar_w %.2f' % (text_w, X0, X1, FIN_BX, FIN_BY, FIN_S, PUSH, bar_w))
