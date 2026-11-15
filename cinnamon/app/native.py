#!/usr/bin/env python3
"""Native Cinnamon/X11 backend for the unchanged MacShell QML surfaces."""
import os,sys,json,time,socket,threading,re,subprocess,signal,select
from pathlib import Path
from render_region import scaled_region
if len(sys.argv)==1:
 from Xlib import threaded
 from Xlib import display,X,Xatom,protocol,error
 from Xlib.ext import shape,randr
 import cairo
 from PIL import Image,ImageGrab,ImageOps,ImageFilter
 import gi
 from gi.repository import Gio,GLib
BASE=Path(__file__).resolve().parent
RUNTIME=Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/'macshell-cinnamon-port'
RUNTIME.mkdir(mode=0o700,exist_ok=True)
SOCKET=RUNTIME/'native.sock';STATE=RUNTIME/'state.json';CAPTURES=RUNTIME/'captures';CAPTURES.mkdir(exist_ok=True)
def cmd(args):
 try:return subprocess.check_output(args,text=True,stderr=subprocess.DEVNULL,timeout=3).strip()
 except Exception:return ''
def spawn(args):
 env=os.environ.copy()
 for k in ['QT_PLUGIN_PATH','QML2_IMPORT_PATH','QML_IMPORT_PATH','LD_LIBRARY_PATH','QT_QPA_PLATFORM_PLUGIN_PATH']:env.pop(k,None)
 subprocess.Popen(args,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
class Native:
 def __init__(self):
  self.d=display.Display();self.root=self.d.screen().root;self.atoms={};self.lock=threading.RLock();self.last='';self.state={};self.monitors=[];self.last_mon=0;self.widget_rects=[];self.input_regions={};self.popup_focus={};self.widget_edit_state=None
  self.shape_applied={};self.own_pids={};self.capture_times={};self.background=Gio.Settings.new("org.cinnamon.desktop.background")
  self.wake_read,self.wake_write=socket.socketpair();self.wake_read.setblocking(False);self.wake_write.setblocking(False);self.watched=set()
  self.root.change_attributes(event_mask=X.PropertyChangeMask|X.SubstructureNotifyMask)
  self.shape_scan_at=0;self.shape_windows={};self.operations={};self.update_count=0
  self.root.xrandr_select_input(randr.RRScreenChangeNotifyMask|randr.RRCrtcChangeNotifyMask|randr.RROutputChangeNotifyMask)
  self.randr_event=self.d.query_extension('RANDR').first_event
  self.apps=[]
  for a in Gio.AppInfo.get_all():
   if not a.get_id():continue
   startup=a.get_startup_wm_class() if isinstance(a,Gio.DesktopAppInfo) else ''
   self.apps.append((a.get_id().removesuffix('.desktop'),(startup or '').lower(),Path(a.get_executable() or '').name.lower(),a.should_show()))
 def atom(self,s):
  if s not in self.atoms:self.atoms[s]=self.d.intern_atom(s)
  return self.atoms[s]
 def prop(self,w,key,default=None):
  try:
   p=w.get_full_property(self.atom(key),X.AnyPropertyType)
   return p.value if p else default
  except Exception:return default
 def string(self,w,key):
  v=self.prop(w,key,b'')
  return v.decode(errors='replace') if isinstance(v,bytes) else str(v)
 def adapt_input_shapes(self):
  # Discover shell windows on creation; only issue XShape when a region changes.
  if time.monotonic()-self.shape_scan_at>2:
   self.shape_scan_at=time.monotonic();found={}
   windows={w.id:w for w in self.root.query_tree().children}
   for wid in self.prop(self.root,'_NET_CLIENT_LIST',[]):windows[int(wid)]=self.d.create_resource_object('window',int(wid))
   for wid,w in windows.items():
    try:
     pid=int(self.prop(w,'_NET_WM_PID',[0])[0])
     if pid not in self.own_pids:self.own_pids[pid]=bool(pid and 'macshell-source.service' in Path(f'/proc/{pid}/cgroup').read_text())
     if self.own_pids[pid]:found[wid]=(w,self.string(w,'_NET_WM_NAME'),pid)
    except Exception:continue
   self.shape_windows=found
   self.shape_applied={wid:value for wid,value in self.shape_applied.items() if wid in found}
  for wid,(w,title,pid) in self.shape_windows.items():
   region=[tuple(map(int,r)) for r in self.widget_rects if r[2]>0 and r[3]>0] if title=='MacShell Widgets' else self.input_regions.get(title)
   signature=(pid,tuple(region)) if region is not None else None
   if signature is not None and self.shape_applied.get(wid)!=signature:
    try:w.shape_rectangles(shape.SO.Set,shape.SK.Input,X.Unsorted,0,0,region);self.shape_applied[wid]=signature
    except Exception:pass
  self.d.flush()
 def update(self):
  self.update_count+=1
  with self.lock:
   while GLib.MainContext.default().pending():GLib.MainContext.default().iteration(False)
   self.adapt_input_shapes()
   desktops=self.prop(self.root,'_NET_CURRENT_DESKTOP',[0]); current=int(desktops[0]); names=self.string(self.root,'_NET_DESKTOP_NAMES').split('\x00');count=int(self.prop(self.root,'_NET_NUMBER_OF_DESKTOPS',[1])[0])
   workspaces=[{'id':i+1,'name':names[i] if i<len(names) and names[i] else str(i+1)} for i in range(count)]
   if time.monotonic()-self.last_mon>60:
    text=cmd(['xrandr','--current','--listmonitors']);mons=[]
    for line in text.splitlines()[1:]:
     m=re.search(r'\d+:\s+([+*]*)(\S+)\s+(\d+)/(?:\d+)x(\d+)/(?:\d+)\+(-?\d+)\+(-?\d+)\s+(\S+)',line)
     if m:mons.append({'id':len(mons),'name':m[7],'width':int(m[3]),'height':int(m[4]),'x':int(m[5]),'y':int(m[6]),'scale':1,'refreshRate':60,'focused':'*' in m[1]})
    if not mons:mons=[{'id':0,'name':'screen','width':self.d.screen().width_in_pixels,'height':self.d.screen().height_in_pixels,'x':0,'y':0,'scale':1,'refreshRate':60,'focused':True}]
    detail=cmd(['xrandr','--current']);output_name=None
    modes={}
    for line in detail.splitlines():
     if line and not line[0].isspace():output_name=line.split()[0] if ' connected' in line else None
     elif output_name:
      row=re.match(r'\s+(\d+x\d+)\s+(.+)',line)
      if row:
       modes.setdefault(output_name,[]).extend(row[1]+'@'+rate+'Hz' for rate in re.findall(r'([\d.]+)[*+]?',row[2]))
    for mon in mons:mon['availableModes']=modes.get(mon['name'],[])
    self.monitors=mons;self.last_mon=time.monotonic()
   for mon in self.monitors:mon.update(activeWorkspace=workspaces[current],specialWorkspace={'id':0,'name':''},reserved=[0,0,0,0])
   active=int(self.prop(self.root,'_NET_ACTIVE_WINDOW',[0])[0]);stack=self.prop(self.root,'_NET_CLIENT_LIST_STACKING',[]);clients=[]
   for wid in stack:
    try:
     w=self.d.create_resource_object('window',int(wid))
     if int(wid) not in self.watched:w.change_attributes(event_mask=X.PropertyChangeMask|X.StructureNotifyMask);self.watched.add(int(wid))
     types=list(self.prop(w,'_NET_WM_WINDOW_TYPE',[]));states=list(self.prop(w,'_NET_WM_STATE',[]))
     if self.atom('_NET_WM_STATE_SKIP_TASKBAR') in states or any(self.atom(s) in types for s in ['_NET_WM_WINDOW_TYPE_DOCK','_NET_WM_WINDOW_TYPE_DESKTOP']):continue
     title=self.string(w,'_NET_WM_NAME') or w.get_wm_name() or '';classes=w.get_wm_class() or ('','')
     if not title:continue
     appid=self.string(w,'_GTK_APPLICATION_ID')
     cls=[c.lower() for c in classes];normalized=[c.removesuffix('-server') for c in cls]
     def app_score(a):
      aid=a[0].lower()
      if appid and aid==appid.lower():return 100
      if aid in cls:return 90
      if a[1] and a[1] in cls:return 80 if a[3] else 60
      if a[2] and a[2] in normalized:return 40 if a[3] else 10
      return 0
     match=max(self.apps,key=app_score,default=None)
     if match and not app_score(match):match=None
     appid=match[0] if match else (appid or classes[-1] or classes[0] or 'unknown-app')
     if appid=='org.quickshell' or any('quickshell' in c for c in cls):appid='org.quickshell'
     g=w.get_geometry()
     # python-xlib translate_coords is called on destination, source is the argument.
     pos=self.root.translate_coords(w,0,0);x=pos.x;y=pos.y
     desk=int(self.prop(w,'_NET_WM_DESKTOP',[current])[0]);desk=current if desk==0xffffffff else min(desk,len(workspaces)-1)
     monitor=next((m['id'] for m in self.monitors if m['x']<=x+g.width/2<m['x']+m['width'] and m['y']<=y+g.height/2<m['y']+m['height']),0)
     clients.append({'wid':int(wid),'address':hex(int(wid)),'class':appid,'initialClass':appid,'title':title,'initialTitle':title,'at':[x,y],'size':[g.width,g.height],'workspace':workspaces[desk],'monitor':monitor,'mapped':True,'hidden':self.atom('_NET_WM_STATE_HIDDEN') in states,'minimized':self.atom('_NET_WM_STATE_HIDDEN') in states,'activated':int(wid)==active,'fullscreen':1 if self.atom('_NET_WM_STATE_FULLSCREEN') in states else 0,'fullscreenClient':0,'floating':True,'pinned':False,'xwayland':True,'pid':int(self.prop(w,'_NET_WM_PID',[0])[0]),'focusHistoryID':0 if int(wid)==active else 1,'grouped':[]})
    except Exception:continue
   self.recover_widget_edit()
   self.state={'clients':clients,'monitors':self.monitors,'workspaces':workspaces,'active':active,'workspace':current+1,'wallpaper':self.background.get_string('picture-uri').removeprefix('file://')}
   text=json.dumps(self.state,separators=(',',':'))
   if text!=self.last:
    tmp=STATE.with_suffix('.tmp');tmp.write_text(text);tmp.replace(STATE);self.last=text
 def screensaver_active(self):
  try:
   bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
   return bool(bus.call_sync('org.cinnamon.ScreenSaver','/org/cinnamon/ScreenSaver','org.cinnamon.ScreenSaver','GetActive',None,GLib.VariantType('(b)'),Gio.DBusCallFlags.NONE,400,None).unpack()[0])
  except Exception:return False
 def fade_to_widget_desktop(self, state):
  # Fade only visible application windows on this workspace. Restore every
  # pre-existing opacity property, including absence, even if a window closes.
  windows=[];atom=self.atom('_NET_WM_WINDOW_OPACITY')
  try:
   animate=Gio.Settings.new('org.cinnamon.desktop.interface').get_boolean('enable-animations')
   if animate and not state['showing'] and not self.screensaver_active():
    with self.lock:
     for client in self.state.get('clients',[]):
      if client['hidden'] or client['workspace']['id']!=self.state.get('workspace'):continue
      try:
       w=self.d.create_resource_object('window',client['wid'])
       if w.get_attributes().map_state!=X.IsViewable:continue
       prop=w.get_full_property(atom,Xatom.CARDINAL)
       original=int(prop.value[0]) if prop is not None else None
       windows.append((w,original))
      except Exception:pass
    for frame in range(1,14):
     if self.widget_edit_state is not state or self.screensaver_active():return
     remaining=(1-frame/13)**3
     with self.lock:
      for w,original in windows:
       try:w.change_property(atom,Xatom.CARDINAL,32,[max(1,int((original if original is not None else 0xffffffff)*remaining))])
       except Exception:pass
      self.d.flush()
     time.sleep(.016)
   if self.widget_edit_state is state and not self.screensaver_active():
    subprocess.run(['wmctrl','-k','on'],check=False,timeout=2)
    time.sleep(.025)
  finally:
   with self.lock:
    for w,original in windows:
     try:
      if original is None:w.delete_property(atom)
      else:w.change_property(atom,Xatom.CARDINAL,32,[original])
     except Exception:pass
    self.d.flush()
 def finish_widget_edit(self):
  state=self.widget_edit_state
  if not state or self.screensaver_active():return
  self.widget_edit_state=None
  showing=int(self.prop(self.root,'_NET_SHOWING_DESKTOP',[0])[0])==1
  if not state['showing'] and showing:
   spawn(['wmctrl','-k','off'])
   if state['active']:self.activate(state['active'])
 def recover_widget_edit(self):
  state=self.widget_edit_state
  if not state or time.monotonic()<state['deadline']:return
  for w in self.root.query_tree().children:
   try:
    if self.string(w,'_NET_WM_NAME')=='MacShell Widget Gallery' and w.get_attributes().map_state==X.IsViewable:return
   except Exception:pass
  self.finish_widget_edit()
 def activate(self,wid):spawn(['wmctrl','-ia',hex(int(wid))])
 def minimize(self,wid):
  with self.lock:
   e=protocol.event.ClientMessage(window=int(wid),client_type=self.atom('WM_CHANGE_STATE'),data=(32,[3,0,0,0,0]));self.root.send_event(e,event_mask=X.SubstructureRedirectMask|X.SubstructureNotifyMask);self.d.flush()
 def capture(self,wid,area=""):
  # Share frames between glass consumers; bound work and prevent duplicate encodes.
  wid=int(wid);area=area if area in ["dock","dock-menu"] else "";key=(wid,area);dest=CAPTURES/(str(wid)+('-'+area if area else '')+'.png')
  with self.lock:
   now=time.monotonic()
   if now-self.capture_times.get(key,0)<.12 and dest.exists():return str(dest)
   self.capture_times[key]=now
   w=self.d.create_resource_object('window',int(wid))
   if w.get_attributes().map_state!=X.IsViewable:return ''
   caught=error.CatchError();pix=w.composite_name_window_pixmap(onerror=caught);self.d.sync()
   if caught.get_error():
    redir_error=error.CatchError();w.composite_redirect_window(0,onerror=redir_error);self.d.sync()
    if redir_error.get_error():return ''
    caught=error.CatchError();pix=w.composite_name_window_pixmap(onerror=caught);self.d.sync()
    if caught.get_error():return ''
   g=pix.get_geometry();sx=sy=0;sw=g.width;sh=g.height
   if area=='dock':
    position=self.root.translate_coords(w,0,0)
    mon=next((m for m in self.monitors if m['x']<=position.x+g.width/2<m['x']+m['width']),self.monitors[0])
    sy=max(0,mon['y']+mon['height']-260-position.y)
    sy=min(sy,g.height-1);sh=g.height-sy
   try:raw=pix.get_image(sx,sy,sw,sh,X.ZPixmap,0xffffffff)
   finally:pix.free()
  piece=Image.frombytes('RGB',(sw,sh),raw.data,'raw','BGRX')
  if sy:
   image=Image.new('RGB',(g.width,g.height));image.paste(piece,(sx,sy))
  else:image=piece
  if image.width>1280:image.thumbnail((1280,960),Image.Resampling.BILINEAR)
  tmp=dest.with_name(dest.name+'.'+str(threading.get_ident())+'.tmp');image.save(tmp,format='PNG',compress_level=1);tmp.replace(dest);return str(dest)
 def frost(self,arg):
  x,y,width,height=[int(arg[k]) for k in ['x','y','width','height']]
  width=max(1,min(2000,width));height=max(1,min(2000,height));margin=64
  area=(x-margin,y-margin,x+width+margin,y+height+margin)
  wallpaper=Path(self.state['wallpaper'])
  size=(self.d.screen().width_in_pixels,self.d.screen().height_in_pixels)
  if wallpaper.exists():
   with Image.open(wallpaper) as source:
    canvas=scaled_region(source,size,area,cover=True)
  else:canvas=Image.new('RGBA',(width+margin*2,height+margin*2),'#242426')
  for client in self.state['clients']:
   if client['title']==arg['exclude'] and (not arg.get('excludeRect') or all(abs(a-b)<=2 for a,b in zip(client['at']+client['size'],arg['excludeRect']))):break
   if client['hidden'] or client['workspace']['id']!=self.state['workspace']:continue
   cx,cy=client['at'];cw,ch=client['size']
   if cx+cw<area[0] or cy+ch<area[1] or cx>area[2] or cy>area[3]:continue
   try:
    path=self.capture(client['wid'])
    if not path:continue
    with Image.open(path) as source:
     image=scaled_region(source,(cw,ch),(area[0]-cx,area[1]-cy,area[2]-cx,area[3]-cy))
    canvas.alpha_composite(image)
   except Exception:continue
  image=canvas.filter(ImageFilter.GaussianBlur(24)).crop((margin,margin,margin+width,margin+height))
  dest=CAPTURES/('frost-'+re.sub(r'[^A-Za-z0-9_.-]','',str(arg.get('key','settings')))[:64]+'.png');tmp=dest.with_name(dest.name+'.'+str(threading.get_ident())+'.tmp');image.save(tmp,format='PNG',compress_level=1);tmp.replace(dest);return str(dest)
 def dispatch(self,text):
  target=re.search(r'address:(0x[0-9a-fA-F]+|[0-9a-fA-F]+)',text)
  wid=int(target[1],16) if target else self.state.get('active',0)
  if 'title:^(' in text:
   title=text.split('title:^(',1)[1].split(')$',1)[0];win=next((w for w in self.state['clients'] if w['title']==title),None)
   if win:wid=win['wid']
  if 'hl.dsp.focus' in text and 'workspace' in text and 'address:' not in text:
   match=re.search(r'workspace\s*=\s*[\"\']?(\d+)',text)
   if match:spawn(['wmctrl','-s',str(int(match[1])-1)])
   return
  if not wid and 'workspace' not in text:return
  addr=hex(wid)
  if 'window.close' in text:spawn(['wmctrl','-ic',addr])
  elif 'special:minimized' in text:self.minimize(wid)
  elif 'window.pin' in text:spawn(['wmctrl','-ir',addr,'-b','toggle,sticky'])
  elif 'window.fullscreen_state' in text:
   mode=re.search(r'internal\s*=\s*(\d+)',text);value=int(mode[1]) if mode else 0
   spawn(['wmctrl','-ir',addr,'-b','toggle,maximized_vert,maximized_horz' if value==2 else ('toggle,fullscreen' if value==1 else 'remove,fullscreen,maximized_vert')])
  elif 'window.fullscreen' in text:
   action='remove' if 'unset' in text else 'add' if 'enable' in text else 'toggle'
   state='maximized_vert,maximized_horz' if 'maximized' in text else 'fullscreen'
   spawn(['wmctrl','-ir',addr,'-b',action+','+state])
  elif 'window.resize' in text or 'window.move' in text:
   x=re.search(r'\bx\s*=\s*(-?\d+)',text);y=re.search(r'\by\s*=\s*(-?\d+)',text)
   if x and y:
    values=f'0,-1,-1,{x[1]},{y[1]}' if 'resize' in text else f'0,{x[1]},{y[1]},-1,-1';spawn(['wmctrl','-ir',addr,'-e',values])
   else:
    ws=re.search(r'workspace\s*=\s*["\']([^"\']+)',text)
    if ws:
     found=next((w for w in self.state['workspaces'] if w['name']==ws[1] or str(w['id'])==ws[1]),None)
     if found:spawn(['wmctrl','-ir',addr,'-t',str(found['id']-1)])
  elif 'window.center' in text:
   win=next((w for w in self.state['clients'] if w['wid']==wid),None)
   if win:
    mon=self.monitors[win['monitor']];x=mon['x']+(mon['width']-win['size'][0])//2;y=mon['y']+(mon['height']-win['size'][1])//2;spawn(['wmctrl','-ir',addr,'-e',f'0,{x},{y},-1,-1'])
  elif 'hl.dsp.focus' in text or 'bring_to_top' in text:self.activate(wid)
  elif 'hl.dsp.exit' in text:spawn(['cinnamon-session-quit','--logout'])
  elif 'workspace' in text:
   m=re.search(r'(?:name|workspace)\s*=\s*["\']?(\d+)',text)
   if m:spawn(['wmctrl','-s',str(int(m[1])-1)])
 def request(self,msg):
  op=msg.get('op');arg=msg.get('arg')
  key=op+(':'+str(arg) if op=='capture' else '')
  self.operations[key]=self.operations.get(key,0)+1
  if op=='diagnostics':return {'operations':self.operations.copy(),'updates':self.update_count}
  if op=='mint-settings':
   from mint_settings import request
   return request(arg)
  if op=='wallpaper-catalog':
   from wallpaper_catalog import request
   return request(arg)
  if op=='widget-data':
   from widget_data import request
   return request(arg)
  if op=='timezones':
   from zoneinfo import available_timezones
   return sorted(available_timezones())
  if op=='filesystem':
   from finder_files import request
   return request(arg)
  if op=='state':return self.state
  if op=='widget-edit':
   if arg=='begin':
    if not self.widget_edit_state:
     self.widget_edit_state={'showing':int(self.prop(self.root,'_NET_SHOWING_DESKTOP',[0])[0])==1,'active':self.state.get('active',0),'deadline':time.monotonic()+2}
     self.fade_to_widget_desktop(self.widget_edit_state)
   else:self.finish_widget_edit()
   return True
  if op=='activate-title':
   title=str(arg)
   if title not in ['MacShell Widget Gallery','Edit Widget']:return False
   with self.lock:
    for w in reversed(self.root.query_tree().children):
     try:
      if self.string(w,'_NET_WM_NAME')!=title or w.get_attributes().map_state!=X.IsViewable:continue
      pid=int(self.prop(w,'_NET_WM_PID',[0])[0])
      if pid and 'macshell-source.service' in Path(f'/proc/{pid}/cgroup').read_text():
       if self.widget_edit_state:
        w.change_property(self.atom('_NET_WM_WINDOW_TYPE'),Xatom.ATOM,32,[self.atom('_NET_WM_WINDOW_TYPE_DOCK')])
        self.d.flush()
        if not int(self.prop(self.root,'_NET_SHOWING_DESKTOP',[0])[0]):
         subprocess.run(['wmctrl','-k','on'],check=False,timeout=2);time.sleep(.06)
        w.configure(stack_mode=X.Above);w.set_input_focus(X.RevertToParent,X.CurrentTime);self.d.flush()
       else:self.activate(w.id)
       return True
     except Exception:continue
   return False
  if op=='popup-focus':
   title=str(arg.get('title',''))
   if not title.startswith(('MacShell Context Menu','MacShell Spotlight')):return False
   with self.lock:
    for w in self.root.query_tree().children:
     try:
      if self.string(w,'_NET_WM_NAME')!=title or w.get_attributes().map_state!=X.IsViewable:continue
      pid=int(self.prop(w,'_NET_WM_PID',[0])[0])
      if not pid or 'macshell-source.service' not in Path(f'/proc/{pid}/cgroup').read_text():continue
      current=self.d.get_input_focus().focus
      previous=int(arg.get('previous') or (current.id if hasattr(current,'id') else 0))
      if title not in self.popup_focus or self.popup_focus[title][1]!=w.id:self.popup_focus[title]=(previous,w.id)
      w.set_input_focus(X.RevertToParent,X.CurrentTime);self.d.flush();return True
     except Exception:continue
   return False
  if op=='popup-restore':
   record=self.popup_focus.pop(str(arg),None)
   if record:
    with self.lock:
     current=self.d.get_input_focus().focus
     try:mapped=current.get_attributes().map_state==X.IsViewable
     except Exception:mapped=False
     if not mapped or (hasattr(current,'id') and current.id==record[1]):
      try:
       previous=self.d.create_resource_object('window',record[0])
       if previous.get_attributes().map_state==X.IsViewable:previous.set_input_focus(X.RevertToParent,X.CurrentTime);self.d.flush()
      except Exception:pass
   return True
  if op=='widget-input':
   if self.widget_rects!=arg:self.widget_rects=arg;self.wake()
   return True
  if op=='input-region':
   def build(node):
    x,y,w,h=[round(v) for v in node['rect']];region=cairo.Region(cairo.RectangleInt(x,y,max(0,w),max(0,h)))
    for child in node['children']:
     other=build(child);operation=child['op']
     region.subtract(other) if operation==1 else region.intersect(other) if operation==2 else region.xor(other) if operation==3 else region.union(other)
    return region
   if not any(title==arg['tag'] for _,title,_ in self.shape_windows.values()):self.shape_scan_at=0
   region=build(arg['region']);self.input_regions[arg['tag']]=[(r.x,r.y,r.width,r.height) for r in (region.get_rectangle(i) for i in range(region.num_rectangles()))];self.wake();return True
  if op=='devices':
   from native_controls import devices
   return devices()
  if op=='layout':
   from native_controls import switch_layout
   return switch_layout(arg)
  if op=='eval':
   from native_controls import evaluate
   if evaluate(str(arg)):return True
   for statement in str(arg).split(';'):
    if 'hl.dsp.' in statement:self.dispatch(statement)
   return True
  if op=='activate':self.activate(int(arg))
  elif op=='minimize':self.minimize(int(arg))
  elif op=='close':spawn(['wmctrl','-ic',hex(int(arg))])
  elif op=='dispatch':self.dispatch(str(arg))
  elif op=='capture':return self.capture(int(arg['wid']),str(arg.get('area',''))) if isinstance(arg,dict) else self.capture(int(arg))
  elif op=='frost':return self.frost(arg)
  elif op=='capture-screen':
   mon=next((m for m in self.monitors if m['name']==str(arg)),self.monitors[0]);image=ImageGrab.grab(bbox=(mon['x'],mon['y'],mon['x']+mon['width'],mon['y']+mon['height']));dest=CAPTURES/('screen-'+str(mon['id'])+'.png');tmp=dest.with_name(dest.name+'.'+str(threading.get_ident())+'.tmp');image.save(tmp,format='PNG',compress_level=1);tmp.replace(dest);return str(dest)
  elif op=='wallpaper':
   path=Path(str(arg)).expanduser().resolve(strict=True)
   with Image.open(path) as image:image.verify()
   settings=Gio.Settings.new('org.cinnamon.desktop.background')
   if not settings.set_string('picture-uri',path.as_uri()):raise OSError('The desktop background setting is not writable.')
   Gio.Settings.sync();self.wake();return str(path)
  elif op=='exec':spawn(arg)
  elif op=='launch':
   a=Gio.DesktopAppInfo.new(str(arg).removesuffix('.desktop')+'.desktop')
   if a:a.launch([],None)
  return True
 def wake(self):
  try:self.wake_write.send(b"1")
  except BlockingIOError:pass
 def serve(self):
  SOCKET.unlink(missing_ok=True);server=socket.socket(socket.AF_UNIX);server.bind(str(SOCKET));os.chmod(SOCKET,0o600);server.listen(32)
  def worker(c):
   with c:
    buffer=b''
    while True:
     try:
      chunk=c.recv(65536)
      if not chunk:return
      buffer+=chunk
      while b'\n' in buffer:
       raw,buffer=buffer.split(b'\n',1)
       try:
        message=json.loads(raw)
        if message.get('op')=='updates':
         from update_bridge import stream_updates
         for event in stream_updates(message.get('arg') or {}):
          try:c.sendall((json.dumps(event)+'\n').encode())
          except OSError:pass # Finish an authorized install even if Settings closes.
         continue
        result=self.request(message);response={'ok':True,'value':result}
       except Exception as e:response={'ok':False,'error':str(e)}
       c.sendall((json.dumps(response)+'\n').encode())
     except Exception:return
  def loop():
   while True:
    c,_=server.accept();threading.Thread(target=worker,args=(c,),daemon=True).start()
  threading.Thread(target=loop,daemon=True).start()
  while True:
   self.update()
   # EWMH events update immediately. The one-second timeout is recovery only.
   with self.lock:pending=self.d.pending_events()
   if not pending:select.select([self.d.fileno(),self.wake_read],[],[],1)
   try:self.wake_read.recv(65536)
   except BlockingIOError:pass
   with self.lock:
    while self.d.pending_events():
     event=self.d.next_event()
     if event.type in [self.randr_event,self.randr_event+1]:self.last_mon=0
     if event.type in [X.CreateNotify,X.MapNotify,X.DestroyNotify]:self.shape_scan_at=0
   time.sleep(.12)
def rpc(op,arg=None):
 with socket.socket(socket.AF_UNIX) as c:
  c.settimeout(5);c.connect(str(SOCKET));c.sendall((json.dumps({'op':op,'arg':arg})+'\n').encode());data=b''
  while b'\n' not in data:
   chunk=c.recv(65536)
   if not chunk:raise ConnectionError('Native adapter closed the connection')
   data+=chunk
  return json.loads(data)['value']
if __name__=='__main__':
 if len(sys.argv)>1:
  op=sys.argv[1];arg=json.loads(sys.argv[2]) if len(sys.argv)>2 else None
  try:print(json.dumps(rpc(op,arg)))
  except Exception as e:print(str(e),file=sys.stderr);sys.exit(1)
 else:Native().serve()
