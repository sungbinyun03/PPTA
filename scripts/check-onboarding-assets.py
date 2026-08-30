#!/usr/bin/env python3
"""
Geometry + color gate for generated onboarding illustrations.

Checks the mechanical half of docs/onboarding-asset-prompts.md §2. It cannot judge whether a
drawing looks hand-drawn — that still needs eyes — but it catches the round-1 failures that were
purely numeric (art running off the canvas, thin bands, off-centre subjects, stray color).

    python3 scripts/check-onboarding-assets.py ~/Downloads/ppta-onboarding-assets
"""
import sys, os, glob

try:
    from PIL import Image
except ImportError:
    sys.exit("needs Pillow:  pip3 install --user Pillow")

# asset -> expected canvas edge
EXPECTED = {
    "onb-the-key": 2048, "onb-pick-apps": 2048, "onb-find-coach": 2048,
    "onb-the-loop": 1024, "onb-waiting": 1024,
}
MIN_MARGIN = 11.0     # percent, all four sides
FILL_RANGE = (60.0, 80.0)   # percent of canvas the subject should span
BALANCE_TOL = 4.0     # percent, opposing margins must be within this


def analyse(path, step=4):
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    px = im.load()
    minx, miny, maxx, maxy = W, H, -1, -1
    ink = colored = 0
    for y in range(0, H, step):
        for x in range(0, W, step):
            r, g, b, a = px[x, y]
            if a <= 128:
                continue
            if max(r, g, b) - min(r, g, b) > 24:
                colored += 1
            if (r + g + b) / 3 < 128:
                ink += 1
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)
    if maxx < 0:
        return None
    return dict(
        W=W, H=H,
        L=minx / W * 100, R=(W - maxx) / W * 100,
        T=miny / H * 100, B=(H - maxy) / H * 100,
        fw=(maxx - minx) / W * 100, fh=(maxy - miny) / H * 100,
        ink=ink * step * step / (W * H) * 100,
        colored=colored,
    )


def main(folder):
    files = sorted(glob.glob(os.path.join(folder, "*.png")))
    files = [f for f in files if "contact-sheet" not in os.path.basename(f)]
    if not files:
        sys.exit(f"no PNGs in {folder}")

    failed = 0
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        base = name.replace("-transparent", "")
        m = analyse(f)
        print(f"\n{name}")
        if m is None:
            print("  FAIL  image is empty")
            failed += 1
            continue

        problems = []
        want = EXPECTED.get(base)
        if want and (m["W"], m["H"]) != (want, want):
            problems.append(f"canvas {m['W']}x{m['H']}, expected {want}x{want}")
        if m["W"] != m["H"]:
            problems.append("canvas is not square")
        for side in ("L", "R", "T", "B"):
            if m[side] < MIN_MARGIN:
                problems.append(f"{side} margin {m[side]:.0f}% < {MIN_MARGIN:.0f}%")
        if abs(m["L"] - m["R"]) > BALANCE_TOL:
            problems.append(f"horizontally off-centre (L{m['L']:.0f}% vs R{m['R']:.0f}%)")
        if abs(m["T"] - m["B"]) > BALANCE_TOL:
            problems.append(f"vertically off-centre (T{m['T']:.0f}% vs B{m['B']:.0f}%)")
        lo, hi = FILL_RANGE
        for axis, label in (("fw", "width"), ("fh", "height")):
            if not (lo <= m[axis] <= hi):
                problems.append(f"subject spans {m[axis]:.0f}% of {label}, want {lo:.0f}-{hi:.0f}%")
        if m["colored"]:
            problems.append(f"{m['colored']} non-grey pixels sampled — must be monochrome")

        print(f"  margins  L{m['L']:.0f}%  R{m['R']:.0f}%  T{m['T']:.0f}%  B{m['B']:.0f}%")
        print(f"  subject  {m['fw']:.0f}% x {m['fh']:.0f}%     ink {m['ink']:.1f}%")
        if problems:
            failed += 1
            for p in problems:
                print(f"  FAIL  {p}")
        else:
            print("  ok")

    print(f"\n{'-'*52}")
    print(f"{len(files) - failed}/{len(files)} passed the geometry gate.")
    print("Still needs eyes: stroke-width variation, no sawtooth serration,")
    print("object MUST-CONTAIN features, figures with arms. See prompts §2.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
