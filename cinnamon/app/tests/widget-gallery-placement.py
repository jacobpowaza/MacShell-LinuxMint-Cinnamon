"""Exercise real gallery movement and menu alpha, restoring focus and pointer."""
from pathlib import Path
import sys,json,subprocess,time
from Xlib import display,X,XK
from Xlib.ext import xtest
from PIL import Image
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
D=display.Display();R=D.screen().root;pointer=R.query_pointer();active=rpc('state')['active']
def ipc(method,*args):return subprocess.check_output([str(B.parent/'runtime/qs'),'ipc','--newest','-p',str(B/'MacShell'),'call','widgets',method,*map(str,args)],text=True).strip()
def window(title):
 for _ in range(50):
  for w in R.query_tree().children:
   try:
    if w.get_wm_name()==title and w.get_attributes().map_state==X.IsViewable:return w
   except Exception:pass
  time.sleep(.05)
 raise AssertionError(title)
def key(name):
 code=D.keysym_to_keycode(XK.string_to_keysym(name));xtest.fake_input(D,X.KeyPress,code);xtest.fake_input(D,X.KeyRelease,code);D.sync()
try:
 ipc('context','clock',700,300);menu=window('MacShell Context Menu');time.sleep(.5)
 g=menu.get_geometry();raw=menu.get_image(0,0,g.width,g.height,X.ZPixmap,0xffffffff)
 image=Image.frombytes('RGBA',(g.width,g.height),raw.data,'raw','BGRA')
 assert image.getpixel((5,g.height//2))[3]<25,'Backdrop paints outside menu hitbox'
 image.save('/tmp/macshell-menu-verified.png');key('Escape');time.sleep(.2)
 ipc('gallery');gallery=window('MacShell Widget Gallery');time.sleep(.6)
 g=gallery.get_geometry();p=R.translate_coords(gallery,0,0)
 assert abs(p.x-(D.screen().width_in_pixels-g.width)/2)<=2,(p.x,g.width)
 assert D.screen().height_in_pixels-90<=p.y+g.height<=D.screen().height_in_pixels-18,(p.y,g.height)
 x,y=p.x+g.width//2,p.y+g.height-28
 R.warp_pointer(x,y);D.sync();xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.1)
 for i in range(1,11):
  xtest.fake_input(D,X.MotionNotify,x=x+10*i,y=y-8*i);D.sync();time.sleep(.025)
 xtest.fake_input(D,X.ButtonRelease,1);D.sync();time.sleep(.25)
 after=R.translate_coords(gallery,0,0)
 assert abs(after.x-p.x)>40 and abs(after.y-p.y)>40,(p,after)
 print('PASS: menu backdrop stays inside card; gallery opens at bottom center and moves via footer drag')
finally:
 xtest.fake_input(D,X.ButtonRelease,1);D.sync();ipc('edit','false');R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
