#!/usr/bin/env python3
"""Generate the 3x3 jigsaw puzzle source image.

Produces a 192x192 px RGB PNG at assets/puzzles/gradient_3x3.png where each
pixel's color encodes its (x, y) position:
  R = round(255 * x / (W-1))  -- increases left -> right
  B = round(255 * y / (H-1))  -- increases top -> bottom
  G = 60                      -- fixed

The gradient makes each of the 9 (64x64) cells a visually distinct color and
makes a rotated piece visibly wrong, unlike a flat color. Deterministic and
safe to re-run; overwrites the output file each time.
"""

from pathlib import Path

from PIL import Image

WIDTH = 192
HEIGHT = 192
FIXED_GREEN = 60

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PATH = REPO_ROOT / "assets" / "puzzles" / "gradient_3x3.png"


def generate() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT))
    pixels = image.load()

    for y in range(HEIGHT):
        for x in range(WIDTH):
            r = round(255 * x / (WIDTH - 1))
            b = round(255 * y / (HEIGHT - 1))
            pixels[x, y] = (r, FIXED_GREEN, b)

    return image


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    image = generate()
    image.save(OUTPUT_PATH)
    print(f"Wrote {OUTPUT_PATH} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
