#!/usr/bin/env python3
"""Generate the 3x3 jigsaw puzzle source images.

Produces three 192x192 px RGB PNGs under assets/puzzles/, one per pattern:

gradient_3x3.png -- each pixel's color encodes its (x, y) position:
  R = round(255 * x / (W-1))  -- increases left -> right
  B = round(255 * y / (H-1))  -- increases top -> bottom
  G = 60                      -- fixed

diagonal_3x3.png -- smooth diagonal gradient anchored on the x+y / x-y axes:
  u = x + y (range 0..2*(W-1)), v = x - y (range -(W-1)..(W-1))
  R = round(255 * u / (2*(W-1)))
  B = round(255 * (v + (W-1)) / (2*(W-1)))
  G = 150                      -- fixed

stripes_3x3.png -- banded diagonal stripes, higher-contrast/discrete look:
  band = floor((x + y) / 16)
  even bands -> teal (20, 120, 180); odd bands -> coral (220, 90, 60)

Each pattern is anchored so that every 64x64 cell (and in particular the
center cell) is asymmetric under 90-degree rotation, making a rotated piece
visibly wrong rather than blending in. Deterministic and safe to re-run;
overwrites the output files each time.
"""

from pathlib import Path

from PIL import Image

WIDTH = 192
HEIGHT = 192
FIXED_GREEN_GRADIENT = 60
FIXED_GREEN_DIAGONAL = 150
STRIPE_BAND_SIZE = 16
STRIPE_TEAL = (20, 120, 180)
STRIPE_CORAL = (220, 90, 60)

REPO_ROOT = Path(__file__).resolve().parent.parent
PUZZLES_DIR = REPO_ROOT / "assets" / "puzzles"
GRADIENT_OUTPUT_PATH = PUZZLES_DIR / "gradient_3x3.png"
DIAGONAL_OUTPUT_PATH = PUZZLES_DIR / "diagonal_3x3.png"
STRIPES_OUTPUT_PATH = PUZZLES_DIR / "stripes_3x3.png"


def generate_gradient() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()

    for y in range(HEIGHT):
        for x in range(WIDTH):
            r = round(255 * x / (WIDTH - 1))
            b = round(255 * y / (HEIGHT - 1))
            pixels[x, y] = (r, FIXED_GREEN_GRADIENT, b)

    return image


def generate_diagonal() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()

    max_u = 2 * (WIDTH - 1)
    max_v_offset = 2 * (WIDTH - 1)

    for y in range(HEIGHT):
        for x in range(WIDTH):
            u = x + y
            v = x - y
            r = round(255 * u / max_u)
            b = round(255 * (v + (WIDTH - 1)) / max_v_offset)
            pixels[x, y] = (r, FIXED_GREEN_DIAGONAL, b)

    return image


def generate_stripes() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()

    for y in range(HEIGHT):
        for x in range(WIDTH):
            band = (x + y) // STRIPE_BAND_SIZE
            pixels[x, y] = STRIPE_TEAL if band % 2 == 0 else STRIPE_CORAL

    return image


def main() -> None:
    PUZZLES_DIR.mkdir(parents=True, exist_ok=True)

    gradient = generate_gradient()
    gradient.save(GRADIENT_OUTPUT_PATH)
    print(f"Wrote {GRADIENT_OUTPUT_PATH} ({WIDTH}x{HEIGHT})")

    diagonal = generate_diagonal()
    diagonal.save(DIAGONAL_OUTPUT_PATH)
    print(f"Wrote {DIAGONAL_OUTPUT_PATH} ({WIDTH}x{HEIGHT})")

    stripes = generate_stripes()
    stripes.save(STRIPES_OUTPUT_PATH)
    print(f"Wrote {STRIPES_OUTPUT_PATH} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
