// Reuse the source Liquid Glass shader for the common alert/button material.
import QtQuick
import QtQuick.Effects

Item {
    id: surface
    property bool dark: true
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property bool reduceMotion: false
    property string role: "neutral" // neutral, accent, destructive
    property real cornerRadius: height/2
    property real hoverAmount: hovered && enabled ? 1 : 0
    property real pressAmount: pressed && enabled ? 1 : 0
    readonly property color tint: role==="accent" ? "#005ac8" : role==="destructive" ? (dark?"#603531":"#f1c8cb") : (dark?"#454545":"#dedede")
    Behavior on hoverAmount { NumberAnimation { duration: surface.reduceMotion ? 0 : 160; easing.type: Easing.OutCubic } }
    Behavior on pressAmount { NumberAnimation { duration: surface.reduceMotion ? 0 : 110; easing.type: Easing.OutCubic } }
    opacity: enabled ? 1 : 0.45

    RectangularShadow {
        anchors.fill: parent; radius: surface.cornerRadius
        blur: 6+surface.hoverAmount*2; offset.y: 2+surface.hoverAmount-surface.pressAmount
        color: surface.dark ? "#44000000" : "#26000000"
        opacity: 1-surface.pressAmount*0.55
    }
    // A local material texture, never another desktop capture. Refraction bends its
    // highlight into the capsule edge using the existing source shader.
    Item {
        id: material
        x: -40; y: -40; width: surface.width+80; height: surface.height+80
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(surface.tint,1.12+surface.hoverAmount*0.06) }
                GradientStop { position: 0.48; color: surface.tint }
                GradientStop { position: 1; color: Qt.darker(surface.tint,1.12+surface.pressAmount*0.08) }
            }
        }
        Rectangle {
            x: 30+surface.width*0.08+surface.hoverAmount*surface.width*0.12
            y: 27; width: surface.width*0.7; height: 24; radius: 12
            rotation: -8
            color: "white"; opacity: 0.02+surface.hoverAmount*0.02-surface.pressAmount*0.015
        }
    }
    ShaderEffectSource { id: texture; sourceItem: material; hideSource: true; live: surface.visible; mipmap: true; visible: false }
    GlassSlab {
        anchors.fill: parent; src: texture; srcSize: Qt.size(material.width,material.height); origin: Qt.point(40,40)
        shaderUrl: Qt.resolvedUrl("liquidglass.frag.qsb"); dark: surface.dark; cornerR: surface.cornerRadius
        baseColor: surface.tint; thickness: 10; liquid: 0.65; rim: 0.10+surface.hoverAmount*0.035
        tint: 0.08; grain: 0.004; shadowAmt: 0; blurPx: 1; flatInner: 1
        strengthMul: 1-surface.pressAmount*0.25
    }
    // Catchlight and inner rim stay attached to the capsule as it compresses.
    Rectangle {
        anchors.fill: parent; radius: surface.cornerRadius; color: "transparent"
        border.width: 1; border.color: Qt.rgba(1,1,1,(surface.dark?0.16:0.48)+surface.hoverAmount*0.08-surface.pressAmount*0.08)
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: 1; radius: Math.max(0,surface.cornerRadius-1); color: "transparent"
        border.width: 1; border.color: Qt.rgba(0,0,0,surface.dark?0.12:0.05)
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: -3; radius: surface.cornerRadius+3; color: "transparent"
        visible: surface.focused; border.width: 2; border.color: surface.dark ? "#8cbeff" : "#006bdd"
    }
}
