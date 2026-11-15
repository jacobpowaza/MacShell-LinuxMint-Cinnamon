// Widget-local glass menu: animate its surface, keeping Qt popup grabs out of
// the desktop editor's multi-window focus lifecycle.
import QtQuick
import QtQuick.Window
import Quickshell
import "Cinnamon" as Cinnamon
import "Symbols.js" as Symbols
Scope {
    id:menu
    property var rows:[]
    property bool dark:true
    property bool reduceMotion:false
    property string family:"SF Pro Text"
    property bool visible:false
    property alias x:window.x
    property alias y:window.y
    readonly property int shadowPad:48
    readonly property int bodyHeight:rows.reduce((n,r)=>n+(r.separator?11:22),0)+10
    property int restoreWindow:0
    signal triggered(var entry)
    function show(items,gx,gy){
        hideLater.stop();rows=items;restoreWindow=Cinnamon.ToplevelManager.state.active||0;
        var screens=Quickshell.screens,s=screens.find(s=>gx>=s.x&&gx<s.x+s.width&&gy>=s.y&&gy<s.y+s.height)||screens[0];
        window.x=Math.max(s.x+8,Math.min(s.x+s.width-252,gx))-48;
        window.y=Math.max(s.y+34,Math.min(s.y+s.height-bodyHeight-12,gy))-48;
        window.hadActive=false;visible=true;window.requestActivate();focusLater.restart();
    }
    function close(){if(!visible)return;visible=false;hideLater.restart();}
    Timer{id:hideLater;interval:menu.reduceMotion?1:120;onTriggered:Cinnamon.Host.send("popup-restore","MacShell Context Menu")}
    Timer{id:focusLater;interval:40;onTriggered:if(menu.visible){Cinnamon.Host.send("popup-focus",{title:"MacShell Context Menu",previous:menu.restoreWindow});surface.forceActiveFocus();}}
    Window {
        id:window;title:"MacShell Context Menu";width:340;height:menu.bodyHeight+96;color:"transparent"
        visible:menu.visible||hideLater.running
        flags:Qt.ToolTip|Qt.FramelessWindowHint|Qt.WindowStaysOnTopHint
        property bool hadActive:false
        onActiveChanged:{if(active)hadActive=true;else if(hadActive && menu.visible)menu.close();}
        Item {
            id:surface;anchors.fill:parent;focus:true;opacity:menu.visible?1:0
            scale:menu.visible?1:0.96;transformOrigin:Item.TopLeft
            Behavior on opacity{NumberAnimation{duration:menu.reduceMotion?0:menu.visible?160:110;easing.type:Easing.OutCubic}}
            Behavior on scale{NumberAnimation{duration:menu.reduceMotion?0:200;easing.type:Easing.OutCubic}}
            Keys.onEscapePressed:event=>{menu.close();event.accepted=true;}
            // Capture-only source: never paint the rectangular window-sized image.
            Item{id:backdrop;anchors.fill:parent;CinnamonFrost{anchors.fill:parent;window:window}}
            DockGlassPanel{x:48;y:48;width:244;bodyH:menu.bodyHeight;backdrop:backdrop;hideBackdrop:true;live:true;dark:menu.dark;radius:11;k:1;tailW:0;tailH:0}
            Column{x:53;y:53;width:234
                Repeater{model:menu.rows
                    Item{
                        id:row;required property var modelData;width:234;height:modelData.separator?11:22
                        Rectangle{visible:!!row.modelData.separator;x:10;y:5;width:214;height:1;color:menu.dark?"#26ffffff":"#24000000"}
                        Rectangle{anchors.fill:parent;anchors.topMargin:1;anchors.bottomMargin:1;radius:6;visible:!row.modelData.separator;color:hover.hovered?"#087df4":"transparent";Behavior on color{ColorAnimation{duration:menu.reduceMotion?0:100}}}
                        SFIcon{visible:!row.modelData.separator;x:10;anchors.verticalCenter:parent.verticalCenter;width:16;height:16;name:row.modelData.icon||Symbols.forLabel(row.modelData.label||"");color:hover.hovered?"white":menu.dark?"#ebebf2":"#38383e"}
                        Text{visible:!row.modelData.separator;x:33;width:180;anchors.verticalCenter:parent.verticalCenter;text:row.modelData.label||"";font.family:menu.family;font.pixelSize:13;color:hover.hovered?"white":row.modelData.danger?(menu.dark?"#ffaaa3":"#c43329"):menu.dark?"#efeff5":"#26262b"}
                        SFIcon{visible:!!row.modelData.checked;anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;width:12;height:12;name:"checkmark";color:hover.hovered?"white":menu.dark?"#ebebf2":"#38383e"}
                        HoverHandler{id:hover;enabled:!row.modelData.separator}
                        TapHandler{enabled:!row.modelData.separator;onTapped:{menu.close();menu.triggered(row.modelData);}}
                    }
                }
            }
        }
    }
}
