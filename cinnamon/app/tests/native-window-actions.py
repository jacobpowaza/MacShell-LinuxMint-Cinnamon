import subprocess,time,json,sys,os
from pathlib import Path
from PIL import Image
b=Path(__file__).resolve().parents[1];sys.path.insert(0,str(b));from native import rpc
code="""import gi;gi.require_version('Gtk','3.0');from gi.repository import Gtk
w=Gtk.Window(title='MacShell adapter verification');w.set_default_size(240,120);w.add(Gtk.Label(label='Native window actions'));w.connect('destroy',Gtk.main_quit);w.show_all();Gtk.main()
"""
p=subprocess.Popen(['/usr/bin/python3','-c',code],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
 for _ in range(30):
  s=rpc('state');win=next((w for w in s['clients'] if w['pid']==p.pid),None)
  if win:break
  time.sleep(.15)
 assert win,'Test window not enumerated';wid=win['wid']
 rpc('activate',wid);time.sleep(.5);assert rpc('state')['active']==wid
 shot=rpc('capture',wid);print('capture result',shot,Image.open(shot).size if shot else None,win['size']);assert shot and Image.open(shot).width>=win['size'][0]
 rpc('minimize',wid);time.sleep(.5);assert next(w for w in rpc('state')['clients'] if w['wid']==wid)['minimized']
 rpc('activate',wid);time.sleep(.5);assert not next(w for w in rpc('state')['clients'] if w['wid']==wid)['minimized']
 rpc('close',wid);p.wait(timeout=5)
 print('PASS: own window enumerate/focus/live capture/minimize/restore/close')
finally:
 if p.poll() is None:p.terminate();p.wait(timeout=3)
