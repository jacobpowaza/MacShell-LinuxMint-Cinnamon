"""Finder collections and durable Linux file tags; no recursive home scans."""
import json, os, threading, xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime
from urllib.parse import unquote, urlparse
from gi.repository import Gio

LOCK=threading.RLock()
TAGS=Path.home()/'.config/macshell-finder/tags.json'
COLORS={'Red':'#ff5f57','Orange':'#ff9f0a','Yellow':'#ffd60a','Green':'#30d158','Blue':'#0a84ff','Purple':'#bf5af2','Gray':'#8e8e93'}

def load():
    try:return json.loads(TAGS.read_text())
    except (OSError,ValueError):return {}

def save(data):
    TAGS.parent.mkdir(parents=True,exist_ok=True)
    tmp=TAGS.with_suffix('.tmp');tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');tmp.chmod(0o600);tmp.replace(TAGS)

def get(path):
    try:return [v for v in os.getxattr(path,'user.xdg.tags').decode().split(',') if v]
    except OSError:return load().get(str(path),[])

def set_tags(paths,tag,enabled):
    if not tag or ',' in tag or len(tag)>64:raise ValueError('Enter a tag without commas, up to 64 characters.')
    with LOCK:
        data=load()
        for name in paths:
            path=Path(name).absolute()
            if not path.exists():raise FileNotFoundError(path.name)
            values=get(path)
            if enabled and tag not in values:values.append(tag)
            elif not enabled:values=[v for v in values if v!=tag]
            try:os.setxattr(path,'user.xdg.tags',','.join(values).encode())
            except OSError:pass
            if values:data[str(path)]=values
            else:data.pop(str(path),None)
        save(data)
    return {'tags':get(Path(paths[0])) if paths else []}

def relocate(old,new,copy=False):
    with LOCK:
        data=load();tags=get(Path(new)) if Path(new).exists() else []
        if str(old) in data:
            tags=data[str(old)]
            if not copy:data.pop(str(old),None)
        if tags:data[str(new)]=tags
        prefix=str(old).rstrip('/')+'/'
        for key,values in list(data.items()):
            if key.startswith(prefix):
                data[str(new).rstrip('/')+'/'+key[len(prefix):]]=values
                if not copy:data.pop(key,None)
        save(data)

def entry(path):
    try:
        p=Path(path);s=p.stat()
        return {'name':p.name,'path':str(p),'url':p.as_uri(),'directory':p.is_dir(),'size':s.st_size,'modified':datetime.fromtimestamp(s.st_mtime).isoformat(),'tags':get(p)}
    except (OSError,ValueError):return None

def locations():
    out=[]
    for m in Gio.VolumeMonitor.get().get_mounts():
        p=m.get_root().get_path()
        if p and Path(p).exists():
            icon=m.get_symbolic_icon();out.append({'label':m.get_name(),'path':p,'icon':'externaldrive','uri':m.get_root().get_uri()})
    return out

def collection(name):
    paths=[]
    if name=='recent:':
        file=Path.home()/'.local/share/recently-used.xbel'
        if file.exists():
            root=ET.parse(file).getroot()
            for mark in sorted(root.findall('bookmark'),key=lambda x:x.get('modified',''),reverse=True):
                href=mark.get('href','')
                if href.startswith('file://'):paths.append(unquote(urlparse(href).path))
    elif name=='shared:':
        paths=[v['path'] for v in locations()]
        for p in [Path('/run/user')/str(os.getuid())/'gvfs',Path('/media')/Path.home().name]:
            if p.is_dir():paths.extend(str(v) for v in p.iterdir() if v.is_dir())
    elif name.startswith('tag:'):
        tag=name[4:];paths=[path for path,tags in load().items() if tag in tags]
    seen=set();out=[]
    for path in paths:
        if path in seen:continue
        seen.add(path);row=entry(path)
        if row:out.append(row)
        if len(out)>=500:break
    return out

FAVORITES=Path.home()/'.config/macshell-finder/favorites.json'
def favorites(action='favorites',paths=()):
    defaults=['applications:',*[str(Path.home()/n) for n in ['Desktop','Documents','Downloads','Pictures']]]
    with LOCK:
        try:values=json.loads(FAVORITES.read_text())
        except (OSError,ValueError):values=defaults
        if not isinstance(values,list):values=defaults
        if action=='favorites-add':
            candidates=[str(Path(p).expanduser().absolute()) for p in paths]
            if any(not Path(p).is_dir() for p in candidates):raise ValueError('Only folders can be added to Favorites.')
            values=list(dict.fromkeys(values+candidates))
        elif action=='favorites-remove':values=[p for p in values if p not in paths]
        if action!='favorites':
            FAVORITES.parent.mkdir(parents=True,exist_ok=True)
            tmp=FAVORITES.with_suffix('.tmp');tmp.write_text(json.dumps(values)+'\n');tmp.chmod(0o600);tmp.replace(FAVORITES)
        icons={'Desktop':'user-desktop','Documents':'folder-documents','Downloads':'folder-download','Pictures':'folder-pictures'}
        return [{'label':'Applications' if p=='applications:' else Path(p).name,'path':p,'icon':'applications' if p=='applications:' else icons.get(Path(p).name,'folder')} for p in values if p=='applications:' or Path(p).is_dir()]

def request(arg):
    action=arg['action']
    if action.startswith('favorites'):return favorites(action,arg.get('paths',[]))
    if action=='locations':return locations()
    if action=='collection':return collection(arg['collection'])
    if action=='tags-get':return {'tags':get(Path(arg['paths'][0])) if arg.get('paths') else [],'names':list(dict.fromkeys([*COLORS,*[tag for tags in load().values() for tag in tags]]))}
    if action=='tags-set':return set_tags(arg['paths'],arg['tag'],bool(arg['enabled']))
    raise ValueError('Unknown Finder metadata action')
