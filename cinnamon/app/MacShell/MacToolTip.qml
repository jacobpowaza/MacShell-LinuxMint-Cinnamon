import QtQuick
import QtQuick.Controls
ToolTip {
    id: tip
    property bool dark: true
    property bool reduceMotion: false
    property string family: "SF Pro Text"
    enter: Transition { NumberAnimation { property:"opacity"; from:0; to:1; duration:tip.reduceMotion?40:120 } }
    exit: Transition { NumberAnimation { property:"opacity"; to:0; duration:tip.reduceMotion?40:80 } }
    delay: 550
    padding: 7
    font.family: family
    font.pixelSize: 12
    contentItem: Text { text: tip.text; font: tip.font; color: tip.dark ? "#f5f5f7" : "#1d1d1f"; wrapMode: Text.Wrap }
    background: Rectangle { color: tip.dark ? "#38383b" : "#f1f1f3"; radius: 8; border.width: 1; border.color: tip.dark ? "#30ffffff" : "#22000000" }
}
