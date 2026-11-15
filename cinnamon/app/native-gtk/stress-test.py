"""Owned GTK processes only: lifecycle, native response IDs and module reload safety."""
import gi
from pathlib import Path
gi.require_version('Gtk','3.0');from gi.repository import Gtk,GLib
module=str(Path(__file__).with_name('libmacshell-dialogs.so').resolve());settings=Gtk.Settings.get_default()
responses=[]
def stage():
    # Removing a dynamic module setting must not leave pointers into unloaded code.
    settings.set_property('gtk-modules',module)
    for _ in range(50):
        d=Gtk.MessageDialog(text='Owned close-window fixture',buttons=Gtk.ButtonsType.OK_CANCEL);d.show_all();d.destroy()
    settings.set_property('gtk-modules','')
    for _ in range(20):
        w=Gtk.Window();w.show_all();w.destroy()
    settings.set_property('gtk-modules',module)
    d=Gtk.MessageDialog(text='Close this window?',secondary_text='Owned fixture. No user process will be closed.',buttons=Gtk.ButtonsType.OK_CANCEL)
    d.connect('response',lambda w,r:responses.append(r));d.show_all()
    def check():
        a=d.get_action_area();assert a.get_orientation()==Gtk.Orientation.VERTICAL
        assert not d.get_decorated()
        d.response(Gtk.ResponseType.CANCEL);assert responses==[Gtk.ResponseType.CANCEL]
        d.destroy();Gtk.main_quit();print('PASS 70 lifecycle iterations, module removal/reload, stacked layout and unchanged Cancel response')
        return False
    GLib.timeout_add(150,check);return False
GLib.idle_add(stage);Gtk.main()
