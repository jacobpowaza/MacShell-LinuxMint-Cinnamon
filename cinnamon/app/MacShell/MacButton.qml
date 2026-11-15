import QtQuick
import QtQuick.Controls
Button {
    id:control
    property bool dark:true
    property bool reduceMotion:false
    scale:down?0.97:1
    Behavior on scale{NumberAnimation{duration:control.reduceMotion?0:120;easing.type:Easing.OutCubic}}
    property string family:"SF Pro Text"
    font.family:family;font.pixelSize:13
    implicitHeight:30
    implicitWidth:Math.max(64,contentItem.implicitWidth+28)
    padding:7
    contentItem:Text{text:control.text;font:control.font;color:!control.enabled?(control.dark?"#85858b":"#94949a"):control.highlighted?"white":control.dark?"#f5f5f7":"#202023";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
    background:MacGlassButtonSurface{dark:control.dark;role:control.highlighted?"accent":"neutral";cornerRadius:8;hovered:control.hovered;pressed:control.down;focused:control.visualFocus;enabled:control.enabled;reduceMotion:control.reduceMotion}
}
