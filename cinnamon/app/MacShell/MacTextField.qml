import QtQuick
import QtQuick.Controls
TextField{
    id:control
    property bool dark:true
    property string family:"SF Pro Text"
    font.family:family;font.pixelSize:13
    implicitHeight:32
    color:dark?"#f5f5f7":"#202023"
    placeholderTextColor:dark?"#ababB1":"#707077"
    selectionColor:"#087df4";selectedTextColor:"white"
    leftPadding:10;rightPadding:10
    background:Rectangle{radius:8;color:control.dark?"#343439":"#ffffff";border.width:control.activeFocus?2:1;border.color:control.activeFocus?"#0a84ff":control.dark?"#24ffffff":"#29000000"}
}
