"""Exercise native Xdnd using only an owned Finder fixture and restore focus/pointer."""
import sys,json,time,subprocess,tempfile
from pathlib import Path
from Xlib import X,display,XK
from Xlib.ext import xtest
BASE=Path(__file__).resolve().parents[1];sys.path.insert(0,str(BASE));from native import rpc
QS=BASE.parent/'runtime/qs'
def ipc(method,*args):return subprocess.check_output([str(QS),'ipc','--newest','-p',str(BASE/'MacShell'),'call','finder',method,*map(str,args)],text=True).strip()
def state():return json.loads(ipc('state'))
def wait(fn,seconds=6):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  if fn():return
  time.sleep(.1)
 raise AssertionError('Timed out: '+str(state()))
D=display.Display();root=D.screen().root;pointer=root.query_pointer();active=rpc('state')['active'];before={w['wid'] for w in rpc('state')['clients']};wid=None
with tempfile.TemporaryDirectory(prefix='macshell-xdnd-',dir=Path.home()/'.cache') as tmp:
 fixture=Path(tmp);folder=fixture/'Destination';folder.mkdir();(fixture/'Move me.txt').write_text('Owned move fixture');(fixture/'Copy me.txt').write_text('Owned copy fixture')
 try:
  ipc('newWindow',str(fixture));wait(lambda:state().get('path')==str(fixture) and len(state().get('items',[]))==3)
  wait(lambda:any(w['wid'] not in before and w['title']=='Finder' for w in rpc('state')['clients']))
  wid=next(w['wid'] for w in rpc('state')['clients'] if w['wid'] not in before and w['title']=='Finder');rpc('activate',wid);time.sleep(.3)
  def point(name):
   s=state();i=next(i for i,e in enumerate(s['items']) if e['name']==name);g=s['geometry'];cols=max(1,int((g['width']-226)//g['cellWidth']));return round(g['gridX']+(i%cols+.5)*g['cellWidth']),round(g['gridY']+(i//cols)*g['cellHeight']+36)
  def drag(name,copy=False):
   x,y=point(name);a,b=point('Destination');root.warp_pointer(x,y);D.sync();time.sleep(.12)
   if copy:xtest.fake_input(D,X.KeyPress,D.keysym_to_keycode(XK.string_to_keysym('Control_L')))
   xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.12)
   for i in range(1,21):
    xtest.fake_input(D,X.MotionNotify,x=round(x+(a-x)*i/20),y=round(y+(b-y)*i/20));D.sync();time.sleep(.035)
   time.sleep(.3);xtest.fake_input(D,X.ButtonRelease,1);D.sync()
   if copy:xtest.fake_input(D,X.KeyRelease,D.keysym_to_keycode(XK.string_to_keysym('Control_L')));D.sync()
  drag('Move me.txt');wait(lambda:(folder/'Move me.txt').exists());assert not (fixture/'Move me.txt').exists()
  print('PASS Finder native drag: moving a file onto a folder',flush=True)
  wait(lambda:len(state()['items'])==2);drag('Copy me.txt',True);wait(lambda:(folder/'Copy me.txt').exists());assert (fixture/'Copy me.txt').exists()
  print('PASS Finder native drag: Control-drag copies a file onto a folder',flush=True)
 finally:
  xtest.fake_input(D,X.ButtonRelease,1);xtest.fake_input(D,X.KeyRelease,D.keysym_to_keycode(XK.string_to_keysym('Control_L')));D.sync()
  if wid:subprocess.run(['wmctrl','-ic',hex(wid)],check=False)
  root.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
  if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
