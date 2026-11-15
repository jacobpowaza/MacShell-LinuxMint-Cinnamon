"""Check external Cinnamon changes and a real MacShell switch; always restore values."""
import sys,json,time,subprocess
from pathlib import Path
from gi.repository import Gio
from PIL import Image
from Xlib import X,display
from Xlib.ext import xtest
BASE=Path(__file__).resolve().parents[1];sys.path.insert(0,str(BASE));from native import rpc
QS=BASE.parent/'runtime/qs'
def ipc(method,*args):return subprocess.check_output([str(QS),'ipc','--newest','-p',str(BASE/'MacShell'),'call','settings',method,*map(str,args)],text=True)
def state():return json.loads(ipc('nativeState'))
def wait(fn):
 for _ in range(70):
  if fn():return
  time.sleep(.1)
 raise AssertionError('Preference did not synchronize')
keyboard=Gio.Settings.new('org.cinnamon.desktop.peripherals.keyboard');interface=Gio.Settings.new('org.cinnamon.desktop.interface');session=Gio.Settings.new('org.cinnamon.SessionManager')
old_delay=keyboard.get_uint('delay');old_seconds=interface.get_boolean('clock-show-seconds');old_quit=session.get_boolean('quit-delay-toggle')
D=display.Display();root=D.screen().root;pointer=root.query_pointer();active=rpc('state')['active'];wid=None
try:
 keyboard.set_uint('delay',old_delay+1);interface.set_boolean('clock-show-seconds',not old_seconds);Gio.Settings.sync()
 wait(lambda:state()['kbRepeatDelay']==old_delay+1 and state()['showSeconds']==(not old_seconds))
 print('PASS Cinnamon → MacShell: live keyboard and clock preferences',flush=True)
 ipc('pane','general');wait(lambda:any(w['title']=='Settings' for w in rpc('state')['clients']))
 wid=next(w['wid'] for w in rpc('state')['clients'] if w['title']=='Settings');rpc('activate',wid);time.sleep(1)
 image=Image.open(rpc('capture',wid)).convert('RGB');width,height=image.size
 rgb=(52,199,89) if old_quit else (85,85,92)
 candidates=[y for y in range(140,min(height-50,710)) if image.getpixel((width-45,y))==rgb]
 assert candidates,'Could not find owned General switch'
 runs=[]
 for y in candidates:
  if not runs or y>runs[-1][-1]+1:runs.append([y])
  else:runs[-1].append(y)
 runs=[r for r in runs if len(r)>=5];assert runs
 y=sum(runs[-1])/len(runs[-1]);window=D.create_resource_object('window',wid);point=root.translate_coords(window,width-62,round(y))
 def click():
  root.warp_pointer(point.x,point.y);D.sync();xtest.fake_input(D,X.ButtonPress,1);xtest.fake_input(D,X.ButtonRelease,1);D.sync()
 click();wait(lambda:session.get_boolean('quit-delay-toggle')!=old_quit)
 time.sleep(.3);click();wait(lambda:session.get_boolean('quit-delay-toggle')==old_quit)
 print('PASS MacShell → Cinnamon: real General switch changed and restored native logout timer preference',flush=True)
finally:
 keyboard.set_uint('delay',old_delay);interface.set_boolean('clock-show-seconds',old_seconds);session.set_boolean('quit-delay-toggle',old_quit);Gio.Settings.sync()
 if wid:subprocess.run(['wmctrl','-ic',hex(wid)])
 root.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
