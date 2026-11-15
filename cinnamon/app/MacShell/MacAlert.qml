// Shared macOS alert: content-driven sizing, stacked actions, native keyboard focus.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell

Dialog {
    id: alert
    property bool dark: true
    property bool reduceMotion: false
    property real elevation: 1
    property string family: "SF Pro Text"
    property string heading: ""
    property string message: ""
    property string iconName: "dialog-warning"
    property string actionText: "OK"
    property string cancelText: ""
    property bool destructive: false
    property bool actionEnabled: true
    default property alias details: detailsColumn.data
    signal actionRequested()
    signal cancelRequested()
    anchors.centerIn: parent
    width: Math.min(320, parent ? parent.width - 32 : 320)
    padding: 22
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    font.family: family
    font.pixelSize: 13
    header: null
    footer: null
    onOpened: { if(destructive && cancelText!=="")secondary.forceActiveFocus();else primary.forceActiveFocus(); }
    onRejected: cancelRequested()
    background: Item {
        RectangularShadow { anchors.fill: parent; radius: 28; blur: 24 + 12*alert.elevation; offset.y: 8 + 4*alert.elevation; color: "#44000000" }
        Rectangle { anchors.fill: parent; radius: 28; color: alert.dark ? "#2c2c2c" : "#f2f2f2"; border.width: 1; border.color: alert.dark ? "#38ffffff" : "#99ffffff" }
    }
    Overlay.modal: Rectangle { color: alert.dark ? "#65000000" : "#35000000" }
    contentItem: Column {
        spacing: 0
        Image { width: 64; height: 64; sourceSize: Qt.size(64,64); source: Quickshell.iconPath(alert.iconName); visible: alert.iconName !== "" }
        Item { width: 1; height: 20; visible: alert.iconName !== "" }
        Label { width: parent.width; text: alert.heading; wrapMode: Text.WordWrap; color: alert.dark ? "#f5f5f7" : "#1d1d1f"; font.family: alert.family; font.pixelSize: 17; font.weight: Font.Bold; Accessible.role: Accessible.Heading }
        Item { width: 1; height: 12; visible: alert.message !== "" }
        ScrollView {
            width: parent.width
            height: Math.min(body.implicitHeight, Math.max(70, (alert.parent ? alert.parent.height : 650) - 330))
            visible: alert.message !== ""
            clip: true
            contentWidth: availableWidth
            Label { id: body; width: parent.width; text: alert.message; wrapMode: Text.Wrap; color: alert.dark ? "#ededf0" : "#262628"; font.family: alert.family; font.pixelSize: 13; lineHeight: 1.15 }
        }
        Column { id: detailsColumn; width: parent.width; topPadding: children.length ? 16 : 0; spacing: 8 }
        Item { width: 1; height: 18 }
        Button {
            id: primary
            width: parent.width; implicitHeight: 36; padding: 8
            scale: down ? 0.975 : 1
            Behavior on scale { NumberAnimation { duration: alert.reduceMotion ? 0 : 120; easing.type: Easing.OutCubic } }
            enabled: alert.actionEnabled
            text: alert.actionText
            Accessible.name: text
            contentItem: Text { text: primary.text; font.family: alert.family; font.pixelSize: 13; font.weight: Font.Medium; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: alert.destructive ? (alert.dark ? "#ffc0b8" : "#aa2420") : "white"; opacity: primary.enabled ? 1 : 0.45 }
            background: MacGlassButtonSurface { dark: alert.dark; role: alert.destructive?"destructive":"accent"; hovered: primary.hovered; pressed: primary.down; focused: primary.visualFocus; enabled: primary.enabled; reduceMotion: alert.reduceMotion }
            onClicked: alert.actionRequested()
            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
        }
        Item { width: 1; height: 8; visible: secondary.visible }
        Button {
            id: secondary
            width: parent.width; implicitHeight: 36; padding: 8
            scale: down ? 0.975 : 1
            Behavior on scale { NumberAnimation { duration: alert.reduceMotion ? 0 : 120; easing.type: Easing.OutCubic } }
            visible: alert.cancelText !== ""
            text: alert.cancelText
            contentItem: Text { text: secondary.text; font.family: alert.family; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: alert.dark ? "#f5f5f7" : "#1d1d1f" }
            background: MacGlassButtonSurface { dark: alert.dark; hovered: secondary.hovered; pressed: secondary.down; focused: secondary.visualFocus; reduceMotion: alert.reduceMotion }
            onClicked: alert.reject()
        }
    }
    transformOrigin: Popup.Center
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: alert.reduceMotion ? 60 : 150 }
            NumberAnimation { property: "scale"; from: alert.reduceMotion ? 1 : 0.94; to: 1; duration: alert.reduceMotion ? 0 : 280; easing.type: Easing.OutQuint }
            NumberAnimation { property: "elevation"; from: 0; to: 1; duration: alert.reduceMotion ? 0 : 280; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: alert.reduceMotion ? 60 : 120 }
            NumberAnimation { property: "scale"; to: alert.reduceMotion ? 1 : 0.98; duration: alert.reduceMotion ? 0 : 120; easing.type: Easing.InCubic }
        }
    }
}
