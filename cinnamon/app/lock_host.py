"""MacLock visual adapter hosted by Cinnamon's unchanged secure Stage.

Passwords remain in the stock GTK/PAM entry. Only length/status is mirrored.
The viewer never authorizes unlock. On any viewer failure, stock UI returns.
"""
import os,json,time,signal,socket,threading,subprocess,uuid
from pathlib import Path
import gi
gi.require_version('Gtk','3.0');gi.require_version('GdkX11','3.0')
from gi.repository import Gtk,Gdk,GdkX11,GLib,Gio
from Xlib import display,X,protocol
from Xlib.ext import dpms
BASE=Path(__file__).resolve().parent
RUNTIME=Path(os.environ['XDG_RUNTIME_DIR'])/'macshell-cinnamon-port'
RUNTIME.mkdir(mode=0o700,exist_ok=True)
class MacLockHost:
 _event_host=None
 def __init__(self,stage,preview=False):
  self.stage=stage;self.preview=preview;self.viewer=None;self.embedded=[];self.saved=[];self.destroyed=False;self.unlocking=False;self.last='';self.submit_pending=False;self.disabled=False;self.ready=False;self.last_frame=0;self.cached_length=0;self.clients=set();self.forward_ids=[];self.started=time.monotonic();self.x=display.Display();self.root=self.x.screen().root;self.socket=None
  self.log=(BASE/'lock-host.log').open('a',buffering=1)
  token=str(os.getpid())+'-'+uuid.uuid4().hex
  self.statefile=RUNTIME/('lock-state-'+token+'.json');self.socketpath=RUNTIME/('lock-native-'+token+'.sock')
  self.preparing_sleep=False;self.display_asleep=False;self.sleep_checked=0;self.resume_until=0;self.last_awake=None
  self.sleep_bus=None;self.sleep_subscription=None
  if not preview:
   try:
    self.sleep_bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
    self.sleep_subscription=self.sleep_bus.signal_subscribe('org.freedesktop.login1','org.freedesktop.login1.Manager','PrepareForSleep','/org/freedesktop/login1',None,0,self.on_prepare_sleep)
   except GLib.Error:pass
  self.stage.connect('destroy',self.destroy)
  self.stage.add_events(Gdk.EventMask.POINTER_MOTION_MASK|Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.BUTTON_RELEASE_MASK)

  self.source=GLib.timeout_add(80,self.tick)
  self.stage.connect('key-press-event',self.emergency_key)
 def write(self,msg):print(time.strftime('%H:%M:%S'),msg,file=self.log)
 def start(self):
  self.socketpath.unlink(missing_ok=True);self.socket=socket.socket(socket.AF_UNIX);self.socket.bind(str(self.socketpath));os.chmod(self.socketpath,0o600);self.socket.listen(4)
  def listen():
   while not self.destroyed:
    try:c,_=self.socket.accept()
    except OSError:return
    if len(self.clients)>=4:c.close();continue
    c.settimeout(5);self.clients.add(c)
    def worker(c):
     with c:
      data=b''
      while True:
       try:chunk=c.recv(256)
       except socket.timeout:continue
       except OSError:self.clients.discard(c);return
       if not chunk:self.clients.discard(c);return
       data+=chunk
       if len(data)>512:return
       while b'\n' in data:
        action,data=data.split(b'\n',1)
        if self.destroyed or self.viewer is None:return
        if action==b'submit' and not self.submit_pending and not self.disabled:
         self.submit_pending=True;GLib.idle_add(self.submit)
        elif action.startswith(b'frame|'):self.last_frame=time.monotonic()
    threading.Thread(target=worker,args=(c,),daemon=True).start()
  threading.Thread(target=listen,daemon=True).start()
  env=os.environ.copy();env.update(MACLOCK_CINNAMON_HOST='1',MACLOCK_PREVIEW='1',MACLOCK_PREVIEW_KB='0',MACLOCK_NATIVE_SOCKET=str(self.socketpath),MACLOCK_NATIVE_STATE=str(self.statefile))
  self.viewer=subprocess.Popen([str(BASE.parent/'runtime/qs'),'-p',str(BASE/'MacLock'),'--no-color'],env=env,stdout=self.log,stderr=self.log,start_new_session=True)
  self.started=time.monotonic();self.write('Started upstream MacLock visual process')
 def entry(self):
  dialog=getattr(self.stage,'unlock_dialog',None)
  return getattr(dialog,'password_entry',None)
 def submit(self):
  self.submit_pending=False
  if self.disabled or self.preview or self.destroyed or self.viewer is None or not self.ready:return False
  import status
  if not (status.Active and status.Locked and status.Awake):return False
  dialog=getattr(self.stage,'unlock_dialog',None)
  if dialog and dialog.get_visible() and dialog.entry_box.get_sensitive() and dialog.auth_unlock_button.get_visible() and dialog.auth_unlock_button.get_sensitive():dialog.auth_unlock_button.emit('clicked')
  return False
 def state(self):
  if self.preview:
   return {'length':len(self.stage.entry.get_text()),'busy':False,'awake':True,'message':'Visual preview — authentication remains Cinnamon-owned','unlocking':False,'showVisual':self.ready,'capsLock':False}
  import status
  dialog=getattr(self.stage,'unlock_dialog',None);entry=self.entry()
  label=getattr(dialog,'auth_message_label',None)
  busy=bool(dialog and not dialog.entry_box.get_sensitive());length=len(entry.get_text()) if entry else 0
  if not busy:self.cached_length=length
  return {'length':self.cached_length if busy else length,'busy':busy,'awake':bool(status.Awake),'message':label.get_text() if label else '', 'unlocking':self.unlocking,'showVisual':self.ready,'capsLock':Gdk.Keymap.get_default().get_caps_lock_state()}
 def hide_stock(self):
  for key in ['unlock_dialog','clock_widget','albumart_widget','audio_panel','info_panel']:
   widget=getattr(self.stage,key,None)
   if widget:
    if widget not in [w for w,_ in self.saved]:self.saved.append((widget,widget.get_opacity()))
    if widget.get_opacity()!=0:widget.set_opacity(0)
  dialog=getattr(self.stage,'unlock_dialog',None)
  if dialog and not getattr(dialog,'maclock_connected',False):
   dialog.maclock_connected=True
   dialog.connect('authenticate-success',lambda *_:setattr(self,'unlocking',True))
 def restore_stock(self):
  for widget,opacity in self.saved:
   try:widget.set_opacity(opacity)
   except Exception:pass
  self.saved=[]
 def find_windows(self):
  candidates=list(self.root.query_tree().children)
  prop=self.root.get_full_property(self.x.intern_atom('_NET_CLIENT_LIST'),X.AnyPropertyType)
  if prop:candidates += [self.x.create_resource_object('window',int(i)) for i in prop.value]
  found=[];seen=set()
  for w in candidates:
   try:
    if w.id in seen:continue
    seen.add(w.id);p=w.get_full_property(self.x.intern_atom('_NET_WM_PID'),X.AnyPropertyType)
    if not p or os.getpgid(int(p.value[0]))!=self.viewer.pid:continue
    g=w.get_geometry()
    if g.width<300 or g.height<300:continue
    found.append(w)
   except Exception:continue
  return found
 def embed(self):
  native=self.stage.get_window()
  if native is None:return
  parent=self.x.create_resource_object('window',native.get_xid())
  for w in self.find_windows():
   if w.id in [q.id for q in self.embedded]:continue
   # Keep the Qt visual as a child of the real secure GTK Stage. It cannot outlive that Stage.
   position=self.root.translate_coords(w,0,0);origin=native.get_root_origin();w.reparent(parent,position.x-origin[0],position.y-origin[1]);w.map();self.x.sync();self.embedded.append(w);self.write('Embedded visual window '+hex(w.id))
  if self.embedded and self.last_frame>self.started and not self.ready:
   dialog=getattr(self.stage,'unlock_dialog',None)
   if dialog and self.unsupported_prompt(dialog):
    self.fallback('Native fallback for a non-password PAM conversation');return
   native_geometry=parent.get_geometry()
   valid=True
   for w in self.embedded:
    g=w.get_geometry();attr=w.get_attributes()
    if g.width!=native_geometry.width or g.height!=native_geometry.height or attr.map_state!=X.IsViewable:valid=False
   if valid:
    self.ready=True;MacLockHost._event_host=self;Gdk.event_handler_set(self.capture_event);self.hide_stock()
    entry=self.entry()
    if entry:entry.grab_focus()
    if self.preview:self.stage.entry.grab_focus()
 def unsupported_prompt(self,dialog):
  import builtins
  entry=self.entry();prompt=entry.get_placeholder_text() if entry else ''
  info=getattr(dialog,'auth_info','') or ''
  standard=getattr(builtins,'_',lambda t:t)('Please enter your password...')
  return dialog.entry_box.get_sensitive() and (bool(info) or bool(prompt and 'password' not in prompt.lower() and prompt!=standard))
 def capture_event(self,event,*_):
  # GDK dispatch hook runs before Gtk routes an event to any descendant.
  # Preserve Cinnamon's activity handling, then route visual pointer events.
  try:
   if not self.disabled and not self.destroyed and event.type==Gdk.EventType.KEY_PRESS and self.emergency_key(self.stage,event):return
   if self.ready and not self.disabled and not self.destroyed:
    if event.type in [Gdk.EventType.MOTION_NOTIFY,Gdk.EventType.BUTTON_PRESS,Gdk.EventType.BUTTON_RELEASE]:
     if not self.preview:
      if event.type==Gdk.EventType.MOTION_NOTIFY:self.stage.event_handler.on_motion_event(event)
      elif event.type==Gdk.EventType.BUTTON_PRESS:self.stage.event_handler.on_button_press_event(event)
     if self.pointer(self.stage,event):return
     self.fallback("Pointer target unavailable; restoring native UI")
  except Exception as e:self.fallback('Input routing failed: '+str(e))
  Gtk.main_do_event(event)
 def emergency_key(self,widget,event):
  if not self.disabled and event.keyval in [Gdk.KEY_F12,Gdk.KEY_Tab,Gdk.KEY_ISO_Left_Tab]:
   self.fallback('Native recovery requested');return True
  return False
 def fallback(self,reason):
  self.disabled=True
  self.write(reason)
  self.destroy_viewer()
  self.restore_stock()
  entry=self.entry()
  if entry:
   try:entry.grab_focus()
   except Exception:pass
 def on_prepare_sleep(self,connection,sender,path,interface,name,parameters,*userdata):
  sleeping=bool(parameters.unpack()[0])
  self.set_sleeping(sleeping)
 def set_sleeping(self,sleeping):
  self.preparing_sleep=bool(sleeping)
  if not sleeping:self.resume_until=time.monotonic()+8;self.last_frame=time.monotonic()
 def is_display_asleep(self):
  if not self.preview and time.monotonic()-self.sleep_checked>1:
   self.sleep_checked=time.monotonic()
   try:
    info=self.x.dpms_info();asleep=bool(info.state and info.power_level!=dpms.DPMSModeOn)
    if self.display_asleep and not asleep:self.resume_until=time.monotonic()+8;self.last_frame=time.monotonic()
    self.display_asleep=asleep
   except Exception:self.display_asleep=False
  return self.preparing_sleep or self.display_asleep
 def tick(self):
  if self.destroyed or self.disabled:return False
  try:
   if not self.preview:
    import status
    if not status.Active or not status.Locked:
     # During Cinnamon's configured lock delay there is no visual renderer yet.
     # Preserve its normal, non-locking screensaver presentation.
     if self.saved:self.restore_stock()
     return True
    monitor=Gdk.Display.get_default()
    if monitor.get_n_monitors()!=1 or monitor.get_monitor(0).get_scale_factor()!=1:
     self.fallback('Native fallback for an unverified monitor/scaling layout');return False
   if self.viewer is None:self.start()
   if self.viewer.poll() is not None:
    self.fallback('Viewer exited; restoring stock secure UI');return False
   dialog=getattr(self.stage,'unlock_dialog',None)
   if dialog and self.ready:
    import status
    focus=self.stage.get_focus()
    if self.unsupported_prompt(dialog) or (status.Awake and focus and focus!=self.entry()):
     self.fallback('Native prompt or accessibility control requires native UI');return False
   asleep=self.is_display_asleep()
   if self.ready and not asleep:
    self.hide_stock()
    awake=bool(self.state()['awake'])
    if awake!=self.last_awake or time.monotonic()<self.resume_until:
     self.last_awake=awake
     for child in self.embedded:child.configure(stack_mode=X.Above)
     self.x.flush()
   for w in self.embedded:
    parent_geometry=self.x.create_resource_object('window',self.stage.get_window().get_xid()).get_geometry();geometry=w.get_geometry()
    if geometry.x!=0 or geometry.y!=0 or geometry.width!=parent_geometry.width or geometry.height!=parent_geometry.height:
     self.fallback('Visual coverage changed; restoring native UI');return False
    if w.get_attributes().map_state!=X.IsViewable and not asleep:
     if time.monotonic()<self.resume_until:w.map();w.configure(stack_mode=X.Above);self.x.flush()
     else:self.fallback('Visual window became unavailable');return False
   if self.ready and not asleep and time.monotonic()>self.resume_until and time.monotonic()-self.last_frame>4:
    self.fallback('Visual heartbeat expired; restoring native UI');return False
   d=json.dumps(self.state(),separators=(',',':'))
   if d!=self.last:
    tmp=self.statefile.with_suffix('.tmp');tmp.write_text(d);os.chmod(tmp,0o600);tmp.replace(self.statefile);self.last=d
   self.embed()
   if not self.ready and time.monotonic()-self.started>5:
    self.fallback('Visual readiness timed out; restoring native UI');return False
  except Exception as e:
   self.fallback('Visual adapter failed: '+str(e));return False
  return True
 def pointer(self,widget,event):
  if not self.embedded or not self.ready or self.destroyed:return False
  try:
   w=None;pos=None
   for candidate in self.embedded:
    at=self.root.translate_coords(candidate,0,0);g=candidate.get_geometry()
    if at.x<=event.x_root<at.x+g.width and at.y<=event.y_root<at.y+g.height:w=candidate;pos=at;break
   if w is None:return False
   x=int(event.x_root-pos.x);y=int(event.y_root-pos.y)
   common=dict(time=X.CurrentTime,root=self.root,window=w,same_screen=1,child=X.NONE,root_x=int(event.x_root),root_y=int(event.y_root),event_x=x,event_y=y,state=int(event.state))
   if event.type==Gdk.EventType.MOTION_NOTIFY:e=protocol.event.MotionNotify(detail=0,**common);mask=X.PointerMotionMask
   elif event.type==Gdk.EventType.BUTTON_PRESS:e=protocol.event.ButtonPress(detail=int(event.button),**common);mask=X.ButtonPressMask
   elif event.type==Gdk.EventType.BUTTON_RELEASE:e=protocol.event.ButtonRelease(detail=int(event.button),**common);mask=X.ButtonReleaseMask
   else:return False
   w.send_event(e,event_mask=mask);self.x.flush();return True
  except Exception:pass
  return False
 def destroy_viewer(self):
  if MacLockHost._event_host is self:
   MacLockHost._event_host=None;Gdk.event_handler_set(Gtk.main_do_event)
  self.ready=False
  for handler in self.forward_ids:
   try:self.stage.disconnect(handler)
   except Exception:pass
  self.forward_ids=[]
  for window in self.embedded:
   try:window.unmap()
   except Exception:pass
  try:self.x.sync()
  except Exception:pass
  self.embedded=[]
  for client in list(self.clients):
   try:client.shutdown(socket.SHUT_RDWR);client.close()
   except OSError:pass
  self.clients.clear()
  viewer=self.viewer;self.viewer=None
  if viewer:
   try:os.killpg(viewer.pid,signal.SIGTERM)
   except ProcessLookupError:pass
   def reap():
    try:viewer.wait(timeout=1)
    except subprocess.TimeoutExpired:
     try:os.killpg(viewer.pid,signal.SIGKILL)
     except ProcessLookupError:pass
     viewer.wait()
   threading.Thread(target=reap,daemon=True).start()
  if self.socket:
   try:self.socket.close()
   except OSError:pass
   self.socket=None
 def destroy(self,*_):
  if self.destroyed:return
  self.destroyed=True;self.destroy_viewer()
  if self.sleep_bus and self.sleep_subscription:self.sleep_bus.signal_unsubscribe(self.sleep_subscription)
  try:self.x.close()
  except Exception:pass
  self.socketpath.unlink(missing_ok=True);self.statefile.unlink(missing_ok=True)

def install():
 import stage
 original=stage.Stage.__init__
 def init(self,*args,**kwargs):
  original(self,*args,**kwargs)
  try:self.maclock_visual=MacLockHost(self)
  except Exception as e:print('MacLock visual adapter unavailable; stock screensaver retained:',e,flush=True)
 stage.Stage.__init__=init
 setup=stage.Stage.setup_children
 def setup_children(self,*args,**kwargs):
  result=setup(self,*args,**kwargs)
  adapter=getattr(self,'maclock_visual',None)
  if adapter and not adapter.disabled:
   # The secure Stage already owns the screen. Keep native widgets off the first
   # paint while the MacLock renderer starts; deadline/F12 always restore them.
   adapter.hide_stock()
   MacLockHost._event_host=adapter;Gdk.event_handler_set(adapter.capture_event)
  return result
 stage.Stage.setup_children=setup_children
 delayed=stage.Stage.setup_delayed_components
 def setup_delayed(self,*args,**kwargs):
  result=delayed(self,*args,**kwargs)
  adapter=getattr(self,'maclock_visual',None)
  if adapter and not adapter.disabled and (adapter.saved or adapter.ready):
   adapter.hide_stock()
   for child in adapter.embedded:child.configure(stack_mode=X.Above)
   adapter.x.flush()
  return result
 stage.Stage.setup_delayed_components=setup_delayed
