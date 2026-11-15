from pathlib import Path
base=Path(__file__).parent/'nvidia-libs'
base.mkdir(exist_ok=True)
for pattern in ['libnvidia-*.so*','libGLX_nvidia.so*','libEGL_nvidia.so*']:
 for source in Path('/usr/lib/x86_64-linux-gnu').glob(pattern):
  link=base/source.name
  if link.is_symlink() and link.resolve()==source.resolve():continue
  link.unlink(missing_ok=True);link.symlink_to(source.resolve())
