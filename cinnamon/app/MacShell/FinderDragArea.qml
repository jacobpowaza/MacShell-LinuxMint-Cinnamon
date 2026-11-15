import QtQuick
import Quickshell
Item{
    id:area
    required property var finder
    required property var entry
    required property int rowIndex
    Rectangle{anchors.fill:parent;anchors.margins:2;radius:8;visible:folderDrop.containsDrag;color:"#300a84ff";border.width:2;border.color:area.finder.accent}
    Item{
        id:proxy;width:64;height:64;visible:false
        Drag.active:dragMouse.drag.active
        Drag.dragType:Drag.Automatic
        Drag.supportedActions:area.entry.application?Qt.CopyAction:Qt.CopyAction|Qt.MoveAction
        Drag.proposedAction:area.entry.application?Qt.CopyAction:Qt.MoveAction
        Drag.mimeData:({"text/uri-list":area.finder.dragUris()})
        Drag.imageSource:Quickshell.iconPath(area.finder.icon(area.entry))
        Drag.imageSourceSize:Qt.size(64,64)
        Drag.hotSpot.x:20;Drag.hotSpot.y:20
        Drag.onDragStarted:area.finder.dragging=true
        Drag.onDragFinished:{area.finder.dragging=false;proxy.x=0;proxy.y=0;}
    }
    MouseArea{
        id:dragMouse;anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton
        preventStealing:true
        drag.target:!(pressedButtons & Qt.LeftButton)?null:proxy
        drag.threshold:8
        property bool preparedSelection:false
        onPressed:m=>{preparedSelection=false;if(m.button===Qt.LeftButton && !area.finder.selected[area.entry.path]){area.finder.select(area.rowIndex,m.modifiers);preparedSelection=true;}}
        onClicked:m=>{if(m.button===Qt.RightButton){var p=mapToGlobal(m.x,m.y);area.finder.contextFor(area.rowIndex,p.x,p.y);}else if(!preparedSelection)area.finder.select(area.rowIndex,m.modifiers);}
        onDoubleClicked:area.finder.activate(area.entry)
        onCanceled:{proxy.x=0;proxy.y=0;area.finder.dragging=false;}
    }
    DropArea{
        id:folderDrop;anchors.fill:parent;enabled:area.entry.directory
        onEntered:drag=>{drag.accepted=drag.hasUrls;}
        onDropped:drop=>{if(drop.hasUrls){area.finder.dropUrls(drop.urls,area.entry.path,drop.proposedAction===Qt.CopyAction);drop.acceptProposedAction();}}
    }
}
