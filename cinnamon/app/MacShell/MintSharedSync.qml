import QtQuick
import Quickshell
import Quickshell.Io
QtObject{
    id:sync
    required property var bar
    property bool applying:false
    property bool ready:false
    property double dirtyUntil:0
    property var last:({})
    readonly property string signature:[bar.showDate,bar.showSeconds,bar.use24h,bar.reduceMotion,bar.nightOn,bar.nightTemp,bar.notifDnd,bar.fontFamily,bar.darkMode].join("|")
    onSignatureChanged:if(ready && !applying && bar.settingsReady){dirtyUntil=Date.now()+600;commit.restart();}
    function read(){if(channel.connected && bar.settingsReady){channel.write('{"op":"mint-settings","arg":{"action":"shared"}}\n');channel.flush();}}
    property Timer commit:Timer{interval:150;onTriggered:{
        var values={};for(var k in sync.last)if(sync.bar[k]!==sync.last[k])values[k]=sync.bar[k];
        if(Object.keys(values).length){sync.channel.write(JSON.stringify({op:"mint-settings",arg:{action:"shared-write",values:values}})+"\n");sync.channel.flush();}
    }}
    property Timer poll:Timer{interval:2000;running:true;repeat:true;onTriggered:if(!sync.commit.running)sync.read()}
    property Socket channel:Socket{
        path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true
        onConnectedChanged:if(connected)sync.read()
        parser:SplitParser{onRead:text=>{try{var r=JSON.parse(text);if(!r.ok || !sync.bar.settingsReady || Date.now()<sync.dirtyUntil)return;sync.applying=true;if(r.value.darkMode!==sync.bar.darkMode)sync.bar.setAppearance(r.value.darkMode?"dark":"light");for(var k in r.value)sync.bar[k]=r.value[k];sync.last=r.value;sync.ready=true;sync.applying=false;}catch(e){sync.applying=false;}}}
    }
}
