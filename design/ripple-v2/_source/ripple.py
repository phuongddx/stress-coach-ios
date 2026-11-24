#!/usr/bin/env python3
"""Ripple v2 — original chibi kid in an otter-hood onesie. Pure SVG, no outlines, one shade tone.
Drawn from scratch (style reference only: flat chibi, blush, pastel). Usage: ripple.py <outdir>"""
import math, os, sys

SUIT, SHADE, ACCENT, DEEP = "#A8DCCF", "#82CBBA", "#5FBFA9", "#206A5D"
BELLY, FACE, BLUSH, HAIR, INK = "#E4F4EE", "#FCE9E6", "#FF9A8B", "#0B2B3A", "#0B2B3A"
TEAR, WHITE, MARK = "#8FD8F2", "#FFFFFF", "#3FA48E"
LVL = dict(relaxed="#8CC12A", mild="#4FA89D", elevated="#F2BC50", high="#E2683C", severe="#E46A80")

def svg(body, vb="0 0 512 512", size=512):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="{vb}">{body}</svg>\n'

def line(d, color, w, extra=""):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'

# ---------------------------------------------------------------- head (local coords, centre 0,0)
FACE_CX, FACE_CY, FACE_RX, FACE_RY = 0, 20, 108, 96
def eyes(kind):
    out = []
    for sx in (-1, 1):
        x, y = 46 * sx, 30
        if kind in ("dot", "worried", "tense", "watery", "lookup"):
            rx, ry = (13, 15) if kind == "tense" else (17, 20) if kind == "watery" else (15, 18)
            ox, oy = (5, -5) if kind == "lookup" else (0, 0)
            out.append(f'<ellipse cx="{x+ox}" cy="{y+oy}" rx="{rx}" ry="{ry}" fill="{INK}"/>')
            out.append(f'<circle cx="{x+ox-5}" cy="{y+oy-7}" r="{6 if kind=="watery" else 5}" fill="{WHITE}"/>')
            if kind == "watery":
                out.append(f'<circle cx="{x+5}" cy="{y+8}" r="3" fill="{WHITE}"/>')
                out.append(f'<path d="M{x+4} {y+26} q8 12 0 20 q-8 -8 0 -20z" fill="{TEAR}"/>')
            if kind in ("worried", "tense", "watery"):
                lift = 12 if kind == "tense" else 8
                # inner end lifted -> worried, never angry
                out.append(line(f"M{x+sx*18} {y-22} L{x-sx*16} {y-22-lift}", INK, 6))
            if kind == "lookup" and sx == 1:
                out.append(line(f"M{x-14} {y-30} Q{x} {y-40} {x+16} {y-32}", INK, 6))
        elif kind == "happy":   # closed, smiling arcs
            out.append(line(f"M{x-15} {y+5} Q{x} {y-13} {x+15} {y+5}", INK, 7))
        elif kind == "closed":  # relaxed / asleep arcs
            out.append(line(f"M{x-15} {y-2} Q{x} {y+11} {x+15} {y-2}", INK, 7))
    return "".join(out)

MOUTHS = {
    "smile":  line("M-13 58 Q0 71 13 58", INK, 6),
    "grin":   f'<path d="M-20 55 Q0 88 20 55 Z" fill="{INK}"/><path d="M-10 70 Q0 64 10 70 Q0 80 -10 70Z" fill="{BLUSH}"/>',
    "o":      f'<ellipse cx="0" cy="64" rx="7" ry="9" fill="{INK}"/>',
    "tiny":   f'<ellipse cx="0" cy="64" rx="5" ry="4" fill="{INK}"/>',
    "wavy":   line("M-15 64 Q-7.5 57 0 64 Q7.5 71 15 64", INK, 5),
    "frown":  line("M-11 67 Q0 58 11 67", INK, 6),
    "sad":    f'<path d="M-13 70 Q0 52 13 70 Q0 65 -13 70Z" fill="{INK}"/>',
    "hmm":    line("M-4 65 Q6 60 16 63", INK, 5),
}

def head(expr="dot", mouth="smile", sweat=False):
    p = []
    # small round otter ears (behind hood)
    for sx in (-1, 1):
        p.append(f'<circle cx="{122*sx}" cy="-84" r="36" fill="{SUIT}"/>')
        p.append(f'<circle cx="{128*sx}" cy="-90" r="18" fill="{ACCENT}"/>')
    hood = "M-150 10 C-150 -80 -80 -138 0 -138 C80 -138 150 -80 150 10 C150 90 110 132 0 134 C-110 132 -150 90 -150 10Z"
    p.append(f'<path d="{hood}" fill="{SUIT}"/>')
    # one-tone shade on the lower-right of the hood
    p.append(f'<path d="M150 10 C150 90 110 132 0 134 C70 120 128 80 136 6 Z" fill="{SHADE}"/>')
    # otter face on the hood: little nose + eyes
    p.append(f'<path d="M-17 -112 Q0 -119 17 -112 Q11 -97 0 -95 Q-11 -97 -17 -112Z" fill="{DEEP}"/>')
    for sx in (-1, 1):
        p.append(f'<circle cx="{44*sx}" cy="-111" r="7.5" fill="{DEEP}"/>')
    # face opening: rim (shade) + face
    p.append(f'<ellipse cx="-4" cy="16" rx="117" ry="105" fill="{SHADE}"/>')
    p.append(f'<ellipse cx="{FACE_CX}" cy="{FACE_CY}" rx="{FACE_RX}" ry="{FACE_RY}" fill="{FACE}"/>')
    # side-swept fringe, clipped to the face
    hair = ("M-114 6 C-112 -62 -60 -86 0 -86 C64 -86 114 -58 114 8 C100 -16 82 -24 64 -20 "
            "C62 -38 52 -48 40 -52 C32 -28 8 -12 -26 -12 C-18 -22 -16 -32 -18 -40 C-40 -20 -70 -10 -114 6Z")
    cid = f"fc{abs(hash((expr, mouth, sweat))) % 10**6}"
    p.append(f'<clipPath id="{cid}"><ellipse cx="{FACE_CX}" cy="{FACE_CY}" rx="{FACE_RX}" ry="{FACE_RY}"/></clipPath>')
    p.append(f'<path d="{hair}" fill="{HAIR}" clip-path="url(#{cid})"/>')
    for sx in (-1, 1):
        p.append(f'<ellipse cx="{70*sx}" cy="60" rx="19" ry="11" fill="{BLUSH}" opacity=".9"/>')
    p.append(eyes(expr))
    p.append(MOUTHS[mouth])
    if sweat:
        p.append(f'<path d="M132 -36 q-16 26 -14 36 a14 14 0 0 0 28 0 q2 -10 -14 -36z" fill="{TEAR}"/>'
                 f'<ellipse cx="127" cy="2" rx="4" ry="6" fill="{WHITE}"/>')
    return "".join(p)

# ---------------------------------------------------------------- body poses (artboard coords)
def arm(d):  # one shade tone underneath, suit on top
    return line(d, SHADE, 38, 'transform="translate(3 5)"') + line(d, SUIT, 38)

def tail(d="M300 418 C350 430 386 420 398 388 C404 372 392 362 382 372 C366 392 338 398 304 392Z"):
    return f'<path d="{d}" fill="{ACCENT}"/>'

def shadow(cx=256, cy=470, rx=118):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="15" fill="{DEEP}" opacity=".14"/>'

BODY = "M206 292 C184 336 180 396 194 436 Q256 452 318 436 C332 396 328 336 306 292Z"
BODY_SHADE = "M206 292 C190 330 186 380 194 430 Q204 436 214 438 C204 390 206 340 222 300Z"
def torso(legs="stand"):
    s = []
    if legs == "stand":
        s += [f'<rect x="210" y="410" width="40" height="58" rx="20" fill="{SUIT}"/>',
              f'<rect x="262" y="410" width="40" height="58" rx="20" fill="{SUIT}"/>']
    elif legs == "walk":
        s += [f'<rect x="210" y="410" width="40" height="58" rx="20" fill="{SHADE}" transform="rotate(18 230 412)"/>',
              f'<rect x="262" y="410" width="40" height="58" rx="20" fill="{SUIT}" transform="rotate(-18 282 412)"/>']
    s += [f'<path d="{BODY}" fill="{SUIT}"/>', f'<path d="{BODY_SHADE}" fill="{SHADE}"/>',
          f'<ellipse cx="256" cy="376" rx="40" ry="48" fill="{BELLY}"/>']
    return "".join(s)

def sit_torso():
    return (f'<path d="M204 316 C184 358 184 408 198 438 Q256 452 314 438 C328 408 328 358 308 316Z" fill="{SUIT}"/>'
            f'<path d="M204 316 C190 356 188 400 198 432 Q206 436 214 438 C206 398 208 356 220 322Z" fill="{SHADE}"/>'
            f'<ellipse cx="256" cy="392" rx="38" ry="40" fill="{BELLY}"/>')

def feet_front():
    out = ""
    for x in (212, 300):
        out += f'<ellipse cx="{x}" cy="448" rx="32" ry="23" fill="{SUIT}"/><ellipse cx="{x}" cy="452" rx="15" ry="11" fill="{BELLY}"/>'
    return out

def head_at(x, y, s=.92, rot=0, **kw):
    return f'<g transform="translate({x} {y}) rotate({rot}) scale({s})">{head(**kw)}</g>'

def figure(pose, face):
    """Returns (behind, figure) svg for a pose. face = kwargs for head()."""
    if pose == "stand":
        return shadow() + tail() + torso() + arm("M212 318 L178 384") + arm("M300 318 L334 384") + head_at(256, 186, **face)
    if pose == "wave":
        return shadow() + tail() + torso() + arm("M212 318 L178 384") + head_at(256, 186, rot=-4, **face) + arm("M306 324 L392 262")
    if pose == "tense":  # paws pulled in together in front
        return shadow() + tail() + torso() + arm("M212 320 L244 376") + arm("M300 320 L268 376") + head_at(256, 188, **face)
    if pose == "breathe":
        return shadow() + tail() + torso() + arm("M212 316 L166 366") + arm("M300 316 L346 366") + head_at(256, 182, **face)
    if pose == "think":
        return (shadow() + tail() + torso() + arm("M212 320 L240 374") +
                line("M304 324 Q344 330 322 292", SHADE, 38, 'transform="translate(3 5)"') + head_at(256, 186, rot=6, **face) +
                line("M304 324 Q344 330 322 292", SUIT, 38))
    if pose == "walk":
        return (shadow(250) + tail() + torso("walk") + arm("M212 318 L176 372") + arm("M300 318 L322 392") +
                head_at(256, 186, rot=-5, **face))
    if pose == "jump":
        g = (tail() + torso() + head_at(256, 186, **face) + arm("M206 324 L132 240") + arm("M306 324 L380 240"))
        return shadow(rx=92) + f'<g transform="translate(0 -18)">{g}</g>'
    if pose == "sit":
        return (shadow(rx=134) + tail("M304 430 C352 446 392 438 408 408 C414 392 402 384 392 394 C376 414 344 420 306 414Z") +
                sit_torso() + feet_front() + arm("M214 340 L240 420") + arm("M298 340 L272 420") +
                head_at(256, 212, rot=face.pop("rot", 0), **face))
    if pose == "float":  # sitting upright in water, paws on belly
        water_back = (f'<ellipse cx="256" cy="448" rx="176" ry="34" fill="{ACCENT}" opacity=".22"/>'
                      f'<ellipse cx="256" cy="448" rx="206" ry="44" fill="none" stroke="{ACCENT}" stroke-width="5" opacity=".35"/>')
        wave = "M110 448 " + " ".join("q18 -9 36 0" for _ in range(8)) + " L398 458 Q256 476 110 458Z"
        water_front = f'<path d="{wave}" fill="{ACCENT}" opacity=".5"/>'
        return (water_back + tail("M304 430 C352 446 392 438 408 408 C414 392 402 384 392 394 C376 414 344 420 306 414Z") +
                sit_torso() + feet_front() + arm("M214 340 L246 392") + arm("M298 340 L266 392") +
                head_at(256, 212, rot=-6, **face) + water_front)
    if pose == "float_back":
        g = (tail() + torso() + arm("M212 318 L240 366") + arm("M300 318 L272 366") + head_at(256, 186, **face))
        water = (f'<ellipse cx="256" cy="300" rx="236" ry="96" fill="{ACCENT}" opacity=".16"/>'
                 f'<ellipse cx="256" cy="300" rx="196" ry="74" fill="none" stroke="{ACCENT}" stroke-width="7" opacity=".45"/>'
                 f'<ellipse cx="256" cy="300" rx="240" ry="100" fill="none" stroke="{ACCENT}" stroke-width="5" opacity=".3"/>')
        return water + f'<g transform="translate(256 292) rotate(-76) scale(.84) translate(-256 -292)">{g}</g>'
    raise KeyError(pose)

# ---------------------------------------------------------------- props
def bubble(cx, cy, r, tx, ty, inner):
    return (f'<path d="M{cx-r*.35} {cy+r*.7} L{tx} {ty} L{cx+r*.15} {cy+r*.85}Z" fill="{WHITE}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{WHITE}"/>' + inner)

def spiral(cx, cy, turns=2.6, a=3.6, color=INK, w=6):
    pts = [(cx + a*t*math.cos(t), cy + a*t*math.sin(t)) for t in [i*0.18 for i in range(int(turns*2*math.pi/0.18))]]
    return line("M" + " L".join(f"{x:.1f} {y:.1f}" for x, y in pts), color, w)

def heart(cx, cy, s, color):
    return (f'<path transform="translate({cx} {cy}) scale({s})" d="M0 10 C-14 0 -22 -8 -22 -16 C-22 -24 -16 -28 -10 -28 '
            f'C-5 -28 -2 -25 0 -21 C2 -25 5 -28 10 -28 C16 -28 22 -24 22 -16 C22 -8 14 0 0 10Z" fill="{color}"/>')

def sparkle(cx, cy, r, color):
    k = r*.28
    return f'<path d="M{cx} {cy-r} Q{cx+k} {cy-k} {cx+r} {cy} Q{cx+k} {cy+k} {cx} {cy+r} Q{cx-k} {cy+k} {cx-r} {cy} Q{cx-k} {cy-k} {cx} {cy-r}Z" fill="{color}"/>'

def zz(x, y, s, color):
    return line(f"M{x} {y} h{s} l{-s} {s} h{s}", color, max(4, s*.22))

def dots(cx, cy, color, gap=20, r=6.5):
    return "".join(f'<circle cx="{cx+i*gap}" cy="{cy}" r="{r}" fill="{color}"/>' for i in (-1, 0, 1))

# ---------------------------------------------------------------- states
STATES = [
 # key, label, pose, face kwargs, props-behind, props-front, head-crop face
 ("base", "Base", "stand", dict(expr="dot", mouth="smile"), "", ""),
 ("relaxed", "Relaxed", "float", dict(expr="happy", mouth="smile"), "",
     sparkle(430, 120, 14, LVL["relaxed"]) + sparkle(84, 150, 10, LVL["relaxed"])),
 ("mild", "Mild", "wave", dict(expr="dot", mouth="smile"), "",
     line("M382 218 q14 12 10 30", LVL["mild"], 6) + line("M398 196 q22 18 16 48", LVL["mild"], 6)),
 ("elevated", "Elevated", "stand", dict(expr="worried", mouth="wavy", sweat=True), "",
     bubble(446, 66, 44, 400, 126, dots(446, 66, LVL["elevated"], gap=18, r=6))),
 ("high", "High", "tense", dict(expr="tense", mouth="frown", sweat=True), "",
     bubble(446, 66, 46, 398, 126, spiral(446, 66, turns=2.4, a=3.4, color=LVL["high"]))),
 ("severe", "Severe", "sit", dict(expr="watery", mouth="sad"), "",
     bubble(446, 78, 42, 404, 140, heart(446, 84, 1.2, LVL["severe"]))),
 ("breathing", "Breathing", "breathe", dict(expr="closed", mouth="o"),
     f'<circle cx="256" cy="262" r="222" fill="{ACCENT}" opacity=".10"/><circle cx="256" cy="262" r="176" fill="{ACCENT}" opacity=".12"/>',
     line("M424 150 q16 -14 32 0", MARK, 6) + line("M88 150 q16 -14 32 0", MARK, 6)),
 ("walking", "Walking", "walk", dict(expr="dot", mouth="smile"), "",
     f'<circle cx="150" cy="456" r="9" fill="{ACCENT}" opacity=".5"/><circle cx="126" cy="448" r="6" fill="{ACCENT}" opacity=".4"/>'
     + line("M76 300 h34", MARK, 6) + line("M60 336 h40", MARK, 6)),
 ("celebrating", "Celebrating", "jump", dict(expr="happy", mouth="grin"), "",
     sparkle(96, 120, 22, LVL["elevated"]) + sparkle(420, 96, 18, LVL["relaxed"]) + sparkle(448, 230, 11, LVL["severe"])
     + sparkle(72, 250, 12, LVL["mild"]) + f'<rect x="132" y="56" width="16" height="9" rx="4" fill="{LVL["high"]}" transform="rotate(30 140 60)"/>'
     + f'<rect x="372" y="168" width="16" height="9" rx="4" fill="{LVL["mild"]}" transform="rotate(-25 380 172)"/>'),
 ("sleeping", "Sleeping", "sit", dict(expr="closed", mouth="tiny", rot=12), 
     f'<path d="M62 40 a44 44 0 1 0 50 62 a36 36 0 1 1 -50 -62z" fill="#F5D98B"/>',
     zz(392, 70, 30, MARK) + zz(436, 40, 20, MARK) + zz(466, 18, 13, MARK)),
 ("thinking", "Thinking", "think", dict(expr="lookup", mouth="hmm"), "",
     f'<circle cx="398" cy="140" r="8" fill="{WHITE}"/><circle cx="414" cy="112" r="12" fill="{WHITE}"/>'
     f'<path d="M400 78 a30 30 0 0 1 36 -40 a32 32 0 0 1 56 12 a26 26 0 0 1 -6 50 a30 30 0 0 1 -50 4 a28 28 0 0 1 -36 -26z" fill="{WHITE}"/>'
     + dots(450, 70, LVL["mild"], gap=19, r=6)),
]

def state_svg(st):
    key, label, pose, face, behind, front = st
    return svg(behind + figure(pose, dict(face)) + front)

def head_svg(st):
    face = {k: v for k, v in st[3].items() if k != "rot"}
    return svg(f'<g transform="translate(256 268) scale(1.5)">{head(**face)}</g>')

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(f"{out}/svg", exist_ok=True)
    for st in STATES:
        open(f"{out}/svg/{st[0]}.svg", "w").write(state_svg(st))
        open(f"{out}/svg/{st[0]}-head.svg", "w").write(head_svg(st))
    print(len(STATES), "states")
