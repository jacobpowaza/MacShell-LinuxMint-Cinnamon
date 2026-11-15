import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
Scope{
    id:info
    property var data:null
    property bool dark:true
    property string family:"SF Pro Text"
    function open(path){channel.write(JSON.stringify({op:"filesystem",arg:{action:"stat",path:path}})+"\n");channel.flush();}
    Socket{id:channel;path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true
        parser:SplitParser{onRead:text=>{try{var r=JSON.parse(text);if(!r.ok)return;info.data=r.value;win.visible=true;win.raise();win.requestActivate();}catch(e){}}}
    }
    Window{
        id:win;visible:false;width:330;height:430;color:"transparent";title:info.data?info.data.name+" Info":"Get Info"
        flags:Qt.Window|Qt.FramelessWindowHint
        Rectangle{anchors.fill:parent;radius:14;color:info.dark?"#29292d":"#f6f6f8";border.width:1;border.color:info.dark?"#32ffffff":"#24000000"}
        MouseArea{x:44;y:0;width:parent.width-44;height:44;onPressed:win.startSystemMove()}
        Rectangle{x:16;y:17;width:12;height:12;radius:6;color:"#ff5f57";TapHandler{onTapped:win.visible=false}}
        Text{x:42;y:15;width:parent.width-60;text:info.data?info.data.name+" Info":"Get Info";elide:Text.ElideMiddle;font.family:info.family;font.pixelSize:13;font.weight:Font.DemiBold;color:info.dark?"#f5f5f7":"#202023"}
        Column{x:20;y:62;width:parent.width-40;spacing:18
            Text{width:parent.width;text:info.data?info.data.name:"";wrapMode:Text.WordWrap;font.family:info.family;font.pixelSize:18;font.weight:Font.DemiBold;color:info.dark?"#f5f5f7":"#202023"}
            Repeater{model:info.data?[{label:"Kind",value:info.data.kind},{label:"Size",value:info.data.size.toLocaleString()+" bytes"},{label:"Where",value:info.data.path},{label:"Modified",value:Qt.formatDateTime(new Date(info.data.modified*1000),"d MMM yyyy, HH:mm")},{label:"Owner",value:info.data.owner+" · "+info.data.group},{label:"Permissions",value:info.data.permissions}]:[]
                Column{required property var modelData;width:parent.width;spacing:4
                    Text{text:modelData.label;font.family:info.family;font.pixelSize:11;color:info.dark?"#b0b0b7":"#66666d"}
                    Text{width:parent.width;text:modelData.value;wrapMode:Text.WrapAnywhere;font.family:info.family;font.pixelSize:12;color:info.dark?"#f5f5f7":"#202023"}
                }
            }
        }
        Shortcut{sequence:"Escape";onActivated:win.visible=false}
    }
}
