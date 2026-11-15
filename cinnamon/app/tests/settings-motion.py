"""Verify a real Settings disclosure produces intermediate card heights."""
import sys,subprocess,time
from pathlib import Path
from Xlib import display,X
from Xlib.ext import xtest
from PIL import Image
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs';D=display.Display();R=D.screen().root;pointer=R.query_pointer();active=rpc('state')['active'];w=None
out=B/'.impeccable/widget-motion';out.mkdir(exist_ok=True)
def capture():
 pix=w.composite_name_window_pixmap();D.sync();g=pix.get_geometry();raw=pix.get_image(0,0,g.width,g.height,X.ZPixmap,0xffffffff);pix.free();return Image.frombytes('RGBA',(g.width,g.height),raw.data,'raw','BGRA')
def extent(im):
 x=im.width-32;ys=[y for y in range(92,240) if im.getpixel((x,y))[:3]==(48,47,51)];assert ys
 start=ys[0];end=start
 for y in ys[1:]:
  if y>end+1:break
  end=y
 return end-start+1
try:
 subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call','settings','pane','general'])
 for _ in range(70):
  for candidate in R.query_tree().children:
   try:
    if candidate.get_wm_name()=='Settings' and candidate.get_attributes().map_state==X.IsViewable:w=candidate
   except:pass
  if w:break
  time.sleep(.1)
 assert w;rpc('activate',w.id);time.sleep(.8);before=capture();initial=extent(before)
 point=R.translate_coords(w,300,122);R.warp_pointer(point.x,point.y);D.sync();xtest.fake_input(D,X.ButtonPress,1);xtest.fake_input(D,X.ButtonRelease,1);D.sync();away=R.translate_coords(w,500,26);R.warp_pointer(away.x,away.y);D.sync()
 frames=[]
 for _ in range(22):frames.append(capture());time.sleep(.014)
 final=extent(frames[-1]);values=[extent(im) for im in frames]
 assert final<initial-35,(initial,final,values)
 assert any(final+5<v<initial-5 for v in values),values
 before.save(out/'settings-disclosure-expanded.png');frames[next(i for i,v in enumerate(values) if final+5<v<initial-5)].save(out/'settings-disclosure-mid.png');frames[-1].save(out/'settings-disclosure-collapsed.png')
 R.warp_pointer(point.x,point.y);D.sync();xtest.fake_input(D,X.ButtonPress,1);xtest.fake_input(D,X.ButtonRelease,1);D.sync();time.sleep(.35)
 print('PASS: disclosure animates through intermediate heights',initial,'→',final,'and reopens')
finally:
 if w:subprocess.run(['wmctrl','-ic',hex(w.id)])
 R.warp_pointer(pointer.root_x,pointer.root_y);D.sync();D.close()
 if any(c['wid']==active for c in rpc('state')['clients']):rpc('activate',active)
