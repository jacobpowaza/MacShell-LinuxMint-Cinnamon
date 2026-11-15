"""Type into an owned Settings field and verify native save; restore preference."""
import sys,subprocess,time
from pathlib import Path
from gi.repository import Gio
from Xlib import display,X,XK
from Xlib.ext import xtest
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs';D=display.Display();R=D.screen().root;pointer=R.query_pointer();active=rpc('state')['active'];w=None
setting=Gio.Settings.new('org.cinnamon.launcher');old=setting.get_int('check-frequency')
def key(name,kind):xtest.fake_input(D,kind,D.keysym_to_keycode(XK.string_to_keysym(name)))
try:
 subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call','settings','pane','general'])
 for _ in range(70):
  for candidate in R.query_tree().children:
   try:
    if candidate.get_wm_name()=='Settings' and candidate.get_attributes().map_state==X.IsViewable:w=candidate
   except:pass
  if w:break
  time.sleep(.1)
 assert w;rpc('activate',w.id);time.sleep(.8)
 point=R.translate_coords(w,700,295);R.warp_pointer(point.x,point.y);D.sync();xtest.fake_input(D,X.ButtonPress,1);xtest.fake_input(D,X.ButtonRelease,1)
 key('Control_L',X.KeyPress);key('a',X.KeyPress);key('a',X.KeyRelease);key('Control_L',X.KeyRelease)
 for char in str(old+1):key(char,X.KeyPress);key(char,X.KeyRelease)
 key('Return',X.KeyPress);key('Return',X.KeyRelease);D.sync()
 for _ in range(40):
  if setting.get_int('check-frequency')==old+1:break
  time.sleep(.1)
 assert setting.get_int('check-frequency')==old+1,setting.get_int('check-frequency')
 print('PASS: native Settings numeric field saves on Return without an extra Set button')
finally:
 setting.set_int('check-frequency',old);Gio.Settings.sync()
 if w:subprocess.run(['wmctrl','-ic',hex(w.id)])
 R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(c['wid']==active for c in rpc('state')['clients']):rpc('activate',active)
