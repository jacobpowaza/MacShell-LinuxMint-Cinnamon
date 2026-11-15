// One desktop widget's content (Weather / Calendar / Clock / Player). Used by MacWidgets.qml for the desktop layer and by
// MacBar.qml to mirror the widgets into the Liquid Glass backdrop, so a menu refracts them together with the live windows.
import QtQuick
import Quickshell.Services.Mpris

Item {
    id: v
    required property var host           // the MacWidgets instance (data, glass state, wallpaper lookup)
    property string wtype: "weather"
    property string wstyle: "liquid"
    property string wsize: "small"
    property string wmode: "auto"
    property bool previewMode:false
    property string wcity: ""
    property string wzone: ""
    WidgetData { id: personal; host: v.host; enabled:!v.previewMode && (v.wtype==="clock" || v.wtype==="weather" && v.wcity!==""); type:v.wtype; city:v.wcity; timezone:v.wzone }
    readonly property var weather: personal.weather
    readonly property bool ownWeather: v.wcity!==""
    readonly property var current: weather ? weather.current : null
    readonly property var info: current ? host.wmo(current.weather_code,current.is_day===1) : host.wxInfo
    function hours(){if(!weather)return [];var a=[],t=weather.hourly.time,cur=weather.current.time.substring(0,13),start=t.findIndex(x=>x.substring(0,13)===cur);for(var i=Math.max(0,start);i<t.length && a.length<6;i++)a.push({h:host.hourLabel(t[i],a.length===0),t:Math.round(weather.hourly.temperature_2m[i]),k:host.wmo(weather.hourly.weather_code[i],weather.hourly.is_day[i]===1).k});return a;}
    function days(){if(!weather)return [];var d=weather.daily;return d.time.map((t,i)=>({d:host.dayLabel(t,i),lo:Math.round(d.temperature_2m_min[i]),hi:Math.round(d.temperature_2m_max[i]),k:host.wmo(d.weather_code[i],true).k}));}
    property string wsrc: ""             // image widget: path of the picture
    property real sx: 0                  // position on the screen (the glass uses it to find the wallpaper behind the widget)
    property real sy: 0
    property string sname: ""            // screen name
    property real sw: 1920
    property real sh: 1080
        Component {
            id: weatherVisual
            WeatherWidget {
                preview:v.previewMode
                scaleF: host.widgetScale
                style: wstyle
                size: wsize
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                city: ownWeather ? (weather ? weather.city : wcity) : host.wxCity
                located: ownWeather ? false : host.wxLocated
                hasData: ownWeather ? !!weather : host.wxReady
                temp: ownWeather ? (current ? Math.round(current.temperature_2m) : 0) : host.wxTemp
                hi: ownWeather ? (weather ? Math.round(weather.daily.temperature_2m_max[0]) : 0) : host.wxHi
                lo: ownWeather ? (weather ? Math.round(weather.daily.temperature_2m_min[0]) : 0) : host.wxLo
                cond: ownWeather ? (weather ? info.t : personal.error || "Loading…") : host.wxReady ? host.wxInfo.t : (host.wxError !== "" ? "Unavailable" : "Loading…")
                kind: ownWeather ? (weather ? info.k : "cloud") : host.wxReady ? host.wxInfo.k : "cloud"
                isDay: ownWeather ? (current ? current.is_day===1 : true) : host.wxDay
                hourly: ownWeather ? v.hours() : host.wxHourly
                daily: ownWeather ? v.days() : host.wxDaily
                glassReady: host.glassState === "ready"
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing && !v.previewMode
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: calendarVisual
            CalendarWidget {
                preview:v.previewMode
                scaleF: host.widgetScale
                style: wstyle
                size: wsize
                mode: wmode
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                weekStart: 0
                glassReady: host.glassState === "ready"
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing && !v.previewMode
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: clockVisual
            ClockWidget {
                preview:v.previewMode
                scaleF: host.widgetScale
                style: wstyle
                size: wsize
                fam: host.fontFamily
                boldFam: host.boldFontFamily
                use24h:host.hub && host.hub.bar?host.hub.bar.use24h:false
                timezoneOffset: personal.offset
                cityCode: wzone ? personal.label : "Local"
                screenX: v.sx; screenY: v.sy
                glassReady: host.glassState === "ready"
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing && !v.previewMode
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: playerVisual
            PlayerWidget {
                preview:v.previewMode
                scaleF: host.widgetScale
                style: wstyle
                size: wsize
                contentScale: host.playerScale
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                hasPlayer: host.player !== null
                title: host.player ? host.player.trackTitle : ""
                artist: host.player ? host.player.trackArtist : ""
                album: host.player ? host.player.trackAlbum : ""
                artUrl: host.player ? host.player.trackArtUrl : ""
                playing: host.player ? host.player.isPlaying : false
                shuffle: (host.player && host.player.shuffleSupported) ? host.player.shuffle : false
                canShuffle: host.player !== null && host.player.shuffleSupported
                loop: (host.player && host.player.loopSupported)
                      ? (host.player.loopState === MprisLoopState.Track ? 1 : (host.player.loopState === MprisLoopState.Playlist ? 2 : 0)) : 0
                canLoop: host.player !== null && host.player.loopSupported
                position: (host.player && host.player.positionSupported) ? host.player.position : 0
                length: (host.player && host.player.lengthSupported) ? host.player.length : 0
                canSeek: host.player !== null && host.player.canSeek && host.player.positionSupported && host.player.lengthSupported
                lyrics: host.lyricsLines
                lyricsState: host.lyricsState
                lyricsSynced: host.lyricsSynced
                onLyricsToggled: on => host.lyricsWanted = on
                glassReady: host.glassState === "ready"
                shaderUrl: "file://" + host.glassShaderOut
                wallUrl: host.fileUrl(host.wallpaperFor(v.sname))
                wallVideo: host.liveWallVideo
                wallPaused: host.liveWallPaused
                screenW: v.sw
                screenH: v.sh
                glassOpacity: host.glassOpacity
                glassBlur: host.glassBlur
                glassLiquid: host.glassLiquid
                glassRim: host.glassRim
                borderTint: host.borderTint
                glassGrain: host.glassGrain
                darkGlass: host.darkGlass
                editing: host.editing && !v.previewMode
                onSeek: seconds => { if (host.player && host.player.canSeek) host.player.position = seconds; }
                onTogglePlaying: { if (host.player && host.player.canTogglePlaying) host.player.togglePlaying(); }
                onNextTrack: { if (host.player && host.player.canGoNext) host.player.next(); }
                onPreviousTrack: { if (host.player && host.player.canGoPrevious) host.player.previous(); }
                onToggleShuffle: { if (host.player && host.player.shuffleSupported) host.player.shuffle = !host.player.shuffle; }
                onCycleLoop: {
                    if (!host.player || !host.player.loopSupported) return;
                    // off -> repeat all -> repeat song -> off
                    var ls = host.player.loopState;
                    host.player.loopState = ls === MprisLoopState.None ? MprisLoopState.Playlist
                                          : (ls === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
                }
                onGlassFailed: host.glassState = "failed"
            }
        }
        Component {
            id: imageVisual
            ImageWidget {
                size: wsize
                borderTint: host.borderTint
                scaleF: host.widgetScale
                fam: host.fontFamily
                screenX: v.sx; screenY: v.sy
                source: host.fileUrl(v.wsrc)
                darkGlass: host.darkGlass
                editing: host.editing && !v.previewMode
            }
        }
        Loader {
            id: visual
            anchors.fill: parent
            sourceComponent: wtype === "calendar" ? calendarVisual
                           : (wtype === "clock" ? clockVisual
                           : (wtype === "player" ? playerVisual
                           : (wtype === "image" ? imageVisual : weatherVisual)))
        }
}
