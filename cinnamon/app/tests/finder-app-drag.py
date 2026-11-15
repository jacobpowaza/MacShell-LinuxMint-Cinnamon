"""Native application drag regression; owned launcher, folders and restored dock pins."""
from pathlib import Path
import sys,json,time,subprocess,tempfile,shutil
from Xlib import display,X
from Xlib.ext import xtest
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs'
def ipc(target,method,*args):return subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call',target,method,*map(str,args)],text=True).strip()
def state():return json.loads(ipc('finder','state'))
def wait(fn):
 end=time.monotonic()+8
 while time.monotonic()<end:
  value=fn()
  if value:return value
  time.sleep(.1)
 raise AssertionError('Timed out: '+str(state()))
D=display.Display();R=D.screen().root;pointer=R.query_pointer();active=rpc('state')['active'];before={w['wid'] for w in rpc('state')['clients']};owned=[]
pins=Path.home()/'.config/macdock/pinned.json';saved=pins.read_bytes() if pins.exists() else None
with tempfile.TemporaryDirectory(prefix='macshell-app-drag-') as tmp:
 name=Path(tmp).name+'.desktop';launcher=Path.home()/'.local/share/applications'/name
 desktop=Path.home()/'Desktop'/name
 launcher.write_text('[Desktop Entry]\nType=Application\nName=Finder Drag Regression Fixture\nExec=/bin/true\nIcon=application-x-executable\n')
 def window(path):
  old={w['wid'] for w in rpc('state')['clients']};ipc('finder','newWindow',path)
  wid=wait(lambda:next((w['wid'] for w in rpc('state')['clients'] if w['wid'] not in old and w['title']=='Finder'),None));owned.append(wid);return wid
 def drag_to(x,y,hover=None):
  s=state();g=s['geometry'];start=(round(g['gridX']+g['cellWidth']/2),round(g['gridY']+(31 if s['listMode'] else 36)))
  R.warp_pointer(*start);D.sync();xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.15)
  for i in range(1,31):
   xtest.fake_input(D,X.MotionNotify,x=round(start[0]+(x-start[0])*i/30),y=round(start[1]+(y-start[1])*i/30));D.sync();time.sleep(.035)
  time.sleep(.3)
  if hover:hover()
  xtest.fake_input(D,X.ButtonRelease,1);D.sync()
 try:
  source=window('applications:');rpc('activate',source);ipc('finder','search','Finder Drag Regression Fixture');wait(lambda:len(state()['items'])==1)
  evidence=B/'.impeccable/finder-app-drag';evidence.mkdir(parents=True,exist_ok=True)
  monitor=rpc('state')['monitors'][0]['name']
  def capture(name):shutil.copy2(rpc('capture-screen',monitor),evidence/name)
  drag_to(1800,850,lambda:capture('desktop-copy-badge.png'))
  wait(lambda:desktop.exists());assert launcher.exists();assert desktop.read_bytes()==launcher.read_bytes()
  print('PASS Applications → desktop surface creates shortcut and preserves installed launcher',flush=True)
  desktop.unlink();ipc('finder','view','list');time.sleep(.3)
  drag_to(1800,850);wait(lambda:desktop.exists());assert launcher.exists()
  print('PASS Applications list view → desktop starts drag instead of scrolling',flush=True)
  desktop.unlink();ipc('finder','view','grid');time.sleep(.3)
  g=state()['geometry'];drag_to(g['x']+90,g['y']+210)
  wait(lambda:desktop.exists());assert launcher.exists()
  print('PASS Applications → Desktop sidebar creates shortcut',flush=True)
  # Folder window behind source, moved aside so its content is a reachable drop target.
  target=window(tmp);subprocess.run(['wmctrl','-ir',hex(target),'-e','0,1150,150,700,500'],check=True)
  rpc('activate',source);time.sleep(.5)
  drag_to(1500,300);wait(lambda:(Path(tmp)/name).exists());assert launcher.exists()
  print('PASS Applications → another Finder folder copies launcher',flush=True)
  # Native drop onto dock adds a persistent pin without duplicating it.
  rpc('activate',source);time.sleep(.3)
  geo=json.loads(ipc('cinnamon','dockGeometry'));dock=next(iter(geo.values()))
  def check_hover():
   during=next(iter(json.loads(ipc('cinnamon','dockGeometry')).values()))
   assert max(i['scale'] for i in during['icons'])>1.05,during
   capture('dock-copy-badge-hover.png')
   print('PASS dock magnifies during native application drag',flush=True)
  drag_to(dock['x']+dock['width']/2,dock['y']+dock['height']/2,check_hover)
  wait(lambda:pins.exists() and name.removesuffix('.desktop') in [str(p).removesuffix('.desktop') for p in json.loads(pins.read_text())])
  drag_to(dock['x']+dock['width']/2,dock['y']+dock['height']/2)
  time.sleep(.3)
  assert [str(p).removesuffix('.desktop') for p in json.loads(pins.read_text())].count(name.removesuffix('.desktop'))==1
  print('PASS Applications → dock persists pin without duplicates',flush=True)
 finally:
  xtest.fake_input(D,X.ButtonRelease,1);D.sync()
  for wid in owned:subprocess.run(['wmctrl','-ic',hex(wid)],check=False)
  launcher.unlink(missing_ok=True);desktop.unlink(missing_ok=True)
  if saved is not None:pins.write_bytes(saved)
  else:pins.unlink(missing_ok=True)
  R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
  if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
