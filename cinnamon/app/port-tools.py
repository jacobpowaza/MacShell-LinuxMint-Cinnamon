#!/usr/bin/python3
"""X11 equivalents for the Wayland helper programs called by upstream MacShell."""
import os,sys,subprocess,json,time,re,sqlite3,hashlib,signal,shutil
from pathlib import Path
NAME=Path(sys.argv[0]).name;args=sys.argv[1:];BASE=Path(__file__).resolve().parent
def run(a,**kw):return subprocess.run(a,**kw)
def xclip(a,**kw):return run(['/usr/bin/xclip','-selection','clipboard',*a],**kw)
def paste(mime='text'):
 target='UTF8_STRING' if mime in ['text','text/plain','text/plain;charset=utf-8'] else mime
 p=xclip(['-out','-target',target],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL);return p.stdout
if NAME=='wl-copy':
 mime=None;clear=False
 for i,a in enumerate(args):
  if a in ['-t','--type'] and i+1<len(args):mime=args[i+1]
  if a in ['-c','--clear']:clear=True
 positionals=[];skip=False
 for a in args:
  if skip:skip=False;continue
  if a in ['-t','--type']:skip=True;continue
  if not a.startswith('-'):positionals.append(a)
 data=b'' if clear else (' '.join(positionals).encode() if positionals else sys.stdin.buffer.read())
 target=mime or 'UTF8_STRING'
 xclip(['-in','-target',target],input=data);sys.exit(0)
if NAME=='wl-paste':
 mime='text'
 for i,a in enumerate(args):
  if a in ['-t','--type'] and i+1<len(args):mime=args[i+1]
 if '--list-types' in args:xclip(['-out','-target','TARGETS']);sys.exit(0)
 if '--watch' not in args:
  sys.stdout.buffer.write(paste(mime));sys.exit(0)
 command=args[args.index('--watch')+1:]
 import gi;gi.require_version('Gtk','3.0')
 from gi.repository import Gtk,Gdk,GLib
 Gtk.init([]);clipboard=Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD);last=None
 def changed(*_):
  global last
  data=paste(mime)
  if not data or data==last:return
  last=data;env=os.environ.copy();env['MACSHELL_CLIPBOARD_MIME']=mime
  run(command,input=data,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 clipboard.connect('owner-change',changed);GLib.idle_add(lambda:changed() or False);Gtk.main();sys.exit(0)
if NAME=='cliphist':
 state=Path(os.environ.get('MACSHELL_CLIPBOARD_STATE',str(Path.home()/'.local/share/macshell-cinnamon/clipboard')));state.mkdir(mode=0o700,parents=True,exist_ok=True)
 db=sqlite3.connect(state/'history.sqlite',timeout=5);os.chmod(state/'history.sqlite',0o600)
 db.execute('CREATE TABLE IF NOT EXISTS clips(id INTEGER PRIMARY KEY AUTOINCREMENT,digest TEXT,mime TEXT,data BLOB,at REAL)')
 op=args[0] if args else 'list'
 if op=='store':
  data=sys.stdin.buffer.read();digest=hashlib.sha256(data).hexdigest();mime=os.environ.get('MACSHELL_CLIPBOARD_MIME','text')
  if data:
   row=db.execute('SELECT digest FROM clips ORDER BY id DESC LIMIT 1').fetchone()
   if not row or row[0]!=digest:
    db.execute('INSERT INTO clips(digest,mime,data,at) VALUES(?,?,?,?)',(digest,mime,data,time.time()));db.execute('DELETE FROM clips WHERE id NOT IN (SELECT id FROM clips ORDER BY id DESC LIMIT 300)');db.commit()
 elif op=='list':
  for ident,mime,data in db.execute('SELECT id,mime,data FROM clips ORDER BY id DESC'):
   text='[[ binary data '+str(len(data))+' bytes '+mime+' ]]' if mime.startswith('image/') else data.decode(errors='replace').replace('\n',' ').replace('\r',' ')[:600]
   print(str(ident)+'\t'+text)
 elif op=='wipe':db.execute('DELETE FROM clips');db.commit()
 elif op in ['decode','delete']:
  value=args[1] if len(args)>1 else sys.stdin.read();m=re.match(r'\s*(\d+)',value)
  if m:
   ident=int(m[1])
   if op=='decode':
    row=db.execute('SELECT data FROM clips WHERE id=?',(ident,)).fetchone()
    if row:sys.stdout.buffer.write(row[0])
   else:db.execute('DELETE FROM clips WHERE id=?',(ident,));db.commit()
 sys.exit(0)
if NAME=='grim':
 from PIL import ImageGrab
 scale=1.;bbox=None;fmt='png';dest='-'
 i=0
 while i<len(args):
  a=args[i]
  if a in ['-s','-g','-t','-o'] and i+1<len(args):
   v=args[i+1];i+=2
   if a=='-s':scale=float(v)
   elif a=='-t':fmt=v
   elif a=='-g':
    m=re.match(r'(-?\d+),(-?\d+)\s+(\d+)x(\d+)',v)
    if m:x,y,w,h=map(int,m.groups());bbox=(x,y,x+w,y+h)
   continue
  if not a.startswith('-') or a=='-':dest=a
  i+=1
 image=ImageGrab.grab(bbox=bbox)
 if scale!=1:image=image.resize((max(1,round(image.width*scale)),max(1,round(image.height*scale))))
 image.save(sys.stdout.buffer if dest=='-' else dest,format='PPM' if fmt in ['ppm','pnm'] else fmt.upper());sys.exit(0)
if NAME=='wtype':
 from Xlib import display,X,XK
 from Xlib.ext import xtest
 d=display.Display();held=[];i=0
 aliases={'ctrl':'Control_L','shift':'Shift_L','alt':'Alt_L','logo':'Super_L','super':'Super_L','enter':'Return','escape':'Escape','backspace':'BackSpace','delete':'Delete','tab':'Tab'}
 def key(name,down):
  symbol=XK.string_to_keysym(aliases.get(name.lower(),name));code=d.keysym_to_keycode(symbol)
  if code:xtest.fake_input(d,X.KeyPress if down else X.KeyRelease,code);d.sync()
 while i<len(args):
  op=args[i]
  if op in ['-M','-m','-k'] and i+1<len(args):
   value=args[i+1];i+=2
   if op=='-M':key(value,True);held.append(value)
   elif op=='-m':key(value,False);held=[h for h in held if h!=value]
   else:key(value,True);key(value,False)
  else:
   for ch in op:key(ch,True);key(ch,False)
   i+=1
 for value in reversed(held):key(value,False)
 d.close();sys.exit(0)
if NAME=='hyprpicker':
 from Xlib import display,X
 from PIL import ImageGrab
 d=display.Display();root=d.screen().root;root.grab_pointer(False,X.ButtonReleaseMask,X.GrabModeAsync,X.GrabModeAsync,X.NONE,X.NONE,X.CurrentTime);d.flush()
 while True:
  event=d.next_event()
  if event.type==X.ButtonRelease:
   d.ungrab_pointer(X.CurrentTime);d.sync();pixel=ImageGrab.grab(bbox=(event.root_x,event.root_y,event.root_x+1,event.root_y+1)).getpixel((0,0));value='#%02X%02X%02X'%pixel[:3];print(value)
   if '-a' in args:xclip(['-in'],input=value.encode())
   break
 d.close();sys.exit(0)
if NAME=='hyprsunset':
 import gi
 from gi.repository import Gio
 settings=Gio.Settings.new('org.cinnamon.settings-daemon.plugins.color')
 previous=settings.get_boolean('night-light-enabled');oldtemp=settings.get_uint('night-light-temperature')
 temperature=int(args[args.index('-t')+1]) if '-t' in args else 4500
 settings.set_uint('night-light-temperature',temperature);settings.set_boolean('night-light-enabled',True);Gio.Settings.sync()
 def restore(*_):settings.set_boolean('night-light-enabled',previous);settings.set_uint('night-light-temperature',oldtemp);Gio.Settings.sync();sys.exit(0)
 signal.signal(signal.SIGTERM,restore);signal.signal(signal.SIGINT,restore)
 while True:time.sleep(1)
if NAME=='wf-recorder':
 
 if '--help' in args:
  print('Cinnamon X11 recorder: -f FILE -g GEOMETRY -r, --framerate FPS -a, --audio');sys.exit(0)
 width=height=x=y=None;output=None;audio=False;fps='60';i=0
 while i<len(args):
  a=args[i]
  if a in ['-g','-f','-o','-c','-p','-r','--framerate'] and i+1<len(args):
   v=args[i+1];i+=2
   if a=='-f':output=v
   if a in ['-r','--framerate']:fps=str(max(1,min(120,int(v))))
   if a=='-g':
    m=re.match(r'(-?\d+),(-?\d+)\s+(\d+)x(\d+)',v)
    if m:x,y,width,height=map(int,m.groups())
   continue
  if a in ['-a','--audio']:audio=True
  i+=1
 if not output:sys.exit('Recording output path is required')
 from PIL import ImageGrab
 if width is None:width,height=ImageGrab.grab().size;x=y=0
 command=[shutil.which('ffmpeg') or 'ffmpeg','-hide_banner','-loglevel','warning','-probesize','32','-analyzeduration','0','-f','x11grab','-framerate',fps,'-video_size',f'{width}x{height}','-i',f'{os.environ.get("DISPLAY",":0")}+{x},{y}']
 if audio:command+=['-f','pulse','-i','default']
 command+=['-c:v','libx264','-preset','veryfast','-pix_fmt','yuv420p','-vf','pad=ceil(iw/2)*2:ceil(ih/2)*2','-y',output]
 env=os.environ.copy()
 process=subprocess.Popen(command,env=env);stop_requested=False
 def stop(*_):
  global stop_requested
  stop_requested=True
  if process.poll() is None:process.send_signal(signal.SIGINT)
 signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
 code=process.wait()
 sys.exit(0 if code==255 and stop_requested and Path(output).exists() and Path(output).stat().st_size>1024 else code)
print('Unknown compatibility helper: '+NAME,file=sys.stderr);sys.exit(2)
