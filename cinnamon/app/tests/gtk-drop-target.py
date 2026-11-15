import gi,json,sys
from pathlib import Path
gi.require_version('Gtk','3.0');from gi.repository import Gtk,Gdk
window=Gtk.Window(title='MacShell QA Xdnd Target');window.set_default_size(300,180);window.move(1530,360);window.set_keep_above(True)
label=Gtk.Label(label='Owned file-drop verification target');window.add(label)
window.drag_dest_set(Gtk.DestDefaults.ALL,[Gtk.TargetEntry.new('text/uri-list',0,0)],Gdk.DragAction.COPY)
def received(widget,context,x,y,data,info,time):
 Path(sys.argv[1]).write_text(json.dumps(data.get_uris()));context.finish(True,False,time)
window.connect('drag-data-received',received);window.connect('destroy',Gtk.main_quit);window.show_all();Gtk.main()
