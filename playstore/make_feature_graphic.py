#!/usr/bin/env python3
"""Compose the Play Store feature graphic (1024x500) for Loady.

Design: dark navy background with a subtle radial glow, the app icon on the
left, the wordmark "Loady" on the right with the French tagline and a pair
of pill badges (LOCAL / RAPIDE) matching the in-app hero.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
ICON_PATH = ROOT / "loady-icon-512.png"
OUT_PATH = ROOT / "loady-feature-graphic.png"

W, H = 1024, 500
BG_DARK = (11, 13, 18)      # #0B0D12
BG_LIGHT = (24, 32, 54)     # a slightly bluer tone for the glow
BRAND_BLUE = (61, 115, 255)  # #3D73FF
BRAND_CYAN = (88, 216, 255)  # #58D8FF
TEXT = (235, 240, 250)
MUTED = (160, 172, 196)
PILL_BG = (61, 115, 255, 46)
PILL_BORDER = (61, 115, 255, 120)

FONT_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"


def gradient_background():
    """Vertical dark gradient with a soft radial glow behind the icon."""
    img = Image.new("RGB", (W, H), BG_DARK)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        r = int(BG_DARK[0] * (1 - t) + BG_LIGHT[0] * t * 0.6)
        g = int(BG_DARK[1] * (1 - t) + BG_LIGHT[1] * t * 0.6)
        b = int(BG_DARK[2] * (1 - t) + BG_LIGHT[2] * t * 0.6)
        for x in range(W):
            px[x, y] = (r, g, b)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((60, 60, 540, 540), fill=(61, 115, 255, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=90))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    return img.convert("RGB")


def rounded_pill(draw, xy, radius, fill, outline, width=2):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def main():
    assert ICON_PATH.exists(), f"missing icon: {ICON_PATH}"

    img = gradient_background()
    draw = ImageDraw.Draw(img, "RGBA")

    # Icon on the left (320x320 with 90px left margin)
    icon = Image.open(ICON_PATH).convert("RGBA")
    icon_size = 320
    icon = icon.resize((icon_size, icon_size), Image.LANCZOS)
    img.paste(icon, (90, (H - icon_size) // 2), icon)

    # Wordmark + tagline on the right
    name_font = ImageFont.truetype(FONT_BOLD, 128)
    tag_font = ImageFont.truetype(FONT_REG, 32)
    sub_font = ImageFont.truetype(FONT_BOLD, 20)

    text_x = 470
    draw.text((text_x, 150), "Loady", font=name_font, fill=TEXT)
    draw.text(
        (text_x, 300),
        "Ton contenu. Ton appareil. Tes règles.",
        font=tag_font,
        fill=MUTED,
    )

    # Two pills: LOCAL / RAPIDE
    def pill(x, y, label):
        padding_x, padding_y = 18, 10
        tw = draw.textlength(label, font=sub_font)
        box = (x, y, x + tw + 2 * padding_x, y + 44)
        rounded_pill(draw, box, radius=22, fill=PILL_BG, outline=PILL_BORDER, width=2)
        draw.text((x + padding_x, y + padding_y - 2), label, font=sub_font, fill=BRAND_CYAN)
        return box[2]

    end1 = pill(text_x, 370, "LOCAL")
    pill(end1 + 14, 370, "RAPIDE")

    img.save(OUT_PATH, "PNG", optimize=True)
    print(f"wrote {OUT_PATH} ({OUT_PATH.stat().st_size} bytes, {img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
