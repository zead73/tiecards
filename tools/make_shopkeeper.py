#!/usr/bin/env python3
"""Builds assets/shopkeeper/shopkeeper.png: the werewolf shopkeeper's portrait, in
the same frame and size as the vampire portraits (596 x 878), on a transparent
background. Hand-written SVG rendered with rsvg-convert, like make_courts.py.
Needs: rsvg-convert, PIL."""
import io, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "shopkeeper")
W, H = 328, 465
PX0, PY0, PX1, PY1 = 66, 88, 262, 378      # the panel, as on the court cards
CX = (PX0 + PX1) // 2
Z = 3

GOLD, GOLD_DK, BONE = "#c9a24a", "#7a5f24", "#e8e0cc"
FUR, FUR_DK, FUR_LT = "#8d7f6c", "#5a4e42", "#b8aa94"
MUZZLE, NOSE, EAR_IN = "#d3c5ad", "#14100d", "#b98378"
AMBER = "#ffb62e"
VEST, VEST_DK, SHIRT = "#2d4b3b", "#1b3226", "#ebe5d6"


def svg():
    s = f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
    s += f"""
  <defs>
    <radialGradient id="bg" cx="{CX}" cy="190" r="160" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#5a3d14"/><stop offset="1" stop-color="#140d08"/>
    </radialGradient>
    <clipPath id="shirt"><path d="M 122 268 L 164 352 L 206 268 Z"/></clipPath>
    <clipPath id="panel"><rect x="{PX0}" y="{PY0}" width="{PX1-PX0}" height="{PY1-PY0}" rx="14"/></clipPath>
  </defs>
  <rect x="{PX0}" y="{PY0}" width="{PX1-PX0}" height="{PY1-PY0}" rx="14" fill="url(#bg)"/>
  <g clip-path="url(#panel)">
    <!-- the moon through the shop window -->
    <circle cx="{CX}" cy="170" r="86" fill="{BONE}" opacity="0.10"/>
    <circle cx="{CX}" cy="170" r="86" fill="none" stroke="{BONE}" stroke-width="1" opacity="0.2"/>
    <!-- shelves with jars and bottles behind -->
    <rect x="{PX0}" y="132" width="52" height="3" fill="#2a1a0c"/>
    <rect x="{PX1-52}" y="132" width="52" height="3" fill="#2a1a0c"/>
    <rect x="{PX0}" y="196" width="46" height="3" fill="#2a1a0c"/>
    <rect x="{PX1-46}" y="196" width="46" height="3" fill="#2a1a0c"/>
    <rect x="76" y="108" width="14" height="24" rx="3" fill="#6a2a1e"/><rect x="80" y="102" width="6" height="7" fill="#3a1a10"/>
    <rect x="96" y="114" width="16" height="18" rx="3" fill="#2e4a3a"/>
    <rect x="224" y="106" width="16" height="26" rx="3" fill="#4a3a6a"/><rect x="229" y="100" width="6" height="7" fill="#3a1a10"/>
    <rect x="244" y="116" width="12" height="16" rx="3" fill="#7a5f24"/>
    <rect x="74" y="172" width="18" height="24" rx="3" fill="#7a5f24"/>
    <rect x="98" y="178" width="12" height="18" rx="3" fill="#6a2a1e"/>
    <rect x="228" y="174" width="14" height="22" rx="3" fill="#2e4a3a"/>
    <rect x="246" y="180" width="10" height="16" rx="3" fill="#4a3a6a"/>
    <!-- a hanging lantern -->
    <line x1="238" y1="88" x2="238" y2="96" stroke="{GOLD_DK}" stroke-width="2"/>
    <rect x="231" y="96" width="14" height="18" rx="3" fill="#ffb62e" opacity="0.9" stroke="{GOLD_DK}" stroke-width="2"/>
    <g transform="translate(0,6)">
      <!-- shoulders: waistcoat over a white shirt -->
      <path d="M 52 400 L 56 296 C 70 268, 112 262, 134 270 L 194 270 C 216 262, 258 268, 272 296 L 276 400 Z" fill="{VEST}"/>
      <path d="M 52 400 L 56 330 L 86 400 Z M 276 400 L 272 330 L 242 400 Z" fill="{VEST_DK}"/>
      <!-- a tie-dyed shirt: rings and rays of colour around a centre -->
      <g clip-path="url(#shirt)">
        <rect x="112" y="258" width="104" height="100" fill="#f2c230"/>
        <circle cx="166" cy="318" r="66" fill="#ff7a3d"/>
        <circle cx="166" cy="318" r="54" fill="#d63384"/>
        <circle cx="166" cy="318" r="43" fill="#7b3fc4"/>
        <circle cx="166" cy="318" r="33" fill="#2f7fd6"/>
        <circle cx="166" cy="318" r="24" fill="#35b58a"/>
        <circle cx="166" cy="318" r="15" fill="#f2c230"/>
        <circle cx="166" cy="318" r="7" fill="#ff7a3d"/>
        <g stroke="#ffffff" stroke-width="1.6" opacity="0.4" stroke-linecap="round">
          <path d="M 166 318 L 120 280"/><path d="M 166 318 L 140 262"/><path d="M 166 318 L 176 258"/>
          <path d="M 166 318 L 214 276"/><path d="M 166 318 L 208 350"/><path d="M 166 318 L 126 350"/>
        </g>
      </g>
      <path d="M 122 268 L 164 352 L 206 268 Z" fill="none" stroke="#3a2a52" stroke-width="2"/>
      <circle cx="164" cy="368" r="3.4" fill="{GOLD}"/>
      <path d="M 122 268 L 164 352 L 164 400" fill="none" stroke="{VEST_DK}" stroke-width="3"/>
      <path d="M 206 268 L 164 352" fill="none" stroke="{VEST_DK}" stroke-width="3"/>
      <!-- fur at the neck and shoulders -->
      <path d="M 112 262 Q 124 292 144 282 L 150 262 Z" fill="{FUR}"/>
      <path d="M 216 262 Q 204 292 184 282 L 178 262 Z" fill="{FUR}"/>
      <path d="M 118 258 L 104 288 L 126 276 Z M 210 258 L 224 288 L 202 276 Z" fill="{FUR_DK}"/>
      <path d="M 128 248 L 164 292 L 200 248 L 190 236 L 138 236 Z" fill="{FUR}"/>
      <!-- a shaggy mane, kept close to the face, over the shoulders -->
      <path d="M 116 132 C 96 144, 90 194, 94 250 C 96 280, 106 304, 122 314 C 116 290, 114 268, 120 244 Z" fill="{FUR_DK}"/>
      <path d="M 212 132 C 232 144, 238 194, 234 250 C 232 280, 222 304, 206 314 C 212 290, 214 268, 208 244 Z" fill="{FUR_DK}"/>
      <path d="M 120 140 C 104 156, 100 200, 104 246 C 106 268, 112 288, 120 298 C 116 274, 116 258, 122 236 Z" fill="{FUR}"/>
      <path d="M 208 140 C 224 156, 228 200, 224 246 C 222 268, 216 288, 208 298 C 212 274, 212 258, 206 236 Z" fill="{FUR}"/>
      <g fill="none" stroke="{FUR_LT}" stroke-width="2.2" stroke-linecap="round" opacity="0.75">
        <path d="M 114 152 C 102 178, 100 212, 104 250"/><path d="M 108 162 C 96 194, 96 232, 102 276"/>
        <path d="M 120 172 C 110 202, 110 238, 114 270"/>
        <path d="M 214 152 C 226 178, 228 212, 224 250"/><path d="M 220 162 C 232 194, 232 232, 226 276"/>
        <path d="M 208 172 C 218 202, 218 238, 214 270"/>
      </g>
      <!-- a thin braid with beads on the left -->
      <path d="M 106 262 C 102 282, 106 298, 112 312" fill="none" stroke="{FUR_LT}" stroke-width="5" stroke-linecap="round" stroke-dasharray="6 3"/>
      <circle cx="112" cy="311" r="4.2" fill="#c0392b"/><circle cx="114" cy="320" r="3.4" fill="{GOLD}"/>
      <!-- ears -->
      <path d="M 110 146 L 98 84 L 142 120 Z" fill="{FUR_DK}"/>
      <path d="M 218 146 L 230 84 L 186 120 Z" fill="{FUR_DK}"/>
      <path d="M 112 140 L 105 98 L 136 122 Z" fill="{EAR_IN}"/>
      <path d="M 216 140 L 223 98 L 192 122 Z" fill="{EAR_IN}"/>
      <!-- head: broad, with cheek fur tufts -->
      <path d="M 108 178 C 108 138, 134 118, 164 118 C 194 118, 220 138, 220 178
               C 224 196, 218 212, 210 226 L 218 238 L 198 236 L 202 250 L 182 244
               C 176 252, 170 256, 164 258 C 158 256, 152 252, 146 244 L 126 250 L 130 236 L 110 238 L 118 226
               C 110 212, 104 196, 108 178 Z" fill="{FUR}"/>
      <path d="M 124 138 C 138 128, 150 124, 164 124 C 178 124, 190 128, 204 138 C 196 134, 180 132, 164 132 C 148 132, 132 134, 124 138 Z" fill="{FUR_DK}" opacity="0.6"/>
      <!-- a pale blaze up the face -->
      <path d="M 164 124 C 172 142, 176 160, 174 184 L 154 184 C 152 160, 156 142, 164 124 Z" fill="{FUR_LT}" opacity="0.7"/>
      <!-- muzzle -->
      <path d="M 138 196 C 138 178, 150 170, 164 170 C 178 170, 190 178, 190 196
               C 192 214, 182 232, 164 236 C 146 232, 136 214, 138 196 Z" fill="{MUZZLE}"/>
      <!-- shaggy forehead fringe -->
      <path d="M 128 128 L 124 156 L 134 140 L 138 162 L 146 138 L 152 158 L 158 132 Z" fill="{FUR_DK}"/>
      <path d="M 200 128 L 204 156 L 194 140 L 190 162 L 182 138 L 176 158 L 170 132 Z" fill="{FUR_DK}"/>
      <path d="M 156 128 L 160 150 L 164 134 L 168 150 L 172 128 Z" fill="{FUR}"/>
      <!-- a leather headband with beads -->
      <path d="M 114 144 Q 164 128 214 144 L 214 154 Q 164 138 114 154 Z" fill="#8a4a2a" stroke="#4a2614" stroke-width="1.4"/>
      <g stroke="#4a2614" stroke-width="0.8">
        <circle cx="140" cy="141" r="4.2" fill="#d85a3a"/><circle cx="164" cy="137.5" r="4.6" fill="{GOLD}"/>
        <circle cx="188" cy="141" r="4.2" fill="#5aa05a"/>
      </g>
      <!-- eyes: amber with slit pupils, heavy brows -->
      <path d="M 128 172 Q 139 162 152 172 Q 140 180 128 172 Z" fill="#241a0e"/>
      <path d="M 176 172 Q 189 162 200 172 Q 188 180 176 172 Z" fill="#241a0e"/>
      <path d="M 131 172 Q 140 165 150 172 Q 140 178 131 172 Z" fill="{AMBER}"/>
      <path d="M 178 172 Q 188 165 197 172 Q 188 178 178 172 Z" fill="{AMBER}"/>
      <ellipse cx="140.5" cy="171.5" rx="1.9" ry="4.4" fill="#120a04"/>
      <ellipse cx="187.5" cy="171.5" rx="1.9" ry="4.4" fill="#120a04"/>
      <path d="M 124 162 L 154 166" stroke="{FUR_DK}" stroke-width="5" stroke-linecap="round"/>
      <path d="M 204 162 L 174 166" stroke="{FUR_DK}" stroke-width="5" stroke-linecap="round"/>
      <!-- nose and mouth, one fang showing in a half smile -->
      <path d="M 154 188 Q 164 182 174 188 Q 174 198 164 202 Q 154 198 154 188 Z" fill="{NOSE}"/>
      <ellipse cx="160" cy="189" rx="3" ry="1.6" fill="#5a5048" opacity="0.7"/>
      <path d="M 164 202 L 164 212" stroke="{NOSE}" stroke-width="2.2"/>
      <path d="M 146 214 Q 156 222 164 214 Q 172 222 184 212" fill="none" stroke="{NOSE}" stroke-width="2.4" stroke-linecap="round"/>
      <path d="M 176 216 L 181 215 L 179 226 Z" fill="#fbf7ee" stroke="#8a8478" stroke-width="0.6"/>
      <path d="M 152 218 L 156 219 L 154 227 Z" fill="#fbf7ee" stroke="#8a8478" stroke-width="0.6"/>
      <!-- long cheek tufts and a flowing chin beard -->
      <path d="M 112 196 L 96 238 L 110 230 L 104 270 L 124 238 L 126 214 Z" fill="{FUR}"/>
      <path d="M 216 196 L 232 238 L 218 230 L 224 270 L 204 238 L 202 214 Z" fill="{FUR}"/>
      <path d="M 118 214 L 108 246 L 118 240 L 114 262 L 128 238 Z" fill="{FUR_LT}" opacity="0.8"/>
      <path d="M 210 214 L 220 246 L 210 240 L 214 262 L 200 238 Z" fill="{FUR_LT}" opacity="0.8"/>
      <path d="M 140 228 C 134 246, 144 264, 164 276 C 184 264, 194 246, 188 228 C 180 242, 148 242, 140 228 Z" fill="{FUR_LT}"/>
      <path d="M 148 236 C 147 252, 154 264, 164 272 C 174 264, 181 252, 180 236 Z" fill="{FUR}" opacity="0.7"/>
      <g fill="none" stroke="#e8dfc9" stroke-width="1.6" stroke-linecap="round" opacity="0.8">
        <path d="M 146 238 C 145 252, 152 264, 164 274"/><path d="M 156 242 C 156 256, 160 266, 164 276"/>
        <path d="M 172 242 C 172 256, 168 266, 164 276"/><path d="M 182 238 C 183 252, 176 264, 164 274"/>
      </g>
      <!-- whiskers -->
      <g stroke="#e8e0cc" stroke-width="0.8" opacity="0.7" fill="none">
        <path d="M 140 204 Q 124 202 112 206"/><path d="M 140 210 Q 126 212 114 218"/>
        <path d="M 188 204 Q 204 202 216 206"/><path d="M 188 210 Q 202 212 214 218"/>
      </g>
      <!-- a peace-sign medallion on a chain -->
      <path d="M 134 262 Q 164 346 194 262" fill="none" stroke="{GOLD}" stroke-width="2.4"/>
      <circle cx="164" cy="326" r="16" fill="{GOLD}" stroke="{GOLD_DK}" stroke-width="2"/>
      <circle cx="164" cy="326" r="11" fill="none" stroke="#2a1d08" stroke-width="2.2"/>
      <path d="M 164 315 L 164 337 M 164 326 L 156.2 333.8 M 164 326 L 171.8 333.8" fill="none" stroke="#2a1d08" stroke-width="2.2" stroke-linecap="round"/>
      <!-- round gold spectacles low on the snout, and a chain -->
      <circle cx="140" cy="173" r="15" fill="#ffe7a8" fill-opacity="0.16"/>
      <circle cx="188" cy="173" r="15" fill="#ffe7a8" fill-opacity="0.16"/>
      <circle cx="140" cy="173" r="15" fill="none" stroke="{GOLD}" stroke-width="3.6"/>
      <circle cx="188" cy="173" r="15" fill="none" stroke="{GOLD}" stroke-width="3.6"/>
      <path d="M 155 171 Q 164 164 173 171" fill="none" stroke="{GOLD}" stroke-width="3.4"/>
      <path d="M 125 171 L 108 162 M 203 171 L 220 162" stroke="{GOLD}" stroke-width="3"/>
      <path d="M 128 166 Q 134 160 142 160" fill="none" stroke="#fff6d8" stroke-width="1.6" opacity="0.7"/>
      <path d="M 176 166 Q 182 160 190 160" fill="none" stroke="#fff6d8" stroke-width="1.6" opacity="0.7"/>
    </g>
  </g>
  <rect x="{PX0}" y="{PY0}" width="{PX1-PX0}" height="{PY1-PY0}" rx="14" fill="none" stroke="{GOLD}" stroke-width="3"/>
  <rect x="{PX0+5}" y="{PY0+5}" width="{PX1-PX0-10}" height="{PY1-PY0-10}" rx="10" fill="none" stroke="{GOLD_DK}" stroke-width="1"/>
</svg>"""
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    png = subprocess.run(["rsvg-convert", "-w", str(W * Z), "-h", str(H * Z)],
                         input=svg().encode(), stdout=subprocess.PIPE, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    im = im.crop((PX0 * Z - 4, PY0 * Z - 4, PX1 * Z + 4, PY1 * Z + 4))
    path = os.path.join(OUT, "shopkeeper.png")
    im.save(path)
    print("wrote %s (%dx%d)" % (os.path.normpath(path), im.width, im.height))


if __name__ == "__main__":
    sys.exit(main())
