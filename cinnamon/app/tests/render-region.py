"""Compare bounded backdrop rendering with full-size composition."""
import sys
from pathlib import Path
from PIL import Image, ImageOps, ImageChops, ImageStat
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from render_region import scaled_region
source = Image.new('RGB', (320, 180))
source.putdata([(x % 256, y % 256, (x+y) % 256) for y in range(180) for x in range(320)])
for size in [(1920, 1080), (800, 1200), (120, 70)]:
    for area in [(30, 20, 110, 60), (-30, -20, 90, 60), (900, 700, 1200, 900)]:
        for cover in [False, True]:
            full = ImageOps.fit(source.convert('RGBA'), size) if cover else source.convert('RGBA').resize(size)
            expected = full.crop(area)
            if cover:
                # Pillow RGBA crop fills outside with transparent black; the
                # production wallpaper is opaque, so compare RGB only.
                pass
            actual = scaled_region(source, size, area, cover)
            error = ImageStat.Stat(ImageChops.difference(expected.convert('RGB'), actual.convert('RGB')))
            assert max(error.mean) < 1, (size, area, cover, error.mean)
            if not cover:assert actual.getchannel('A').tobytes() == expected.getchannel('A').tobytes()
# Ensure intermediates never scale a window to its full desktop dimensions.
class Tracked:
    size = source.size
    def resize(self, size, *args, **kwargs):
        assert size[0] <= 240 and size[1] <= 180, size
        return source.resize(size, *args, **kwargs)
scaled_region(Tracked(), (7680, 4320), (100, 100, 340, 280))
print('PASS: crop/cover geometry, clipping, transparency, bounded resize')
