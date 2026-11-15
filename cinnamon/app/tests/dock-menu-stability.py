from pathlib import Path
import json,subprocess,time
from Xlib import display,X
b=Path.home()/'.local/share/macshell-cinnamon';qs=str(b/'runtime/qs');p=str(b/'app/MacShell');out=b/'app/.impeccable/window-decoration';out.mkdir(exist_ok=True)
def ipc(m,*a):return subprocess.check_output([qs,'ipc','--newest','-p',p,'call','cinnamon',m,*a],text=True)
def geometry():return json.loads(ipc('dockGeometry'))
d=display.Display();r=d.screen().root;original=r.query_pointer();orig=(original.root_x,original.root_y)
try:
 g=geometry();screen=next(iter(g));icon=next(i for i in g[screen]['icons'] if i['key']=='org.gnome.terminal')
 r.warp_pointer(int(icon['x']+icon['width']/2),int(icon['y']+icon['height']/2));d.sync();time.sleep(1)
 before=geometry();ipc('dockMenu','org.gnome.terminal');time.sleep(1);during=geometry()
 def rects(g):return {k:{f:v[f] for f in ['x','y','width','height','icons']} for k,v in g.items()}
 assert rects(before)==rects(during),(before,during)
 assert during[screen]['menuOpen']
 # Moving into the menu must not move or grow the dock either.
 r.warp_pointer(950,750);d.sync();time.sleep(.5);moved=geometry();assert rects(during)==rects(moved)
 ipc('dismissDockMenus');time.sleep(.4);assert not geometry()[screen]['menuOpen']
 (out/'dock-geometry.json').write_text(json.dumps({'before':before,'menu':during,'menuPointer':moved},indent=2))
 print('PASS: hovered dock and every icon retain exact global rectangles on right-click/menu entry; dismissal works.')
finally:
 ipc('dismissDockMenus');r.warp_pointer(*orig);d.sync();d.close()
