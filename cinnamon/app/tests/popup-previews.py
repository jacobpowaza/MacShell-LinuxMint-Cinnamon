"""Owned, non-destructive GTK popup fixture; never invokes a system action."""
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk, GLib
w=Gtk.Window(title='MacShell Popup QA')
w.set_default_size(600,420)
w.connect('destroy',Gtk.main_quit)
b=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=14,margin=24)
w.add(b)
for title,kind in [('Warning',Gtk.MessageType.WARNING),('Information',Gtk.MessageType.INFO),('Error',Gtk.MessageType.ERROR)]:
    button=Gtk.Button(label=title)
    def show(_,kind=kind,title=title):
        d=Gtk.MessageDialog(transient_for=w,modal=True,message_type=kind,buttons=Gtk.ButtonsType.NONE,text='MacShell '+title)
        d.set_title('MacShell '+title+' QA')
        d.format_secondary_text('This is a styling preview. The buttons only close this test dialog.')
        d.add_button('Cancel',Gtk.ResponseType.CANCEL)
        a=d.add_button('Continue',Gtk.ResponseType.OK);a.get_style_context().add_class('suggested-action')
        d.connect('response',lambda d,r:d.destroy());d.show_all()
    button.connect('clicked',show);b.pack_start(button,False,False,0)
pop=Gtk.MenuButton(label='Menu Preview');menu=Gtk.Menu()
for label in ['Open','Rename…','Move to Trash']:
    menu.append(Gtk.MenuItem(label=label))
menu.show_all();pop.set_popup(menu);b.pack_start(pop,False,False,0)
w.show_all()
GLib.timeout_add(300,lambda: b.get_children()[0].clicked() or False)
Gtk.main()
