"""Open Spotlight and type without a click, only after confirming its exact focus window."""
from pathlib import Path
import json,sys,subprocess,time
from Xlib import display,X,XK
from Xlib.ext import xtest
BASE=Path(__file__).resolve().parents[1];sys.path.insert(0,str(BASE));from native import rpc
QS=BASE.parent/'runtime/qs';D=display.Display();active=rpc('state')['active']
def ipc(t,m,*args):return subprocess.check_output([str(QS),'ipc','--newest','-p',str(BASE/'MacShell'),'call',t,m,*map(str,args)],text=True).strip()
def state():return json.loads(ipc('cinnamon','spotlightState'))
try:
 ipc('spotlight','toggle')
 title=''
 for _ in range(40):
  focus=D.get_input_focus().focus;title=focus.get_wm_name() or ''
  if title.startswith('MacShell Spotlight'):break
  time.sleep(.02)
 assert title.startswith('MacShell Spotlight'),title
 for c in 'calc':
  code=D.keysym_to_keycode(XK.string_to_keysym(c));xtest.fake_input(D,X.KeyPress,code);xtest.fake_input(D,X.KeyRelease,code);D.sync();time.sleep(.06)
 time.sleep(.3);s=state();assert s['open'] and s['query']=='calc' and s['focus'],s
 print('PASS Spotlight: immediate no-click typing reaches search input')
finally:
 if state().get('open'):ipc('spotlight','toggle')
 if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
 D.close()
