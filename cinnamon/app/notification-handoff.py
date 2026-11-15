#!/usr/bin/python3
"""Hand D-Bus notifications to MacShell; keep Cinnamon queued for recovery."""
import time
from gi.repository import Gio,GLib
bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
def owner(name):
 try:return bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetNameOwner',GLib.Variant('(s)',(name,)),None,0,1000,None).unpack()[0]
 except GLib.Error:return ''
def cinnamon(method):
 script="imports.gi.Gio.DBus.session.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','%s',new imports.gi.GLib.Variant('%s',%s),null,imports.gi.Gio.DBusCallFlags.NONE,-1,null);"%(method,'(s)' if method=='ReleaseName' else '(su)',"['org.freedesktop.Notifications']" if method=='ReleaseName' else "['org.freedesktop.Notifications',0]")
 bus.call_sync('org.Cinnamon','/org/Cinnamon','org.Cinnamon','Eval',GLib.Variant('(s)',(script,)),None,0,3000,None)
native=owner('org.Cinnamon');cinnamon('ReleaseName')
for _ in range(100):
 current=owner('org.freedesktop.Notifications')
 if current and current!=native:break
 time.sleep(.2)
cinnamon('RequestName')
