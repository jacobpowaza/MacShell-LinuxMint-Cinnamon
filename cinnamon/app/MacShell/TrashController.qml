import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: trash
    property string path: Quickshell.env("HOME")+"/.local/share/Trash/files"
    property int count: 0
    property bool busy: false
    property string pending: ""
    property string error: ""
    signal emptied()
    function send(action){if(pending || !channel.connected)return;pending=action;busy=action!=="trash-state";error="";channel.write(JSON.stringify({op:"filesystem",arg:{action:action}})+"\n");channel.flush();}
    function refresh(){send("trash-state");}
    function empty(){send("empty-trash");}
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected: true
        onConnectedChanged: if(connected)trash.refresh();else {trash.pending="";trash.busy=false;}
        parser: SplitParser { onRead: text=>{
            var action=trash.pending;trash.pending="";trash.busy=false;
            try {var r=JSON.parse(text);if(!r.ok){trash.error=r.error;return;}trash.path=r.value.path;trash.count=r.value.count;if(action==="empty-trash")trash.emptied();}
            catch(e){trash.error="Trash could not be updated. Try again.";}
        }}
    }
    property Timer poll: Timer { interval: 2000;running: true;repeat: true;onTriggered: trash.refresh() }
}
