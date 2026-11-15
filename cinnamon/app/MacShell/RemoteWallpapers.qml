import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    id: remote
    property var entries: []
    property bool busy: false
    property string phase: ""
    property string pendingId: ""
    property string error: ""
    signal selected(string path)
    function send(action,id) {
        if(busy || !channel.connected)return;
        busy=true;phase=action;pendingId=id||"";error="";
        channel.write(JSON.stringify({op:"wallpaper-catalog",arg:{action:action,id:id}})+"\n");channel.flush();
    }
    function choose(id){send("download",id);}
    function refresh(){send("refresh","");}
    property Socket channel: Socket {
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected: true
        onConnectedChanged: if(connected)remote.send("list","");else {remote.busy=false;remote.error="Wallpaper service disconnected. Reopen Settings to retry.";}
        parser: SplitParser { onRead: text=>{
            try {
                var r=JSON.parse(text);remote.busy=false;
                if(!r.ok){remote.error=r.error;remote.phase="";return;}
                if(Array.isArray(r.value))remote.entries=r.value.map(e=>({id:e.id,path:"cloud:"+e.id,name:e.name,thumb:e.thumb,fav:false,video:false,preview:"",remote:true,author:e.author,downloaded:e.downloaded,localPath:e.localPath||""}));
                else {
                    var id=remote.pendingId,path=r.value;
                    remote.entries=remote.entries.map(e=>e.id===id?Object.assign({},e,{downloaded:true,localPath:path}):e);
                    remote.selected(path);
                }
                remote.phase="";remote.pendingId="";
            }catch(e){remote.busy=false;remote.phase="";remote.error="Download failed. Select the wallpaper to retry.";}
        }}
    }
}
