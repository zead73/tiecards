#!/usr/bin/env python3
"""Builds assets/specials/special_relic_<key>.png: a small card picture for each relic on
Fenwick's Relics page (same size and frame as the special cards and trophies, so the
overlay code draws them the same way). Drawn as SVG and rendered with rsvg-convert.
Needs: rsvg-convert, PIL. Keys (see RelicKey in src/relics.pas): garlic pick spoon
locket moonstone. Not part of make-art.sh: run it on its own to change a picture."""
import io, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "specials")
W, H = 164, 232
GOLD, GOLD_DK, BONE = "#c9a24a", "#7a5f24", "#e8e0cc"
BODY, BODY2 = "#1d1526", "#2c2038"
IRON, IRON_DK = "#8d92a3", "#575c6e"
CX, CY = W / 2, H / 2


def frame(inner):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <radialGradient id="g" cx="{CX}" cy="{CY}" r="120" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{BODY2}"/><stop offset="1" stop-color="{BODY}"/>
    </radialGradient>
    <radialGradient id="moon" cx="0.38" cy="0.35" r="0.7">
      <stop offset="0" stop-color="#f4f8ff"/><stop offset="0.55" stop-color="#b9c8e6"/><stop offset="1" stop-color="#6b7fa8"/>
    </radialGradient>
  </defs>
  <rect x="1.5" y="1.5" width="{W-3}" height="{H-3}" rx="12" fill="url(#g)" stroke="{GOLD}" stroke-width="3"/>
  <rect x="8" y="8" width="{W-16}" height="{H-16}" rx="8" fill="none" stroke="{GOLD_DK}" stroke-width="1"/>
  <g transform="translate({CX},{CY}) scale(1.3) translate({-CX},{-CY})">{inner}</g>
</svg>"""


def garlic():
    # a bulb with its cloves, and a dry sprig
    s = f'<path d="M {CX-3} {CY-46} q -4 -14 4 -24 q 8 10 4 24" fill="#c9c29a" stroke="#8d8864" stroke-width="2"/>'
    s += f'<path d="M {CX} {CY-48} C {CX-52} {CY-40} {CX-56} {CY+30} {CX} {CY+46} C {CX+56} {CY+30} {CX+52} {CY-40} {CX} {CY-48} Z" fill="#efe9d6" stroke="#b9b196" stroke-width="3"/>'
    for dx in (-26, -12, 0, 12, 26):
        s += f'<path d="M {CX} {CY-46} Q {CX+dx*1.6:.0f} {CY} {CX+dx*0.6:.0f} {CY+44}" fill="none" stroke="#c9c1a2" stroke-width="2"/>'
    s += f'<path d="M {CX-12} {CY+44} l 6 8 M {CX} {CY+46} l 0 9 M {CX+10} {CY+44} l -5 8" stroke="#c9c1a2" stroke-width="2" stroke-linecap="round"/>'
    return s


def pick():
    # a lockpick: a slim steel tool with a hooked tip and a ring handle
    s = f'<g transform="rotate(35 {CX} {CY})">'
    s += f'<circle cx="{CX}" cy="{CY-48}" r="15" fill="none" stroke="{IRON_DK}" stroke-width="9"/>'
    s += f'<circle cx="{CX}" cy="{CY-48}" r="15" fill="none" stroke="{IRON}" stroke-width="5"/>'
    s += f'<rect x="{CX-3}" y="{CY-33}" width="6" height="74" fill="{IRON}" stroke="{IRON_DK}" stroke-width="1.5"/>'
    s += f'<path d="M {CX} {CY+41} q 0 12 10 12 q 8 0 8 -8" fill="none" stroke="{IRON_DK}" stroke-width="7" stroke-linecap="round"/>'
    s += f'<path d="M {CX} {CY+41} q 0 12 10 12 q 8 0 8 -8" fill="none" stroke="{IRON}" stroke-width="4" stroke-linecap="round"/>'
    s += '</g>'
    return s


def spoon():
    # an iron spoon
    s = f'<g transform="rotate(-28 {CX} {CY})">'
    s += f'<ellipse cx="{CX}" cy="{CY-34}" rx="21" ry="28" fill="{IRON}" stroke="{IRON_DK}" stroke-width="4"/>'
    s += f'<ellipse cx="{CX-4}" cy="{CY-40}" rx="9" ry="13" fill="#a6abbb" opacity="0.8"/>'
    s += f'<path d="M {CX-5} {CY-8} L {CX+5} {CY-8} L {CX+3} {CY+54} Q {CX} {CY+60} {CX-3} {CY+54} Z" fill="{IRON}" stroke="{IRON_DK}" stroke-width="3" stroke-linejoin="round"/>'
    s += '</g>'
    return s


def locket():
    # a gold locket on a chain
    s = ''
    for i in range(7):
        s += f'<ellipse cx="{CX-30+i*10}" cy="{CY-60+ (abs(i-3)**1.6)*-2.0 + 6:.1f}" rx="4" ry="2.6" fill="none" stroke="{GOLD}" stroke-width="2"/>'
    s += f'<path d="M {CX-26} {CY-50} L {CX-8} {CY-26} M {CX+26} {CY-50} L {CX+8} {CY-26}" stroke="{GOLD}" stroke-width="2.5"/>'
    s += f'<circle cx="{CX}" cy="{CY-28}" r="5" fill="none" stroke="{GOLD}" stroke-width="3"/>'
    s += f'<ellipse cx="{CX}" cy="{CY+10}" rx="34" ry="42" fill="{GOLD}" stroke="{GOLD_DK}" stroke-width="4"/>'
    s += f'<ellipse cx="{CX}" cy="{CY+10}" rx="25" ry="32" fill="#e2bf62" stroke="{GOLD_DK}" stroke-width="2"/>'
    s += f'<path d="M {CX} {CY+28} C {CX-22} {CY+12} {CX-12} {CY-6} {CX} {CY+4} C {CX+12} {CY-6} {CX+22} {CY+12} {CX} {CY+28} Z" fill="#8a2236" stroke="{GOLD_DK}" stroke-width="2"/>'
    return s


def moonstone():
    # a round pale gem with a crescent glow inside
    s = f'<circle cx="{CX}" cy="{CY}" r="46" fill="url(#moon)" stroke="#e8f0ff" stroke-width="3"/>'
    s += f'<path d="M {CX+4} {CY-30} A 30 30 0 1 0 {CX+4} {CY+30} A 22 22 0 1 1 {CX+4} {CY-30} Z" fill="#ffffff" opacity="0.55"/>'
    s += f'<ellipse cx="{CX-18}" cy="{CY-22}" rx="9" ry="6" fill="#ffffff" opacity="0.85" transform="rotate(-35 {CX-18} {CY-22})"/>'
    return s


PICTURES = [("garlic", garlic), ("pick", pick), ("spoon", spoon), ("locket", locket), ("moonstone", moonstone)]


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, fn in PICTURES:
        png = subprocess.run(["rsvg-convert", "-w", str(W * 2), "-h", str(H * 2)],
                             input=frame(fn()).encode(), check=True, capture_output=True).stdout
        Image.open(io.BytesIO(png)).convert("RGBA").save(os.path.join(OUT, "special_relic_%s.png" % key))
        print("special_relic_%s.png" % key)
    return 0


if __name__ == "__main__":
    sys.exit(main())
