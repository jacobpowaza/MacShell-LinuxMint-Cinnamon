"""Home XDG Trash operations shared by Finder and the dock.

Only immediate entries in the configured Trash are accepted. Never follow symlinks
when removing entries, never overwrite a restored item, and retain metadata on failure.
"""
import os, shutil, threading
from pathlib import Path
LOCK=threading.RLock()
def root():
    data=os.environ.get('XDG_DATA_HOME','')
    return (Path(data) if data and Path(data).is_absolute() else Path.home()/'.local/share')/'Trash'
def files():
    target=root()/'files';target.mkdir(parents=True,exist_ok=True);return target
def entries():return list(files().iterdir())
def status():
    with LOCK:return {'path':str(files()),'count':len(entries())}
def delete(paths=None):
    with LOCK:
        folder=files()
        targets=entries() if paths is None else [Path(os.path.abspath(p)) for p in paths]
        if any(p.parent!=folder or p.name in ['.','..'] for p in targets):raise ValueError('Only items in Trash can be deleted permanently.')
        failures=[];count=0
        for p in targets:
            try:
                if p.is_dir() and not p.is_symlink():shutil.rmtree(p)
                else:p.unlink()
                (root()/'info'/(p.name+'.trashinfo')).unlink(missing_ok=True)
                count+=1
            except OSError as e:failures.append(p.name+': '+str(e))
        if failures:raise OSError(f'{count} item(s) removed. Could not delete '+ '; '.join(failures))
        (root()/'directorysizes').unlink(missing_ok=True)
        return dict(status(),deleted=count)
