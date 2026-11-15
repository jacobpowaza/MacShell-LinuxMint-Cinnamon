"""Render every local weather condition and verify glyphs contain visible pixels."""
import sys,time,subprocess,shutil
from pathlib import Path
from PIL import Image
from Xlib import display,X
B=Path(__file__).resolve().parents[1];sys.path.insert(0,str(B));from native import rpc
D=display.Display();R=D.screen().root;active=rpc('state')['active'];p=None;fixture=B/'MacShell/WeatherIconsQa.qml'
shutil.copy2(B/'tests/weather-icons.qml',fixture)
try:
 p=subprocess.Popen([str(B.parent/'runtime/qs'),'-p',str(fixture)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 w=None
 for _ in range(80):
  for candidate in R.query_tree().children:
   try:
    if candidate.get_wm_name()=='MacShell Owned Weather Icons QA' and candidate.get_attributes().map_state==X.IsViewable:w=candidate
   except Exception:pass
  if w:break
  time.sleep(.1)
 assert w,'Weather fixture did not load';time.sleep(.6)
 im=Image.open(rpc('capture',w.id)).convert('RGBA')
 for i,kind in enumerate(['sun','moon','partly','partlyNight','cloud','fog','rain','snow','storm']):
  crop=im.crop((18+i*116,10,98+i*116,90)).convert('RGB')
  visible=sum(1 for r,g,b in crop.getdata() if max(abs(r-52),abs(g-52),abs(b-59))>30)
  assert visible>100,(kind,visible)
 out=B/'.impeccable/widget-motion';out.mkdir(exist_ok=True);im.save(out/'weather-all-conditions.png')
 print('PASS: all nine weather conditions draw visible local glyphs')
finally:
 if p:
  subprocess.run([str(B.parent/"runtime/qs"),"kill","--newest","-p",str(fixture)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 fixture.unlink(missing_ok=True)
 if any(w['wid']==active for w in rpc('state')['clients']):rpc('activate',active)
 D.close()
