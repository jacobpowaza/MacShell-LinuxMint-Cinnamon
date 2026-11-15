"""Render only the visible portion of a scaled glass backdrop."""
from PIL import Image


def scaled_region(source, size, area, cover=False):
    """Equivalent geometry to resize/center-cover then crop, with bounded output.

    Transparent pixels outside the target allow correct window compositing.
    Wallpaper crops use opaque black outside the screen, as Pillow crop does.
    """
    width, height = size
    left, top, right, bottom = area
    result = Image.new('RGBA', (right-left, bottom-top), (0, 0, 0, 255 if cover else 0))
    x0, y0 = max(0, left), max(0, top)
    x1, y1 = min(width, right), min(height, bottom)
    if x1 <= x0 or y1 <= y0:
        return result
    sw, sh = source.size
    if cover:
        scale = max(width/sw, height/sh)
        crop_w, crop_h = width/scale, height/scale
        offset_x, offset_y = (sw-crop_w)/2, (sh-crop_h)/2
    else:
        crop_w, crop_h = sw, sh
        offset_x = offset_y = 0
    box = (offset_x+x0*crop_w/width, offset_y+y0*crop_h/height,
           offset_x+x1*crop_w/width, offset_y+y1*crop_h/height)
    piece = source.resize((x1-x0, y1-y0), Image.Resampling.BICUBIC, box=box).convert('RGBA')
    result.paste(piece, (x0-left, y0-top))
    return result
