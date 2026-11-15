"""Verify Finder's real text/uri-list drag reaches an owned GTK application."""
import sys,json,time,subprocess,tempfile
from pathlib import Path
from Xlib import X,display
from Xlib.ext import xtest
BASE=Path(__file__).resolve().parents[1];sys.path.insert(0,str(BASE));from native import rpc
QS=BASE.parent/'runtime/qs'
def ipc(method,*args):return subprocess.check_output([str(QS),'ipc','--newest','-p',str(BASE/'MacShell'),'call','finder',method,*map(str,args)],text=True).strip()
def state():return json.loads(ipc('state'))
def wait(fn):
 for _ in range(60):
  if fn():return
  time.sleep(.1)
 raise AssertionError('GTK drag did not complete')
D=display.Display();root=D.screen().root;pointer=root.query_pointer();active=rpc('state')['active'];before={w['wid'] for w in rpc('state')['clients']};wid=None;process=None
with tempfile.TemporaryDirectory(prefix='macshell-gtk-xdnd-',dir=Path.home()/'.cache') as tmp:
 fixture=Path(tmp);file=fixture/'Drag to another app.txt';file.write_text('Owned interop fixture');received=fixture/'received.json'
 try:
  ipc('newWindow',str(fixture));wait(lambda:state().get('path')==str(fixture) and len(state().get('items',[]))==1)
  wait(lambda:any(w['title']=='Finder' and w['wid'] not in before for w in rpc('state')['clients']))
  wid=next(w['wid'] for w in rpc('state')['clients'] if w['title']=='Finder' and w['wid'] not in before)
  helper=BASE/'tests/gtk-drop-target.py'
  process=subprocess.Popen(['/usr/bin/python3',str(helper),str(received)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  wait(lambda:any(w['title']=='MacShell QA Xdnd Target' for w in rpc('state')['clients']))
  target=next(w for w in rpc('state')['clients'] if w['title']=='MacShell QA Xdnd Target');rpc('activate',wid);time.sleep(.25)
  g=state()['geometry'];x=round(g['gridX']+g['cellWidth']/2);y=round(g['gridY']+36);a=target['at'][0]+target['size'][0]//2;b=target['at'][1]+target['size'][1]//2
  root.warp_pointer(x,y);D.sync();xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.15)
  for i in range(1,31):
   xtest.fake_input(D,X.MotionNotify,x=round(x+(a-x)*i/30),y=round(y+(b-y)*i/30));D.sync();time.sleep(.035)
  time.sleep(.3);xtest.fake_input(D,X.ButtonRelease,1);D.sync();wait(received.exists)
  assert file.as_uri() in json.loads(received.read_text());assert file.exists()
  print('PASS Finder ↔ GTK: native Xdnd delivered the exact text/uri-list to another app; original retained')
 finally:
  xtest.fake_input(D,X.ButtonRelease,1);D.sync()
  if process:process.terminate();process.wait(timeout=5)
  if wid:subprocess.run(['wmctrl','-ic',hex(wid)])
  root.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
  if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
