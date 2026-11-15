// Shared desktop-glass menu using Qt's native popup focus and dismissal lifecycle.
import QtQuick
import QtQuick.Window
import Quickshell
import "Cinnamon" as Cinnamon
Scope{
    id:bridge
    property var rows:[]
    property bool dark:true
    property bool reduceMotion:false
    property string family:"SF Pro Text"
    property alias visible:popup.visible
    property alias x:host.x
    property alias y:host.y
    readonly property int shadowPad:0
    readonly property int width:244
    readonly property int height:Math.min(490,rows.reduce((n,r)=>n+(r.separator?11:22),0)+10)
    signal triggered(var entry)
    signal dismissed()
    function show(items,gx,gy){
        popup.restoreWindow=Cinnamon.ToplevelManager.state.active||0;rows=items;
        var screens=Quickshell.screens,s=screens.find(s=>gx>=s.x&&gx<s.x+s.width&&gy>=s.y&&gy<s.y+s.height)||screens[0];
        host.x=Math.max(s.x+8,Math.min(s.x+s.width-width-8,gx));host.y=Math.max(s.y+34,Math.min(s.y+s.height-height-12,gy));
        host.visible=true;
        Qt.callLater(function(){popup.popup(host.contentItem,0,0);});
    }
    function diagnostics(){var w=popup.contentItem.Window.window;return {visible:popup.visible,focus:popup.focus,activeFocus:popup.activeFocus,itemFocus:popup.contentItem.focus,itemActiveFocus:popup.contentItem.activeFocus,windowActive:w?w.active:false,hostActive:host.active,currentIndex:popup.currentIndex};}
    function close(){popup.close();}
    Window{id:host;title:"MacShell Context Menu Host";width:1;height:1;visible:false;color:"transparent";flags:Qt.Tool|Qt.FramelessWindowHint|Qt.WindowStaysOnTopHint}
    TahoeActionMenu{id:popup;reduceMotion:bridge.reduceMotion;parent:host.contentItem;rows:bridge.rows;dark:bridge.dark;family:bridge.family;onChosen:entry=>bridge.triggered(entry);onClosed:{host.visible=false;bridge.dismissed();}}
}
