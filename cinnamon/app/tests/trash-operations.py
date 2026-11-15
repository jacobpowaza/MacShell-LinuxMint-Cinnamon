"""Exercise permanent deletion only inside a private XDG Trash fixture."""
import os,sys,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from finder_files import request
import trash_service
with tempfile.TemporaryDirectory(prefix='macshell-trash-regression-') as temp:
    os.environ['XDG_DATA_HOME']=temp
    trash=trash_service.files();info=trash.parent/'info';info.mkdir()
    outside=Path(temp)/'keep';outside.write_text('must survive')
    (trash/'link').symlink_to(outside);(trash/'folder').mkdir();(trash/'folder'/'child').write_text('fixture')
    (trash/'.hidden').write_text('fixture')
    for name in ['link','folder','.hidden']:(info/(name+'.trashinfo')).write_text('[Trash Info]\nPath='+str(outside)+'\n')
    assert request({'action':'trash-state'})['count']==3
    try:request({'action':'delete-forever','paths':[str(trash/'link'),str(outside)]})
    except ValueError:pass
    else:raise AssertionError('Accepted a path outside Trash')
    assert (trash/'link').is_symlink(),'Validation was not atomic'
    result=request({'action':'delete-forever','paths':[str(trash/'link')]})
    assert result['deleted']==1 and outside.read_text()=='must survive'
    result=request({'action':'empty-trash'})
    assert result['deleted']==2 and result['count']==0 and not list(info.iterdir())
    assert outside.read_text()=='must survive'
    assert request({'action':'empty-trash'})['deleted']==0
print('PASS empty, per-item delete, folders, hidden items, symlink safety, outside-path rejection, empty no-op')
