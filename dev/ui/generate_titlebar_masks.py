"""Rebuild the Canvas window frame and close icon (Pillow, NumPy)."""

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


def frame_shape(x, y, inset=0):
    # Both arcs are concentric; the body has square bottom corners.
    dx = np.maximum(np.maximum(8 - x, x - 24), 0)
    dy = np.maximum(8 - y, 0)
    return ((dx ** 2 + dy ** 2 <= (8 - inset) ** 2)
            & (x >= inset) & (x <= 32 - inset) & (y >= inset) & (y <= 64 - inset))


def coverage(width, height, shape, softness):
    # All dimensions, including the filter radius, are in final window pixels.
    x = (np.arange(width * SAMPLES_PER_PIXEL) + 0.5) / SAMPLES_PER_PIXEL
    y = (np.arange(height * SAMPLES_PER_PIXEL) + 0.5) / SAMPLES_PER_PIXEL
    inside = shape(x[None, :], y[:, None])
    alpha = Image.fromarray(inside.astype(np.uint8) * 255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(softness * SAMPLES_PER_PIXEL))
    return alpha.resize((width * TEXTURE_SCALE, height * TEXTURE_SCALE), Image.Resampling.BOX)


def window_frame():
    outer = coverage(32, 64, frame_shape, 0.34)
    inner = coverage(32, 64, lambda x, y: frame_shape(x, y, 1), 0.34)
    # Store straight luminance and alpha. The outermost covered samples contain
    # only the outline color; the interior is tinted by the Canvas image.
    alpha = np.asarray(outer, dtype=float)
    fill = np.divide(np.asarray(inner), alpha, out=np.zeros_like(alpha), where=alpha > 0)
    light = np.full_like(alpha, 255)
    light[31 * TEXTURE_SCALE : 32 * TEXTURE_SCALE] = [[226], [244]]
    luminance = np.rint(185 + (light - 185) * np.minimum(fill, 1)).astype(np.uint8)
    return Image.merge("LA", (Image.fromarray(luminance), outer))


if __name__ == "__main__":
    close = coverage(16, 16, close_shape, 0.45)
    Image.merge("LA", (Image.new("L", close.size, 255), close)).save(OUTPUT / "close-mask.png", optimize=True)
    window_frame().save(OUTPUT / "window-frame.png", optimize=True)
