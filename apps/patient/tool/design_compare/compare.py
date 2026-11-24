"""Compare board frames with app frames: per-frame diff stats and side-by-side sheets."""
import sys, os
from PIL import Image, ImageChops, ImageDraw
board, app, out = sys.argv[1], sys.argv[2], sys.argv[3]
start = float(sys.argv[4]) if len(sys.argv) > 4 else 0.55
fps = 60
os.makedirs(out, exist_ok=True)
names = sorted(f for f in os.listdir(app) if f.endswith('.png'))
rows = []
for n in names:
    i = int(n[2:6]); t = i / fps
    if t < start or not os.path.exists(os.path.join(board, n)): continue
    a = Image.open(os.path.join(board, n)).convert('RGB')
    b = Image.open(os.path.join(app, n)).convert('RGB')
    if a.size != b.size: b = b.resize(a.size)
    d = ImageChops.difference(a, b).convert('L')
    hist = d.histogram()
    tot = sum(hist)
    mean = sum(k * v for k, v in enumerate(hist)) / tot
    big = sum(hist[40:]) / tot * 100
    rows.append((t, mean, big, n))
with open(os.path.join(out, 'stats.tsv'), 'w') as f:
    for t, m, bg, n in rows: f.write(f'{t:.3f}\t{m:.3f}\t{bg:.3f}\n')
worst = sorted(rows, key=lambda r: -r[2])[:8]
print('frames', len(rows), 'mean diff', round(sum(r[1] for r in rows) / len(rows), 3), 'mean %px>40', round(sum(r[2] for r in rows) / len(rows), 3))
print('worst:', [(round(t, 2), round(bg, 2)) for t, m, bg, n in worst])
def sheet(n, label):
    a = Image.open(os.path.join(board, n)).convert('RGB'); b = Image.open(os.path.join(app, n)).convert('RGB')
    d = ImageChops.difference(a, b)
    d = Image.eval(d, lambda v: min(255, v * 4))
    W, H = a.size
    s = Image.new('RGB', (W * 3 + 20, H + 30), (255, 255, 255))
    s.paste(a, (0, 30)); s.paste(b, (W + 10, 30)); s.paste(d, (2 * W + 20, 30))
    dr = ImageDraw.Draw(s); dr.text((4, 8), f'board  t={label}', fill=(0, 0, 0)); dr.text((W + 14, 8), 'app', fill=(0, 0, 0)); dr.text((2 * W + 24, 8), 'diff x4', fill=(0, 0, 0))
    s.save(os.path.join(out, f'sheet_{label}.png'))
for t in [float(x) for x in (sys.argv[5].split(',') if len(sys.argv) > 5 else [])]:
    sheet(f'f_{round(t * fps):04d}.png', f'{t:.2f}')
