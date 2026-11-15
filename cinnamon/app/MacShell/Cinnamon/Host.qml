pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: host
    property var pending: []
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected: true
        onConnectedChanged: if(connected)host.drain()
        parser: SplitParser { onRead: data => {} }
    }
    function drain(){
        var queue=pending;pending=[]
        for(var i=0;i<queue.length;i++) if(Date.now()-queue[i].at<2000){channel.write(queue[i].text+"\n")}
        channel.flush()
    }
    function send(op,arg){
        var text=JSON.stringify({op:op,arg:arg})
        if(!channel.connected){pending.push({at:Date.now(),text:text});channel.connected=true;return}
        channel.write(text+"\n");channel.flush()
    }
    function execDetached(args){send("exec",args)}
    function launchDesktop(id){send("launch",id)}
}
