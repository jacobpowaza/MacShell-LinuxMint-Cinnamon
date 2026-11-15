"""Real pointer resize and native opacity restoration on an owned test window."""
from pathlib import Path
import json,subprocess,sys,time
from Xlib import display,X
from Xlib.ext import xtest
from PIL import Image
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs';D=display.Display();R=D.screen().root;active=rpc('state')['active'];pointer=R.query_pointer();wid='';bg=None;out=B/'.impeccable/widget-motion';out.mkdir(exist_ok=True)
def ipc(m,*a):return subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call','widgets',m,*map(str,a)],text=True).strip()
def raw(t):
 for w in R.query_tree().children:
  try:
   if w.get_wm_name()==t and w.get_attributes().map_state==X.IsViewable:return w
  except Exception:pass

def wait(fn):
 for _ in range(80):
  value=fn()
  if value:return value
  time.sleep(.05)
 raise AssertionError('Timeout')
def snap():return next(v for v in json.loads(ipc('snapshot')) if v['wid']==wid)
try:
 bg=subprocess.Popen(['/usr/bin/python3',str(B/'tests/qa_backdrop.py')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 owned=wait(lambda:raw('MacShell Owned QA Backdrop'));wait(lambda:any(c['wid']==owned.id for c in rpc('state')['clients']))
 atom=D.intern_atom('_NET_WM_WINDOW_OPACITY');original=0xefffffff;owned.change_property(atom,D.intern_atom('CARDINAL'),32,[original]);D.sync()
 wid=ipc('add','clock','light','small');ipc('move',wid,1200,80);time.sleep(.2)
 ipc('gallery');samples=[];end=time.monotonic()+.9
 while time.monotonic()<end:
  prop=owned.get_full_property(atom,X.AnyPropertyType);samples.append(int(prop.value[0]) if prop else None);time.sleep(.012)
 assert any(v is not None and 1<v<original for v in samples),samples
 assert owned.get_full_property(atom,X.AnyPropertyType).value[0]==original
 gallery=wait(lambda:raw('MacShell Widget Gallery'));assert D.get_input_focus().focus.id==gallery.id
 print('PASS: background fades through intermediate opacities, original opacity restored before gallery focus',flush=True)
 w=snap();x=w['wx'];y=w['wy'];R.warp_pointer(round(x+170),round(y+170));D.sync();xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.08)
 for step in range(1,12):
  xtest.fake_input(D,X.MotionNotify,x=round(x+170+10*step),y=round(y+170));D.sync();time.sleep(.02)
 time.sleep(.16)
 layer=wait(lambda:raw('MacShell Widgets'));pix=layer.composite_name_window_pixmap();D.sync();geo=pix.get_geometry();data=pix.get_image(0,0,geo.width,geo.height,X.ZPixmap,0xffffffff);pix.free();im=Image.frombytes('RGBA',(geo.width,geo.height),data.data,'raw','BGRA');im.crop((x-10,y-10,x+440,y+235)).save(out/'widget-continuous-resize.png')
 strip=im.crop((x,y+60,x+430,y+65));alpha=strip.getchannel('A');bbox=alpha.point(lambda v:255 if v>180 else 0).getbbox();assert bbox,bbox
 width=bbox[2];assert 265<width<330,width
 xtest.fake_input(D,X.ButtonRelease,1);D.sync();time.sleep(.45);w=snap();assert w['wsize']=='medium',w
 print('PASS: pointer produces continuous non-preset width',width,'then settles to medium',flush=True)
 ipc('edit','false');time.sleep(.5);assert not json.loads(ipc('galleryState'))['gallery']
 assert owned.get_full_property(atom,X.AnyPropertyType).value[0]==original
 print('PASS: animated dismissal restores normal desktop/window state',flush=True)
finally:
 xtest.fake_input(D,X.ButtonRelease,1);D.sync();ipc('edit','false');time.sleep(.3)
 if wid:ipc('remove',wid)
 if bg:bg.terminate();bg.wait(timeout=5)
 R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(c['wid']==active for c in rpc('state')['clients']):rpc('activate',active)
