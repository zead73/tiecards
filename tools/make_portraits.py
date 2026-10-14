#!/usr/bin/env python3
"""Builds assets/vampires/vampire_{jack,queen,king}.png: each vampire's portrait
panel on its own (no card), rendered large from the same drawings as the court
cards (see make_courts.py), on a transparent background. Used by the duel scenes.
Also vampire_<name>_fangs.png (his mouth open, fangs and chin running with your
blood) and vampire_<name>_cup.png (a goblet of your blood in his hand): the two
pictures shown when he takes his due after a lost hand.
Needs: rsvg-convert, PIL."""
import io, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_courts as mc

OUT = os.path.join(HERE, "..", "assets", "vampires")
Z = 3                                           # render at 3x the card's design size
# same line-up as the win screen: Jack, Queen, King
VAMPIRES = [("jack", 11, "black"), ("queen", 12, "red"), ("king", 13, "black")]


BLOOD, BLOOD_DK, BLOOD_HI = "#c4091f", "#7e0614", "#ff5a66"
SKIN, SKIN_SH, GOLD, GOLD_DK = mc.SKIN, mc.SKIN_SH, mc.GOLD, mc.GOLD_DK


def fangs_extras():
    """The mouth thrown open over the usual one: dark, with two long fangs
    wet with blood, drips falling from the tips and a smear down the chin."""
    return f"""
    <path d="M 147 213 Q 164 210 181 213 Q 177 240 164 242 Q 151 240 147 213 Z" fill="#32060e" stroke="#16030a" stroke-width="1.4"/>
    <ellipse cx="164" cy="236" rx="9" ry="4.5" fill="#8f1030"/>
    <path d="M 151.5 213.5 L 160.5 213.5 L 156 234 Z" fill="#fbf7ee" stroke="#8a8478" stroke-width="0.7"/>
    <path d="M 167.5 213.5 L 176.5 213.5 L 172 234 Z" fill="#fbf7ee" stroke="#8a8478" stroke-width="0.7"/>
    <path d="M 153.6 224 L 158.4 224 L 156 234 Z" fill="{BLOOD}"/>
    <path d="M 169.6 224 L 174.4 224 L 172 234 Z" fill="{BLOOD}"/>
    <path d="M 154.4 221.5 Q 156 224.5 157.6 221.5 L 158.2 224 L 153.8 224 Z" fill="{BLOOD}"/>
    <path d="M 170.4 221.5 Q 172 224.5 173.6 221.5 L 174.2 224 L 169.8 224 Z" fill="{BLOOD}"/>
    <path d="M 156 234 L 156 246" stroke="{BLOOD}" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M 156 252 C 152.4 247.4 153.6 245 156 243.4 C 158.4 245 159.6 247.4 156 252 Z" fill="{BLOOD}"/>
    <path d="M 172 234 L 172 254" stroke="{BLOOD}" stroke-width="2.2" stroke-linecap="round"/>
    <path d="M 172 261 C 167.6 255.4 169.2 252.4 172 250.6 C 174.8 252.4 176.4 255.4 172 261 Z" fill="{BLOOD}"/>
    <path d="M 148 232 C 145 244 150 254 147 266" fill="none" stroke="{BLOOD}" stroke-width="3.6" stroke-linecap="round"/>
    <path d="M 147 270 C 143.6 265 144.8 262.4 147 261 C 149.2 262.4 150.4 265 147 270 Z" fill="{BLOOD}"/>
    <path d="M 181 215 C 184 224 183 232 181 238" fill="none" stroke="{BLOOD_DK}" stroke-width="2" stroke-linecap="round" opacity="0.8"/>
    <path d="M 158 228 L 158 232" stroke="{BLOOD_HI}" stroke-width="1" opacity="0.8"/>
"""


def cup_extras():
    """A gold goblet brimming with blood, held up in front of his chest; a thread of blood at the corner of his mouth."""
    return f"""
    <path d="M 146 218 Q 160 224 178 218" fill="none" stroke="{BLOOD}" stroke-width="2.4" stroke-linecap="round"/>
    <path d="M 177.5 219 C 180 228 179 236 178 242" fill="none" stroke="{BLOOD}" stroke-width="2.6" stroke-linecap="round"/>
    <path d="M 178 248 C 175.2 244 176.2 242 178 240.6 C 179.8 242 180.8 244 178 248 Z" fill="{BLOOD}"/>
    <ellipse cx="164" cy="372" rx="22" ry="5.5" fill="{GOLD_DK}"/>
    <ellipse cx="164" cy="370" rx="19" ry="4.6" fill="{GOLD}"/>
    <path d="M 160.5 366 L 159 350 L 169 350 L 167.5 366 Z" fill="{GOLD}"/>
    <path d="M 159 350 L 169 350" stroke="{GOLD_DK}" stroke-width="2"/>
    <path d="M 128 310 L 200 310 Q 200 350 164 354 Q 128 350 128 310 Z" fill="{GOLD}" stroke="{GOLD_DK}" stroke-width="2"/>
    <path d="M 134 316 Q 136 340 156 348" fill="none" stroke="#f3e2a8" stroke-width="3" stroke-linecap="round" opacity="0.7"/>
    <ellipse cx="164" cy="310" rx="36" ry="7.5" fill="{GOLD_DK}"/>
    <ellipse cx="164" cy="310.5" rx="33" ry="5.8" fill="{BLOOD}"/>
    <ellipse cx="164" cy="309.5" rx="33" ry="5.8" fill="none" stroke="{BLOOD_DK}" stroke-width="1.4"/>
    <path d="M 146 308.6 Q 156 306.2 166 308" fill="none" stroke="{BLOOD_HI}" stroke-width="1.6" stroke-linecap="round" opacity="0.8"/>
    <path d="M 188 314 L 188 330" stroke="{BLOOD}" stroke-width="4" stroke-linecap="round"/>
    <path d="M 188 338 C 183.4 332 185.2 329 188 327 C 190.8 329 192.6 332 188 338 Z" fill="{BLOOD}"/>
"""


EXTRAS = {"": "", "_fangs": fangs_extras(), "_cup": cup_extras()}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, rank, variant in VAMPIRES:
      for suffix, extras in EXTRAS.items():
        svg = mc.portrait_svg(rank, variant, extras)
        png = subprocess.run(["rsvg-convert", "-w", str(mc.W * Z), "-h", str(mc.H * Z)],
                             input=svg.encode(), stdout=subprocess.PIPE, check=True).stdout
        im = Image.open(io.BytesIO(png)).convert("RGBA")
        im = im.crop((mc.PX0 * Z - 4, mc.PY0 * Z - 4, mc.PX1 * Z + 4, mc.PY1 * Z + 4))
        path = os.path.join(OUT, "vampire_%s%s.png" % (name, suffix))
        im.save(path)
        print("wrote %s (%dx%d)" % (os.path.normpath(path), im.width, im.height))


if __name__ == "__main__":
    sys.exit(main())
