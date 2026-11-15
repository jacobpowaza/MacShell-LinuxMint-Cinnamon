"""GitHub metadata and thumbnail previews; originals download only on selection."""
import hashlib, json, os, tempfile, threading
from pathlib import Path
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from PIL import Image
BASE=Path(__file__).resolve().parent
DEST=Path.home()/'.local/share/macshell/wallpapers'
MANIFEST=Path.home()/'.cache/macshell/wallpaper-catalog.json'
REPO='LAYTAT/macOS-Wallpapers'
LOCK=threading.RLock()
MAX_BYTES=128*1024*1024

def fetch(url):return urlopen(Request(url,headers={'User-Agent':'MacShell-Cinnamon/1.0'}),timeout=60)
def from_tree(tree):
    if tree.get('truncated'):raise ValueError('GitHub returned an incomplete catalog. Try again.')
    versions={'10-0_10-1':'Cheetah and Puma','10-0_10.1':'Cheetah and Puma','10-2':'Jaguar','10-3':'Panther','10-4':'Tiger','10-5':'Leopard','10-6':'Snow Leopard','10-7':'Lion','10-8':'Mountain Lion','10-9':'Mavericks','10-10':'Yosemite','10-11':'El Capitan','10-12':'Sierra','10-13':'High Sierra','10-14':'Mojave','10-15':'Catalina','11-0':'Big Sur','12':'Monterey','13':'Ventura','14':'Sonoma','15':'Sequoia','26':'Tahoe'}
    result=[]
    for blob in tree['tree']:
        name=blob['path'];suffix=Path(name).suffix.lower()
        if blob['type']!='blob' or suffix not in ['.jpg','.jpeg','.png','.heic','.webp']:continue
        stem=Path(name).stem;label=stem
        for prefix in sorted(versions,key=len,reverse=True):
            if stem==prefix or stem.lower().startswith(prefix.lower()+'-'):
                tail=stem[len(prefix):].strip('-').replace('-',' ')
                
                if tail.lower().startswith(versions[prefix].lower()+' '):tail=tail[len(versions[prefix]):].strip()
                label=versions[prefix]+(' — '+tail if tail else '');break
        url=f'https://raw.githubusercontent.com/{REPO}/{tree["sha"]}/{quote(name)}'
        result.append({'id':'macos-'+hashlib.sha256(name.encode()).hexdigest()[:16],'name':label,'filename':name,'author':'Apple','url':url,'thumb':'https://images.weserv.nl/?'+urlencode({'url':url,'w':420,'h':260,'fit':'cover','q':70,'output':'jpg'}),'source':f'https://github.com/{REPO}','sha':blob['sha'],'bytes':blob.get('size',0)})
    if not result:raise ValueError('No wallpapers found in the GitHub catalog.')
    return result

def catalog():
    try:return json.loads(MANIFEST.read_text())
    except (OSError,ValueError):return json.loads((BASE/'wallpaper-catalog.json').read_text())
def cache_path(e):
    # Existing Mint catalog caches keep their original .jpg names.
    ext=Path(e.get('filename','')).suffix.lower() or '.jpg'
    return DEST/(e['id']+('.jpg' if ext=='.heic' else ext))
def listed():return [dict(e,downloaded=cache_path(e).is_file(),localPath=str(cache_path(e)) if cache_path(e).is_file() else '') for e in catalog()]
def request(arg):
    action=arg.get('action')
    if action=='refresh':
        with fetch(f'https://api.github.com/repos/{REPO}/git/trees/main?recursive=1') as response:tree=json.load(response)
        remote=from_tree(tree)
        old=[e for e in catalog() if e.get('source')!=f'https://github.com/{REPO}']
        MANIFEST.parent.mkdir(parents=True,exist_ok=True)
        fd,tmp=tempfile.mkstemp(dir=MANIFEST.parent,prefix='.catalog-')
        try:
            with os.fdopen(fd,'w') as out:json.dump(remote+old,out,indent=2)
            os.replace(tmp,MANIFEST)
        finally:Path(tmp).unlink(missing_ok=True)
        return listed()
    if action=='list':return listed()
    if action!='download':raise ValueError('Unknown wallpaper action.')
    with LOCK:
        entry=next((e for e in catalog() if e['id']==arg.get('id')),None)
        if not entry:raise ValueError('Unknown wallpaper')
        DEST.mkdir(parents=True,exist_ok=True);final=cache_path(entry)
        if final.exists():
            try:
                with Image.open(final) as im:im.verify()
                return str(final)
            except (OSError,ValueError):pass # replace a damaged cache atomically
        fd,tmp=tempfile.mkstemp(prefix='.download-',dir=DEST)
        try:
            digest=hashlib.sha1();size=0
            with os.fdopen(fd,'wb') as out,fetch(entry['url']) as response:
                while chunk:=response.read(65536):
                    size+=len(chunk)
                    if size>MAX_BYTES:raise ValueError('Wallpaper exceeds the size limit')
                    out.write(chunk)
            data=Path(tmp).read_bytes()
            digest=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
            if digest!=entry['sha']:raise ValueError('Wallpaper download is incomplete. Try again.')
            if Path(entry.get('filename','')).suffix.lower()=='.heic':
                from heic_preview import convert
                # Mint's desktop needs a still image; retain the verified source beside it.
                preview=final;convert(tmp,str(preview)+'.tmp');os.replace(str(preview)+'.tmp',preview)
                os.replace(tmp,final.with_suffix('.heic'))
                (DEST/(entry['id']+'.origin.json')).write_text(json.dumps(entry,indent=2)+'\n')
                return str(preview)
            with Image.open(tmp) as im:im.verify()
            os.replace(tmp,final)
            (DEST/(entry['id']+'.origin.json')).write_text(json.dumps(entry,indent=2)+'\n')
            return str(final)
        finally:Path(tmp).unlink(missing_ok=True)
