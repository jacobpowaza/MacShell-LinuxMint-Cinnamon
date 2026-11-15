import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: service
    property bool busy: false
    property string queued: ""
    property string error: ""
    signal applied(string path)
    function apply(path){queued=path;drain();}
    function drain(){if(busy || !queued || !channel.connected)return;var path=queued;queued="";busy=true;error="";channel.write(JSON.stringify({op:"wallpaper",arg:path})+"\n");channel.flush();}
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true
        onConnectedChanged: if(connected)service.drain();else {service.busy=false;service.error="Wallpaper service disconnected. Select the picture to retry.";}
        parser: SplitParser { onRead: text=>{
            service.busy=false;
            try {var r=JSON.parse(text);if(r.ok)service.applied(r.value);else service.error=r.error;}
            catch(e){service.error="Wallpaper could not be applied. Select it to retry.";}
            service.drain();
        }}
    }
}
