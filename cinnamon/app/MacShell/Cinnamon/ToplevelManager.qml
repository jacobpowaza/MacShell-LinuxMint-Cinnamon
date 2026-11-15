pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: manager
    property QtObject toplevels: QtObject { property var values: [] }
    property var activeToplevel: null
    property var registry: ({})
    property var state: ({clients:[],monitors:[],workspaces:[]})
    property string last: ""
    property Component factory: Component {
        QtObject {
            id: window
            property int wid: 0
            property string appId: ""
            property string title: ""
            property bool activated: false
            property bool minimized: false
            property bool maximized: false
            property bool fullscreen: false
            property var screens: []
            property var lastIpcObject: ({})
            property string address: Number(wid).toString(16)
            property var wayland: window
            function activate() { manager.send("activate",wid) }
            function close() { manager.send("close",wid) }
            function minimize() { manager.send("minimize",wid) }
        }
    }
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected: true
        parser: SplitParser { onRead: data => {} }
    }
    function send(op,arg) {
        if(!channel.connected){channel.connected=true;return}
        channel.write(JSON.stringify({op:op,arg:arg})+"\n");channel.flush()
    }
    function apply(text) {
        if(text===last) return
        last=text
        var d
        try {d=JSON.parse(text)}catch(e){return}
        var list=[], active=null, ids=[]
        for(var i=0;i<d.clients.length;i++) {
            var w=d.clients[i], id=String(w.wid), item=registry[id]
            if(!item){ item=factory.createObject(manager); registry[id]=item }
            item.wid=w.wid; item.appId=w.class; item.title=w.title
            item.activated=w.activated; item.minimized=w.minimized; item.fullscreen=w.fullscreen!==0
            item.lastIpcObject=w
            list.push(item); ids.push(id)
            if(w.activated) active=item
        }
        activeToplevel=active
        var prior=toplevels.values.map(x=>String(x.wid)).join(",")
        if(prior!==ids.join(",")) toplevels.values=list
        for(var key in registry) if(ids.indexOf(key)<0){registry[key].destroy();delete registry[key]}
        state=d
    }
    property FileView file: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/state.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: manager.apply(text())
        printErrors: false
    }
    property Timer poll: Timer {interval:350;running:true;repeat:true;onTriggered:manager.file.reload()}
}
