import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: sync
    required property var bar
    function refresh(){if(channel.connected && bar.settingsReady && Date.now()>=bar.nativeInputDirtyUntil){channel.write('{"op":"mint-settings","arg":{"action":"input"}}\n');channel.flush();}}
    property Socket channel: Socket {
        path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected:true
        onConnectedChanged:if(connected)sync.refresh()
        parser:SplitParser {onRead:text=>{try{var r=JSON.parse(text);if(!r.ok || !sync.bar.settingsReady || Date.now()<sync.bar.nativeInputDirtyUntil)return;sync.bar.mintInputSync=true;for(var key in r.value)if(sync.bar[key]!==r.value[key])sync.bar[key]=r.value[key];sync.bar.mintInputReady=true;sync.bar.mintInputSync=false;}catch(e){sync.bar.mintInputSync=false;}}}
    }
    property Timer poll:Timer {interval:2000;running:true;repeat:true;onTriggered:sync.refresh()}
}
