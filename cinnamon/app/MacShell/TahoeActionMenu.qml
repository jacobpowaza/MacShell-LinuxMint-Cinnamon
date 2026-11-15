import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "Cinnamon" as Cinnamon
Menu{
    id:menu
    property var rows:[]
    property var menuEntry:({})
    property bool dark:true
    property bool reduceMotion:false
    property string family:"SF Pro Text"
    property var generated:[]
    property bool destroying:false
    property int restoreWindow:0
    property bool focusSent:false
    onClosed:{focusSent=false;Cinnamon.Host.send("popup-restore",windowTitle);}
    property string windowTitle:"MacShell Context Menu"
    signal chosen(var entry)
    popupType:Popup.Window
    focus:true
    padding:5
    margins:8
    implicitWidth:244
    implicitHeight:Math.min(490,rows.reduce((n,r)=>n+(r.separator?11:22),0)+10)
    topInset:-48;bottomInset:-48;leftInset:-48;rightInset:-48
    closePolicy:Popup.CloseOnEscape|Popup.CloseOnPressOutside|Popup.CloseOnReleaseOutside
    function rebuild(){
        if(destroying)return;
        for(var g=0;g<generated.length;g++){var obj=generated[g];if(obj && obj.menuEntry)removeMenu(obj);}
        while(count)takeItem(0);
        for(var i=0;i<generated.length;i++)if(generated[i])generated[i].destroy();generated=[];
        for(var j=0;j<rows.length;j++){
            var row=rows[j];
            if(row.separator){var sep=separatorFactory.createObject(menu.contentItem);addItem(sep);generated.push(sep);continue;}
            if(row.children){
                var factory=Qt.createComponent(Qt.resolvedUrl("TahoeActionMenu.qml"));
                var child=factory.createObject(menu,{title:row.label,rows:row.children,menuEntry:row,dark:dark,family:family,reduceMotion:reduceMotion,windowTitle:windowTitle+" Submenu"});
                child.chosen.connect(function(entry){menu.chosen(entry);menu.dismiss();});addMenu(child);generated.push(child);
            }else{var item=itemFactory.createObject(menu.contentItem,{entry:row,text:row.label||"",enabled:!row.disabled});addItem(item);generated.push(item);}
        }
    }
    transformOrigin: Popup.TopLeft
    enter: Transition { ParallelAnimation {
        NumberAnimation { property:"opacity"; from:0; to:1; duration:menu.reduceMotion?60:120 }
        NumberAnimation { property:"scale"; from:menu.reduceMotion?1:0.97; to:1; duration:menu.reduceMotion?0:190; easing.type:Easing.OutQuint }
    }}
    exit: Transition { NumberAnimation { property:"opacity"; to:0; duration:menu.reduceMotion?40:90 } }
    onAboutToShow:focusSent=false
    onOpened:contentItem.forceActiveFocus()
    Timer{id:rebuildLater;interval:0;onTriggered:menu.rebuild()}
    onRowsChanged:rebuildLater.restart()
    Component.onCompleted:rebuildLater.restart()
    Component.onDestruction:{destroying=true;rebuildLater.stop();}
    Component{id:itemFactory;MacMenuItem{reduceMotion:menu?menu.reduceMotion:false;dark:menu?menu.dark:true;family:menu?menu.family:"SF Pro Text";onTriggered:if(menu){menu.chosen(entry);menu.dismiss();}}}
    Component{id:separatorFactory;MenuSeparator{implicitHeight:11;padding:0;leftPadding:10;rightPadding:10;topPadding:5;bottomPadding:5;contentItem:Rectangle{implicitHeight:1;color:menu.dark?"#26ffffff":"#24000000"}}}
    delegate:MacMenuItem{reduceMotion:menu?menu.reduceMotion:false;dark:menu?menu.dark:true;family:menu?menu.family:"SF Pro Text"}
    contentItem:ListView{
        id:list;focus:true
        Keys.onEscapePressed:event=>{menu.dismiss();event.accepted=true;}
        implicitHeight:contentHeight;model:menu.contentModel;currentIndex:menu.currentIndex;clip:true
        interactive:contentHeight>height;boundsBehavior:Flickable.StopAtBounds
        LiquidScrollBar{flick:list;anchors{right:parent.right;top:parent.top;bottom:parent.bottom}dark:menu.dark}
    }
    background:Item{
        id:bg
        Item{id:backdrop;anchors.fill:parent;CinnamonFrost{anchors.fill:parent;window:menu.contentItem.Window.window}}
        DockGlassPanel{x:48;y:48;width:parent.width-96;bodyH:parent.height-96;backdrop:backdrop;hideBackdrop:true;live:true;dark:menu.dark;radius:11;k:1;tailW:0;tailH:0}
    }
    Connections{
        target:menu.contentItem.Window.window
        function onActiveChanged(){var w=menu.contentItem.Window.window;if(w && !w.active && menu.visible && !menu.generated.some(child=>child && child.menuEntry && child.visible))menu.dismiss();}
        function onVisibleChanged(){var w=menu.contentItem.Window.window;if(w && !w.visible && menu.visible)menu.dismiss();}
    }
    Timer{interval:40;running:menu.visible;repeat:true;onTriggered:{var w=menu.contentItem.Window.window;if(w){if(w.title!==menu.windowTitle)w.title=menu.windowTitle;if(!menu.focusSent){Cinnamon.Host.send("popup-focus",{title:menu.windowTitle,previous:menu.restoreWindow});menu.contentItem.forceActiveFocus();menu.focusSent=true;}}}}
}
