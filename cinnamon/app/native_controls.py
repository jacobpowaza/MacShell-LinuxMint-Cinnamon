"""Translate MacShell compositor settings into Cinnamon/XRandR settings."""
import re,json,subprocess
from gi.repository import Gio,GLib

def cinnamon_eval(script):
 bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
 success,text=bus.call_sync('org.Cinnamon','/org/Cinnamon','org.Cinnamon','Eval',GLib.Variant('(s)',(script,)),GLib.VariantType('(bs)'),Gio.DBusCallFlags.NONE,2000,None).unpack()
 if not success:raise RuntimeError(text)
 try:return json.loads(text)
 except ValueError:return text

def devices():
 try:
  value=cinnamon_eval("JSON.stringify((()=>{const m=imports.ui.keyboardManager.getInputSourceManager();return {layouts:Object.values(m.inputSources).map(s=>({id:s.id,name:s.displayName})),active:m.currentSource.index};})())")
  if isinstance(value,str):value=json.loads(value)
  layouts=value['layouts'];active=value['active']
  return {'keyboards':[{'name':'cinnamon-input','main':True,'layout':','.join(q['id'] for q in layouts),'active_keymap':layouts[active]['name'],'activeLayoutIndex':active,'capsLock':False}]}
 except Exception:
  return {'keyboards':[{'name':'cinnamon-input','main':True,'layout':'us','active_keymap':'English (US)','activeLayoutIndex':0,'capsLock':False}]}

def switch_layout(index):
 index=int(index)
 return cinnamon_eval(f'imports.ui.keyboardManager.getInputSourceManager().activateInputSourceIndex({index})')

def evaluate(text):
 if 'hl.monitor(' in text:
  output=re.search(r'output\s*=\s*"([^"]+)"',text);mode=re.search(r'mode\s*=\s*"(\d+)x(\d+)@([\d.]+)',text)
  if output and mode:
   args=['xrandr','--output',output[1],'--mode',mode[1]+'x'+mode[2],'--rate',mode[3]]
   pos=re.search(r'position\s*=\s*"(-?\d+)x(-?\d+)"',text)
   if pos:args+=['--pos',pos[1]+'x'+pos[2]]
   subprocess.run(args,check=True)
  return True
 if 'hl.config(' in text and 'input' in text:
  keyboard=Gio.Settings.new('org.cinnamon.desktop.peripherals.keyboard');mouse=Gio.Settings.new('org.cinnamon.desktop.peripherals.mouse');touchpad=Gio.Settings.new('org.cinnamon.desktop.peripherals.touchpad')
  def number(key,source=text):
   m=re.search(r'\b'+key+r'\s*=\s*(-?[\d.]+)',source);return float(m[1]) if m else None
  def boolean(key,source=text):
   m=re.search(r'\b'+key+r'\s*=\s*(true|false)',source);return m[1]=='true' if m else None
  rate=number('repeat_rate');delay=number('repeat_delay');speed=number('sensitivity')
  if rate is not None:keyboard.set_uint('repeat-interval',max(1,round(1000/max(1,rate))))
  if delay is not None:keyboard.set_uint('delay',max(1,round(delay)))
  if speed is not None:mouse.set_double('speed',max(-1.,min(1.,speed)))
  parts=text.split('touchpad',1);natural=boolean('natural_scroll',parts[0])
  if natural is not None:mouse.set_boolean('natural-scroll',natural)
  if len(parts)>1:
   speed=number('scroll_factor',parts[1])
   if speed is not None:touchpad.set_double('speed',max(-1.,min(1.,speed)))
   for lua,key in [('natural_scroll','natural-scroll'),('tap_to_click','tap-to-click'),('disable_while_typing','disable-while-typing')]:
    value=boolean(lua,parts[1])
    if value is not None:touchpad.set_boolean(key,value)
  Gio.Settings.sync();return True
 return False
