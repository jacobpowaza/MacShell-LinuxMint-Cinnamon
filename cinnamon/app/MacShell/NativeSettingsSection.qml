import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Column{
    id:section
    property string category:"general"
    property bool dark:true
    property bool reduceMotion:false
    property string family:"SF Pro Text"
    property var groups:[]
    property var expanded:({})
    property string error:""
    readonly property color fg:dark?"#f5f5f7":"#202023"
    readonly property color secondary:dark?"#b0b0b6":"#66666d"
    spacing:8
    function send(arg){if(!channel.connected || !category)return;channel.write(JSON.stringify({op:"mint-settings",arg:arg})+"\n");channel.flush();}
    function read(){send({action:"category",category:category});}
    function write(row,value){send({action:"category-write",category:category,schema:row.schema,key:row.key,value:value});}
    function title(name){return ({Launcher:"Memory",Sessionmanager:"Shutdown and Logout",Muffin:"Compositor",Wm:"Windows"})[name]||name;}
    function groupIcon(label) {
        var s = label.toLowerCase();
        if (/update/.test(s)) return ["arrow.clockwise", "#8E8E93"];
        if (/memory/.test(s)) return ["internaldrive", "#8E8E93"];
        if (/shutdown|logout|session/.test(s)) return ["power", "#8E8E93"];
        if (/compositor|effect|window/.test(s)) return ["macwindow", "#007AFF"];
        if (/accessibility|a11y/.test(s)) return ["person.crop.circle", "#007AFF"];
        if (/zoom/.test(s)) return ["magnifyingglass", "#007AFF"];
        if (/keyboard|typing|shortcut/.test(s)) return ["keyboard", "#8E8E93"];
        if (/pointer|mouse|touchpad|trackpad|touchscreen|gesture/.test(s)) return ["computermouse", "#8E8E93"];
        if (/privacy|lock|screen.?saver/.test(s)) return ["lock", "#007AFF"];
        if (/notification/.test(s)) return ["rectangle.3.group", "#FF3B30"];
        if (/sound|media/.test(s)) return ["speaker.wave.2", "#FF2D55"];
        if (/power|sleep|battery/.test(s)) return ["battery.100", "#34C759"];
        if (/background|wallpaper/.test(s)) return ["photo", "#30B0C7"];
        if (/display|color|night/.test(s)) return ["sun.max", "#007AFF"];
        if (/font|theme|interface|appearance/.test(s)) return ["slider.horizontal.3", "#8E8E93"];
        if (/application|extension|startup/.test(s)) return ["app.dashed", "#FF9500"];
        if (/calendar|date|time/.test(s)) return ["calendar", "#FF3B30"];
        if (/desktop|panel|workspace/.test(s)) return ["menubar.dock.rectangle", "#007AFF"];
        if (/user|account/.test(s)) return ["person.2", "#007AFF"];
        return ["gearshape", "#8E8E93"];
    }
    onCategoryChanged:{groups=[];expanded={};read();}
    Socket{id:channel;path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock";connected:true
        onConnectedChanged:if(connected)section.read()
        parser:SplitParser{onRead:text=>{try{var r=JSON.parse(text);if(!r.ok){section.error=r.error;return;}section.error="";if(r.value.category!==section.category)return;if(JSON.stringify(section.groups)!==JSON.stringify(r.value.groups))section.groups=r.value.groups;}catch(e){section.error="Unable to read these settings.";}}}
    }
    Timer{interval:2000;running:section.visible;repeat:true;onTriggered:section.read()}
    MacTextField{id:filter;width:parent.width;height:30;dark:section.dark;family:section.family;visible:section.groups.length>2;placeholderText:"Search "+section.category.charAt(0).toUpperCase()+section.category.slice(1);leftPadding:30
        SFIcon{x:10;anchors.verticalCenter:parent.verticalCenter;width:13;height:13;name:"search";color:section.secondary}
        background:Rectangle{radius:10;color:section.dark?"#12ffffff":"#09000000";border.width:filter.activeFocus?2:0;border.color:"#529afa"}
    }
    Repeater{
        model:section.groups
        Item{
            id:group
            required property var modelData
            required property int index
            width:section.width;height:42+reveal.height+8
            Rectangle{width:parent.width;height:parent.height-8;radius:12;color:section.dark?"#302f33":"#fefeff";border.width:1;border.color:section.dark?"#13ffffff":"#10000000"}
            readonly property bool open:(section.expanded[modelData.title]!==undefined?!!section.expanded[modelData.title]:(section.category==="general" && ["Compositor","Memory","Shutdown and Logout"].indexOf(modelData.title)>=0 || section.category==="apps" && modelData.title==="Default Applications")) || filter.text!==""
            readonly property var rows:modelData.rows.filter(r=>!filter.text||(r.name+" "+r.description).toLowerCase().includes(filter.text.toLowerCase()))
            visible:rows.length>0
            Rectangle{
                width:parent.width;height:42;radius:12;color:groupHover.hovered?(section.dark?"#0cffffff":"#06000000"):"transparent"
                HoverHandler{id:groupHover}
                SFIcon{anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter;width:12;height:12;name:"chevron.right";color:section.secondary;rotation:group.open?90:0;Behavior on rotation{NumberAnimation{duration:section.reduceMotion?0:220;easing.type:Easing.OutCubic}}}
                Rectangle{x:12;anchors.verticalCenter:parent.verticalCenter;width:26;height:26;radius:6;color:section.groupIcon(group.modelData.title)[1]
                    SFIcon{anchors.centerIn:parent;width:17;height:17;name:section.groupIcon(group.modelData.title)[0];color:"white"}
                }
                Text{x:48;width:parent.width-82;elide:Text.ElideRight;anchors.verticalCenter:parent.verticalCenter;text:section.title(group.modelData.title);font.family:section.family;font.pixelSize:13;font.weight:Font.DemiBold;color:section.fg}
                TapHandler{onTapped:{var a=Object.assign({},section.expanded);a[group.modelData.title]=!group.open;section.expanded=a;}}
                Accessible.role:Accessible.Button;Accessible.name:section.title(group.modelData.title)
            }
            Item{
                id:reveal;y:42;width:parent.width;clip:true;height:group.open?groupRows.implicitHeight:0
                opacity:group.open?1:0
                Behavior on height{NumberAnimation{duration:section.reduceMotion?0:260;easing.type:Easing.OutCubic}}
                Behavior on opacity{NumberAnimation{duration:section.reduceMotion?0:180;easing.type:Easing.OutCubic}}
                Column{id:groupRows;width:parent.width;spacing:0
                Repeater{
                    model:group.open||reveal.height>0?group.rows:[]
                    Rectangle{
                        id:row
                        required property var modelData
                        width:group.width;height:Math.max(50,labelColumn.height+22);color:"transparent"
                        Rectangle{x:14;width:parent.width-28;height:1;color:section.dark?"#16ffffff":"#13000000"}
                        Column{id:labelColumn;x:14;y:12;width:Math.max(130,parent.width-control.width-42);spacing:5
                            Text{width:parent.width;text:row.modelData.name;wrapMode:Text.WordWrap;font.family:section.family;font.pixelSize:13;color:section.fg}
                            Text{width:parent.width;text:row.modelData.description;visible:text!=="";wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;font.family:section.family;font.pixelSize:11;color:section.secondary}
                        }
                        Loader{
                            id:control;anchors.right:parent.right;anchors.rightMargin:14;anchors.verticalCenter:parent.verticalCenter
                            width:row.modelData.type==="b"?44:["i","u","d","n","q","x","t"].indexOf(row.modelData.type)>=0?112:Math.min(210,parent.width*0.45)
                            sourceComponent:row.modelData.type==="application"?applicationControl:row.modelData.type==="b"?booleanControl:row.modelData.range[0]==="enum"?enumControl:row.modelData.type==="a{sv}"?managedControl:editControl
                        }
                        Component{id:applicationControl;MacComboBox{reduceMotion:section.reduceMotion;dark:section.dark;family:section.family;model:row.modelData.options;textRole:"name";currentIndex:row.modelData.options.findIndex(a=>a.id===row.modelData.value);onActivated:section.write(row.modelData,row.modelData.options[currentIndex].id)}}
                        Component{id:booleanControl;Switch{
                            id:toggle;checked:row.modelData.value;enabled:row.modelData.writable;implicitHeight:28
                            indicator:Rectangle{width:40;height:22;radius:11;color:toggle.checked?"#34c759":section.dark?"#55555c":"#c7c7cc";Behavior on color{ColorAnimation{duration:section.reduceMotion?0:160}}
                            Rectangle{x:toggle.checked?20:2;Behavior on x{NumberAnimation{duration:section.reduceMotion?0:220;easing.type:Easing.OutCubic}} y:2;width:18;height:18;radius:9;color:"white"}}
                            onToggled:section.write(row.modelData,checked)
                        }}
                        Component{id:enumControl;MacComboBox{reduceMotion:section.reduceMotion;dark:section.dark;family:section.family;model:row.modelData.range[1];currentIndex:model.indexOf(row.modelData.value);enabled:row.modelData.writable;onActivated:section.write(row.modelData,currentText)}}
                        Component{id:managedControl;Text{text:"Managed by applications";color:section.secondary;font.family:section.family;font.pixelSize:11;wrapMode:Text.WordWrap}}
                        Component{id:editControl;MacTextField{
                            id:input;width:control.width;dark:section.dark;family:section.family;enabled:row.modelData.writable
                            readonly property string formatted:row.modelData.type==="as"?row.modelData.value.join(", "):typeof row.modelData.value==="string"?row.modelData.value:JSON.stringify(row.modelData.value)
                            text:formatted;selectByMouse:true
                            horizontalAlignment:["i","u","d","n","q","x","t"].indexOf(row.modelData.type)>=0?TextInput.AlignRight:TextInput.AlignLeft
                            onEditingFinished:{if(text===formatted)return;try{var t=row.modelData.type,v=t==="s"?text:t==="as"?(text.trim()?text.split(/,\s*/):[]):JSON.parse(text);section.write(row.modelData,v);}catch(e){section.error="Enter a valid value for "+row.modelData.name;}}
                        }}
                    }
                }
            }
            } // clipped group contents
        }
    }
    Text{width:parent.width;text:section.error;visible:text!=="";color:section.dark?"#ffb4ac":"#b42318";font.family:section.family;font.pixelSize:12;wrapMode:Text.WordWrap}
}
