import QtQuick
import Quickshell
import Quickshell.Io
Image {
 id: frost
 required property var window
 property string frostId: String(Date.now())+"-"+String(Math.random()).slice(2)
 property int revision:0
 property bool busy:false
 onWindowChanged:Qt.callLater(refresh)
 cache:false
 smooth:true
 function refresh(){
  if(!window || !visible || busy || !channel.connected)return
  busy=true
  var p=mapToGlobal(0,0),end=mapToGlobal(width,height)
  channel.write(JSON.stringify({op:"frost",arg:{x:Math.round(p.x),y:Math.round(p.y),width:Math.round(end.x-p.x),height:Math.round(end.y-p.y),exclude:window.title,key:frostId,excludeRect:[window.x,window.y,window.width,window.height]}})+"\n");channel.flush()
 }
 Timer {interval:600;repeat:true;running:!!frost.window && frost.window.visible && frost.window.active;onTriggered:frost.refresh()}
 Connections {target:frost.window;function onActiveChanged(){if(frost.window && frost.window.active)frost.refresh()}}
 Socket {
  id:channel
  connected:true
  path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
  onConnectedChanged: {frost.busy=false;if(connected)frost.refresh()}
  parser:SplitParser {onRead:data=>{frost.busy=false;try{var d=JSON.parse(data);if(d.ok && d.value)frost.source="file://"+d.value+"?v="+(++frost.revision)}catch(e){}}}
 }
}
