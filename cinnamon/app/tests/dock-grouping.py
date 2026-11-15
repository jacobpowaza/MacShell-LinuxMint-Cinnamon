import subprocess,json,time,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]));from native import rpc
base=Path(__file__).resolve().parents[1];qs=str(base.parent/'runtime/qs')
def model():return json.loads(subprocess.check_output([qs,'ipc','--newest','-p',str(base/'MacShell'),'call','cinnamon','dockState'],text=True))
code='''import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk
windows=[]
for i in range(12):
 w=Gtk.Window(title='MacShell grouping verification '+str(i));w.set_wmclass('macshell-group-test','macshell-group-test');w.set_default_size(140,80);w.move(450+i*5,50+i*4);w.add(Gtk.Label(label='Grouping test '+str(i)));w.show_all();windows.append(w)
Gtk.main()
'''
p=subprocess.Popen(['/usr/bin/python3','-c',code],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
 time.sleep(4);state=rpc('state');wins=[w for w in state['clients'] if w['pid']==p.pid];assert len(wins)==12,len(wins)
 items=model();matches=[it for it in items if it['key']=='macshell-group-test'];assert len(matches)==1 and matches[0]['windows']==12,matches
 assert not any(it['kind']=='win' for it in items),'Separate previews in dock'
 keys=[it['key'] for it in items]
 rpc('activate',wins[0]['wid']);time.sleep(.6);rpc('activate',wins[6]['wid']);time.sleep(.6)
 assert [it['key'] for it in model()]==keys,'App order changed on focus'
 print('PASS: twelve windows form one icon; focus preserves app order; no per-window dock cells')
finally:p.terminate();p.wait(timeout=4)
