import gi
gi.require_version('Gtk','3.0');from gi.repository import Gtk,Gdk
w=Gtk.Window(title='MacShell Owned QA Backdrop');w.set_decorated(False);w.set_default_size(1920,1000);w.move(0,28)
provider=Gtk.CssProvider();provider.load_from_data(b'window { background-color: #34343b; }');Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
w.connect('destroy',Gtk.main_quit);w.maximize();w.show_all();Gtk.main()
