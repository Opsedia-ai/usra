"""Render Usra's app icon and splash PNGs.

The icon's shapes are copied from the founder's
app/assets/branding/app-icon.svg (art units, centred by ART_SCALE). The splash
still uses the older logo in design/screens/Character.dc.html (viewBox 0 0 200
200). The PNGs land in
app/assets/branding/, where flutter_launcher_icons and flutter_native_splash
pick them up (see app/flutter_launcher_icons.yaml and
app/flutter_native_splash.yaml).

    python3 -m venv /tmp/venv && /tmp/venv/bin/pip install pillow svg.path
    /tmp/venv/bin/python tools/branding/render_icons.py
    cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw
from svg.path import parse_path

NILE = (0x1F, 0x5F, 0xA8, 255)
SAND = (0xF6, 0xEE, 0xDF, 255)
INK = (0x14, 0x26, 0x3D, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

HOUSE = (
    "M100 18 Q106 18 111 22 L172 72 Q180 79 180 89 L180 172 Q180 192 160 192 "
    "L40 192 Q20 192 20 172 L20 89 Q20 79 28 72 L89 22 Q94 18 100 18 Z"
)
HEART = (
    "M100 184 C90 176 86 171 86 167 A7 7 0 0 1 100 165 A7 7 0 0 1 114 167 "
    "C114 171 110 176 100 184 Z"
)

APP = Path(__file__).resolve().parents[2] / "app"
OUT = APP / "assets" / "branding"
RES = APP / "android" / "app" / "src" / "main" / "res"
SUPERSAMPLE = 4


def _points(d, steps=200):
    path = parse_path(d)
    return [(p.real, p.imag) for p in (path.point(i / steps) for i in range(steps + 1))]


class Canvas:
    """Draws the 200x200 logo viewBox into a square image, at [box] of its size."""

    def __init__(self, size, background, box):
        self.size = size * SUPERSAMPLE
        self.image = Image.new("RGBA", (self.size, self.size), background)
        self.draw = ImageDraw.Draw(self.image)
        self.scale = self.size * box / 200
        self.offset = (self.size - 200 * self.scale) / 2

    def _xy(self, x, y):
        return (self.offset + x * self.scale, self.offset + y * self.scale)

    def path(self, d, fill):
        self.draw.polygon([self._xy(x, y) for x, y in _points(d)], fill=fill)

    def ellipse(self, cx, cy, rx, ry, fill):
        self.draw.ellipse([self._xy(cx - rx, cy - ry), self._xy(cx + rx, cy + ry)], fill=fill)

    def rounded_rect(self, x, y, w, h, r, fill):
        self.draw.rounded_rectangle(
            [self._xy(x, y), self._xy(x + w, y + h)], radius=r * self.scale, fill=fill
        )

    def stroke(self, d, width, fill):
        # A round brush dragged along the curve: smooth joins and the
        # stroke-linecap="round" ends in one go.
        r = width * self.scale / 2
        for px, py in (self._xy(x, y) for x, y in _points(d, 400)):
            self.draw.ellipse([px - r, py - r, px + r, py + r], fill=fill)

    def save(self, name, opaque=False, folder=OUT, size=None):
        size = size or self.size // SUPERSAMPLE
        image = self.image.resize((size, size), Image.LANCZOS)
        if opaque:  # The App Store rejects icons with an alpha channel.
            image = image.convert("RGB")
        folder.mkdir(parents=True, exist_ok=True)
        image.save(folder / name, optimize=True)


def app_icon(canvas, house=WHITE, face=INK, heart=NILE):
    """White house on Nile blue: the "Usra app icon" frame."""
    canvas.path(HOUSE, house)
    canvas.ellipse(78, 112, 10, 12, face)
    canvas.ellipse(122, 112, 10, 12, face)
    canvas.stroke("M84 136 Q100 152 116 136", 7, face)
    canvas.path(HEART, heart)


def logo_mark(canvas):
    """Nile blue house with a sand face: the "Usra logo mark" frame."""
    canvas.path(HOUSE, NILE)
    canvas.rounded_rect(46, 80, 108, 72, 34, SAND)
    canvas.ellipse(80, 112, 8, 10, INK)
    canvas.ellipse(120, 112, 8, 10, INK)
    canvas.stroke("M86 131 Q100 144 114 131", 6, INK)
    canvas.path(HEART, WHITE)


# app-icon.svg: translate(512 520) scale(4.6) translate(-110 -119), on 1024.
NAVY = (0x26, 0x41, 0x5E, 255)
ART_SCALE = 4.6


class ArtCanvas(Canvas):
    """Draws app-icon.svg's art units, at [fit] of the art's size in the SVG."""

    def __init__(self, size, background, fit=1.0):
        super().__init__(size, background, 1)
        self.scale = self.size / 1024 * ART_SCALE * fit
        self.cx, self.cy = self.size / 2, self.size * 520 / 1024

    def _xy(self, x, y):
        return (self.cx + (x - 110) * self.scale, self.cy + (y - 119) * self.scale)


BODY = "M60 92 L110 52 L160 92 V176 a16 16 0 0 1 -16 16 H76 a16 16 0 0 1 -16 -16 Z"
ROOF = "M48 96 L110 46 L172 96"
MOUTH = "M101 128 Q110 136 119 128"
DOOR = "M92 192 V164 a18 18 0 0 1 36 0 V192 Z"
DOOR_HEART = (
    "M110 176 C104 171 100 168 100 164 a5 5 0 0 1 10 -1 a5 5 0 0 1 10 1 "
    "C120 168 116 171 110 176 Z"
)


def founder_icon(canvas, body, roof, ink, cheek, door, heart):
    canvas.path(BODY, body)
    canvas.stroke(ROOF, 16, roof)
    canvas.ellipse(92, 114, 6, 6, ink)
    canvas.ellipse(128, 114, 6, 6, ink)
    canvas.stroke(MOUTH, 3.5, ink)
    canvas.ellipse(80, 128, 9, 5.5, cheek)
    canvas.ellipse(140, 128, 9, 5.5, cheek)
    canvas.path(DOOR, door)
    canvas.path(DOOR_HEART, heart)


def colour_icon(canvas):
    founder_icon(
        canvas,
        body=(0x8A, 0xAA, 0xD2, 255),
        roof=(0xDC, 0xE6, 0xF2, 255),
        ink=(0x0D, 0x1E, 0x4C, 255),
        cheek=(0xE5, 0xC9, 0xD7, 255),
        door=(0xE5, 0xC9, 0xD7, 255),
        heart=(0xC4, 0x8C, 0xB3, 255),
    )


def silhouette(canvas):
    """Only alpha is used: the face and the door's heart are cut out."""
    founder_icon(
        canvas, body=WHITE, roof=WHITE, ink=CLEAR, cheek=WHITE, door=WHITE, heart=CLEAR
    )


def main():
    # iOS and legacy Android: full-bleed square; the OS rounds the corners.
    canvas = ArtCanvas(1024, NAVY)
    colour_icon(canvas)
    canvas.save("icon.png", opaque=True)

    # Android adaptive icon foreground, same art size. flutter_launcher_icons
    # insets it by 16% on each side, which leaves the whole glyph inside the
    # 33 dp safe-zone circle.
    canvas = ArtCanvas(1024, CLEAR)
    colour_icon(canvas)
    canvas.save("icon_foreground.png")

    # Android 13 themed icon.
    canvas = ArtCanvas(1024, CLEAR)
    silhouette(canvas)
    canvas.save("icon_monochrome.png")

    # Notification small icon: 20 dp live area in a 24 dp icon, drawn by
    # alpha only. The glyph is about 0.7 of the square at full art size.
    canvas = ArtCanvas(1024, CLEAR, fit=20 / 24 / 0.7)
    silhouette(canvas)
    for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        canvas.save("ic_stat_usra.png", folder=RES / f"drawable-{density}", size=round(24 * scale))

    # Splash: the logo mark on the light background; the white app-icon
    # glyph on dark mode's navy. Android 12+ shows the image inside a 2/3
    # circle, so it is drawn small within its 1152 px canvas.
    # Left as they were, Nile blue: pass --splash to redraw them.
    if "--splash" in sys.argv:
        canvas = Canvas(1152, CLEAR, 0.5)
        logo_mark(canvas)
        canvas.save("splash.png")
        canvas = Canvas(1152, CLEAR, 0.5)
        app_icon(canvas, heart=NILE)
        canvas.save("splash_dark.png")


if __name__ == "__main__":
    main()
