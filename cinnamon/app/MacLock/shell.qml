// MacLock: a macOS 26/27-style lock screen for Quickshell, matching MacShell's Liquid Glass.
//
//   qs -c MacLock                         lock now (one-shot; started by hypridle via maclock.sh)
//   MACLOCK_DAEMON=1 qs -c MacLock        start unlocked for an IPC-triggered lock
//   MACLOCK_PREVIEW=1 qs -c MacLock       draw it as an overlay window instead of a real lock (for tweaking)
//
// Runs as its own process on purpose: a MacShell crash can never take the lock with it, and maclock.sh
// relaunches this one if it dies (Hyprland's misc:allow_session_lock_restore lets the new instance take over).
// Password check: PAM, /etc/pam.d/hyprlock (same stack hyprlock uses).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Cinnamon" as Cinnamon
import Quickshell.Services.Pam

ShellRoot {
    // User-installed SF faces; binaries are deliberately external to this port.
    FontLoader { id: uiFontLoader; source: "file://"+Quickshell.env("HOME")+"/.local/share/fonts/macshell-sf/SF-Pro-Text-Regular.otf" }
    FontLoader { id: uiBoldFontLoader; source: "file://"+Quickshell.env("HOME")+"/.local/share/fonts/macshell-sf/SF-Pro-Rounded-Semibold.otf" }

    // never hot-reload while holding the session lock: a half-edited config must not touch a live lock
    settings.watchFiles: false
    id: root
    readonly property bool preview: true
    readonly property bool cinnamonHost: Quickshell.env("MACLOCK_CINNAMON_HOST") === "1"
    readonly property bool daemonMode: Quickshell.env("MACLOCK_DAEMON") === "1"
    // Default launch keeps the original behavior and locks immediately. In daemon mode, wait for IPC.
    property bool lockRequested: !daemonMode
    function requestLock() {
        if (!preview) lockRequested = true;
    }
    IpcHandler {
        target: "lockscreen"
        function state(): string {
            if (lock.wasSecure) return lock.secure ? "busy" : "stopping";
            return root.lockRequested ? "busy" : "ready";
        }
        function lock(): void { root.requestLock(); }
    }

    // the monitor that was focused when the lock started gets the full layout
    property string primary: ""
    function pickPrimary() {
        if (primary === "" && Cinnamon.Hyprland.focusedMonitor) primary = Cinnamon.Hyprland.focusedMonitor.name;
    }
    Component.onCompleted: pickPrimary()
    // Hyprland's state arrives a moment after startup; only fall back to the first screen if it never does
    Timer {
        interval: 400; running: true
        onTriggered: if (root.primary === "" && Quickshell.screens.length > 0) root.primary = Quickshell.screens[0].name
    }
    Connections { target: Cinnamon.Hyprland; function onFocusedMonitorChanged() { root.pickPrimary(); } }

    QtObject {
        id: lockState
        property var now: new Date()
        property string wallpaper: ""
        property string wallpaperVideo: ""      // animated wallpaper set in MacShell (~/.config/macshell/wallpaper-video)
        property string userName: Quickshell.env("USER") || ""
        property string avatar: ""
        property int wifiLevel: -1          // -1 unknown/hidden, 0 off, 1..3 bars
        property bool ethernet: false       // wired connection up
        property string pass: ""
        property bool busy: false
        property int fails: 0
        property string message: ""
        property bool engaged: false
        property bool unlocking: false
        property string mediaSlot: "top"    // "top" (under the clock) | "bottom" (above the password field)
        property bool capsLock: false
        property bool nativeVisible: false
        property bool use24h: true          // MacShell → Menu Bar → "24-hour clock"
        // Settings → Lock Screen → Clock (MACLOCK_CLOCK='{"f":"serif",...}' overrides it, for previews)
        property var clockCfg: { try { return JSON.parse(Quickshell.env("MACLOCK_CLOCK") || "{}"); } catch (e) { return {}; } }
        property bool artBg: true           // blurred album art behind everything while the cover is enlarged (MacShell setting)
        property bool sounds: false         // MacShell's "Play user interface sound effects" (and not in Game Mode)
        function sound(name) {
            if (sounds) Quickshell.execDetached(["pw-play", "--volume=0.7", Quickshell.env("HOME") + "/.local/share/sounds/macshell/" + name + ".wav"]);
        }
        // Now Playing presentation: "" (bubble), "art" (cover floats out, tap the cover) or "lyrics" (lyrics button)
        property string npMode: Quickshell.env("MACLOCK_NP") || (Quickshell.env("MACLOCK_ART") === "1" ? "art" : "")

        function setMediaSlot(v) {
            if (v === mediaSlot) return;
            mediaSlot = v;
            saveProc.command = ["sh", "-c", "mkdir -p \"$HOME/.config/maclock\" && printf '{\\n  \"mediaSlot\": \"%s\"\\n}\\n' \"$1\" > \"$HOME/.config/maclock/settings.json\"", "sh", v];
            saveProc.running = true;
        }
        function checkCaps() { if (!capsProc.running) capsProc.running = true; }

        function poke() {
            engaged = true;
            idleTimer.restart();
        }
        function submit() {
            if(root.cinnamonHost) nativeChannel.send("submit")
        }
        function fail(msg) {
            pass = "";
            message = msg;
            fails++;
            msgTimer.restart();
        }
        function unlock() {
            unlocking = true;
            sound("unlock");
            unlockTimer.start();
        }
    }

    Process { id: saveProc }
    // Caps Lock indicator
    Process {
        id: capsProc
        // Hyprland's own state, not the LEDs (a virtual keyboard such as GPU Screen Recorder's can leave the LEDs lit).
        // Caps Lock lives per keyboard in Hyprland; the one you typed on last is "main" and its state is what applies
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main) | .capsLock] | any'"]
        stdout: StdioCollector {
            onStreamFinished: lockState.capsLock = text.trim() === "true"
        }
    }
    Timer { interval: 700; repeat: true; running: !root.cinnamonHost; triggeredOnStart: true; onTriggered: lockState.checkCaps() }

    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: lockState.now = new Date() }
    // preview-only test hook: MACLOCK_TEST_MORPH=1 flips 12/24-hour every 1.5 s so the clock morph can be checked
    Timer { interval: 1500; repeat: true; running: root.preview && Quickshell.env("MACLOCK_TEST_MORPH") === "1"; onTriggered: lockState.use24h = !lockState.use24h }
    Timer { id: idleTimer; interval: 9000; onTriggered: if (lockState.pass.length === 0 && !lockState.busy) lockState.engaged = false }
    Timer { id: msgTimer; interval: 3500; onTriggered: lockState.message = "" }
    // let the exit animation play, then drop the lock and quit
    Timer {
        id: unlockTimer
        interval: 430
        onTriggered: {
            if (root.preview) Qt.quit();
            else {
                root.lockRequested = false;
                // A WlSessionLock is single-use in practice: retire this process after unlock so
                // the next IPC launch creates a fresh session-lock object.
                quitTimer.start();
            }
        }
    }
    Timer { id: quitTimer; interval: 150; onTriggered: Qt.quit() }



    // Resolve wallpaper paths independently of slower network/profile probes so the lock scene can decode them immediately.
    Process {
        running: true
        command: ["sh", "-c",
            "p=$(jq -r '.wallpaperPath // empty' \"$HOME/.config/macbar/settings.json\" 2>/dev/null); "
            + "[ -f \"$p\" ] || p=$(jq -r '.wallpaperPath // empty' \"$HOME/.config/macdock/settings.json\" 2>/dev/null); "
            + "[ -f \"$p\" ] || p=$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1); "
            + "printf '%s\\n' \"$p\"; "
            + "v=$(cat \"$HOME/.config/macshell/wallpaper-video-play\" 2>/dev/null); [ -f \"$v\" ] || v=$(cat \"$HOME/.config/macshell/wallpaper-video\" 2>/dev/null); "
            + "[ -f \"$HOME/.config/macshell/wallpaper-video\" ] && [ -f \"$v\" ] && printf '%s' \"$v\"; echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                lockState.wallpaper = (l[0] || "").trim();
                lockState.wallpaperVideo = (l[1] || "").trim();
            }
        }
    }

    // ── one-shot lookups: real name, avatar, wifi, and other settings
    Process {
        running: true
        command: ["sh", "-c",
            "n=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); printf '%s\\n' \"${n:-$USER}\"; "
            + "for a in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -f \"$a\" ] && { printf '%s' \"$a\"; break; }; done; echo; "
            + "if [ \"$(nmcli radio wifi 2>/dev/null)\" = enabled ]; then s=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep '^yes' | head -n1 | cut -d: -f2); "
            + "[ -n \"$s\" ] && printf '%s' \"$s\" || printf 0; else printf -- -1; fi; echo; "
            + "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$' && echo eth || echo -; "
            + "jq -r '.mediaSlot // \"top\"' \"$HOME/.config/maclock/settings.json\" 2>/dev/null || echo top; "
            + "[ \"$(jq -r '.uiSounds' \"$HOME/.config/macbar/settings.json\" 2>/dev/null)\" != false ] && [ ! -f \"${XDG_RUNTIME_DIR:-/tmp}/macshell-gaming.state\" ] && echo snd || echo -; "
            + "jq -r '.lockArtBackground' \"$HOME/.config/macbar/settings.json\" 2>/dev/null || echo true; "
            + "jq -r '.use24h' \"$HOME/.config/macbar/settings.json\" 2>/dev/null || echo true; "
            + "jq -r '.language // \"auto\"' \"$HOME/.config/macbar/settings.json\" 2>/dev/null || echo auto; "
            + "jq -c '{f: .lockClockFont, w: .lockClockWeight, m: .lockClockMaterial, d: .lockClockDate, i: .lockClockIntensity, c: .lockClockTint}' \"$HOME/.config/macbar/settings.json\" 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n");
                if ((l[0] || "").trim() !== "") lockState.userName = l[0].trim();
                lockState.avatar = (l[1] || "").trim();
                var s = parseInt((l[2] || "-1").trim());
                lockState.wifiLevel = isNaN(s) || s < 0 ? -1 : (s === 0 ? 0 : (s > 66 ? 3 : (s > 33 ? 2 : 1)));
                lockState.ethernet = (l[3] || "").trim() === "eth";
                lockState.mediaSlot = (l[4] || "top").trim() === "bottom" ? "bottom" : "top";
                lockState.sounds = (l[5] || "").trim() === "snd";
                lockState.artBg = (l[6] || "true").trim() !== "false";
                lockState.use24h = (l[7] || "true").trim() !== "false";
                var lang = (l[8] || "auto").trim();
                Qt.uiLanguage = (lang === "auto" || lang === "null") ? "" : lang;
                if (!Quickshell.env("MACLOCK_CLOCK")) { try { lockState.clockCfg = JSON.parse((l[9] || "{}").trim() || "{}"); } catch (e) { } }
                if (!root.preview) lockState.sound("lock");
            }
        }
    }

    // The Cinnamon Stage owns the real X11 grabs and PAM authentication.
    // This process only paints the upstream MacLock UI, inside that secure Stage.
    QtObject { id: lock; property bool locked: false; property bool secure: false; property bool wasSecure: false }


    QtObject {
        id: nativeChannel
        property Socket socket: Socket {
            path: Quickshell.env("MACLOCK_NATIVE_SOCKET") || Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/lock-native.sock"
            connected: root.cinnamonHost
            parser: SplitParser {onRead: data => {}}
        }
        function send(action){if(socket.connected){socket.write(action+"\n");socket.flush()}}
    }
    Timer {
        interval:1000;repeat:true
        running:root.cinnamonHost && !nativeChannel.socket.connected
        onTriggered:nativeChannel.socket.connected=true
    }
    FileView {
        id: nativeState
        path: Quickshell.env("MACLOCK_NATIVE_STATE") || Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/lock-state.json"
        watchChanges: root.cinnamonHost
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if(!root.cinnamonHost)return
            try {
                var d=JSON.parse(text())
                lockState.pass="x".repeat(d.length||0)
                lockState.busy=d.busy||false
                lockState.engaged=d.awake||false
                lockState.message=d.message||""
                lockState.unlocking=d.unlocking||false
                lockState.nativeVisible=d.showVisual||false
                lockState.capsLock=d.capsLock||false
            }catch(e){}
        }
    }

    // ═════════════ preview window ═════════════
    Variants {
        model: root.preview ? Quickshell.screens : []
        PanelWindow {
            id: pw
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            aboveWindows: true
            property string cinnamonRole: "maclock-ui"
            objectName: "MacLock Cinnamon Visual"
            focusable: !root.cinnamonHost && Quickshell.env("MACLOCK_PREVIEW_KB") === "1"
            Item {
                id: visualHolder
                anchors.fill: parent
                opacity: root.cinnamonHost ? (lockState.nativeVisible ? 1 : 0) : 1
                Behavior on opacity { NumberAnimation {duration:650;easing.type:Easing.OutQuint} }
                LockScreen {
                id: visual
                anchors.fill: parent
                st: lockState
                Keys.enabled: !root.cinnamonHost
                isPrimary: root.primary === "" || pw.modelData.name === root.primary
                }
            }
            Timer {
                interval:500;running:root.cinnamonHost;repeat:true
                onTriggered:if(visual.shown)visual.grabToImage(result=>nativeChannel.send("frame|"+pw.modelData.name))
            }
        }
    }
}
