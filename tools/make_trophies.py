#!/usr/bin/env python3
"""Builds assets/specials/special_trophy_<key>.png: a small card picture for each
trophy shown in the side panel and on the trophy page (same size and frame as the
special cards, so the overlay code draws them the same way). Drawn as SVG and
rendered with rsvg-convert. Needs: rsvg-convert, PIL.
Keys (see TrophyKeys in src/trophies.pas): firstwin perfect jack queen king flawless.
Not part of make-art.sh: run it on its own when you want to change a picture."""
import io, math, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "specials")
W, H = 164, 232
GOLD, GOLD_DK, BONE = "#c9a24a", "#7a5f24", "#e8e0cc"
BODY, BODY2 = "#1d1526", "#2c2038"
SILVER, IRON = "#c7cddb", "#8d92a3"
CX, CY = W / 2, H / 2


def frame(inner):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <radialGradient id="g" cx="{CX}" cy="{CY}" r="120" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{BODY2}"/><stop offset="1" stop-color="{BODY}"/>
    </radialGradient>
  </defs>
  <rect x="1.5" y="1.5" width="{W-3}" height="{H-3}" rx="12" fill="url(#g)" stroke="{GOLD}" stroke-width="3"/>
  <rect x="8" y="8" width="{W-16}" height="{H-16}" rx="8" fill="none" stroke="{GOLD_DK}" stroke-width="1"/>
  <g transform="translate({CX},{CY}) scale(1.3) translate({-CX},{-CY})">{inner}</g>
</svg>"""


def firstwin():
    # a tarnished coin with a crescent moon
    s = f'<circle cx="{CX}" cy="{CY}" r="48" fill="#a98a3c" stroke="{GOLD_DK}" stroke-width="4"/>'
    s += f'<circle cx="{CX}" cy="{CY}" r="38" fill="none" stroke="{GOLD_DK}" stroke-width="2"/>'
    s += f'<circle cx="{CX-3}" cy="{CY}" r="19" fill="#2a2018"/>'
    s += f'<circle cx="{CX+4}" cy="{CY-3}" r="17" fill="#a98a3c"/>'
    s += f'<path d="M {CX-30} {CY-30} l 14 -8" stroke="#c9a24a" stroke-width="3" stroke-linecap="round" opacity="0.5"/>'
    return s


def perfect():
    # an hourglass with the sand all in the bottom
    s = f'<rect x="{CX-34}" y="{CY-62}" width="68" height="9" rx="3" fill="{SILVER}"/>'
    s += f'<rect x="{CX-34}" y="{CY+53}" width="68" height="9" rx="3" fill="{SILVER}"/>'
    s += f'<path d="M {CX-26} {CY-53} L {CX+26} {CY-53} L {CX+4} {CY} L {CX+26} {CY+53} L {CX-26} {CY+53} L {CX-4} {CY} Z" fill="#1a2438" stroke="{SILVER}" stroke-width="3" stroke-linejoin="round"/>'
    s += f'<path d="M {CX-20} {CY+50} L {CX+20} {CY+50} L {CX+6} {CY+22} L {CX-6} {CY+22} Z" fill="{BONE}"/>'
    s += f'<path d="M {CX} {CY-4} L {CX} {CY+22}" stroke="{BONE}" stroke-width="2"/>'
    s += f'<path d="M {CX-18} {CY-46} L {CX-8} {CY-46} L {CX-2} {CY-30}" stroke="#3a4a6a" stroke-width="3" fill="none" stroke-linecap="round"/>'
    return s


def jack():
    # a signet ring: the band seen from the front and a bezel with an L
    s = f'<circle cx="{CX}" cy="{CY+22}" r="36" fill="none" stroke="{GOLD_DK}" stroke-width="15"/>'
    s += f'<circle cx="{CX}" cy="{CY+22}" r="36" fill="none" stroke="{GOLD}" stroke-width="10"/>'
    s += f'<rect x="{CX-27}" y="{CY-48}" width="54" height="46" rx="10" fill="{GOLD}" stroke="{GOLD_DK}" stroke-width="3"/>'
    s += f'<rect x="{CX-20}" y="{CY-41}" width="40" height="32" rx="6" fill="#1a1020" stroke="{GOLD_DK}" stroke-width="1.5"/>'
    s += f'<text x="{CX}" y="{CY-16}" font-family="Liberation Serif, serif" font-size="30" font-style="italic" font-weight="bold" fill="{GOLD}" text-anchor="middle">L</text>'
    return s


def queen():
    # a mourning brooch: black jet in silver, ringed with pearls, with a drop
    s = ''
    for i in range(14):
        a = math.radians(i * 360 / 14)
        s += f'<circle cx="{CX + math.cos(a) * 49:.1f}" cy="{CY - 14 + math.sin(a) * 49:.1f}" r="5" fill="{BONE}"/>'
    s += f'<circle cx="{CX}" cy="{CY-14}" r="42" fill="#0d0a13" stroke="{SILVER}" stroke-width="6"/>'
    s += f'<path d="M {CX-26} {CY-26} A 32 32 0 0 1 {CX+4} {CY-44}" fill="none" stroke="#5a5470" stroke-width="4" stroke-linecap="round"/>'
    s += f'<path d="M {CX} {CY-14} m -12 0 a 12 12 0 1 0 24 0 a 12 12 0 1 0 -24 0" fill="none" stroke="#2a2438" stroke-width="2"/>'
    s += f'<path d="M {CX} {CY+36} q -10 14 0 26 q 10 -12 0 -26 Z" fill="#0d0a13" stroke="{SILVER}" stroke-width="3"/>'
    return s


def king():
    # a heavy iron key
    s = f'<g transform="rotate(-22 {CX} {CY})">'
    s += f'<circle cx="{CX}" cy="{CY-38}" r="22" fill="none" stroke="#575c6e" stroke-width="13"/>'
    s += f'<circle cx="{CX}" cy="{CY-38}" r="22" fill="none" stroke="{IRON}" stroke-width="8"/>'
    s += f'<rect x="{CX-5}" y="{CY-18}" width="10" height="82" fill="{IRON}" stroke="#575c6e" stroke-width="2"/>'
    s += f'<rect x="{CX+5}" y="{CY+36}" width="20" height="9" fill="{IRON}" stroke="#575c6e" stroke-width="2"/>'
    s += f'<rect x="{CX+5}" y="{CY+52}" width="14" height="9" fill="{IRON}" stroke="#575c6e" stroke-width="2"/>'
    s += f'<rect x="{CX-9}" y="{CY-14}" width="18" height="7" rx="2" fill="{IRON}" stroke="#575c6e" stroke-width="2"/>'
    s += '</g>'
    return s


def flawless():
    # a cut gem with no flaw
    pts = lambda *p: " ".join(f"{CX+x:.1f},{CY+y:.1f}" for x, y in p)
    s = f'<polygon points="{pts((-44,-12),(-26,-42),(26,-42),(44,-12),(0,52))}" fill="#6cc0e0" stroke="{BONE}" stroke-width="3" stroke-linejoin="round"/>'
    s += f'<polygon points="{pts((-44,-12),(-26,-42),(-10,-12))}" fill="#a6e3f5"/>'
    s += f'<polygon points="{pts((-26,-42),(26,-42),(10,-12),(-10,-12))}" fill="#d4f3fb"/>'
    s += f'<polygon points="{pts((26,-42),(44,-12),(10,-12))}" fill="#4fa3c8"/>'
    s += f'<polygon points="{pts((-44,-12),(-10,-12),(0,52))}" fill="#4aa0c6"/>'
    s += f'<polygon points="{pts((-10,-12),(10,-12),(0,52))}" fill="#7fd0ec"/>'
    s += f'<polygon points="{pts((10,-12),(44,-12),(0,52))}" fill="#3b8bb3"/>'
    s += f'<path d="M {CX+28} {CY-58} l 4 9 l 9 4 l -9 4 l -4 9 l -4 -9 l -9 -4 l 9 -4 Z" fill="{BONE}"/>'
    return s


PICTURES = [("firstwin", firstwin), ("perfect", perfect), ("jack", jack),
            ("queen", queen), ("king", king), ("flawless", flawless)]


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, fn in PICTURES:
        png = subprocess.run(["rsvg-convert", "-w", str(W * 2), "-h", str(H * 2)],
                             input=frame(fn()).encode(), check=True, capture_output=True).stdout
        Image.open(io.BytesIO(png)).convert("RGBA").save(os.path.join(OUT, "special_trophy_%s.png" % key))
        print("special_trophy_%s.png" % key)
    return 0


if __name__ == "__main__":
    sys.exit(main())
