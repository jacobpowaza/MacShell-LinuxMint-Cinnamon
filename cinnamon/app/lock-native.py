#!/usr/bin/python3
import sys,os
# A secure authentication surface must never load application-dialog adapters.
os.environ["MACSHELL_SECURE_SURFACE"]="1"
os.environ["GTK_MODULES"]="gail:atk-bridge"
# Match /usr/bin/cinnamon-screensaver before importing its private GI namespace.
if os.environ.get('MACSHELL_LOCK_ENV')!='1':
 env=os.environ.copy();env['MACSHELL_LOCK_ENV']='1'
 env['GI_TYPELIB_PATH']='/usr/libexec/cinnamon-screensaver/girepository-1.0'
 env['LD_LIBRARY_PATH']='/usr/libexec/cinnamon-screensaver'
 os.execve(sys.executable,[sys.executable,__file__,*sys.argv[1:]],env)
import runpy,gi
sys.path.insert(0,'/usr/share/cinnamon-screensaver')
gi.require_version('Gtk','3.0');gi.require_version('GdkX11','3.0');gi.require_version('CScreensaver','1.0')
try:
 from lock_host import install
 install()
except Exception as e:
 print('MacLock adapter unavailable; starting stock Cinnamon:',e,flush=True)
runpy.run_path('/usr/share/cinnamon-screensaver/cinnamon-screensaver-main.py',run_name='__main__')
