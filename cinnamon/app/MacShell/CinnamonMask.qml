import QtQuick
import QtQuick.Window
import Quickshell
import "Cinnamon" as Cinnamon
QtObject {
 id: bridge
 required property var host
 required property var region
 property var subtractRects: []
 property string tag: "MacShell Input "+Date.now()+" "+Math.random()
 function encode(r){
  var rect=[r.x,r.y,r.width,r.height]
  if(r.item){var p=r.item.mapToItem(host.contentItem,0,0,r.item.width,r.item.height);rect=[p.x,p.y,p.width,p.height]}
  var children=[]
  for(var i=0;i<r.regions.length;i++)children.push(encode(r.regions[i]))
  return {rect:rect,op:r.intersection,children:children}
 }
 property string lastRegion: ""
 property Timer timer: Timer {
  interval:50;running:bridge.host.visible;repeat:true
  onTriggered:{
   var w=bridge.host.contentItem.Window.window
   if(!w)return
   if(w.title!==bridge.tag)w.title=bridge.tag
   var region=bridge.encode(bridge.region);for(var i=0;i<bridge.subtractRects.length;i++){var r=bridge.subtractRects[i];region.children.push({rect:[r.x,r.y,r.width,r.height],op:1,children:[]});}var signature=JSON.stringify(region)
   if(signature===bridge.lastRegion)return
   bridge.lastRegion=signature
   Cinnamon.Host.send("input-region",{tag:bridge.tag,region:region})
  }
 }
}
