import QtQuick
import QtQuick.Controls
import "Symbols.js" as Symbols
MenuItem{
    id:row
    property var entry:subMenu && subMenu.menuEntry?subMenu.menuEntry:({})
    property bool dark:true
    property bool reduceMotion:false
    property string family:"SF Pro Text"
    implicitHeight:22
    font.family:family;font.pixelSize:13
    padding:0
    contentItem:Item{
        implicitWidth:220;implicitHeight:22
        SFIcon{x:10;anchors.verticalCenter:parent.verticalCenter;width:16;height:16;visible:!row.entry.dot;name:row.entry.icon||Symbols.forLabel(row.text);color:row.highlighted?"white":row.dark?"#ebebf2":"#38383e";opacity:row.enabled?1:0.4}
        Rectangle{x:13;anchors.verticalCenter:parent.verticalCenter;width:10;height:10;radius:5;visible:!!row.entry.dot;color:row.entry.dot||"transparent"}
        Text{x:33;width:parent.width-54;anchors.verticalCenter:parent.verticalCenter;text:row.text;font:row.font;elide:Text.ElideRight;color:!row.enabled?(row.dark?"#85858d":"#9999a0"):row.highlighted?"white":row.entry.danger?(row.dark?"#ffaaa3":"#c43329"):row.dark?"#efeff5":"#26262b"}
        SFIcon{anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;width:12;height:12;name:row.subMenu?"chevron.right":row.entry.checked?"checkmark":"";color:row.highlighted?"white":row.dark?"#ebebf2":"#38383e"}
    }
    arrow:Item{visible:false}
    indicator:Item{visible:false}
    background:Rectangle{Behavior on color{ColorAnimation{duration:row.reduceMotion?0:100}} radius:6;anchors.fill:parent;anchors.topMargin:1;anchors.bottomMargin:1;color:row.highlighted&&row.enabled?"#087df4":"transparent"}
}
