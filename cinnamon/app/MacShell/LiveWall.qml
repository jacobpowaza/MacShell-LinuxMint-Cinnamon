// LiveWall — placeholder for upstream's animated (video) wallpaper glass.
// The real implementation needs Qt Multimedia, which is not part of the small user-space Quickshell runtime that the
// Cinnamon installer sets up. Same properties as upstream, but nothing is ever decoded; the glass uses the still wallpaper.
// The original is kept as LiveWall.qml.multimedia: copy it over this file and provide a QtMultimedia QML module
// (QML_IMPORT_PATH) to re-enable video wallpapers.
import QtQuick

Item {
    property string video: ""
    property bool live: false
    property bool paused: false
    readonly property bool active: false
}
