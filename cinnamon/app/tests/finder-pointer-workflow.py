"""Natural Finder right-click, marquee, and Favorites drop using owned fixtures."""
from pathlib import Path
import sys,json,time,subprocess,tempfile,shutil
from Xlib import display,X,XK
from Xlib.ext import xtest
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs';D=display.Display();R=D.screen().root;pointer=R.query_pointer();active=rpc('state')['active'];before={w['wid'] for w in rpc('state')['clients']};wid=None
fav=Path.home()/'.config/macshell-finder/favorites.json';saved=fav.read_bytes() if fav.exists() else None
def ipc(m,*a):return subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call','finder',m,*map(str,a)],text=True).strip()
def state():return json.loads(ipc('state'))
def wait(f):
 for _ in range(70):
  v=f()
  if v:return v
  time.sleep(.1)
 raise AssertionError('Timeout '+str(state()))
def click(x,y,b=1):
 R.warp_pointer(round(x),round(y));D.sync();xtest.fake_input(D,X.ButtonPress,b);xtest.fake_input(D,X.ButtonRelease,b);D.sync();time.sleep(.25)
def drag(x,y,a,b,capture=None):
 R.warp_pointer(round(x),round(y));D.sync();xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.1)
 for i in range(1,25):xtest.fake_input(D,X.MotionNotify,x=round(x+(a-x)*i/24),y=round(y+(b-y)*i/24));D.sync();time.sleep(.03)
 if capture:shutil.copy2(rpc("capture",wid),B/".impeccable/tahoe-workflow"/capture)
 time.sleep(.2);xtest.fake_input(D,X.ButtonRelease,1);D.sync();time.sleep(.3)
def key(k):
 code=D.keysym_to_keycode(XK.string_to_keysym(k));xtest.fake_input(D,X.KeyPress,code);xtest.fake_input(D,X.KeyRelease,code);D.sync();time.sleep(.2)
with tempfile.TemporaryDirectory(prefix='macshell-pointer-',dir=Path.home()/'.cache') as tmp:
 p=Path(tmp);(p/'Favorite fixture').mkdir();[(p/(n+'.txt')).write_text('Owned fixture') for n in ['Alpha','Beta','Gamma','Delta','Epsilon','Zeta','Eta']]
 try:
  ipc('newWindow',tmp);wait(lambda:state().get('path')==tmp and len(state()['items'])==8)
  wid=wait(lambda:next((w['wid'] for w in rpc('state')['clients'] if w['title']=='Finder' and w['wid'] not in before),None));rpc('activate',wid);time.sleep(.4)
  g=state()['geometry'];x,y=g['gridX'],g['gridY'];cw,ch=g['cellWidth'],g['cellHeight']
  click(x+cw/2,y+35,3);wait(lambda:state()['menuVisible']);s=state();assert len(s['selection'])==1
  # File menu: Get Info is the third row. Clicking it must run a real action.
  click(s['menuX']+90,s['menuY']+5+22*2+11)
  info=wait(lambda:next((w['wid'] for w in rpc('state')['clients'] if w['title']=='Favorite fixture Info'),None));subprocess.run(['wmctrl','-ic',hex(info)]);rpc('activate',wid)
  print('PASS Finder: natural file right-click and Get Info action',flush=True)
  click(x+cw*5.5,y+ch*2.7,3);wait(lambda:state()['menuVisible']);assert not state()['selection'];time.sleep(.6);assert D.get_input_focus().focus.get_wm_name()=='MacShell Context Menu';key('Escape');wait(lambda:not state()['menuVisible'])
  print('PASS Finder: natural blank-space right-click and Escape',flush=True)
  # Start below the file rows and drag backwards across the first two columns.
  drag(x+cw*1.9,y+ch*2.5,x+3,y+3,"finder-marquee.png");s=state();assert len(s['selection'])>=3,s['selection']
  shutil.copy2(rpc('capture',wid),B/'.impeccable/tahoe-workflow/finder-selection.png')
  print('PASS Finder: drag-box selects multiple files',flush=True)
  # Clear selection, then drag folder to the Favorites section.
  click(x+cw*5.5,y+ch*2.7);drag(x+cw/2,y+35,g['x']+90,g['y']+180)
  wait(lambda:any(v['path']==str(p/'Favorite fixture') for v in state()['favorites']));assert (p/'Favorite fixture').is_dir()
  assert str(p/'Favorite fixture') in json.loads(fav.read_text())
  print('PASS Finder: folder drop pins Favorites without moving files and persists',flush=True)
 finally:
  xtest.fake_input(D,X.ButtonRelease,1);D.sync()
  if wid:subprocess.run(['wmctrl','-ic',hex(wid)])
  if saved is None:fav.unlink(missing_ok=True)
  else:fav.write_bytes(saved)
  R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
  if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
