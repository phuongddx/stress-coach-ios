"""B · Surfacing v2 — HIG fixes. Emits Icon Composer layers (transparent SVG, 1024 canvas)
+ flattened SVG masters (light/dark/tinted) for the iOS 18 fallback and watch."""
import os, sys
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)

OT = dict(fur="#6E5240", ear="#4B3226", earIn="#E9D2B2", cream="#F0DEC4", white="#FFFFFF",
          pupil="#1B1A1F", nose="#1B1A1F", cheek="#E39A90")
OT_D = dict(OT, fur="#8A6A54", ear="#5E4233", cream="#EBD7BA", cheek="#D98B82")
OT_M = dict(fur="#9A9A9A", ear="#6A6A6A", earIn="#D6D6D6", cream="#E6E6E6", white="#FFFFFF",
            pupil="#000000", nose="#000000", cheek="#9A9A9A")

def otter(cx, cy, s, p):
    X = lambda v: cx + v*s; Y = lambda v: cy + v*s; R = lambda v: v*s
    g = []
    for sx in (-1, 1):
        g.append(f'<circle cx="{X(sx*214):.1f}" cy="{Y(-120):.1f}" r="{R(58):.1f}" fill="{p["ear"]}"/>')
        g.append(f'<circle cx="{X(sx*210):.1f}" cy="{Y(-114):.1f}" r="{R(30):.1f}" fill="{p["earIn"]}"/>')
    g.append(f'<ellipse cx="{X(0)}" cy="{Y(0)}" rx="{R(268):.1f}" ry="{R(230):.1f}" fill="{p["fur"]}"/>')
    # muzzle: two pads + chin (whiskers + freckle dots removed: sub-pixel below 60 px)
    g.append(f'<ellipse cx="{X(0)}" cy="{Y(138):.1f}" rx="{R(112):.1f}" ry="{R(74):.1f}" fill="{p["cream"]}"/>')
    for sx in (-1, 1):
        g.append(f'<ellipse cx="{X(sx*72):.1f}" cy="{Y(92):.1f}" rx="{R(92):.1f}" ry="{R(78):.1f}" fill="{p["cream"]}"/>')
        g.append(f'<ellipse cx="{X(sx*184):.1f}" cy="{Y(50):.1f}" rx="{R(40):.1f}" ry="{R(26):.1f}" fill="{p["cheek"]}"/>')
    for sx in (-1, 1):  # bigger eyes, bigger catchlight
        g.append(f'<circle cx="{X(sx*108):.1f}" cy="{Y(-38):.1f}" r="{R(54):.1f}" fill="{p["white"]}"/>')
        g.append(f'<circle cx="{X(sx*112):.1f}" cy="{Y(-32):.1f}" r="{R(34):.1f}" fill="{p["pupil"]}"/>')
        g.append(f'<circle cx="{X(sx*108-8):.1f}" cy="{Y(-46):.1f}" r="{R(13):.1f}" fill="{p["white"]}"/>')
    g.append(f'<ellipse cx="{X(0)}" cy="{Y(34):.1f}" rx="{R(44):.1f}" ry="{R(30):.1f}" fill="{p["nose"]}"/>')
    sw = R(16)
    g.append(f'<path d="M{X(-46):.1f} {Y(96):.1f} Q{X(-23):.1f} {Y(126):.1f} {X(0)} {Y(100):.1f} Q{X(23):.1f} {Y(126):.1f} {X(46):.1f} {Y(96):.1f}" '
             f'stroke="{p["nose"]}" stroke-width="{sw:.1f}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>')
    g.append(f'<line x1="{X(0)}" y1="{Y(58):.1f}" x2="{X(0)}" y2="{Y(100):.1f}" stroke="{p["nose"]}" stroke-width="{sw:.1f}" stroke-linecap="round"/>')
    return "\n".join(g)

def wave(y, amp, n, x0=-60, x1=1084):
    d = f"M{x0} {y}"; w = (x1-x0)/n
    for i in range(n):
        xa = x0 + i*w; a, b = (-amp, amp) if i % 2 == 0 else (amp, -amp)
        d += f" C{xa+w*.25:.1f} {y+a} {xa+w*.75:.1f} {y+b} {xa+w:.1f} {y}"
    return d + f" L{x1} 1084 L{x0} 1084 Z"

PAL = {  # sky = icon fill, water + ripple = foreground
  "light":  dict(bg1="#DDEBCA", bg2="#BFDCAE", w1="#2A7A6A", w2="#206A5D", rip="#BFDCAE", otter=OT),
  "dark":   dict(bg1="#24443B", bg2="#1A332C", w1="#174A3F", w2="#0F362D", rip="#9CCB3A", otter=OT_D),
  "tinted": dict(bg1="#2A2A2A", bg2="#1A1A1A", w1="#7E7E7E", w2="#6C6C6C", rip="#D0D0D0", otter=OT_M),
}
OX, OY, OS = 512, 470, 1.10   # otter centre/scale; head bottom ~723, water line 712 -> otter surfaces through it
WY = 712

def doc(body, defs=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024"><defs>{defs}</defs>{body}</svg>'

def layer_otter(m): return doc(otter(OX, OY, OS, PAL[m]["otter"]))
def layer_water(m):
    c = PAL[m]
    defs = f'<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c["w1"]}"/><stop offset="1" stop-color="{c["w2"]}"/></linearGradient>'
    body = f'<path d="{wave(WY, 16, 4)}" fill="url(#w)"/>'
    body += f'<ellipse cx="512" cy="{WY+44}" rx="236" ry="30" fill="none" stroke="{c["rip"]}" stroke-width="30"/>'
    body += f'<ellipse cx="512" cy="{WY+110}" rx="330" ry="44" fill="none" stroke="{c["rip"]}" stroke-width="24" stroke-opacity=".55"/>'
    return doc(body, defs)
def flat(m):
    c = PAL[m]
    defs = f'<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{c["bg1"]}"/><stop offset="1" stop-color="{c["bg2"]}"/></linearGradient>'
    body = '<rect width="1024" height="1024" fill="url(#bg)"/>'
    inner = lambda s: s.split("</defs>", 1)[1].rsplit("</svg>", 1)[0]
    wd = layer_water(m).split("<defs>")[1].split("</defs>")[0]
    return doc(body + inner(layer_otter(m)) + inner(layer_water(m)), defs + wd)

for m in PAL:
    open(f"{OUT}/otter-{m}.svg", "w").write(layer_otter(m))
    open(f"{OUT}/water-{m}.svg", "w").write(layer_water(m))
    open(f"{OUT}/B2-{m}.svg", "w").write(flat(m))
print("ok")
