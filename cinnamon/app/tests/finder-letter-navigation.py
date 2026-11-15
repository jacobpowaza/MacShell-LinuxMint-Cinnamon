"""Real key presses select matching names, cycle initials and reveal all Finder views."""
from pathlib import Path
import sys,json,time,subprocess,tempfile
from Xlib import display,X,XK
from Xlib.ext import xtest
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
Q=B.parent/'runtime/qs'
def ipc(method,*args):return subprocess.check_output([str(Q),'ipc','--newest','-p',str(B/'MacShell'),'call','finder',method,*map(str,args)],text=True).strip()
def state():return json.loads(ipc('state'))
def wait(fn):
 end=time.monotonic()+6
 while time.monotonic()<end:
  value=fn()
  if value:return value
  time.sleep(.05)
 raise AssertionError(state())
D=display.Display();active=rpc('state')['active'];before={w['wid'] for w in rpc('state')['clients']};wid=None
with tempfile.TemporaryDirectory(prefix='finder-letter-') as tmp:
 p=Path(tmp);(p/'Victor').mkdir();(p/'Violet.txt').touch();(p/'Zulu.txt').touch()
 for i in range(65):(p/f'Alpha {i:02}.txt').touch()
 def press(letter):
  key=D.keysym_to_keycode(XK.string_to_keysym(letter));xtest.fake_input(D,X.KeyPress,key);xtest.fake_input(D,X.KeyRelease,key);D.sync()
 def selected(name):return state()['selection']==[str(p/name)]
 try:
  ipc('newWindow',tmp);wait(lambda:state().get('path')==tmp and len(state()['items'])==68)
  wid=wait(lambda:next((w['wid'] for w in rpc('state')['clients'] if w['wid'] not in before and w['title']=='Finder'),None));rpc('activate',wid)
  for view in ['grid','list','columns','gallery']:
   ipc('view',view);ipc('choose',0);time.sleep(.15)
   # Victor is a folder; Violet is a file beyond a page of Alpha entries.
   press('v');wait(lambda:selected('Violet.txt'))
   press('v');wait(lambda:selected('Victor'))
   press('v');wait(lambda:selected('Violet.txt'))
   press('i');wait(lambda:selected('Violet.txt'))
   press('c');wait(lambda:selected('Victor'))
   print('PASS '+view+': letter jump, repeated-letter wrap, folder/file matching and typed prefix',flush=True)
 finally:
  if wid:subprocess.run(['wmctrl','-ic',hex(wid)])
  if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
  D.close()
