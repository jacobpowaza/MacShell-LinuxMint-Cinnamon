import QtQuick
import QtQuick.Controls

Menu {
    id: menu
    property bool dark: true
    property string family: "SF Pro Text"
    font.family: family
    font.pixelSize: 13
    padding: 5
    implicitWidth: 238
    margins: 8
    background: Rectangle {
        radius: 11
        color: menu.dark ? "#f02b2b2e" : "#f5f6f6f7"
        border.width: 1
        border.color: menu.dark ? "#38ffffff" : "#29000000"
        layer.enabled: true
    }
    delegate: MenuItem {
        id: row
        implicitHeight: 27
        font: menu.font
        contentItem: Text {
            text: row.text; font: row.font
            color: !row.enabled ? (menu.dark ? "#77777d" : "#94949a") : row.highlighted ? "white" : menu.dark ? "#f5f5f7" : "#202023"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 9; rightPadding: 9
        }
        background: Rectangle { radius: 6; color: row.highlighted && row.enabled ? "#087df4" : "transparent" }
    }
}
