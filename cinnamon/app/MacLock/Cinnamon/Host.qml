pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected: true
        parser: SplitParser { onRead: data => {} }
    }
    function send(op,arg){
        if(!channel.connected){channel.connected=true;return}
        channel.write(JSON.stringify({op:op,arg:arg})+"\n");channel.flush()
    }
    function execDetached(args){send("exec",args)}
    function launchDesktop(id){send("launch",id)}
}
