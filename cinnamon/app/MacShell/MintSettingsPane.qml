import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Cinnamon" as Cinnamon

Column {
    id: pane
    property bool dark:true
    property string family:"SF Pro Text"
    property color fg:dark?"#f5f5f7":"#202023"
    property color secondary:dark?"#b0b0b5":"#66666c"
    property var panels:[]
    property var schemas:[]
    property var rows:[]
    property string schema:""
    property string error:""
    property string pending:"list"
    spacing:16
    function send(arg){pending=arg.action;channel.write(JSON.stringify({op:"mint-settings",arg:arg})+"\n");channel.flush();}
    function read(){if(schema)send({action:"read",schema:schema});}
    function write(key,value){send({action:"write",schema:schema,key:key,value:value});}
    Socket {
        id:channel
        path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true
        onConnectedChanged:if(connected)pane.send({action:"list"})
        parser:SplitParser{onRead:text=>{try{var r=JSON.parse(text);if(!r.ok){pane.error=r.error;return;}pane.error="";if(r.value.panels){pane.panels=r.value.panels;pane.schemas=r.value.schemas.map(s=>({schema:s,label:s.replace(/^org\.cinnamon\./, "").replace(/^desktop\./, "").replace(/\./g," · ").replace(/-/g," ").replace(/(^|[ ·])\w/g,c=>c.toUpperCase())}));}else if(JSON.stringify(pane.rows)!==JSON.stringify(r.value))pane.rows=r.value;}catch(e){pane.error="Unable to read system preferences";}}}
    }
    Timer{interval:2000;running:pane.visible && pane.schema!=="";repeat:true;onTriggered:pane.read()}
    Text{text:"Linux Mint";font.family:pane.family;font.pixelSize:22;font.weight:Font.DemiBold;color:pane.fg}
    Text{width:parent.width;text:"Your installed system settings. Changes use Cinnamon’s live preferences and stay in sync with Mint.";font.family:pane.family;font.pixelSize:13;color:pane.secondary;wrapMode:Text.WordWrap}
    MacTextField{dark:pane.dark;family:pane.family;id:search;width:parent.width;placeholderText:"Search system settings";font.family:pane.family}
    Column {
        width:parent.width;spacing:1
        Repeater{
            model:pane.panels.filter(p=>!search.text || (p.name+" "+p.description).toLowerCase().includes(search.text.toLowerCase()))
            Rectangle {
                required property var modelData
                width:parent.width;height:54;radius:8;color:panelHover.hovered?(pane.dark?"#38383d":"#e5e5e9"):(pane.dark?"#29292d":"#ffffff")
                Image{x:14;y:12;width:30;height:30;source:Quickshell.iconPath(modelData.icon)}
                Text{x:58;y:10;width:parent.width-86;text:modelData.name;color:pane.fg;font.family:pane.family;font.pixelSize:13;elide:Text.ElideRight}
                Text{x:58;y:30;width:parent.width-86;text:modelData.description;color:pane.secondary;font.family:pane.family;font.pixelSize:11;elide:Text.ElideRight}
                HoverHandler{id:panelHover}
                TapHandler{onTapped:Cinnamon.Host.launchDesktop(modelData.id)}
                Accessible.role:Accessible.Button;Accessible.name:modelData.name
            }
        }
    }
    Text{text:"Cinnamon preferences";color:pane.fg;font.family:pane.family;font.pixelSize:17;font.weight:Font.DemiBold}
    Text{width:parent.width;text:"Edit real system preferences below. Values also update when changed in another settings window.";color:pane.secondary;font.family:pane.family;font.pixelSize:12;wrapMode:Text.WordWrap}
    MacComboBox{dark:pane.dark;family:pane.family;id:schemaPicker;width:parent.width;model:pane.schemas;textRole:"label";font.family:pane.family;displayText:currentIndex>=0 && pane.schema?pane.schemas[currentIndex].label:"Choose a preferences category";onActivated:{pane.schema=pane.schemas[currentIndex].schema;pane.read();}}
    Repeater{
        model:pane.rows.filter(r=>!search.text||(r.name+" "+r.key+" "+r.description).toLowerCase().includes(search.text.toLowerCase()))
        Column{
            id:setting
            required property var modelData
            width:pane.width;spacing:7
            Text{width:parent.width;text:setting.modelData.name;color:pane.fg;font.family:pane.family;font.pixelSize:13;wrapMode:Text.WordWrap}
            Text{width:parent.width;visible:text!=="";text:setting.modelData.description;color:pane.secondary;font.family:pane.family;font.pixelSize:11;wrapMode:Text.WordWrap;maximumLineCount:3;elide:Text.ElideRight}
            Loader{
                width:parent.width
                sourceComponent:setting.modelData.type==="b"?boolControl:setting.modelData.range[0]==="enum"?enumControl:valueControl
            }
            Component{id:boolControl;Switch{checked:setting.modelData.value;enabled:setting.modelData.writable;onToggled:pane.write(setting.modelData.key,checked)}}
            Component{id:enumControl;MacComboBox{dark:pane.dark;family:pane.family;width:setting.width;model:setting.modelData.range[1];currentIndex:model.indexOf(setting.modelData.value);enabled:setting.modelData.writable;onActivated:pane.write(setting.modelData.key,currentText)}}
            Component{id:valueControl;RowLayout{
                width:setting.width
                MacTextField{dark:pane.dark;family:pane.family;id:valueInput;Layout.fillWidth:true;enabled:setting.modelData.writable && setting.modelData.type!=="a{sv}";text:typeof setting.modelData.value==="string"?setting.modelData.value:JSON.stringify(setting.modelData.value);font.family:pane.family;selectByMouse:true}
                MacButton{dark:pane.dark;family:pane.family;text:"Apply";enabled:setting.modelData.writable && setting.modelData.type!=="a{sv}";onClicked:{try{var v=setting.modelData.type==="s"?valueInput.text:JSON.parse(valueInput.text);pane.write(setting.modelData.key,v);}catch(e){pane.error="Enter a valid value for "+setting.modelData.name;}}}
            }}
            Item{width:1;height:8}
        }
    }
    Text{width:parent.width;text:pane.error;visible:text!=="";color:pane.dark?"#ffb4ac":"#b42318";font.family:pane.family;font.pixelSize:12;wrapMode:Text.WordWrap}
}
