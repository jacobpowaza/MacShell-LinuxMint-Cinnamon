from pathlib import Path
import sys,subprocess,time
from Xlib import display,X
from Xlib.ext import xtest
b=Path.home()/'.local/share/macshell-cinnamon';sys.path.insert(0,str(b/'app'));from native import rpc
qs=str(b/'runtime/qs');d=display.Display();r=d.screen().root;pos=r.query_pointer();original=rpc('state')['active']
def ipc(target,m):subprocess.run([qs,'ipc','--newest','-p',str(b/'app/MacShell'),'call',target,m],check=True,stdout=subprocess.DEVNULL)
try:
 for target,title in [('settings','Settings'),('clock','Clock')]:
  ipc(target,'open');time.sleep(1)
  wins=[w for w in rpc('state')['clients'] if w['title']==title];assert len(wins)==1,(title,len(wins))
  wid=wins[0]['wid'];rpc('activate',wid);time.sleep(.3);w=d.create_resource_object('window',wid);p=r.translate_coords(w,46,21)
  r.warp_pointer(p.x,p.y);d.sync();xtest.fake_input(d,X.ButtonPress,1);xtest.fake_input(d,X.ButtonRelease,1);d.sync();time.sleep(.5)
  prop=w.get_full_property(d.intern_atom('_NET_WM_STATE'),X.AnyPropertyType);assert prop and d.intern_atom('_NET_WM_STATE_HIDDEN') in prop.value,(title,'yellow did not minimize')
  ipc(target,'open');time.sleep(.4);prop=w.get_full_property(d.intern_atom('_NET_WM_STATE'),X.AnyPropertyType);assert not prop or d.intern_atom('_NET_WM_STATE_HIDDEN') not in prop.value
  print('PASS',title,'yellow minimizes and reopening restores window')
  subprocess.run(['wmctrl','-ic',hex(wid)])
finally:
 r.warp_pointer(pos.root_x,pos.root_y);d.sync();d.close()
 if any(w['wid']==original for w in rpc('state')['clients']):rpc('activate',original)
