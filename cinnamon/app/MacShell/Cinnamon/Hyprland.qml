pragma Singleton
import QtQuick
import Quickshell
QtObject {
    id: hypr
    property var toplevels: ToplevelManager.toplevels
    property QtObject monitors: QtObject { property var values: [] }
    property QtObject workspaces: QtObject { property var values: [] }
    property var focusedMonitor: monitors.values.length ? monitors.values[0] : null
    property var focusedWorkspace: workspaces.values.length ? workspaces.values[0] : null
    property string monitorSignature: ""
    property string geometrySignature: ""
    property int lastActive: 0
    signal rawEvent(var event)
    function dispatch(s){ToplevelManager.send("dispatch",s)}
    function refreshToplevels(){}
    function refreshMonitors(){}
    function refreshWorkspaces(){}
    function monitorFor(screen){
        if(!screen)return focusedMonitor
        var name=screen.name
        for(var i=0;i<monitors.values.length;i++)if(monitors.values[i].name===name)return monitors.values[i]
        return focusedMonitor
    }
    property Connections sync: Connections {
        target: ToplevelManager
        function onStateChanged(){
            var d=ToplevelManager.state
            var monitorKey=JSON.stringify(d.monitors)
            if(monitorKey!==hypr.monitorSignature){
                hypr.monitorSignature=monitorKey
                hypr.monitors.values=d.monitors.map(m=>Object.assign({lastIpcObject:m},m))
            }
            hypr.workspaces.values=d.workspaces
            hypr.focusedMonitor=hypr.monitors.values.find(m=>m.focused)||hypr.monitors.values[0]||null
            hypr.focusedWorkspace=d.workspaces.find(w=>w.id===d.workspace)||null
            var geometry=monitorKey+JSON.stringify(d.clients.map(w=>[w.wid,w.at,w.size,w.workspace.id,w.hidden,w.fullscreen]))
            if(geometry!==hypr.geometrySignature){hypr.geometrySignature=geometry;hypr.rawEvent({name:"movewindow",data:""})}
            else if(d.active!==hypr.lastActive)hypr.rawEvent({name:"activewindowv2",data:String(d.active)})
            else hypr.rawEvent({name:"windowtitle",data:""})
            hypr.lastActive=d.active
        }
    }
}
