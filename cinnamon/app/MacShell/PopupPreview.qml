import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
Scope {
    IpcHandler {
        target: "preview"
        function theme(dark: bool): void { alert.dark=dark; }
        function danger(value:bool):void { alert.destructive=value; }
        function reopen(): void { alert.open(); }
        function dismiss(): void { alert.close(); }
        function reduced(value:bool):void { alert.reduceMotion=value; }
        function state():string { return JSON.stringify({visible:alert.visible,scale:alert.scale,opacity:alert.opacity,elevation:alert.elevation,reduced:alert.reduceMotion}); }
    }
    Window {
        id: preview
        width: 640; height: 620; visible: true
        title: "MacShell Alert QA"
        color: "#e9e9ec"
        MacAlert {
            id: alert
            dark: false
            heading: "Allow from Anywhere Makes This Mac Less Secure"
            message: "Allowing apps from anywhere will make your Mac less secure because this increases the risk of malware from unknown developers. You can keep your Mac more secure by only allowing apps from developers you trust."
            actionText: "Allow From Anywhere"; cancelText: "Cancel"
            destructive: true
            onActionRequested: close()
            Component.onCompleted: open()
        }
    }
}
