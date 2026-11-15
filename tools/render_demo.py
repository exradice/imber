#!/usr/bin/env python3
"""Render demo images of Imber for the README and the AWTRIX Hub.

A made-up cold front crosses the map from west to east: light rain ahead of it,
a narrow band of heavy rain with thunderstorms, showers behind it. The drawing
follows imber.be (frames, chart, draw()) pixel by pixel on the 52 x 16 display;
only the clock font is an approximation of the firmware font.

    python3 tools/render_demo.py          # writes docs/imber.gif and docs/imber-front.png
"""

import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")

W, H = 52, 16
RAIN = 0x60C8FF
HEAVY = 0x7A28E0
TEXT = 0x4FA8FF
BAR_FULL = 4.0
STORM_FULL = 10.0
THRESHOLD = 0.2
NOW = 13 * 3600 + 20 * 60          # local time, seconds since midnight
DAY_END = 20 * 3600
ANIM_MS = 6000                      # app time 7 s minus the pause


# ---- made-up weather -------------------------------------------------------

CELLS = [(gx, gy) for gy in range(-3, 4) for gx in range(-3, 4) if gx * gx + gy * gy <= 12]
CENTRE = CELLS.index((0, 0))
ANGLE = math.radians(18)            # the front moves towards east-north-east
UX, UY = math.cos(ANGLE), -math.sin(ANGLE)


def weather(gx, gy, t):
    """Rain rate (mm/h) and lightning potential (J/kg) at a cell, t in seconds."""
    hours = t / 3600
    along = gx * UX + gy * UY                      # position in the direction of motion
    across = gx * -UY + gy * UX                    # position along the front, + = south
    front = -2.4 + 1.45 * (hours - 14.0)           # where the cold front is
    d = along - front                              # > 0: ahead of the front
    vary = 1 + 0.35 * math.sin(1.6 * across + 0.7) + 0.12 * math.sin(3.1 * gx + 1.3 * gy)
    rate = 0.0
    lpi = 0.0
    if 0.25 < d <= 2.2:                            # light rain ahead of the front
        rate = 0.9 * (1 - (d - 0.25) / 1.95) ** 1.6 + 0.04
    elif -0.65 <= d <= 0.25:                       # the narrow band of heavy rain
        rate = 1.5 + 8.5 * math.exp(-((d + 0.2) / 0.3) ** 2)
        if 15.1 <= hours <= 15.95:                # thunderstorms while it crosses the middle
            lpi = 18 * math.exp(-((d + 0.2) / 0.3) ** 2) * max(0.0, vary - 1.05) * 3
    elif -2.6 < d < -0.65:                         # a few showers behind it
        rate = 1.2 * math.exp((d + 0.65) * 1.6) * max(0.0, math.sin(2.3 * across + 3 * d))
    rate = max(0.0, rate * vary)
    return rate, lpi


def mean(gx, gy, t_end, length):
    """Mean of the period before t_end, as Open-Meteo gives its values."""
    n = 6
    rs, ls = [], []
    for i in range(n):
        r, l = weather(gx, gy, t_end - length + (i + 0.5) * length / n)
        rs.append(r)
        ls.append(l)
    return sum(rs) / n, max(ls)


HOURS = [h * 3600 for h in range(11, 25)]          # hourly timestamps (end of the hour)
HOURLY = []                                        # per cell: [(rate, lpi, code)] per hour
for gx, gy in CELLS:
    row = []
    for T in HOURS:
        r, l = mean(gx, gy, T, 3600)
        row.append((r, l, 95 if l > 8 else 61))
    HOURLY.append(row)

FINE_T = [11 * 3600 + 900 * k for k in range(1, 53)]
FINE = [mean(0, 0, T, 900) for T in FINE_T]        # mm/h; the app gets mm per quarter hour


# ---- imber.be ---------------------------------------------------------------

def dim(c, pc):
    return (((c >> 16) & 255) * pc // 100 << 16) | (((c >> 8) & 255) * pc // 100 << 8) | (c & 255) * pc // 100


def mix(c1, c2, t):
    out = 0
    for sh in (16, 8, 0):
        a, b = (c1 >> sh) & 255, (c2 >> sh) & 255
        out |= int(a + (b - a) * t) << sh
    return out


def rain_shade(rate, min_pc):
    f = min(1.0, math.sqrt(rate / BAR_FULL))
    if f >= 0.6:
        return mix(RAIN, HEAVY, (f - 0.6) / 0.4)
    pc = int(f / 0.6 * 100)
    return dim(RAIN, max(pc, min_pc))


def storm_color(lpi, coded):
    g = lpi / STORM_FULL
    if coded and g < 0.8:
        g = 0.8
    if g <= 0:
        return 0
    g = min(1.0, max(0.25, g))
    return mix(0x302000, 0xFFE000, g)


def clock(ts):
    s = ts % 86400
    return "%d:%02d" % (s // 3600, (s % 3600) // 60)


start = -1
for T, (r, _) in zip(FINE_T, FINE):
    if start < 0 and T > NOW and T - 900 < DAY_END and r >= THRESHOLD:
        start = T - 900
A = start if start > NOW else NOW - NOW % 900
B = max(DAY_END, A + 3 * 3600)

FRAMES = []
for k, T in enumerate(HOURS):
    if T - 3600 < B and T > A:
        colors = [0 if HOURLY[i][k][0] < 0.05 else rain_shade(HOURLY[i][k][0], 8) for i in range(len(CELLS))]
        storm = [storm_color(HOURLY[i][k][1], HOURLY[i][k][2] >= 95) for i in range(len(CELLS))]
        FRAMES.append((T - 1800, colors, storm))

BARS = []
cols = 36
dur = (B - A) / cols
for col in range(cols):
    ca = A + col * dur
    cb = ca + dur
    rate = lpi = 0.0
    for T, (r, l) in zip(FINE_T, FINE):
        if T - 900 < cb and T > ca:
            rate = max(rate, r)
            lpi = max(lpi, l)
    coded = False
    mid = ca + dur / 2
    for k, T in enumerate(HOURS):
        if T - 3600 <= mid < T:
            lpi = max([lpi] + [HOURLY[i][k][1] for i in range(len(CELLS))])
            coded = coded or any(HOURLY[i][k][2] >= 95 for i in range(len(CELLS)))
    bh = min(8, int(math.sqrt(rate / BAR_FULL) * 8 + 0.5))
    if rate >= 0.05 and bh < 1:
        bh = 1
    sc = storm_color(lpi, coded)
    BARS.append((bh, sc if sc else (rain_shade(rate, 100) if rate >= THRESHOLD else dim(RAIN, 40))))

# 3 x 5 digits, close to the firmware font
GLYPHS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    ":": ["0", "1", "0", "1", "0"],
}


def ink_width(s):
    return sum(len(GLYPHS[c][0]) + 1 for c in s) - 1


def draw(p):
    """Pixels of the display with the radar at run position p (0..1)."""
    px = [[0] * W for _ in range(H)]

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            px[y][x] = c

    def rect(x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                put(xx, yy, c)

    def text(x, y, s, c):
        for ch in s:
            g = GLYPHS[ch]
            for r, line in enumerate(g):
                for i, b in enumerate(line):
                    if b == "1":
                        put(x + i, y - 5 + r, c)
            x += len(g[0]) + 1

    t = A + (B - A) * p
    n = len(FRAMES)
    j = 0
    while j + 1 < n and FRAMES[j + 1][0] <= t:
        j += 1
    k = j + 1 if j + 1 < n else j
    f = 0.0
    if k != j and t > FRAMES[j][0]:
        f = min(1.0, (t - FRAMES[j][0]) / (FRAMES[k][0] - FRAMES[j][0]))
    c1, c2 = FRAMES[j][1], FRAMES[k][1]
    storm = FRAMES[j if f < 0.5 else k][2]

    dry = 0x0C0C14
    for i, (gx, gy) in enumerate(CELLS):
        x, y = (gx + 3) * 2, 1 + (gy + 3) * 2
        a = c1[i] or dry
        b = c2[i] or dry
        rect(x, y, 2, 2, a if a == b else mix(a, b, f))
        if storm[i]:
            put(x + 1, y, storm[i])
    for x, y in ((5, 6), (8, 6), (5, 9), (8, 9)):
        put(x, y, 0x707070)

    label = clock(int(t) // 900 * 900)
    end = clock(B)
    x0 = 16
    ws, we = ink_width(label), ink_width(end)
    text(x0, 6, label, 0xFFFFFF)
    text(W - we, 6, end, TEXT)
    space = W - we - (x0 + ws)
    if space >= 5:
        rect(x0 + ws + (space - 3) // 2, 3, 3, 1, dim(TEXT, 60))

    for i, (bh, c) in enumerate(BARS):
        if bh > 0:
            rect(x0 + i, 16 - bh, 1, bh, c)
        else:
            put(x0 + i, 15, 0x101018)
    rect(x0 + int(p * (cols - 1) + 0.5), 8, 1, 8, 0xFFFFFF)
    return px


# ---- LED look ---------------------------------------------------------------

def rgb(c):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255)


def led(px, scale, pad):
    """The display as round LEDs on a dark panel, antialiased by drawing 4x larger."""
    ss = 4
    s = scale * ss
    img = Image.new("RGB", ((W * scale + 2 * pad) * ss, (H * scale + 2 * pad) * ss), (8, 8, 10))
    d = ImageDraw.Draw(img)
    gap = max(1, s // 6)
    o = pad * ss
    for y in range(H):
        for x in range(W):
            c = px[y][x]
            col = rgb(c) if c else (22, 22, 26)
            d.rounded_rectangle((o + x * s + gap, o + y * s + gap, o + (x + 1) * s - gap, o + (y + 1) * s - gap),
                                radius=s // 4, fill=col)
    return img.resize((img.width // ss, img.height // ss), Image.LANCZOS)


def time_p(hh, mm):
    return min(1.0, max(0.0, (hh * 3600 + mm * 60 - A) / (B - A)))


def gif():
    fps = 20
    run = ANIM_MS * fps // 1000
    frames = [led(draw(i / run), 12, 12) for i in range(run + 1)]
    frames += [frames[-1]] * (fps - 1)                        # the second standing still
    pal = [f.quantize(colors=128, method=Image.Quantize.MEDIANCUT) for f in frames]
    pal[0].save(os.path.join(DOCS, "imber.gif"), save_all=True, append_images=pal[1:],
                duration=1000 // fps, loop=0, optimize=True, disposal=1)


def filmstrip(moments):
    font = "/usr/share/fonts/noto/NotoSans-Regular.ttf"
    bold = "/usr/share/fonts/noto/NotoSans-Bold.ttf"
    f_title = ImageFont.truetype(bold, 30)
    f_time = ImageFont.truetype(bold, 26)
    f_text = ImageFont.truetype(font, 18)
    f_small = ImageFont.truetype(font, 16)

    scale, pad = 9, 8
    panel_w, panel_h = W * scale + 2 * pad, H * scale + 2 * pad
    left = 300
    margin = 32
    row_h = panel_h + 22
    top = 96
    legend_h = 70
    width = margin * 2 + left + panel_w
    height = top + row_h * len(moments) + legend_h
    img = Image.new("RGB", (width, height), (16, 17, 22))
    d = ImageDraw.Draw(img)
    d.text((margin, 28), "Imber: a cold front passes", font=f_title, fill=(235, 238, 245))
    d.text((margin, 66), "One run of the radar, from the start of the rain to the end of the chart",
           font=f_small, fill=(150, 156, 170))

    y = top
    for (hh, mm), caption in moments:
        p = time_p(hh, mm)
        img.paste(led(draw(p), scale, pad), (margin + left, y))
        d.text((margin, y + 18), clock(int(A + (B - A) * p) // 900 * 900), font=f_time, fill=(255, 255, 255))
        cy = y + 58
        for line in caption:
            d.text((margin, cy), line, font=f_text, fill=(190, 196, 210))
            cy += 24
        y += row_h

    # legend
    y += 8
    x = margin
    for c, name in ((0x0C0C14, "dry"), (dim(RAIN, 45), "light rain"), (RAIN, "rain"),
                    (HEAVY, "heavy rain"), (0xFFE000, "thunderstorm")):
        d.rounded_rectangle((x, y + 4, x + 18, y + 22), radius=4, fill=rgb(c), outline=(60, 62, 70))
        d.text((x + 26, y + 1), name, font=f_small, fill=(190, 196, 210))
        x += 26 + int(d.textlength(name, font=f_small)) + 28
    d.text((margin, y + 34), "Weather data: Open-Meteo (CC BY 4.0), DWD ICON-D2. Example data.",
           font=f_small, fill=(110, 116, 130))
    img.save(os.path.join(DOCS, "imber-front.png"), optimize=True)


if __name__ == "__main__":
    import sys
    if "--debug" in sys.argv:
        print("start", clock(A), "end", clock(B), "frames", [clock(f[0]) for f in FRAMES])
        for T, (r, l) in zip(FINE_T, FINE):
            print(clock(T), "%.2f mm/h" % r, "lpi %.1f" % l)
        sys.exit()
    gif()
    filmstrip([
        ((14, 30), ["Light rain reaches you,", "the front is still west of you"]),
        ((15, 15), ["The band of heavy rain comes", "closer, with thunderstorms"]),
        ((16, 0), ["Heavy rain and thunder", "right over you"]),
        ((16, 45), ["The front moves on east,", "a few showers behind it"]),
        ((18, 0), ["Dry again"]),
    ])
    print("wrote docs/imber.gif and docs/imber-front.png")
