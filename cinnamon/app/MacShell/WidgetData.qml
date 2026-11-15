import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: data
    required property var host
    property bool enabled:true
    property string type: "clock"
    property string city: ""
    property string timezone: ""
    property var weather: null
    property real offset: -new Date().getTimezoneOffset()*60
    property string label: "Local"
    property string error: ""
    property bool busy: false
    function refresh() {
        if (!enabled || !channel.connected || busy) return;
        busy=true;
        channel.write(JSON.stringify({op:"widget-data",arg:{type:type,city:city,timezone:timezone,unit:host.tempUnit}})+"\n");channel.flush();
    }
    property Connections units:Connections{target:data.host;function onTempUnitChanged(){data.refreshSoon.restart();}}
    onCityChanged: refreshSoon.restart()
    onTimezoneChanged: refreshSoon.restart()
    property Timer refreshSoon: Timer {interval:300;onTriggered:data.refresh()}
    property Timer clock: Timer {interval:60000;running:data.enabled;repeat:true;onTriggered:data.refresh()}
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected:data.enabled
        onConnectedChanged: {data.busy=false;if(connected)data.refresh();}
        parser:SplitParser {onRead: text=>{
            data.busy=false;
            try{var r=JSON.parse(text);if(!r.ok){data.error=r.error;return;}data.offset=r.value.offset;data.label=r.value.city;data.weather=r.value.weather||null;data.error=r.value.error||"";}catch(e){data.error="Unable to load widget data";}
        }}
    }
}
