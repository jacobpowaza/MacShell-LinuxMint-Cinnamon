"""Verify lazy downloads, hash failure cleanup and offline cache reuse."""
import io,hashlib,tempfile,sys
from pathlib import Path
from PIL import Image
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import wallpaper_catalog as w
image=io.BytesIO();Image.new('RGB',(8,8),'blue').save(image,format='JPEG');data=image.getvalue()
sha=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
entry={'id':'fixture','url':'https://example.invalid/image.jpg','sha':sha,'filename':'image.jpg'}
with tempfile.TemporaryDirectory(prefix='macshell-wallpaper-regression-') as tmp:
    w.DEST=Path(tmp);w.catalog=lambda:[entry]
    calls=[]
    def fetch(url):calls.append(url);return io.BytesIO(data)
    w.fetch=fetch
    assert not w.request({'action':'list'})[0]['downloaded'] and not calls
    result=w.request({'action':'download','id':'fixture'})
    assert len(calls)==1 and Path(result).is_file()
    assert w.request({'action':'download','id':'fixture'})==result and len(calls)==1
    assert w.request({'action':'list'})[0]['localPath']==result
    Path(result).unlink();entry['sha']='0'*40
    try:w.request({'action':'download','id':'fixture'})
    except ValueError:pass
    else:raise AssertionError('Accepted a mismatched Git blob')
    assert not list(Path(tmp).glob('.download-*')) and not Path(result).exists()
    try:w.request({'action':'download','id':'../unknown'})
    except ValueError:pass
    else:raise AssertionError('Accepted unknown catalog ID')
print('PASS no listing download, selection download, offline cache, hash failure cleanup, unknown ID refusal')
