import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "Cinnamon" as Cinnamon

Scope {
    id: manager
    required property var host
    readonly property string family:host.fontFamily
    readonly property bool dark:host.darkGlass
    readonly property color fg:dark?"#f5f5f7":"#202023"
    readonly property color secondary:dark?"#b8b8be":"#626268"
    readonly property bool reduceMotion:host.hub && host.hub.bar ? host.hub.bar.reduceMotion : false
    property bool awaitingDesktop:false
    function requestDesktop(){if(transitionChannel.connected){transitionChannel.write('{"op":"widget-edit","arg":"begin"}\n');transitionChannel.flush();}}
    Socket{id:transitionChannel;path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true;onConnectedChanged:if(connected && manager.awaitingDesktop)manager.requestDesktop();parser:SplitParser{onRead:text=>{if(!manager.awaitingDesktop)return;try{var r=JSON.parse(text);manager.awaitingDesktop=false;if(r.ok)presentLater.restart();else{manager.error=r.error;manager.close();}}catch(e){manager.close();}}}}
    property string selectedId:""
    property string selectedType:""
    property var menuRows:[]
    property var zones:[]
    property string error:""
    function state(){return JSON.stringify({gallery:gallery.visible,galleryActive:gallery.active,galleryFocus:search.activeFocus,menu:menu.visible,menuX:menu.x+menu.shadowPad,menuY:menu.y+menu.shadowPad,editor:editor.visible,selectedId:selectedId,category:gallery.category});}
    readonly property bool contextOpen:menu.visible
    function dismissContext(){menu.close();}
    function find(id){for(var i=0;i<host.model.count;i++)if(host.model.get(i).wid===id)return host.model.get(i);return null;}
    function open(){if(gallery.visible){closeLater.stop();gallery.presented=true;galleryRaise.restart();return;}if(awaitingDesktop)return;closeLater.stop();awaitingDesktop=true;host.editing=true;requestDesktop();}
    function close(){awaitingDesktop=false;presentLater.stop();menu.close();editor.visible=false;gallery.presented=false;closeLater.restart();}
    Timer{id:presentLater;interval:1;onTriggered:{gallery.visible=true;gallery.raise();gallery.requestActivate();Qt.callLater(()=>gallery.presented=true);galleryRaise.restart();}}
    Timer{id:closeLater;interval:manager.reduceMotion?1:170;onTriggered:{gallery.visible=false;host.editing=false;Cinnamon.Host.send("widget-edit","end");}}
    function context(id,x,y){
        galleryRaise.stop();
        var w=find(id);if(!w)return;
        selectedId=id;selectedType=w.wtype;
        if(!host.editing){menuRows=[{label:"Edit Widgets…",action:"gallery"}];menu.show(menuRows,x,y);return;}
        menuRows=[{label:"Edit "+title(w.wtype)+"…",action:"edit"},{separator:true},
            {label:"Small",action:"small",checked:w.wsize==="small"},
            {label:"Medium",action:"medium",checked:w.wsize==="medium"},
            {label:"Large",action:"large",checked:w.wsize==="large"},{separator:true},
            {label:"Edit Widgets…",action:"gallery"},{label:"Remove Widget",action:"remove",danger:true}];
        menu.show(menuRows,x,y);
    }
    function title(type){return ({weather:"Weather",clock:"Clock",calendar:"Calendar",player:"Music",image:"Photos"})[type]||type;}
    function edit(){var w=find(selectedId);if(!w)return;city.text=w.wcity;timezone.editText=w.wzone||"Local";style.currentIndex=style.values.indexOf(w.wstyle);mode.currentIndex=mode.values.indexOf(w.wmode);var scr=Quickshell.screens[0];editor.x=Math.max(scr.x+12,Math.min(scr.x+scr.width-editor.width-12,menu.x+menu.shadowPad));editor.y=Math.max(scr.y+34,Math.min(scr.y+scr.height-editor.height-12,menu.y+menu.shadowPad));editor.visible=true;editor.raise();editor.requestActivate();editorRaise.restart();}
    function run(action){menu.close();if(action==="edit")edit();else if(action==="gallery")open();else if(action==="remove")host.removeWidget(selectedId);else if(!host.setSize(selectedId,action))error="There isn’t enough space for this widget size.";}
    Timer{id:galleryRaise;interval:180;onTriggered:{Cinnamon.Host.send("activate-title","MacShell Widget Gallery");search.forceActiveFocus();}}
    Timer{id:editorRaise;interval:180;onTriggered:{Cinnamon.Host.send("activate-title","Edit Widget");editorRoot.forceActiveFocus();}}
    Socket{id:zoneChannel;path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true;onConnectedChanged:if(connected){write('{"op":"timezones"}\n');flush();}parser:SplitParser{onRead:text=>{try{var r=JSON.parse(text);if(r.ok)manager.zones=["Local"].concat(r.value);}catch(e){}}}}
    WidgetContextMenu{id:menu;reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;rows:manager.menuRows;onTriggered:entry=>manager.run(entry.action)}
    Window{
        id:editor;title:"Edit Widget";width:410;height:manager.selectedType==="weather"||manager.selectedType==="clock"?306:264;visible:false;color:"transparent"
        onVisibleChanged:if(!visible && gallery.visible)galleryRaise.restart()
        flags:Qt.Dialog|Qt.FramelessWindowHint|Qt.WindowStaysOnTopHint
        Item{id:editorRoot;anchors.fill:parent;focus:true;Keys.onEscapePressed:event=>{editor.visible=false;event.accepted=true;}
        Rectangle{anchors.fill:parent;radius:18;color:manager.dark?"#29292d":"#f6f6f8";border.width:1;border.color:manager.dark?"#38ffffff":"#29000000"}
        Column{x:24;y:22;width:parent.width-48;spacing:14
            Text{text:"Edit "+manager.title(manager.selectedType);color:manager.fg;font.family:manager.family;font.pixelSize:19;font.weight:Font.DemiBold}
            Column{width:parent.width;spacing:6;visible:manager.selectedType==="weather"
                Text{text:"Location";color:manager.fg;font.family:manager.family;font.pixelSize:13}
                MacTextField{dark:manager.dark;family:manager.family;id:city;width:parent.width;placeholderText:"City name, or leave blank for default";font.family:manager.family;selectByMouse:true}
            }
            Column{width:parent.width;spacing:6;visible:manager.selectedType==="clock"
                Text{text:"Time zone";color:manager.fg;font.family:manager.family;font.pixelSize:13}
                MacComboBox{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;id:timezone;width:parent.width;editable:true;model:manager.zones;font.family:manager.family}
            }
            Row{spacing:12;visible:manager.selectedType!=="image"
                Column{spacing:6
                    Text{text:"Appearance";color:manager.fg;font.family:manager.family;font.pixelSize:13}
                    MacComboBox{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;id:style;width:manager.selectedType==="calendar"?170:362;property var values:manager.selectedType==="clock"||manager.selectedType==="player"?["liquid","light","dark"]:["normal","liquid"];model:values.map(v=>({liquid:"Liquid Glass",light:"Light",dark:"Dark",normal:"Standard"})[v]);font.family:manager.family}
                }
                Column{spacing:6;visible:manager.selectedType==="calendar"
                    Text{text:"Color";color:manager.fg;font.family:manager.family;font.pixelSize:13}
                    MacComboBox{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;id:mode;width:170;property var values:["auto","light","dark"];model:["Automatic","Light","Dark"];font.family:manager.family}
                }
            }
            MacButton{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;visible:manager.selectedType==="image";text:"Choose Photo…";onClicked:{manager.host.pickImage(manager.selectedId,"small");editor.visible=false;}}
            Text{visible:manager.error!=="";text:manager.error || "Drag here to move";color:manager.error?(manager.dark?"#ffb4ac":"#b42318"):manager.secondary;width:parent.width;wrapMode:Text.WordWrap;font.family:manager.family;font.pixelSize:11}
        }
        Row{anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:20;spacing:10
            MacButton{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;text:"Cancel";onClicked:{editor.visible=false;manager.error="";}}
            MacButton{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;text:"Done";highlighted:true;onClicked:{
                var z=timezone.editText.trim();if(z==="Local")z="";
                if(manager.selectedType==="clock" && z!=="" && manager.zones.indexOf(z)<0){manager.error="Choose an IANA time zone from the list.";return;}
                manager.host.configure(manager.selectedId,city.text.trim(),z);manager.host.setStyle(manager.selectedId,style.values[style.currentIndex]);if(manager.selectedType==="calendar")manager.host.setMode(manager.selectedId,mode.values[mode.currentIndex]);editor.visible=false;manager.error="";
            }}
        }
        }
    }
    Window{
        id:gallery
        title:"MacShell Widget Gallery";width:Math.min(1000,Quickshell.screens[0].width-56);height:Math.min(550,Quickshell.screens[0].height-140);visible:false;color:"transparent"
        flags:Qt.Tool|Qt.FramelessWindowHint|Qt.WindowStaysOnTopHint
        x:Quickshell.screens[0].x+(Quickshell.screens[0].width-width)/2
        y:Quickshell.screens[0].y+Quickshell.screens[0].height-height-18
        onClosing:function(e){e.accepted=false;manager.close();}
        property bool presented:false
        property string category:"clock"
        readonly property var providers:[
            {id:"clock",name:"Clock",symbol:"clock",color:"#55555b",title:"City",description:"See the time in a city around the world.",styles:["light","dark","liquid"]},
            {id:"weather",name:"Weather",symbol:"cloud.sun",color:"#2889dc",title:"Forecast",description:"See the current weather and the forecast.",styles:["normal","liquid"]},
            {id:"calendar",name:"Calendar",symbol:"calendar",color:"#fa5759",title:"Month",description:"Keep track of today and this month.",styles:["normal","liquid"]},
            {id:"player",name:"Music",symbol:"music.note",color:"#fa4e6c",title:"Now Playing",description:"Control music from your media player.",styles:["light","dark","liquid"]},
            {id:"image",name:"Photos",symbol:"photo",color:"#9a64cd",title:"Photo",description:"Display a photo of your choice.",styles:["normal"]}
        ]
        readonly property var previews:{
            var out=[];
            for(var i=0;i<providers.length;i++){var p=providers[i];if(p.id!==category)continue;if(search.text && (p.name+" "+p.description).toLowerCase().indexOf(search.text.toLowerCase())<0)continue;
                for(var j=0;j<p.styles.length;j++)for(var k=0;k<3;k++)out.push({type:p.id,style:p.styles[j],size:["small","medium","large"][k],title:p.title,description:p.description});
            }return out;
        }
        Item{id:gallerySurface;anchors.fill:parent;opacity:gallery.presented?1:0
        transform:Translate{y:gallery.presented?0:22;Behavior on y{NumberAnimation{duration:manager.reduceMotion?0:320;easing.type:Easing.OutCubic}}}
        Behavior on opacity{NumberAnimation{duration:manager.reduceMotion?0:170;easing.type:Easing.OutCubic}}
        Item{id:galleryMask;anchors.fill:parent;visible:false;layer.enabled:true;Rectangle{anchors.fill:parent;radius:14;color:"white"}}
        Item{anchors.fill:parent;layer.enabled:true;layer.effect:MultiEffect{maskEnabled:true;maskSource:galleryMask;maskThresholdMin:0.5;maskSpreadAtMin:1}
            CinnamonFrost{anchors.fill:parent;window:gallery}
            Rectangle{anchors.fill:parent;radius:14;color:manager.dark?"#aa303038":"#aaf4f4f8";border.width:1;border.color:manager.dark?"#45ffffff":"#66ffffff"}
            Rectangle{x:0;y:0;width:200;height:parent.height;color:manager.dark?"#15303038":"#10ffffff"}
            Rectangle{x:200;y:10;width:1;height:parent.height-20;color:manager.dark?"#20ffffff":"#15000000"}
        }
        MacTextField{
            id:search;Keys.onEscapePressed:event=>{manager.close();event.accepted=true;}
            x:14;y:14;width:172;height:28;dark:manager.dark;family:manager.family;placeholderText:"Search Widgets";leftPadding:28
            SFIcon{x:8;anchors.verticalCenter:parent.verticalCenter;width:14;height:14;name:"search";color:manager.secondary}
            background:Rectangle{radius:14;color:manager.dark?"#22ffffff":"#1a000000";border.width:search.activeFocus?2:1;border.color:search.activeFocus?"#529afa":manager.dark?"#26ffffff":"#19000000"}
            onTextChanged:if(text){var p=gallery.providers.find(p=>(p.name+" "+p.description).toLowerCase().indexOf(text.toLowerCase())>=0);if(p)gallery.category=p.id;}
        }
        Column{x:10;y:52;width:180;spacing:2
            Repeater{model:gallery.providers
                Rectangle{required property var modelData;width:180;height:30;radius:7;color:gallery.category===modelData.id?(manager.dark?"#35ffffff":"#36000000"):providerHover.hovered?(manager.dark?"#15ffffff":"#12000000"):"transparent"
                    Rectangle{x:8;anchors.verticalCenter:parent.verticalCenter;width:20;height:20;radius:5;color:modelData.color;SFIcon{anchors.centerIn:parent;width:16;height:16;name:modelData.symbol;color:"white"}}
                    Text{x:38;anchors.verticalCenter:parent.verticalCenter;text:modelData.name;color:manager.fg;font.family:manager.family;font.pixelSize:13}
                    HoverHandler{id:providerHover}
                    TapHandler{onTapped:{gallery.category=modelData.id;search.text="";previewGrid.positionViewAtBeginning();}}
                }
            }
        }
        // The footer is a drag handle; previews and controls keep their gestures.
        MouseArea{
            x:0;y:parent.height-58;width:parent.width-100;height:58
            cursorShape:pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
            property point pressGlobal:Qt.point(0,0)
            property point pressWindow:Qt.point(0,0)
            onPressed:mouse=>{pressGlobal=mapToGlobal(mouse.x,mouse.y);pressWindow=Qt.point(gallery.x,gallery.y);}
            onPositionChanged:mouse=>{
                if(!pressed)return;
                var p=mapToGlobal(mouse.x,mouse.y),screen=Quickshell.screens.find(s=>p.x>=s.x && p.x<s.x+s.width && p.y>=s.y && p.y<s.y+s.height)||Quickshell.screens[0];
                gallery.x=Math.max(screen.x,Math.min(screen.x+screen.width-gallery.width,pressWindow.x+p.x-pressGlobal.x));
                gallery.y=Math.max(screen.y+30,Math.min(screen.y+screen.height-gallery.height,pressWindow.y+p.y-pressGlobal.y));
            }
            Accessible.name:"Move widget gallery"
        }
        Text{x:14;anchors.bottom:parent.bottom;anchors.bottomMargin:18;width:172;text:"Drag a widget to place it on the desktop.";wrapMode:Text.WordWrap;font.family:manager.family;font.pixelSize:11;font.weight:Font.DemiBold;color:manager.fg}
        GridView{
            id:previewGrid;x:220;y:18;width:parent.width-240;height:parent.height-74;clip:true
            model:gallery.visible?gallery.previews:[]
            cellWidth:width/3;cellHeight:290
            delegate:Item{
                id:previewTile
                required property var modelData
                width:previewGrid.cellWidth;height:previewGrid.cellHeight
                readonly property var dims:manager.host.dims(modelData.size)
                readonly property real previewScale:Math.min(0.48,(width-24)/Math.max(manager.host.dims("medium")[0],manager.host.dims("large")[0]))
                Item{
                    id:previewCard
                    width:previewTile.dims[0]*previewTile.previewScale;height:previewTile.dims[1]*previewTile.previewScale
                    anchors.horizontalCenter:parent.horizontalCenter;y:112-height/2
                    Item{width:previewTile.dims[0];height:previewTile.dims[1];scale:previewTile.previewScale;transformOrigin:Item.TopLeft
                        Loader{anchors.fill:parent;active:gallery.visible;sourceComponent:WidgetVisual{host:manager.host;wtype:previewTile.modelData.type;wstyle:previewTile.modelData.style;wsize:previewTile.modelData.size;previewMode:true}}
                        Rectangle{anchors.fill:parent;radius:28;color:manager.dark?"#3d3d46":"#eff0f4";visible:previewTile.modelData.type==="image";SFIcon{anchors.centerIn:parent;width:52;height:52;name:"photo";color:manager.dark?"#ceced8":"#83838d"}}
                    }
                    MouseArea{
                        anchors.fill:parent;cursorShape:pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
                        property real startX:0;property real startY:0
                        onPressed:m=>{var p=mapToGlobal(m.x,m.y);startX=p.x;startY=p.y;}
                        onReleased:m=>{var p=mapToGlobal(m.x,m.y),entry=previewTile.modelData,dragged=Math.abs(p.x-startX)+Math.abs(p.y-startY)>10;
                            if(entry.type==="image"){manager.host.pickImage("",entry.size);return;}
                            if(dragged && (p.y<gallery.y || p.x<gallery.x || p.x>gallery.x+gallery.width)){var screen=Quickshell.screens[0];manager.host.addAt(entry.type,entry.style,entry.size,p.x-screen.x-previewTile.dims[0]/2,p.y-screen.y-previewTile.dims[1]/2);}
                            else if(!dragged && !manager.host.addWidget(entry.type,entry.style,entry.size))manager.error="There isn’t enough space for another widget.";
                        }
                    }
                }
                Text{y:230;width:parent.width;horizontalAlignment:Text.AlignHCenter;text:previewTile.modelData.title;color:manager.fg;font.family:manager.family;font.pixelSize:12;font.weight:Font.DemiBold}
                Text{x:16;y:249;width:parent.width-32;horizontalAlignment:Text.AlignHCenter;text:previewTile.modelData.description;color:manager.secondary;font.family:manager.family;font.pixelSize:11;wrapMode:Text.WordWrap;maximumLineCount:2}
                Accessible.role:Accessible.Button;Accessible.name:"Add "+modelData.size+" "+manager.title(modelData.type)+" widget"
            }
            LiquidScrollBar{flick:previewGrid;anchors{right:parent.right;top:parent.top;bottom:parent.bottom}dark:manager.dark}
        }
        Text{x:220;anchors.bottom:parent.bottom;anchors.bottomMargin:22;width:parent.width-340;text:manager.error || "Drag here to move";color:manager.error?(manager.dark?"#ffb4ac":"#b42318"):manager.secondary;font.family:manager.family;font.pixelSize:12;elide:Text.ElideRight}
        MacButton{reduceMotion:manager.reduceMotion;dark:manager.dark;family:manager.family;anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:16;text:"Done";height:28;implicitWidth:76;highlighted:true;onClicked:manager.close()}
        } // animated gallery surface
        Shortcut{sequence:"Escape";context:Qt.ApplicationShortcut;enabled:gallery.visible && !editor.visible && !menu.visible;onActivated:manager.close()}
    }
}
