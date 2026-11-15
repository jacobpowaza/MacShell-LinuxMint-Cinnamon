import QtQuick

// A copy/add badge beside the native drag image, without intercepting input.
Rectangle {
    required property point pointerPosition
    x: Math.max(2, Math.min(parent.width - width - 2, pointerPosition.x + 46))
    y: Math.max(2, Math.min(parent.height - height - 2, pointerPosition.y + 22))
    width: 19; height: 19; radius: width / 2
    color: "#28b84b"
    border.color: "white"; border.width: 1.5
    z: 100
    Rectangle { anchors.centerIn: parent; width: 10; height: 2; radius: 1; color: "white" }
    Rectangle { anchors.centerIn: parent; width: 2; height: 10; radius: 1; color: "white" }
}
