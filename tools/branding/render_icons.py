"""Render Usra's app icon and splash PNGs from the logo in design/.

The shapes are copied from the "Usra app icon" and "Usra logo mark" SVGs in
design/screens/Character.dc.html (viewBox 0 0 200 200). The PNGs land in
app/assets/branding/, where flutter_launcher_icons and flutter_native_splash
pick them up (see app/flutter_launcher_icons.yaml and
app/flutter_native_splash.yaml).

    python3 -m venv /tmp/venv && /tmp/venv/bin/pip install pillow svg.path
    /tmp/venv/bin/python tools/branding/render_icons.py
    cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

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


def main():
    # iOS and legacy Android: full-bleed square; the OS rounds the corners.
    # The design shows the glyph at 72/104 of the tile.
    canvas = Canvas(1024, NILE, 72 / 104)
    app_icon(canvas)
    canvas.save("icon.png", opaque=True)

    # Android adaptive icon foreground. flutter_launcher_icons insets it by
    # 16% on each side; at 0.8 the house's bottom corners stay inside the
    # 33 dp safe-zone radius, so circle masks don't clip them.
    canvas = Canvas(1024, CLEAR, 0.8)
    app_icon(canvas)
    canvas.save("icon_foreground.png")

    # Android 13 themed icon: only the alpha channel is used, so the face
    # and heart are cut out of the house.
    canvas = Canvas(1024, CLEAR, 0.8)
    app_icon(canvas, house=WHITE, face=CLEAR, heart=CLEAR)
    canvas.save("icon_monochrome.png")

    # Notification small icon: 20 dp live area in a 24 dp icon. Android
    # draws only its alpha, so a full-colour launcher icon would show as a
    # white square.
    canvas = Canvas(1024, CLEAR, 20 / 24 / 0.8)
    app_icon(canvas, house=WHITE, face=CLEAR, heart=CLEAR)
    for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        canvas.save("ic_stat_usra.png", folder=RES / f"drawable-{density}", size=round(24 * scale))

    # Splash: the logo mark on the light background; the white app-icon
    # glyph on dark mode's navy. Android 12+ shows the image inside a 2/3
    # circle, so it is drawn small within its 1152 px canvas.
    canvas = Canvas(1152, CLEAR, 0.5)
    logo_mark(canvas)
    canvas.save("splash.png")
    canvas = Canvas(1152, CLEAR, 0.5)
    app_icon(canvas, heart=NILE)
    canvas.save("splash_dark.png")


if __name__ == "__main__":
    main()
