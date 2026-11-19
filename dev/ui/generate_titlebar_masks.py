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
    # A small lower radius fits around the rectangular content canvas, which
    # starts one pixel inside the frame. Each inner arc shares its outer center.
    side = np.minimum(x, 32 - x)
    top = np.maximum(8 - side, 0) ** 2 + np.maximum(8 - y, 0) ** 2
    bottom_radius = 2.5
    bottom = np.maximum(bottom_radius - side, 0) ** 2 + np.maximum(y - (64 - bottom_radius), 0) ** 2
    return (top <= (8 - inset) ** 2) & (bottom <= (bottom_radius - inset) ** 2)


def coverage(width, height, shape, softness):
    # All dimensions, including the filter radius, are in final window pixels.
    x = (np.arange(width * SAMPLES_PER_PIXEL) + 0.5) / SAMPLES_PER_PIXEL
    y = (np.arange(height * SAMPLES_PER_PIXEL) + 0.5) / SAMPLES_PER_PIXEL
    inside = shape(x[None, :], y[:, None])
    alpha = Image.fromarray(inside.astype(np.uint8) * 255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(softness * SAMPLES_PER_PIXEL))
    return alpha.resize((width * TEXTURE_SCALE, height * TEXTURE_SCALE), Image.Resampling.BOX)


def window_frame():
    outer = np.asarray(coverage(32, 64, frame_shape, 0.34), dtype=float)
    fill = np.asarray(coverage(32, 64, lambda x, y: frame_shape(x, y, 0.75), 0.34), dtype=float)
    # A translucent graphite edge picks up the actual scenery or window beneath it.
    edge = (outer - fill) * 0.18
    alpha = fill + edge
    light = np.full_like(fill, 255)
    light[31 * TEXTURE_SCALE : 32 * TEXTURE_SCALE] = [[226], [244]]
    # PNG stores straight color. Weight by covered area before dividing by alpha.
    luminance = np.divide(fill * light + edge * 32, alpha, out=np.zeros_like(alpha), where=alpha > 0)
    return Image.fromarray(np.rint(np.stack((luminance, alpha), axis=-1)).astype(np.uint8))


if __name__ == "__main__":
    close = coverage(16, 16, close_shape, 0.45)
    Image.merge("LA", (Image.new("L", close.size, 255), close)).save(OUTPUT / "close-mask.png", optimize=True)
    window_frame().save(OUTPUT / "window-frame.png", optimize=True)
