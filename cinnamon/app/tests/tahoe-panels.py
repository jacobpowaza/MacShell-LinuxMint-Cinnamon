import sys,subprocess,json,time,shutil
from pathlib import Path
from Xlib import display,X,XK
from Xlib.ext import xtest
BASE=Path(__file__).resolve().parents[1];sys.path.insert(0,str(BASE));from native import rpc
OUT=BASE/'.impeccable/tahoe-workflow';OUT.mkdir(exist_ok=True);QS=BASE.parent/'runtime/qs';D=display.Display();root=D.screen().root;pointer=root.query_pointer();active=rpc('state')['active'];opened=[];added=[];bg=None

def ipc(target,method,*args):return subprocess.check_output([str(QS),'ipc','--newest','-p',str(BASE/'MacShell'),'call',target,method,*map(str,args)],text=True).strip()
def wait(fn,seconds=8):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  value=fn()
  if value:return value
  time.sleep(.1)
 raise AssertionError('UI did not settle')
def raw(title):
 for w in root.query_tree().children:
  try:
   if w.get_wm_name()==title and w.get_attributes().map_state==X.IsViewable:return w.id
  except Exception:pass
 return None
def shot(wid,name):
 time.sleep(1.15);shutil.copy2(rpc('capture',wid),OUT/name);print('Captured',name,flush=True)
def key(name):
 code=D.keysym_to_keycode(XK.string_to_keysym(name));xtest.fake_input(D,X.KeyPress,code);xtest.fake_input(D,X.KeyRelease,code);D.sync();time.sleep(.15)
def click(x,y,button=1):
 root.warp_pointer(round(x),round(y));D.sync();xtest.fake_input(D,X.ButtonPress,button);xtest.fake_input(D,X.ButtonRelease,button);D.sync();time.sleep(.2)
def state():return json.loads(ipc('finder','state'))
try:
 bg=subprocess.Popen(['/usr/bin/python3',str(BASE/'tests/qa_backdrop.py')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);wait(lambda:raw('MacShell Owned QA Backdrop'))
 ipc('widgets','gallery');gallery=wait(lambda:raw('MacShell Widget Gallery'));time.sleep(.6)
 ipc('widgets','context','clock',1050,400);menu=wait(lambda:raw('MacShell Context Menu'));shot(menu,'widget-context-menu.png');click(1110,415)
 editor=wait(lambda:raw('Edit Widget'));shot(editor,'widget-editor.png');key('Escape');time.sleep(.5)
 shot(gallery,'widget-gallery.png');assert D.get_input_focus().focus.id==gallery;assert not json.loads(ipc('widgets','galleryState'))['menu'];key('Escape');wait(lambda:not json.loads(ipc('widgets','galleryState'))['gallery'])
 print('PASS Widget editor returns keyboard focus to gallery; Escape exits',flush=True)
 for pane,name in [('general','settings-general.png'),('keyboard','settings-keyboard.png'),('apps','settings-default-apps.png'),('about','settings-about.png')]:
  ipc('settings','pane',pane);settings=wait(lambda:raw('Settings'))
  if settings not in opened:opened.append(settings)
  shot(settings,name)
 subprocess.run(['wmctrl','-ic',hex(settings)]);opened.remove(settings)
 ipc('wallpapers','open');time.sleep(4);surface=wait(lambda:raw('MacShell Wallpaper Picker'));shot(surface,'wallpaper-picker.png');ipc('wallpapers','close')
finally:
 ipc('widgets','edit','false');ipc('wallpapers','close')
 for wid in opened:subprocess.run(['wmctrl','-ic',hex(wid)])
 if bg:bg.terminate();bg.wait(timeout=5)
 root.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
