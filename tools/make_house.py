#!/usr/bin/env python3
"""Builds assets/house/house.png: the house on the hill, where the story begins
(three peaks behind it, three gabled roofs on it: the Tri Peaks of the title).
Used behind the start menu and for the campaign's opening lines. Drawn as SVG
and rendered with rsvg-convert. Needs: rsvg-convert.   Usage: make_house.py"""
import os, random, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "house", "house.png")
W, H = 1600, 1000
BONE, GOLD = "#e8e0cc", "#c9a24a"
AMBER, AMBER_HI = "#ff9f3c", "#ffe08a"
SIL = "#0d0816"            # the house and trees
SIL_RIM = "#241a38"


def window(x, y, w, h, color=AMBER, glow=True):
    """An arched window with a warm light and a little glow on the wall."""
    r = w / 2
    s = ""
    if glow:
        s += f'<ellipse cx="{x + r}" cy="{y + h / 2}" rx="{w * 1.5}" ry="{h * 0.9}" fill="url(#glow)" opacity="0.55"/>'
    s += (f'<path d="M {x} {y + h} L {x} {y + r} A {r} {r} 0 0 1 {x + w} {y + r} L {x + w} {y + h} Z" fill="{color}"/>'
          f'<path d="M {x + w * 0.16} {y + h * 0.96} L {x + w * 0.16} {y + r} A {r * 0.84} {r * 0.84} 0 0 1 {x + w * 0.84} {y + r} L {x + w * 0.84} {y + h * 0.96} Z" fill="{AMBER_HI}" opacity="0.55"/>'
          f'<path d="M {x + w / 2} {y + 2} V {y + h} M {x} {y + h * 0.5} H {x + w}" stroke="{SIL}" stroke-width="2.2" fill="none"/>')
    return s


def spire(cx, base_y, half_w, top_y, finial=True):
    s = f'<path d="M {cx - half_w} {base_y} L {cx} {top_y} L {cx + half_w} {base_y} Z" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>'
    if finial:
        s += f'<path d="M {cx} {top_y} V {top_y - 34}" stroke="{SIL}" stroke-width="3"/><path d="M {cx - 9} {top_y - 22} H {cx + 9}" stroke="{SIL}" stroke-width="3"/>'
    return s


def tree(x, y, scale, flip=1):
    """A bare dead tree: a trunk and a few forking branches."""
    t = (f'<g transform="translate({x},{y}) scale({flip * scale},{scale})" fill="none" stroke="#06030a" stroke-linecap="round">'
         '<path d="M 0 0 C -6 -60 4 -120 0 -190" stroke-width="16"/>'
         '<path d="M 0 -80 C -40 -110 -70 -120 -96 -170" stroke-width="9"/>'
         '<path d="M -50 -108 C -70 -112 -92 -104 -118 -112" stroke-width="5"/>'
         '<path d="M -80 -140 C -84 -170 -76 -190 -84 -214" stroke-width="5"/>'
         '<path d="M 2 -130 C 36 -150 62 -158 84 -196" stroke-width="8"/>'
         '<path d="M 52 -152 C 70 -150 94 -138 112 -144" stroke-width="4.5"/>'
         '<path d="M 0 -190 C -8 -216 6 -236 -2 -262" stroke-width="7"/>'
         '<path d="M -3 -226 C -26 -238 -40 -256 -46 -278" stroke-width="4"/>'
         '</g>')
    return t


def bat(x, y, s=1.0, rot=0):
    return (f'<path transform="translate({x},{y}) rotate({rot}) scale({s})" fill="#05030a" '
            'd="M -22 0 Q -12 -14 -3 -3 Q 0 -8 3 -3 Q 12 -14 22 0 Q 12 -5 6 3 Q 0 6 -6 3 Q -12 -5 -22 0 Z"/>')


def build():
    rnd = random.Random(1313)
    stars = ""
    for _ in range(170):
        x, y = rnd.uniform(0, W), rnd.uniform(0, H * 0.55)
        r = rnd.choice([0.8, 0.9, 1.1, 1.4, 1.8])
        op = rnd.uniform(0.3, 0.9)
        stars += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{BONE}" opacity="{op:.2f}"/>'
    fence = ""
    for i in range(0, 17):                                    # iron railings across the front
        x = 470 + i * 40
        if 780 < x < 820:
            continue                                            # the gate
        fence += f'<path d="M {x} 770 V 722 L {x - 5} 714 L {x} 700 L {x + 5} 714 L {x} 722" fill="#06030a" stroke="#06030a" stroke-width="3"/>'
    fence += '<path d="M 470 742 H 770 M 830 742 H 1110" stroke="#06030a" stroke-width="5"/>'
    fence += '<path d="M 770 770 V 690 Q 800 650 830 690 V 770" fill="none" stroke="#06030a" stroke-width="6"/>'
    bats = bat(1180, 120, 1.1, -8) + bat(1260, 190, 0.8, 10) + bat(300, 230, 0.9, 6) + bat(380, 160, 0.65, -12) + bat(960, 300, 0.7, 14)
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#080512"/><stop offset="0.45" stop-color="#1f1033"/>
    <stop offset="0.75" stop-color="#43183a"/><stop offset="1" stop-color="#6b2234"/>
  </linearGradient>
  <radialGradient id="moonglow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#f4ecd4" stop-opacity="0.55"/><stop offset="1" stop-color="#f4ecd4" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{AMBER}" stop-opacity="0.8"/><stop offset="1" stop-color="{AMBER}" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="fog" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9a8fb8" stop-opacity="0"/><stop offset="1" stop-color="#9a8fb8" stop-opacity="0.42"/>
  </linearGradient>
  <linearGradient id="path" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#5a3b52"/><stop offset="1" stop-color="#2a1d3a"/>
  </linearGradient>
</defs>
<rect width="{W}" height="{H}" fill="url(#sky)"/>
{stars}
<!-- the moon -->
<circle cx="1230" cy="200" r="190" fill="url(#moonglow)"/>
<circle cx="1230" cy="200" r="78" fill="#f1e8cf"/>
<circle cx="1206" cy="180" r="14" fill="#d9ceb0"/><circle cx="1256" cy="222" r="19" fill="#d9ceb0"/><circle cx="1240" cy="168" r="8" fill="#d9ceb0"/>
<!-- the three peaks -->
<path d="M 0 700 L 0 520 L 110 450 L 250 330 L 330 400 L 430 470 L 540 380 L 640 300 L 800 190 L 930 300 L 1010 380 L 1110 450 L 1200 420 L 1330 330 L 1440 430 L 1520 470 L 1600 520 L 1600 700 Z" fill="#241640"/>
<path d="M 250 330 L 215 372 L 240 366 L 258 384 L 276 366 L 296 372 Z M 800 190 L 752 250 L 782 244 L 800 266 L 822 242 L 852 252 Z M 1330 330 L 1296 372 L 1318 366 L 1334 384 L 1350 366 L 1372 372 Z" fill="#b9b2d4" opacity="0.55"/>
<path d="M 0 720 L 0 600 L 150 540 L 300 590 L 460 520 L 620 600 L 800 540 L 980 600 L 1140 520 L 1300 590 L 1450 540 L 1600 600 L 1600 720 Z" fill="#150d28"/>
{bats}
<!-- the hill -->
<path d="M 0 760 Q 400 690 800 680 Q 1200 690 1600 760 L 1600 1000 L 0 1000 Z" fill="#0a0612"/>
<path d="M 640 1000 L 770 770 L 830 770 L 960 1000 Z" fill="url(#path)" opacity="0.9"/>
<!-- the house: left tower, great hall, right tower, two low wings -->
<rect x="470" y="560" width="110" height="206" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<path d="M 456 560 L 525 482 L 594 560 Z" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<rect x="1020" y="560" width="110" height="206" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<path d="M 1006 560 L 1075 482 L 1144 560 Z" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<rect x="580" y="500" width="440" height="266" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<rect x="650" y="428" width="300" height="80" fill="{SIL}"/>
{spire(800, 430, 170, 258)}
{spire(525, 484, 74, 372)}
{spire(1075, 484, 74, 372)}
<rect x="610" y="352" width="26" height="90" fill="{SIL}"/><rect x="962" y="352" width="26" height="90" fill="{SIL}"/>
<path d="M 604 352 H 642 L 636 340 H 610 Z M 956 352 H 994 L 988 340 H 962 Z" fill="{SIL_RIM}"/>
<rect x="392" y="650" width="90" height="116" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<path d="M 380 650 L 437 598 L 494 650 Z" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<rect x="1118" y="650" width="90" height="116" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<path d="M 1106 650 L 1163 598 L 1220 650 Z" fill="{SIL}" stroke="{SIL_RIM}" stroke-width="2"/>
<!-- the round window in the gable -->
<circle cx="800" cy="360" r="30" fill="#ff3b4a"/><circle cx="800" cy="360" r="30" fill="url(#glow)" opacity="0.5"/>
<path d="M 770 360 H 830 M 800 330 V 390" stroke="{SIL}" stroke-width="3"/>
<!-- windows -->
{window(498, 596, 54, 96)}{window(1048, 596, 54, 96)}
{window(500, 500, 30, 50)}{window(1070, 500, 30, 50)}
{window(630, 560, 52, 96)}{window(722, 548, 52, 108)}{window(826, 548, 52, 108)}{window(918, 560, 52, 96)}
{window(410, 690, 40, 62)}{window(1150, 690, 40, 62)}
{window(770, 454, 60, 44)}
<!-- the door -->
<path d="M 760 766 V 690 A 40 40 0 0 1 840 690 V 766 Z" fill="#150c1c" stroke="{SIL_RIM}" stroke-width="3"/>
<path d="M 770 766 V 692 A 30 30 0 0 1 830 692 V 766 Z" fill="url(#glow)"/>
<path d="M 770 766 V 692 A 30 30 0 0 1 830 692 V 766 Z" fill="{AMBER}" opacity="0.65"/>
<path d="M 800 662 V 766" stroke="{SIL}" stroke-width="3"/>
{tree(310, 800, 1.3)}{tree(1290, 810, 1.45, -1)}{tree(150, 840, 0.9, -1)}{tree(1450, 850, 0.8)}
{fence}
<!-- fog -->
<rect y="700" width="{W}" height="300" fill="url(#fog)"/>
<ellipse cx="300" cy="800" rx="340" ry="26" fill="#9a8fb8" opacity="0.10"/>
<ellipse cx="1260" cy="830" rx="360" ry="30" fill="#9a8fb8" opacity="0.10"/>
<ellipse cx="800" cy="860" rx="520" ry="34" fill="#9a8fb8" opacity="0.08"/>
</svg>"""
    return svg


def main():
    png = subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H)], input=build().encode(),
                         stdout=subprocess.PIPE, check=True).stdout
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(png)
    print("wrote %s" % os.path.normpath(OUT))


if __name__ == "__main__":
    sys.exit(main())
