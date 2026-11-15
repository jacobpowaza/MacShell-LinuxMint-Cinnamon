"""Owned widget pointer checks; no input sent to another app."""
from pathlib import Path
import json,sys,subprocess,time,shutil
from Xlib import display,X,XK
from Xlib.ext import xtest
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs';D=display.Display();R=D.screen().root;pointer=R.query_pointer();active=rpc('state')['active'];wid='';darkid='';original_desktop=R.get_full_property(D.intern_atom('_NET_SHOWING_DESKTOP'),X.AnyPropertyType).value[0]
def ipc(m,*a):return subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call','widgets',m,*map(str,a)],text=True).strip()
def snap():return json.loads(ipc('snapshot'))
def wait(f):
 for _ in range(70):
  v=f()
  if v:return v
  time.sleep(.1)
 raise AssertionError('Timeout')
def raw(t):
 for w in R.query_tree().children:
  try:
   if w.get_wm_name()==t and w.get_attributes().map_state==X.IsViewable:return w
  except:pass

def drag(x,y,a,b):
 R.warp_pointer(round(x),round(y));D.sync();xtest.fake_input(D,X.ButtonPress,1);D.sync();time.sleep(.1)
 for i in range(1,21):xtest.fake_input(D,X.MotionNotify,x=round(x+(a-x)*i/20),y=round(y+(b-y)*i/20));D.sync();time.sleep(.025)
 xtest.fake_input(D,X.ButtonRelease,1);D.sync();time.sleep(.3)
try:
 wid=ipc('add','clock','light','small');assert wid
 ipc('move',wid,1200,80);time.sleep(.2);before=next(w for w in snap() if w['wid']==wid)
 ipc('gallery');gallery=wait(lambda:raw('MacShell Widget Gallery'));time.sleep(.6)
 assert json.loads(ipc('galleryState'))['gallery'];assert D.get_input_focus().focus.id==gallery.id
 out=B/'.impeccable/tahoe-workflow';out.mkdir(exist_ok=True);shutil.copy2(rpc('capture',gallery.id),out/'widget-gallery.png')
 w=next(w for w in snap() if w['wid']==wid)
 from PIL import Image
 layer=raw('MacShell Widgets');im=Image.open(rpc('capture',layer.id));scale=im.width/D.screen().width_in_pixels
 box=tuple(round(v*scale) for v in (w['wx']-12,w['wy']-12,w['wx']+197,w['wy']+197));im.crop(box).save(out/'widget-resize-grip.png')
 darkid=ipc('add','clock','dark','small');assert darkid
 ipc('move',darkid,1500,80);time.sleep(.2);dark=next(v for v in snap() if v['wid']==darkid)
 im=Image.open(rpc('capture',layer.id));box=tuple(round(v*scale) for v in (dark['wx']-12,dark['wy']-12,dark['wx']+197,dark['wy']+197));im.crop(box).save(out/'widget-resize-grip-dark.png')
 ipc('remove',darkid);darkid=''
 x,y=w['wx'],w['wy'];assert y<250
 drag(x+50,y+50,x+300,y+50);m=next(w for w in snap() if w['wid']==wid);assert m['wx']!=x or m['wy']!=y,(w,m)
 print('PASS Widget: gallery owns focus and edit mode permits pointer movement',flush=True)
 # Resize the owned widget using the visible curved corner grip.
 drag(m['wx']+170,m['wy']+170,m['wx']+375,m['wy']+170);w=next(w for w in snap() if w['wid']==wid);assert w['wsize']=='medium',w
 print('PASS Widget: corner grip resizes small to medium',flush=True)
 ipc('edit','false');time.sleep(.5)
 after=R.get_full_property(D.intern_atom('_NET_SHOWING_DESKTOP'),X.AnyPropertyType).value[0];assert after==original_desktop,(after,original_desktop)
 print('PASS Widget: Done leaves edit mode and restores desktop state',flush=True)
finally:
 xtest.fake_input(D,X.ButtonRelease,1);D.sync();ipc('edit','false')
 if wid:ipc('remove',wid)
 if darkid:ipc('remove',darkid)
 R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
