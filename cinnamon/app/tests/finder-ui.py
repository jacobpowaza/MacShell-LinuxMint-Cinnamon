"""Exercise only an owned Finder fixture and its exact window; never type globally."""
import json,subprocess,sys,time
from pathlib import Path
from Xlib import display,X,XK,protocol
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));from native import rpc
base=Path(__file__).resolve().parents[1];qs=base.parent/'runtime/qs';fixture=base/'.impeccable/finder-fixture';out=base/'.impeccable/finder-review';out.mkdir(exist_ok=True)
def ipc(method,*args):return subprocess.check_output([str(qs),'ipc','--newest','-p',str(base/'MacShell'),'call','finder',method,*map(str,args)],text=True)
def state():return json.loads(ipc('state'))
def wait(predicate):
 for _ in range(60):
  s=state()
  if predicate(s):return s
  time.sleep(.1)
 raise AssertionError('Finder state did not settle: '+str({k:v for k,v in s.items() if k!='items'}))
def names(s):return [e['name'] for e in s['items']]
before={w['wid'] for w in rpc('state')['clients']};ipc('newWindow',str(fixture));s=wait(lambda s:s.get('path')==str(fixture) and 'Read me.txt' in names(s))
wins=[w for w in rpc('state')['clients'] if w['title']=='Finder' and w['wid'] not in before];assert len(wins)==1
wid=wins[0]['wid'];D=display.Display();root=D.screen().root;w=D.create_resource_object('window',wid)
def key(name,modifiers=0):
 detail=D.keysym_to_keycode(XK.string_to_keysym(name))
 for cls in [protocol.event.KeyPress,protocol.event.KeyRelease]:
  w.send_event(cls(time=X.CurrentTime,root=root,window=w,child=X.NONE,root_x=0,root_y=0,event_x=0,event_y=0,state=modifiers,detail=detail,same_screen=1),event_mask=X.KeyPressMask if cls==protocol.event.KeyPress else X.KeyReleaseMask)
 D.sync()
def text(value):
 for char in value:key('space' if char==' ' else char,X.ShiftMask if char.isupper() else 0)
def shot(name):
 time.sleep(1.5);path=rpc('capture',wid);__import__('shutil').copy2(path,out/name)
def choose(name):
 rpc('activate',wid);time.sleep(.15);s=state();ipc('choose',names(s).index(name));wait(lambda s:bool(s['selection']))
try:
 assert s['fontFamily']=='SF Pro Text'
 shot('finder-grid.png')
 ipc('view','list');wait(lambda s:s['listMode']);shot('finder-list.png')
 choose('Read me.txt')
 ipc('search','notes');s=wait(lambda s:len(s['items'])==1 and names(s)==['Project notes.md']);assert s['items'][0]['directory'] is False
 key('Down',X.ShiftMask);wait(lambda s:s['selection']==[str(fixture/'Project notes.md')])
 print('PASS Finder: stale late-row anchor resets after filtering, Shift selection remains valid')
 ipc('search','');wait(lambda s:'Read me.txt' in names(s));ipc('hidden','true');wait(lambda s:'.hidden-check' in names(s));ipc('hidden','false');wait(lambda s:'.hidden-check' not in names(s))
 extra=fixture/'zz-selection-check.txt';extra.write_text('Owned selection regression fixture')
 wait(lambda s:extra.name in names(s));choose(extra.name);extra.unlink();wait(lambda s:extra.name not in names(s))
 key('Down',X.ShiftMask);wait(lambda s:len(s['selection'])==1 and s['selection'][0]==s['items'][0]['path'])
 print('PASS Finder: stale late-row anchor resets after deletion, Shift selection remains valid')
 choose('Read me.txt');ipc('preview');wait(lambda s:s['quickLook'] and s['previewMime']=='text/plain');shot('finder-quick-look.png');key('Escape');wait(lambda s:not s['quickLook'])
 rpc('activate',wid);time.sleep(.3)
 key('N',X.ControlMask|X.ShiftMask);time.sleep(.25);text('Verified Folder');key('Return');wait(lambda s:'Verified Folder' in names(s))
 choose('Verified Folder');key('F2');time.sleep(.2);key('a',X.ControlMask);text('Renamed Folder');key('Return');wait(lambda s:'Renamed Folder' in names(s) and 'Verified Folder' not in names(s))
 assert state()['selection']==[str(fixture/'Renamed Folder')], 'Rename lost selection'
 key('Return');wait(lambda s:s['path']==str(fixture/'Renamed Folder'));key('Left',X.Mod1Mask);wait(lambda s:s['path']==str(fixture))
 ipc('view','grid');print('PASS Finder UI: SF family, grid/list, search, hidden files, Quick Look, keyboard mkdir/rename, folder navigation and Back')
finally:
 subprocess.run(['wmctrl','-ic',hex(wid)]);D.close()
 (fixture/'zz-selection-check.txt').unlink(missing_ok=True)
 for name in ['Verified Folder','Renamed Folder']:
  p=fixture/name
  if p.exists():p.rmdir()
