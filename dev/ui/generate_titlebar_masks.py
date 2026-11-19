"""Rebuild the two alpha masks used by gui/dialogs/base/window.nas (Pillow, NumPy)."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


OUTPUT = Path(__file__).resolve().parents[2] / "gui" / "images"
SAMPLES_PER_PIXEL = 64
TEXTURE_SCALE = 2


def close_shape(x, y):
    # Fold the four arms onto the same segment, from the center to (13, 13).
    x = np.abs(x - 8)
    y = np.abs(y - 8)
    nearest = np.minimum((x + y) / 2, 5)
    return (x - nearest) ** 2 + (y - nearest) ** 2 <= 0.8 ** 2


def titlebar_shape(x, y):
    # Only the top corners are rounded. The nine-slice center stretches in FG.
    dx = np.maximum(np.maximum(8 - x, x - 24), 0)
    dy = np.maximum(8 - y, 0)
    return dx ** 2 + dy ** 2 <= 8 ** 2


def save_mask(name, size, shape, softness):
    # All dimensions, including the filter radius, are in final window pixels.
    side = size * SAMPLES_PER_PIXEL
    centers = (np.arange(side) + 0.5) / SAMPLES_PER_PIXEL
    inside = shape(centers[None, :], centers[:, None])
    alpha = Image.fromarray(inside.astype(np.uint8) * 255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(softness * SAMPLES_PER_PIXEL))
    side = size * TEXTURE_SCALE
    alpha = alpha.resize((side, side), Image.Resampling.BOX)
    mask = Image.new("LA", alpha.size, (255, 0))
    mask.putalpha(alpha)
    mask.save(OUTPUT / name, optimize=True)


if __name__ == "__main__":
    save_mask("close-mask.png", 16, close_shape, 0.45)
    save_mask("titlebar-mask.png", 32, titlebar_shape, 0.34)
