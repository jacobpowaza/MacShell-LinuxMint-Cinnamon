import QtQuick
import QtQuick.Controls
ComboBox{
    id:control
    property bool dark:true
    property bool reduceMotion:false
    property string family:"SF Pro Text"
    implicitHeight:32
    font.family:family;font.pixelSize:13
    leftPadding:10;rightPadding:28
    contentItem:TextField{
        text:control.editable?control.editText:control.displayText
        font:control.font;color:control.dark?"#f5f5f7":"#202023"
        readOnly:!control.editable;selectByMouse:control.editable
        background:null;padding:0;verticalAlignment:Text.AlignVCenter
        onTextEdited:control.editText=text
    }
    indicator:Canvas{x:control.width-21;y:(control.height-height)/2;width:11;height:8;onPaint:{var c=getContext("2d");c.reset();c.strokeStyle=control.dark?"#eeeeF1":"#303036";c.lineWidth=1.5;c.beginPath();c.moveTo(1,2);c.lineTo(5.5,6);c.lineTo(10,2);c.stroke();}}
    background:Rectangle{radius:8;color:control.dark?"#3b3b41":"#ffffff";border.width:control.activeFocus?2:1;border.color:control.activeFocus?"#0a84ff":control.dark?"#24ffffff":"#29000000"}
    delegate:ItemDelegate{
        width:control.popup.width;height:28;highlighted:control.highlightedIndex===index
        contentItem:Text{text:control.textRole?modelData[control.textRole]:modelData;font:control.font;color:parent.highlighted?"white":control.dark?"#f5f5f7":"#202023";verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
        background:Rectangle{radius:6;color:parent.highlighted?"#087df4":"transparent"}
    }
    popup:Popup{
        transformOrigin:Popup.Top
        enter:Transition{ParallelAnimation{NumberAnimation{property:"opacity";from:0;to:1;duration:control.reduceMotion?50:120}NumberAnimation{property:"scale";from:control.reduceMotion?1:0.96;to:1;duration:control.reduceMotion?0:200;easing.type:Easing.OutQuint}}}
        exit:Transition{NumberAnimation{property:"opacity";to:0;duration:control.reduceMotion?40:90}}
        y:control.height+4;width:control.width;padding:5
        implicitHeight:Math.min(280,contentItem.implicitHeight+10)
        contentItem:ListView{clip:true;implicitHeight:contentHeight;model:control.popup.visible?control.delegateModel:null;currentIndex:control.highlightedIndex;ScrollIndicator.vertical:ScrollIndicator{}}
        background:Rectangle{radius:10;color:control.dark?"#2b2b2e":"#f6f6f8";border.width:1;border.color:control.dark?"#38ffffff":"#29000000"}
    }
}
