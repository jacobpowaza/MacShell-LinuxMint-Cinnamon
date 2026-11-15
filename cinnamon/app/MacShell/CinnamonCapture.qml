import QtQuick
import Quickshell
import Quickshell.Io
Image {
    id: view
    property var captureSource: null
    property bool live: false
    property string captureArea: ""
    property bool paintCursor: false
    readonly property bool hasContent: status === Image.Ready
    property int revision: 0
    property bool busy: false
    property string requestedArea: ""
    cache: false
    smooth: true
    function captureFrame(){
        if(busy || !captureSource)return
        if(!channel.connected){channel.connected=true;return}
        busy=true
        requestedArea=captureArea
        channel.write(JSON.stringify({op:captureSource.wid?"capture":"capture-screen",arg:captureSource.wid ? (captureArea ? {wid:captureSource.wid,area:captureArea} : captureSource.wid) : captureSource.name})+"\n");channel.flush()
    }
    onCaptureAreaChanged: captureFrame()
    onCaptureSourceChanged: { if(captureSource)captureFrame();else source="" }
    Timer {interval:140;running:view.live && view.captureSource!==null;repeat:true;onTriggered:view.captureFrame()}
    Socket {
        id: channel
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected: true
        onConnectedChanged: { view.busy=false;if(connected)view.captureFrame() }
        parser: SplitParser {
            onRead: data => {
                view.busy=false
                try{var reply=JSON.parse(data);if(reply.ok && reply.value)view.source="file://"+reply.value+"?frame="+(++view.revision)}catch(e){}
                if(view.requestedArea!==view.captureArea)view.captureFrame()
            }
        }
    }
}
