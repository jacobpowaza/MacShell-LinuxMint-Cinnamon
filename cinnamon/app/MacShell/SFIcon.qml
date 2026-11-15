import QtQuick
import QtQuick.Effects
import Quickshell
import "Symbols.js" as Symbols
Item{
    id:icon
    property string name:""
    property color color:"white"
    width:18;height:18
    // SF Symbols are Apple property and are not redistributed. If the user has exported them to
    // ~/.local/share/macshell-cinnamon/symbols they are used; otherwise a freedesktop symbolic icon is shown.
    readonly property string symbolName:Symbols.symbol(icon.name)
    Image{
        id:sf
        anchors.fill:parent
        source:icon.symbolName?"file://"+Quickshell.env("HOME")+"/.local/share/macshell-cinnamon/symbols/"+icon.symbolName+".svg":""
        sourceSize:Qt.size(Math.round(icon.width*2),Math.round(icon.height*2))
        fillMode:Image.PreserveAspectFit;smooth:true
        visible:status===Image.Ready
        layer.enabled:visible
        layer.effect:MultiEffect{colorization:1;colorizationColor:icon.color}
    }
    Image{
        anchors.fill:parent
        source:sf.status!==Image.Ready&&Symbols.fallback(icon.name)?"image://icon/"+Symbols.fallback(icon.name):""
        sourceSize:Qt.size(Math.round(icon.width*2),Math.round(icon.height*2))
        fillMode:Image.PreserveAspectFit;smooth:true
        visible:status===Image.Ready
        layer.enabled:visible
        layer.effect:MultiEffect{colorization:1;colorizationColor:icon.color}
    }
}
