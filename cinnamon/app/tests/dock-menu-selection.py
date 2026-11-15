import subprocess,json,time,sys,os
from pathlib import Path
from Xlib import display,X,XK,protocol
from PIL import ImageGrab
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));from native import rpc
base=Path(__file__).resolve().parents[1];qs=str(base.parent/'runtime/qs');out=base/'.impeccable/review-revision'
def ipc(method,*args):return subprocess.check_output([qs,'ipc','--newest','-p',str(base/'MacShell'),'call','cinnamon',method,*args],text=True)
D=display.Display();root=D.screen().root
original=rpc('state')['active']
def focus_menu():
 for _ in range(20):
  w=D.get_input_focus().focus
  if hasattr(w,'get_full_property'):
   prop=w.get_full_property(D.intern_atom('_NET_WM_PID'),X.AnyPropertyType)
   if prop and 'macshell-source.service' in Path('/proc/'+str(int(prop.value[0]))+'/cgroup').read_text():return w
  time.sleep(.05)
 raise AssertionError('Menu did not acquire keyboard focus')
def key(window,name):
 code=D.keysym_to_keycode(XK.string_to_keysym(name))
 for kind in [protocol.event.KeyPress,protocol.event.KeyRelease]:
  window.send_event(kind(time=X.CurrentTime,root=root,window=window,child=X.NONE,root_x=0,root_y=0,event_x=0,event_y=0,state=0,detail=code,same_screen=1),event_mask=X.KeyPressMask if kind==protocol.event.KeyPress else X.KeyReleaseMask)
 D.sync()
code='''import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk
windows=[]
for i in range(30):
 w=Gtk.Window(title='MacShell grouping verification '+str(i+1));w.set_wmclass('macshell-group-test','macshell-group-test');w.set_default_size(140,80);w.move(450+i*2,50+i*2);w.add(Gtk.Label(label='Grouping test '+str(i+1)));w.show_all();windows.append(w)
Gtk.main()
'''
p=subprocess.Popen(['/usr/bin/python3','-c',code],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
 time.sleep(4)
 for index in [8,9,10,11,29]:
  state=rpc('state');wins=[w for w in state['clients'] if w['pid']==p.pid];assert len(wins)==30,len(wins);target=wins[index]
  ipc('dockMenu','macshell-group-test');time.sleep(2);w=focus_menu()
  if index==8:
   time.sleep(2);ImageGrab.grab().crop((450,300,1470,1080)).save(out/'dock-menu-many-top.png')
  for _ in range(index+1):key(w,'Down')
  time.sleep(.2)
  if index==29:
   time.sleep(2);ImageGrab.grab().crop((450,300,1470,1080)).save(out/'dock-menu-many-bottom.png')
  key(w,'Return');time.sleep(.65)
  state=rpc('state');assert state['active']==target['wid'],(index,target['wid'],state['active'])
  active=[item for item in state['clients'] if item['activated']];assert len(active)==1 and active[0]['wid']==target['wid']
  print('PASS menu position',index+1,'focused exact window',target['wid'])
 ipc('dockMenu','macshell-group-test');time.sleep(2);w=focus_menu();key(w,'Escape');time.sleep(.3)
 assert all(not v['menuOpen'] for v in json.loads(ipc('dockGeometry')).values()),'Escape left dock menu open'
 print('PASS Escape dismissal and bounded scroll through all30windows')
finally:
 ipc('dismissDockMenus');p.terminate();p.wait(timeout=4)
 if any(w['wid']==original for w in rpc('state')['clients']):rpc('activate',original)
 D.close()
