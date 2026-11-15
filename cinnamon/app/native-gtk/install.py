#!/usr/bin/python3
"""Install/remove the GTK3 message-dialog adapter without replacing applications."""
import json,shutil,sys,hashlib
from pathlib import Path
from gi.repository import Gio,GLib
BASE=Path(__file__).resolve().parent
MODULE_DIR=Path.home()/'.local/lib/gtk-3.0/modules'
TARGET=MODULE_DIR/('libmacshell-dialogs-'+hashlib.sha256((BASE/'libmacshell-dialogs.so').read_bytes()).hexdigest()[:12]+'.so')
BACKUP=BASE/'install-state.json'
s=Gio.Settings.new('org.cinnamon.settings-daemon.plugins.xsettings')
def overrides():
    v=s.get_value('overrides');result={}
    for i in range(v.n_children()):
        e=v.get_child_value(i);result[e.get_child_value(0).get_string()]=e.get_child_value(1).get_variant()
    return result
values=overrides();before=values.get('Gtk/Modules');modules=before.get_string().split(':') if before else []
if '--remove' in sys.argv:
    modules=[m for m in modules if not (Path(m).parent==MODULE_DIR and Path(m).name.startswith('libmacshell-dialogs'))]
    if modules:values['Gtk/Modules']=GLib.Variant('s',':'.join(modules))
    else:values.pop('Gtk/Modules',None)
else:
    if not BACKUP.exists():BACKUP.write_text(json.dumps({'Gtk/Modules':before.get_string() if before else None},indent=2)+'\n')
    TARGET.parent.mkdir(parents=True,exist_ok=True)
    if not TARGET.exists():shutil.copy2(BASE/'libmacshell-dialogs.so',TARGET)
    modules=[m for m in modules if not (Path(m).parent==MODULE_DIR and Path(m).name.startswith('libmacshell-dialogs'))]
    if str(TARGET) not in modules:modules.append(str(TARGET))
    values['Gtk/Modules']=GLib.Variant('s',':'.join(filter(None,modules)))
if not s.set_value('overrides',GLib.Variant('a{sv}',values)):raise RuntimeError('Cinnamon XSettings overrides are not writable.')
Gio.Settings.sync()
print('GTK3 message-dialog adapter '+('disabled for new module loads' if '--remove' in sys.argv else 'enabled in the current session'))
