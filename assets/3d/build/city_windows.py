"""The distant city's window-grid texture (docs/STYLES.md §7 Stage 1 sky).

64 x 64 px, a 2 x 2 grid of dark-glass windows on the silhouette facade with slightly lighter
mullions. SkyService tiles it on each skyline block's faces at 20 studs per tile (one window
per 10-stud storey); the lit windows are separate Neon strips. Run with any Python that has
Pillow:

    python assets/3d/build/city_windows.py

writes assets/3d/city_windows.png (upload once as a Decal; the image id goes in
SkyService.WINDOW_TEXTURE and assets/3d/ASSET_IDS.md).
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "city_windows.png")

FACADE = (30, 27, 30)  # SkyService SILHOUETTE_COLOR
MULLION = (44, 40, 42)
GLASS = (19, 21, 25)
SIZE, CELL = 64, 32
FRAME, SILL = 6, 4  # px of facade round each window (sides / top), plus a sill band below


def main():
    img = Image.new("RGB", (SIZE, SIZE), FACADE)
    px = img.load()
    for cy in range(2):
        for cx in range(2):
            x0, y0 = cx * CELL, cy * CELL
            for y in range(y0 + FRAME, y0 + CELL - FRAME - SILL):
                for x in range(x0 + FRAME, x0 + CELL - FRAME):
                    px[x, y] = GLASS
            for x in range(x0 + FRAME, x0 + CELL - FRAME):  # sill
                px[x, y0 + CELL - FRAME - SILL] = MULLION
            for y in range(y0 + FRAME, y0 + CELL - FRAME - SILL):  # centre mullion
                px[x0 + CELL // 2, y] = MULLION
    img.save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
