// Cinnamon Finder adaptation: source MacShell materials with real filesystem actions.
import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "Cinnamon" as Cinnamon
import "Symbols.js" as Symbols

Scope {
    id: root
    property var hub: null
    signal closed()
    readonly property bool active: win.active
    readonly property bool trashMode: location===(hub && hub.trash ? hub.trash.path : home+"/.local/share/Trash/files")
    readonly property string home: Quickshell.env("HOME")
    readonly property bool dark: hub && hub.bar ? hub.bar.darkMode : true
    readonly property string fam: hub && hub.bar ? hub.bar.fontFamily : "SF Pro Text"
    readonly property color fg: dark ? "#f5f5f7" : "#1d1d1f"
    readonly property color secondary: dark ? "#a1a1a6" : "#68686d"
    readonly property color accent: hub && hub.bar ? hub.bar.accent : "#0a84ff"
    property string location: home
    property string folderUrl: "file://"+home
    property var history: []
    property int historyIndex: -1
    property var entries: []
    property var selected: ({})
    property int anchorIndex: -1
    property int currentIndex: -1
    property string pendingSelection: ""
    property string query: ""
    property bool hiddenFiles: false
    property bool listMode: false
    property string viewMode: "grid"
    property bool searchExpanded: false
    property var applicationEntries: []
    readonly property bool applicationMode: location==="applications:"
    readonly property bool collectionMode: location==="recent:" || location==="shared:" || location.indexOf("tag:")===0
    readonly property bool virtualMode:applicationMode || collectionMode
    property bool dragging:false
    property bool showPathBar:false
    property bool showStatusBar:false
    readonly property int footerHeight:(showPathBar?28:0)+(showStatusBar?28:0)
    property var selectedTags:[]
    property var tagNames:["Red","Orange","Yellow","Green","Blue","Purple","Gray"]
    property var mounts:[]
    readonly property var tagColors:({Red:"#ff5f57",Orange:"#ff9f0a",Yellow:"#ffd60a",Green:"#30d158",Blue:"#0a84ff",Purple:"#bf5af2",Gray:"#8e8e93"})
    function tagColor(name){return tagColors[name]||"#8e8e93";}
    function displayLocation(){return trashMode?"Trash":applicationMode?"Applications":location==="recent:"?"Recents":location==="shared:"?"Shared":location.indexOf("tag:")===0?location.substring(4):location===home?"Home":location==="/"?"File System":location.split('/').pop();}
    function dragUris(){return entries.filter(e=>selected[e.path]).map(e=>e.url || (e.path.indexOf("/")===0?"file://"+encodeURI(e.path).replace(/#/g,"%23").replace(/\?/g,"%3F"):"")).filter(u=>u!=="").join("\r\n");}
    function pinUrls(urls){var paths=[];for(var i=0;i<urls.length;i++){var u=String(urls[i]);if(u.indexOf("file:///")===0)paths.push(decodeURIComponent(u.substring(7)));}if(paths.length)call("favorites-add",{paths:paths});}
    function dropUrls(urls,destination,copy){var paths=[];for(var i=0;i<urls.length;i++){var u=String(urls[i]);if(u.indexOf("file:///")===0)paths.push(decodeURIComponent(u.substring(7)));}if(paths.length)call("transfer",{paths:paths,destination:destination,copy:copy});}
    function reloadCollection(){if(collectionMode)call("collection",{collection:location});}
    function refreshTags(){if(chosen().length && !applicationMode)call("tags-get",{paths:chosen()});}
    function toggleTag(tag){call("tags-set",{paths:chosen(),tag:tag,enabled:selectedTags.indexOf(tag)<0});}

    property string sortBy: "name"
    property bool reverseSort: false
    property string message: ""
    onMessageChanged:if(message!=="")errorDialog.open()
    property double freeBytes: 0
    property var queue: []
    property var currentRequest: null
    property var preview: null
    property bool quickLook: false
    property string sheet: ""
    onSheetChanged: { if(sheet!=="")nameDialog.open(); else { nameDialog.close(); Qt.callLater(function(){content.forceActiveFocus();}); } }
    onQuickLookChanged: if(!quickLook)Qt.callLater(function(){content.forceActiveFocus();})
    Component.onCompleted:call("favorites")
    property var places: [
        {label:"Applications",path:"applications:",icon:"applications"},
        {label:"Desktop",path:home+"/Desktop",icon:"user-desktop"},
        {label:"Documents",path:home+"/Documents",icon:"folder-documents"},
        {label:"Downloads",path:home+"/Downloads",icon:"folder-download"},
        {label:"Pictures",path:home+"/Pictures",icon:"folder-pictures"}
    ]
    function dateText(value){if(!value)return "—";return Qt.formatDateTime(typeof value==="string"?new Date(value):value,"d MMM yyyy, HH:mm");}
    function bytes(value) {
        if(value<1024)return value+" bytes";
        if(value<1048576)return (value/1024).toFixed(1)+" KB";
        if(value<1073741824)return (value/1048576).toFixed(1)+" MB";
        return (value/1073741824).toFixed(1)+" GB";
    }
    function icon(entry) {
        if(entry.icon)return entry.icon;
        if(entry.directory)return "folder";
        var suffix=entry.name.split('.').pop().toLowerCase();
        if(["png","jpg","jpeg","webp","gif","svg","bmp"].indexOf(suffix)>=0)return "image-x-generic";
        if(["mp3","wav","flac","ogg","m4a"].indexOf(suffix)>=0)return "audio-x-generic";
        if(["mp4","mkv","mov","webm"].indexOf(suffix)>=0)return "video-x-generic";
        if(suffix==="pdf")return "application-pdf";
        if(["zip","tar","gz","xz","7z"].indexOf(suffix)>=0)return "package-x-generic";
        return "text-x-generic";
    }
    function call(action,args) {
        var request=Object.assign({action:action,path:location},args || {});
        queue=queue.concat([request]);pump();
    }
    function pump() {
        if(currentRequest || !channel.connected || queue.length===0)return;
        currentRequest=queue[0];queue=queue.slice(1);
        channel.write(JSON.stringify({op:"filesystem",arg:currentRequest})+"\n");channel.flush();
    }
    function navigate(path,replaceHistory) {
        if(path && (path==="recent:" || path==="shared:" || path.indexOf("tag:")===0)){location=path;selected={};query="";search.text="";if(!replaceHistory){var h=history.slice(0,historyIndex+1);h.push(path);history=h;historyIndex=h.length-1;}reloadCollection();return;}
        if(path==="applications:"){location=path;selected={};query="";search.text="";if(!replaceHistory){var h=history.slice(0,historyIndex+1);if(h[h.length-1]!==path)h.push(path);history=h;historyIndex=h.length-1;}call("applications");return;}
        message="";quickLook=false;
        call("info",{path:path || home,replaceHistory:!!replaceHistory});
    }
    function open(path) { win.visible=true;win.raise();win.requestActivate();navigate(path || location); }
    function goBack(delta) {
        var index=historyIndex+delta;
        if(index<0 || index>=history.length)return;
        historyIndex=index;navigate(history[index],true);
    }
    function rebuild() {
        var rows=[],filter=query.toLocaleLowerCase();
        if(virtualMode){var virtualRows=applicationEntries.filter(e=>!filter||e.name.toLocaleLowerCase().includes(filter));var keep={};for(var j=0;j<virtualRows.length;j++)if(selected[virtualRows[j].path])keep[virtualRows[j].path]=true;entries=virtualRows;selected=keep;anchorIndex=-1;currentIndex=-1;return;}
        for(var i=0;i<files.count;i++) {
            var name=files.get(i,"fileName");
            if(filter && name.toLocaleLowerCase().indexOf(filter)<0)continue;
            rows.push({name:name,path:files.get(i,"filePath"),url:String(files.get(i,"fileUrl")),directory:files.get(i,"fileIsDir"),size:Number(files.get(i,"fileSize")),modified:files.get(i,"fileModified")});
        }
        var anchorPath=anchorIndex>=0 && anchorIndex<entries.length ? entries[anchorIndex].path : "";
        var currentPath=currentIndex>=0 && currentIndex<entries.length ? entries[currentIndex].path : "";
        entries=rows;
        anchorIndex=rows.findIndex(e=>e.path===anchorPath);
        currentIndex=rows.findIndex(e=>e.path===currentPath);
        var existing={};for(var i=0;i<rows.length;i++)if(selected[rows[i].path])existing[rows[i].path]=true;
        selected=existing;
        if(pendingSelection) {
            var pendingIndex=rows.findIndex(e=>e.path===pendingSelection);
            if(pendingIndex>=0) {
                var next={};next[pendingSelection]=true;selected=next;
                anchorIndex=pendingIndex;currentIndex=pendingIndex;pendingSelection="";
            }
        }
    }
    function select(index,modifiers) {
        if(index<0 || index>=entries.length)return;
        var next={},path=entries[index].path;
        if(modifiers & Qt.ShiftModifier && anchorIndex>=0) {
            for(var i=Math.min(index,anchorIndex);i<=Math.max(index,anchorIndex);i++)next[entries[i].path]=true;
        } else if(modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
            next=Object.assign({},selected);if(next[path])delete next[path];else next[path]=true;
            anchorIndex=index;
        } else {next[path]=true;anchorIndex=index;}
        currentIndex=index;selected=next;refreshTags();content.forceActiveFocus();
    }
    function chosen() { return Object.keys(selected); }
    function first() {
        for(var i=0;i<entries.length;i++)if(selected[entries[i].path])return entries[i];
        return null;
    }
    function activate(entry) {
        if(!entry)return;
        if(entry.application)Cinnamon.Host.launchDesktop(entry.path);
        else if(entry.directory)navigate(entry.path);
        else Cinnamon.Host.execDetached(["xdg-open",entry.path]);
    }
    function copy(cut) { if(!applicationMode && chosen().length)call("clipboard",{paths:chosen(),cut:cut}); }
    function trash() { if(trashMode){if(chosen().length)confirmPermanent(false);}else if(!applicationMode && chosen().length)call("trash",{paths:chosen()}); }
    property bool emptyingAll:false
    property var permanentPaths:[]
    function confirmPermanent(all){emptyingAll=all;permanentPaths=chosen().slice();permanentDialog.open();}
    function showPreview() {
        var entry=first();if(!entry || entry.application)return;
        call("preview",{path:entry.path});
    }
    function nameSheet(mode) {
        var entry=first();if(mode==="rename" && !entry)return;
        sheet=mode;nameInput.text=mode==="rename" ? entry.name : mode==="tag"?"":"untitled folder";
        Qt.callLater(function(){nameInput.forceActiveFocus();nameInput.selectAll();});
    }
    function commitName() {
        var mode=sheet;if(mode==="tag"){sheet="";call("tags-set",{paths:chosen(),tag:nameInput.text.trim(),enabled:true});return;}if(mode!=="rename" && mode!=="mkdir")return;sheet="";
        call(mode==="rename" ? "rename" : "mkdir",{path:mode==="rename" ? first().path : location,name:nameInput.text});
    }
    property string typedPrefix: ""
    property real lastTypedAt: 0
    function revealIndex(index) {
        if(listMode)list.positionViewAtIndex(index,ListView.Contain);
        else if(viewMode==="grid")grid.positionViewAtIndex(index,GridView.Contain);
        else if(alternateViews.item)alternateViews.item.revealIndex(index);
    }
    function jumpToName(text) {
        if(!entries.length)return;
        var letter=text.toLocaleLowerCase(), now=Date.now();
        var cycle=typedPrefix===letter;
        var prefix=now-lastTypedAt<900 && !cycle?typedPrefix+letter:letter;
        function find(prefix,start) {
            for(var n=0;n<entries.length;n++) {
                var i=(Math.max(0,start)+n)%entries.length;
                if(entries[i].name.toLocaleLowerCase().indexOf(prefix)===0)return i;
            }
            return -1;
        }
        var index=find(prefix,prefix.length>1?currentIndex:currentIndex+1);
        if(index<0 && prefix.length>1){prefix=letter;index=find(prefix,currentIndex+1);}
        typedPrefix=prefix;lastTypedAt=now;
        if(index>=0){select(index,0);revealIndex(index);}
    }
    function keyboardMove(delta,extend) {
        if(!entries.length)return;
        var index=currentIndex<0 ? 0 : Math.max(0,Math.min(entries.length-1,currentIndex+delta));
        select(index,extend ? Qt.ShiftModifier : 0);
        revealIndex(index);
    }
    function contextFor(index,gx,gy){if(index>=0 && !selected[entries[index].path])select(index,0);refreshTags();fileMenu.show(contextRows(),gx,gy);}
    function contextRows(){var one=chosen().length===1,any=chosen().length>0;
        if(trashMode)return [{label:"Put Back",action:"restore",disabled:!any},{label:"Delete Immediately…",action:"trash",danger:true,disabled:!any},{separator:true},{label:"Empty Trash…",action:"empty-trash",danger:true,disabled:hub && hub.trash ? hub.trash.count===0 : !entries.length},{separator:true},{label:"Sort By",children:sortRows()}];
        var tags=tagNames.map(t=>({label:t,action:"tag:"+t,icon:"",dot:tagColor(t),checked:selectedTags.indexOf(t)>=0}));tags.push({separator:true},{label:"New Tag…",action:"newtag"});
        if(!any)return [{label:"New Folder",action:"mkdir",disabled:virtualMode},{separator:true},{label:"Get Info",action:"info"},{label:"Paste",action:"paste",disabled:virtualMode},{separator:true},{label:"Sort By",children:sortRows()},{label:"Show View Options",children:viewRows()}];
        return [{label:"Open",action:"open"},{label:"Quick Look",action:"preview",disabled:applicationMode},{label:"Get Info",action:"info",disabled:applicationMode},{separator:true},{label:"Move to Trash",action:"trash",danger:true,disabled:applicationMode},{label:"Put Back",action:"restore",disabled:!trashMode},{separator:true},{label:"Rename…",action:"rename",disabled:!one||applicationMode},{label:"Copy",action:"copy",disabled:applicationMode},{label:"Cut",action:"cut",disabled:applicationMode},{label:"Paste",action:"paste",disabled:virtualMode},{separator:true},{label:"Tags",icon:"tag",children:tags,disabled:applicationMode}];
    }
    function sortRows(){return [{label:"Name",action:"sort:name",checked:sortBy==="name"},{label:"Date Modified",action:"sort:modified",checked:sortBy==="modified"},{label:"Size",action:"sort:size",checked:sortBy==="size"},{label:"Kind",action:"sort:kind",checked:sortBy==="kind"},{separator:true},{label:"Reverse Order",action:"reverse",checked:reverseSort}];}
    function viewRows(){return [{label:"Icon View",action:"view:grid",icon:"grid",checked:!listMode && viewMode==="grid"},{label:"List View",action:"view:list",icon:"list",checked:listMode},{label:"Column View",action:"view:columns",icon:"columns",checked:!listMode && viewMode==="columns"},{label:"Gallery View",action:"view:gallery",icon:"gallery",checked:!listMode && viewMode==="gallery"},{separator:true},{label:"Show Hidden Files",action:"hidden",checked:hiddenFiles},{label:"Show Path Bar",action:"pathbar",checked:showPathBar},{label:"Show Status Bar",action:"statusbar",checked:showStatusBar}];}
    function runContext(entry){var a=entry.action||"";if(a.indexOf("tag:")===0)toggleTag(a.substring(4));else if(a.indexOf("sort:")===0)sortBy=a.substring(5);else if(a.indexOf("view:")===0){viewMode=a.substring(5);listMode=viewMode==="list";}else if(a==="reverse")reverseSort=!reverseSort;else if(a==="hidden")hiddenFiles=!hiddenFiles;else if(a==="pathbar")showPathBar=!showPathBar;else if(a==="statusbar")showStatusBar=!showStatusBar;else if(a==="newtag")nameSheet("tag");else if(a==="open")activate(first());else if(a==="preview")showPreview();else if(a==="info")hub.finder.info(first()?first().path:virtualMode?home:location);else if(a==="copy")copy(false);else if(a==="cut")copy(true);else if(a==="paste")call("paste");else if(a==="empty-trash")confirmPermanent(true);else if(a==="trash")trash();else if(a==="restore")call("restore",{paths:chosen()});else if(a==="mkdir"||a==="rename")nameSheet(a);}
    function openSortMenu(){var p=toolbar.mapToGlobal(toolbar.width-110,toolbar.height);sortMenu.show([{label:"New Folder",action:"mkdir",disabled:virtualMode},{separator:true},{label:"Sort By",children:sortRows()},{label:"View",children:viewRows()}],p.x,p.y);}

    function setQuery(value){query=value;search.text=value;}
    function setSort(key) {sortBy=key;sortMenu.close();}
    function state() {return JSON.stringify({path:location,items:entries.map(e=>({name:e.name,path:e.path,directory:e.directory})),selection:chosen(),listMode:listMode,hiddenFiles:hiddenFiles,message:message,busy:!!currentRequest,quickLook:quickLook,previewMime:preview?preview.mime:"",fontFamily:fam,viewMode:viewMode,menuVisible:fileMenu.visible,menuFocus:fileMenu.diagnostics(),menuX:fileMenu.x+fileMenu.shadowPad,menuY:fileMenu.y+fileMenu.shadowPad,tags:selectedTags,tagNames:tagNames,favorites:places,geometry:{x:win.x,y:win.y,width:win.width,height:win.height,gridX:grid.mapToGlobal(0,0).x,gridY:grid.mapToGlobal(0,0).y,cellWidth:grid.cellWidth,cellHeight:grid.cellHeight}});}
    property Socket channel: Socket {
        path:Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected:true
        onConnectedChanged: if(connected)root.pump()
        parser:SplitParser {onRead:data=>{
            var request=root.currentRequest;root.currentRequest=null;
            try {
                var reply=JSON.parse(data);
                if(!reply.ok)root.message=reply.error || "The operation could not be completed.";
                else {
                    var value=reply.value;
                    if(request.action==="applications" || request.action==="collection"){root.applicationEntries=value;root.rebuild();}
                    else if(request.action==="locations")root.mounts=value;
                    else if(request.action.indexOf("favorites")===0)root.places=value;
                    else if(request.action==="tags-get"){root.selectedTags=value.tags;if(value.names)root.tagNames=value.names;if(fileMenu.visible)fileMenu.rows=root.contextRows();}
                    else if(request.action==="tags-set"){root.selectedTags=value.tags;root.call("tags-get",{paths:root.chosen()});root.reloadCollection();}
                    else if(request.action==="info") {
                        root.location=value.path;root.folderUrl=value.url;root.freeBytes=value.free;
                        root.selected={};root.anchorIndex=-1;root.currentIndex=-1;root.query="";search.text="";
                        if(!request.replaceHistory) {
                            var history=root.history.slice(0,root.historyIndex+1);
                            if(history[history.length-1]!==value.path)history.push(value.path);
                            root.history=history;root.historyIndex=history.length-1;
                        }
                        rebuildSoon.restart();
                    } else if(request.action==="preview") {root.preview=value;root.quickLook=true;}
                    else if(request.action==="clipboard")root.message="";
                    else {
                        if(request.action==="rename" || request.action==="mkdir")root.pendingSelection=value.path;
                        root.message="";if(root.collectionMode)root.reloadCollection();else rebuildSoon.restart();
                        if(root.hub && root.hub.trash)root.hub.trash.refresh();
                    }
                }
            }catch(error){root.message=String(error);}
            root.pump();
        }}
    }
    Timer{interval:30000;running:win.visible;repeat:true;triggeredOnStart:true;onTriggered:{root.call("locations");if(root.collectionMode)root.reloadCollection();}}
    FolderListModel {
        id:files
        folder:root.folderUrl
        showDotAndDotDot:false
        showDirsFirst:true
        showHidden:root.hiddenFiles
        sortCaseSensitive:false
        sortField:root.sortBy==="modified" ? FolderListModel.Time : root.sortBy==="size" ? FolderListModel.Size : root.sortBy==="kind" ? FolderListModel.Type : FolderListModel.Name
        sortReversed:root.reverseSort
        onCountChanged:rebuildSoon.restart()
        onStatusChanged:if(status===FolderListModel.Ready)rebuildSoon.restart()
    }
    Connections {target:files;function onDataChanged(){rebuildSoon.restart();}function onModelReset(){rebuildSoon.restart();}}
    Timer {id:rebuildSoon;interval:100;onTriggered:root.rebuild()}
    onQueryChanged:rebuildSoon.restart()
    component Glyph: Canvas {
        property string kind:""
        property color ink:root.fg
        width:18;height:18;antialiasing:true
        SFIcon{anchors.fill:parent;name:Symbols.symbol(parent.kind);color:parent.ink}
        onKindChanged:requestPaint();onInkChanged:requestPaint()
        onPaint:{
            var c=getContext("2d");c.reset();if(Symbols.symbol(kind)!=="")return;c.strokeStyle=ink;c.fillStyle=ink;c.lineWidth=1.6;c.lineCap="round";c.lineJoin="round";
            function line(x,y,a,b){c.beginPath();c.moveTo(x,y);c.lineTo(a,b);c.stroke();}
            function rect(x,y,w,h){c.strokeRect(x,y,w,h);}
            if(kind==="back" || kind==="forward"){var k=kind==="back"?1:-1,o=kind==="back"?0:18;line(o+11*k,4,o+6*k,9);line(o+6*k,9,o+11*k,14);}
            else if(kind==="up"){line(4,10,9,5);line(9,5,14,10);}
            else if(kind==="applications"){line(3,15,9,3);line(9,3,15,15);line(3,11,15,11);}
            else if(kind==="grid"){for(var x=3;x<14;x+=7)for(var y=3;y<14;y+=7)rect(x,y,4,4);}
            else if(kind==="list"){for(var y=4;y<15;y+=5){line(6,y,15,y);c.fillRect(2,y-1,2,2);}}
            else if(kind==="columns"){rect(2,3,14,12);line(7,3,7,15);line(12,3,12,15);}
            else if(kind==="gallery"){rect(2,3,14,9);for(var x=2;x<17;x+=4)c.fillRect(x,14,2,2);}
            else if(kind==="search"){c.beginPath();c.arc(7.5,7.5,4.7,0,Math.PI*2);c.stroke();line(11,11,15,15);}
            else if(kind==="more"){for(var x=3;x<17;x+=6){c.beginPath();c.arc(x,9,1.2,0,Math.PI*2);c.fill();}}
            else if(kind==="new"){line(4,9,14,9);line(9,4,9,14);}
            else if(kind==="user-home"){line(2,8,9,2);line(9,2,16,8);line(4,7,4,16);line(4,16,14,16);line(14,16,14,7);rect(7,11,4,5);}
            else if(kind==="user-desktop"){rect(2,3,14,10);line(9,13,9,16);line(6,16,12,16);}
            else if(kind==="folder-documents"){rect(4,2,10,14);line(7,6,11,6);line(7,9,11,9);line(7,12,10,12);}
            else if(kind==="folder-download"){c.beginPath();c.arc(9,9,7,0,Math.PI*2);c.stroke();line(9,4,9,13);line(6,10,9,13);line(9,13,12,10);}
            else if(kind==="folder-pictures"){rect(2,3,14,12);c.beginPath();c.arc(12,6,1,0,Math.PI*2);c.stroke();line(3,13,7,8);line(7,8,12,14);line(10,11,13,8);line(13,8,16,12);}
            else if(kind==="folder-music"){line(7,4,14,2);line(7,4,7,13);line(14,2,14,11);c.beginPath();c.ellipse(5,14,2,1.5,0,0,Math.PI*2);c.stroke();c.beginPath();c.ellipse(12,12,2,1.5,0,0,Math.PI*2);c.stroke();}
            else if(kind==="folder-videos"){rect(2,3,14,12);line(5,3,5,15);line(13,3,13,15);line(2,7,5,7);line(2,11,5,11);line(13,7,16,7);line(13,11,16,11);}
            else if(kind==="drive-harddisk"){rect(3,3,12,12);line(3,11,15,11);c.beginPath();c.arc(12,13,0.6,0,Math.PI*2);c.fill();}
            else if(kind==="trash"){line(3,5,15,5);rect(5,5,8,10);line(7,2,11,2);line(8,8,8,12);line(11,8,11,12);}
        }
    }
    component Tool: Rectangle {
        property string glyph:""
        property string tip:""
        property bool active:false
        signal clicked()
        width:30;height:28;radius:7
        color:active ? (root.dark?"#58585d":"#ffffff") : (toolHover.hovered?(root.dark?"#15ffffff":"#0d000000"):"transparent")
        opacity:enabled?1:0.3
        Glyph {anchors.centerIn:parent;kind:parent.glyph}
        HoverHandler{id:toolHover}
        TapHandler{onTapped:parent.clicked()}
        MacToolTip { reduceMotion:root.hub && root.hub.bar?root.hub.bar.reduceMotion:false; visible: toolHover.hovered && parent.tip!==""; text: parent.tip; dark: root.dark; family: root.fam }
        Accessible.role:Accessible.Button;Accessible.name:tip
    }
    component Label: Text {font.family:root.fam;font.pixelSize:13;color:root.fg}
    component PlaceRow:Rectangle{
        id:placeRow;property var place:({});property bool favorite:false
        width:sidebarList.width;height:30;radius:8
        color:placeDrop.containsDrag?"#400a84ff":root.location===place.path?(root.dark?"#4b5866":"#dce8ee"):placeHover.hovered?(root.dark?"#12ffffff":"#0a000000"):"transparent"
        SFIcon{x:8;anchors.verticalCenter:parent.verticalCenter;width:18;height:18;name:place.icon||"folder";color:root.location===place.path?root.accent:root.fg;visible:!place.tag}
        Rectangle{x:13;anchors.verticalCenter:parent.verticalCenter;width:10;height:10;radius:5;color:place.tag?root.tagColor(place.tag):"transparent";visible:!!place.tag}
        Label{x:34;width:parent.width-42;anchors.verticalCenter:parent.verticalCenter;text:place.label||"";elide:Text.ElideRight;color:root.location===place.path?root.accent:root.fg}
        HoverHandler{id:placeHover}
        TapHandler{acceptedButtons:Qt.LeftButton;onTapped:root.navigate(place.path)}
        TapHandler{acceptedButtons:Qt.RightButton;onTapped:event=>{if(!placeRow.favorite)return;var p=placeRow.mapToGlobal(event.position.x,event.position.y);sidebarMenu.show([{label:"Open",action:"open-place",path:place.path},{separator:true},{label:"Remove from Sidebar",action:"unpin",path:place.path}],p.x,p.y);}}
        DropArea{id:placeDrop;anchors.fill:parent;enabled:place.path && place.path.indexOf('/')===0;onEntered:d=>{d.accepted=d.hasUrls;};onDropped:d=>{if(d.hasUrls){if(place.icon==="trash")root.call("trash",{paths:d.urls.map(u=>decodeURIComponent(String(u).substring(7)))});else if(placeRow.favorite && !root.applicationMode)root.pinUrls(d.urls);else root.dropUrls(d.urls,place.path,d.proposedAction===Qt.CopyAction);d.acceptProposedAction();}}}
    }
    component Action: MenuItem {
        id:actionRow
        font.family:root.fam;font.pixelSize:13;implicitHeight:27
        contentItem:Text{text:actionRow.text;font:actionRow.font;leftPadding:23;rightPadding:10;verticalAlignment:Text.AlignVCenter;color:!actionRow.enabled?root.secondary:actionRow.highlighted?"white":root.fg}
        background:Rectangle{radius:6;color:actionRow.highlighted && actionRow.enabled?root.accent:"transparent"}
    }
    Window {
        id:win
        title:"Finder"
        width:1000;height:520;minimumWidth:760;minimumHeight:450
        visible:false;color:"transparent";flags:Qt.Window|Qt.FramelessWindowHint
        Component.onCompleted:{var s=Quickshell.screens[0];if(s){x=s.x+Math.round((s.width-width)/2);y=s.y+Math.round((s.height-height)/2);}}
        onClosing: function(close){close.accepted=false;visible=false;root.closed();}
        Item{id:sidebarMask;width:174;height:win.height-16;visible:false;layer.enabled:true;Rectangle{anchors.fill:parent;radius:17;color:"white"}}
        Item{id:windowMask;anchors.fill:parent;visible:false;layer.enabled:true;Rectangle{anchors.fill:parent;radius:22;color:"white"}}
        Rectangle {
            id:frame
            anchors.fill:parent;radius:22;clip:true
            layer.enabled:true
            layer.effect:MultiEffect{maskEnabled:true;maskSource:windowMask;maskThresholdMin:0.5;maskSpreadAtMin:1}
            color:root.dark?"#1e1e20":"#ffffff"
            border.width:1;border.color:root.dark?"#26ffffff":"#26000000"
            Rectangle {
                id:sidebar
                x:8;y:8;width:174;height:parent.height-16;radius:17;clip:true
                color:root.dark?"#292929":"#e9e9ec"
                layer.enabled:true
                layer.effect:MultiEffect{maskEnabled:true;maskSource:sidebarMask;maskThresholdMin:0.5;maskSpreadAtMin:1}
                CinnamonFrost {anchors.fill:parent;window:win;z:0}
                Rectangle{anchors.fill:parent;color:root.dark?"#88292929":"#b3e9e9ec"}
                Row {
                    x:12;y:12;spacing:8
                    Repeater {
                        model:["#ff5f57","#febc2e","#28c840"]
                        Rectangle {
                            required property string modelData;required property int index
                            width:14;height:14;radius:7;color:win.active?modelData:(root.dark?"#656568":"#b4b4b8")
                            TapHandler{onTapped:{if(index===0)win.close();else if(index===1)win.showMinimized();else if(win.visibility===Window.Maximized)win.showNormal();else win.showMaximized();}}
                            Accessible.role:Accessible.Button;Accessible.name:index===0?"Close":index===1?"Minimize":"Maximize"
                        }
                    }
                }
                MouseArea{x:85;y:0;width:parent.width-85;height:55;onPressed:win.startSystemMove();onDoubleClicked:win.visibility===Window.Maximized?win.showNormal():win.showMaximized()}
                Flickable{
                    id:sideFlick;x:7;y:55;width:parent.width-14;height:parent.height-65;contentHeight:sidebarList.height;clip:true
                    Column{id:sidebarList;width:sideFlick.width;spacing:3
                        PlaceRow{place:({label:"Shared",path:"shared:",icon:"shared"})}
                        PlaceRow{place:({label:"Recents",path:"recent:",icon:"clock"})}
                        Item{width:1;height:10}
                        Label{x:10;text:"Favorites";font.pixelSize:11;font.weight:Font.DemiBold;color:root.secondary}
                        Item{width:1;height:3}
                        Item{width:parent.width;height:favoriteRows.height+20
                            Column{id:favoriteRows;width:parent.width;Repeater{model:root.places;PlaceRow{required property var modelData;place:modelData;favorite:true}}}
                            DropArea{anchors.fill:parent;z:-1;onEntered:d=>{d.accepted=d.hasUrls;};onDropped:d=>{if(d.hasUrls){root.pinUrls(d.urls);d.acceptProposedAction();}}}
                            Rectangle{anchors.fill:parent;radius:8;color:"#220a84ff";visible:favoriteDrop.containsDrag;z:-2}
                            DropArea{id:favoriteDrop;x:0;y:favoriteRows.height;width:parent.width;height:20;onEntered:d=>{d.accepted=d.hasUrls;};onDropped:d=>{if(d.hasUrls){root.pinUrls(d.urls);d.acceptProposedAction();}}}
                        }
                        Item{width:1;height:12}
                        Label{x:10;text:"Locations";font.pixelSize:11;font.weight:Font.DemiBold;color:root.secondary}
                        PlaceRow{place:({label:root.home.split("/").pop(),path:root.home,icon:"house"})}
                        PlaceRow{place:({label:"File System",path:"/",icon:"internaldrive"})}
                        Repeater{model:root.mounts;PlaceRow{required property var modelData;place:modelData}}
                        PlaceRow{place:({label:"Trash",path:root.hub && root.hub.trash ? root.hub.trash.path : root.home+"/.local/share/Trash/files",icon:"trash"})}
                        Item{width:1;height:12}
                        Label{x:10;text:"Tags";font.pixelSize:11;font.weight:Font.DemiBold;color:root.secondary}
                        Repeater{model:root.tagNames;PlaceRow{required property string modelData;place:({label:modelData,path:"tag:"+modelData,tag:modelData})}}
                        Item{width:1;height:10}
                    }
                    LiquidScrollBar{flick:sideFlick;anchors{right:parent.right;top:parent.top;bottom:parent.bottom}dark:root.dark}
                }
            }
            Rectangle {
                id:toolbar
                x:194;y:4;width:parent.width-x-12;height:44
                color:"transparent"
                MouseArea{anchors.fill:parent;onPressed:win.startSystemMove();onDoubleClicked:win.visibility===Window.Maximized?win.showNormal():win.showMaximized()}
                Rectangle{x:0;anchors.verticalCenter:parent.verticalCenter;width:76;height:36;radius:18;color:root.dark?"#353538":"#f6f6f7"
                    Row{anchors.centerIn:parent;spacing:2
                        Tool{glyph:"back";tip:"Back";width:32;height:32;enabled:root.historyIndex>0;onClicked:root.goBack(-1)}
                        Tool{glyph:"forward";tip:"Forward";width:32;height:32;enabled:root.historyIndex<root.history.length-1;onClicked:root.goBack(1)}
                    }
                }
                Label{x:90;anchors.verticalCenter:parent.verticalCenter;width:Math.max(60,parent.width-controls.width-104);elide:Text.ElideRight;text:root.displayLocation();font.pixelSize:16;font.weight:Font.DemiBold}
                Row{id:controls;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;spacing:10
                    MacButton { reduceMotion:root.hub && root.hub.bar ? root.hub.bar.reduceMotion : false; visible:root.trashMode; text:"Empty Trash…"; dark:root.dark; family:root.fam; enabled:root.hub && root.hub.trash ? root.hub.trash.count>0 : root.entries.length>0; onClicked:root.confirmPermanent(true) }
                    Rectangle{width:148;height:36;radius:18;color:root.dark?"#353538":"#f6f6f7"
                        Row{anchors.centerIn:parent;spacing:2
                            Tool{glyph:"grid";tip:"Icon view";width:32;height:30;active:!root.listMode && root.viewMode==="grid";onClicked:{root.viewMode="grid";root.listMode=false;}}
                            Tool{glyph:"list";tip:"List view";width:32;height:30;active:root.listMode;onClicked:{root.listMode=true;root.viewMode="list";}}
                            Tool{glyph:"columns";tip:"Column view";width:32;height:30;active:!root.listMode && root.viewMode==="columns";onClicked:{root.viewMode="columns";root.listMode=false;}}
                            Tool{glyph:"gallery";tip:"Gallery view";width:32;height:30;active:!root.listMode && root.viewMode==="gallery";onClicked:{root.viewMode="gallery";root.listMode=false;}}
                        }
                    }
                    Rectangle{width:38;height:36;radius:18;color:root.dark?"#353538":"#f6f6f7";Tool{anchors.centerIn:parent;glyph:"more";tip:"Actions and sorting";onClicked:root.openSortMenu()}}
                    Rectangle{
                        id:searchBox
                        width:root.searchExpanded?170:36;height:36;radius:18;color:root.dark?"#353538":"#f6f6f7"
                        Tool{visible:!root.searchExpanded;anchors.centerIn:parent;glyph:"search";tip:"Search";onClicked:{root.searchExpanded=true;search.forceActiveFocus();}}
                        Glyph{visible:root.searchExpanded;x:10;anchors.verticalCenter:parent.verticalCenter;kind:"search";ink:root.secondary}
                        TextField{id:search;visible:root.searchExpanded;x:34;width:parent.width-40;height:parent.height;padding:0;verticalAlignment:Text.AlignVCenter;font.family:root.fam;font.pixelSize:13;color:root.fg;placeholderText:"Search";placeholderTextColor:root.secondary;background:null;selectByMouse:true;onTextChanged:root.query=text;onActiveFocusChanged:if(!activeFocus && !text)root.searchExpanded=false}
                    }
                }
            }
            Item {
                id:content
                x:194;y:64;width:parent.width-x-8;height:parent.height-y-root.footerHeight-8
                focus:true
                Keys.onPressed:function(event){
                    if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter){root.activate(root.first());event.accepted=true;}
                    else if(event.key===Qt.Key_Space){root.showPreview();event.accepted=true;}
                    else if(event.key===Qt.Key_Delete){root.trash();event.accepted=true;}
                    else if(event.key===Qt.Key_Backspace){root.navigate(String(files.parentFolder));event.accepted=true;}
                    else if(event.key===Qt.Key_F2){root.nameSheet("rename");event.accepted=true;}
                    else if(event.key===Qt.Key_Right){root.keyboardMove(1,event.modifiers & Qt.ShiftModifier);event.accepted=true;}
                    else if(event.key===Qt.Key_Left){root.keyboardMove(-1,event.modifiers & Qt.ShiftModifier);event.accepted=true;}
                    else if(event.key===Qt.Key_Down){root.keyboardMove(root.listMode?1:Math.max(1,Math.floor(grid.width/grid.cellWidth)),event.modifiers & Qt.ShiftModifier);event.accepted=true;}
                    else if(event.key===Qt.Key_Up){root.keyboardMove(root.listMode?-1:-Math.max(1,Math.floor(grid.width/grid.cellWidth)),event.modifiers & Qt.ShiftModifier);event.accepted=true;}
                    else if(!(event.modifiers & (Qt.ControlModifier|Qt.MetaModifier|Qt.AltModifier)) && event.text.length===1 && /[a-z0-9]/i.test(event.text)){root.jumpToName(event.text);event.accepted=true;}
                }
                MouseArea{anchors.fill:parent;z:-1;acceptedButtons:Qt.LeftButton|Qt.RightButton;onClicked:m=>{if(m.button===Qt.RightButton){var p=mapToGlobal(m.x,m.y);root.selected={};root.contextFor(-1,p.x,p.y);}else{root.selected={};content.forceActiveFocus();}}}
                DropArea{anchors.fill:parent;enabled:!root.virtualMode;onEntered:d=>{d.accepted=d.hasUrls;};onDropped:d=>{if(d.hasUrls){root.dropUrls(d.urls,root.location,d.proposedAction===Qt.CopyAction);d.acceptProposedAction();}}}
                GridView {
                    id:grid
                    anchors.fill:parent;anchors.margins:12
                    visible:!root.listMode && root.viewMode==="grid"
                    model:visible?root.entries:[]
                    cellWidth:Math.floor(width/Math.max(1,Math.floor(width/124)));cellHeight:116;clip:true
                    delegate:Item {
                        required property var modelData;required property int index
                        width:grid.cellWidth;height:116
                        Rectangle{width:76;height:72;anchors.horizontalCenter:parent.horizontalCenter;y:1;radius:5;color:root.selected[modelData.path]?(root.dark?"#365573":"#d3d6da"):"transparent"}
                        Image{width:58;height:58;anchors.horizontalCenter:parent.horizontalCenter;y:8;source:Quickshell.iconPath(root.icon(modelData));sourceSize:Qt.size(64,64);smooth:true}
                        Label{id:fileName;x:(parent.width-width)/2;y:78;width:Math.min(parent.width-14,implicitWidth+6);leftPadding:3;rightPadding:3;text:modelData.name;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideMiddle;maximumLineCount:2;wrapMode:Text.WrapAnywhere;font.pixelSize:13;color:root.selected[modelData.path]?"white":root.fg;Rectangle{anchors.fill:parent;z:-1;radius:3;color:root.selected[modelData.path]?root.accent:"transparent"}}
                        FinderDragArea{anchors.fill:parent;finder:root;entry:modelData;rowIndex:index}
                    }
                    MouseArea{
                        id:marquee;anchors.fill:parent;z:10;acceptedButtons:Qt.LeftButton|Qt.RightButton;preventStealing:true
                        property real startX:0;property real startY:0;property real endX:0;property real endY:0;property bool selecting:false;property var base:({})
                        function updateSelection(){var next=Object.assign({},base),left=Math.min(startX,endX)+grid.contentX,top=Math.min(startY,endY)+grid.contentY,right=Math.max(startX,endX)+grid.contentX,bottom=Math.max(startY,endY)+grid.contentY,cols=Math.max(1,Math.floor(grid.width/grid.cellWidth));for(var i=0;i<root.entries.length;i++){var cx=(i%cols)*grid.cellWidth,cy=Math.floor(i/cols)*grid.cellHeight;if(cx+grid.cellWidth-8>left&&cx+8<right&&cy+106>top&&cy+4<bottom)next[root.entries[i].path]=true;}root.selected=next;}
                        onPressed:m=>{var i=grid.indexAt(m.x+grid.contentX,m.y+grid.contentY);if(m.button===Qt.RightButton)return;if(i>=0){m.accepted=false;return;}startX=endX=m.x;startY=endY=m.y;base=m.modifiers&(Qt.ControlModifier|Qt.MetaModifier|Qt.ShiftModifier)?Object.assign({},root.selected):({});root.selected=base;selecting=true;content.forceActiveFocus();}
                        onPositionChanged:m=>{if(selecting&&pressed){endX=m.x;endY=m.y;updateSelection();}}
                        onClicked:m=>{if(m.button===Qt.RightButton){var i=grid.indexAt(m.x+grid.contentX,m.y+grid.contentY);if(i<0)root.selected={};var p=mapToGlobal(m.x,m.y);root.contextFor(i,p.x,p.y);}}
                        onReleased:{selecting=false;root.refreshTags();}
                        onCanceled:selecting=false
                        Rectangle{x:Math.min(marquee.startX,marquee.endX);y:Math.min(marquee.startY,marquee.endY);width:Math.abs(marquee.endX-marquee.startX);height:Math.abs(marquee.endY-marquee.startY);visible:marquee.selecting;color:root.dark?"#306c91b6":"#287b8796";border.width:1;border.color:root.dark?"#829cb6":"#9099a3"}
                    }
                    LiquidScrollBar{flick:grid;anchors{right:parent.right;top:parent.top;bottom:parent.bottom} dark:root.dark}
                }
                Loader{id:alternateViews;anchors.fill:parent;active:!root.listMode && (root.viewMode==="columns" || root.viewMode==="gallery");sourceComponent:FinderViews{finder:root;mode:root.viewMode}}
                Column {
                    id:listContainer
                    anchors.fill:parent;visible:root.listMode
                    Rectangle {
                        width:parent.width;height:28;color:root.dark?"#292929":"#eeeeef"
                        Row{
                            x:14;anchors.verticalCenter:parent.verticalCenter
                            Repeater{model:[{label:"Name",key:"name",size:Math.max(160,list.width-340)},{label:"Date Modified",key:"modified",size:158},{label:"Size",key:"size",size:80},{label:"Kind",key:"kind",size:90}]
                                Label{required property var modelData;width:modelData.size;text:modelData.label;font.pixelSize:11;color:root.secondary;MouseArea{anchors.fill:parent;onClicked:{if(root.sortBy===modelData.key)root.reverseSort=!root.reverseSort;else root.sortBy=modelData.key;}}}
                            }
                        }
                    }
                    ListView {
                        id:list
                        width:parent.width;height:parent.height-28;clip:true
                        model:listContainer.visible?root.entries:[]
                        delegate:Rectangle{
                            required property var modelData;required property int index
                            width:list.width;height:30
                            color:root.selected[modelData.path]?root.accent:index%2?(root.dark?"#04ffffff":"#03000000"):"transparent"
                            Image{x:14;y:5;width:20;height:20;source:Quickshell.iconPath(root.icon(modelData));sourceSize:Qt.size(64,64)}
                            Label{x:42;width:Math.max(120,list.width-368);anchors.verticalCenter:parent.verticalCenter;text:modelData.name;elide:Text.ElideMiddle;color:root.selected[modelData.path]?"white":root.fg}
                            Label{x:Math.max(174,list.width-326);width:152;anchors.verticalCenter:parent.verticalCenter;text:root.dateText(modelData.modified);font.pixelSize:11;color:root.selected[modelData.path]?"white":root.secondary}
                            Label{x:list.width-168;width:76;anchors.verticalCenter:parent.verticalCenter;text:modelData.directory?"—":root.bytes(modelData.size);font.pixelSize:11;color:root.selected[modelData.path]?"white":root.secondary}
                            Label{x:list.width-88;width:80;anchors.verticalCenter:parent.verticalCenter;text:modelData.directory?"Folder":modelData.name.indexOf('.')>=0?modelData.name.split('.').pop().toUpperCase():"Document";font.pixelSize:11;color:root.selected[modelData.path]?"white":root.secondary;elide:Text.ElideRight}
                            FinderDragArea{anchors.fill:parent;finder:root;entry:modelData;rowIndex:index}
                        }
                        MouseArea{anchors.fill:parent;z:10;acceptedButtons:Qt.RightButton;onClicked:m=>{var i=list.indexAt(m.x+list.contentX,m.y+list.contentY);if(i<0)root.selected={};var p=mapToGlobal(m.x,m.y);root.contextFor(i,p.x,p.y);}}
                        LiquidScrollBar{flick:list;anchors{right:parent.right;top:parent.top;bottom:parent.bottom} dark:root.dark}
                    }
                }
                Column{anchors.centerIn:parent;spacing:10;visible:root.entries.length===0
                    Image{anchors.horizontalCenter:parent.horizontalCenter;width:48;height:48;source:Quickshell.iconPath(root.query?"edit-find":"folder")}
                    Label{anchors.horizontalCenter:parent.horizontalCenter;text:files.status===FolderListModel.Loading?"Loading…":root.query?"No matching items":"This folder is empty";color:root.secondary}
                }
            }
            Rectangle {
                x:194;y:parent.height-root.footerHeight;width:parent.width-x-1;height:28;visible:root.showPathBar;color:root.dark?"#242426":"#ededf0"
                TextField{id:pathField;anchors.fill:parent;leftPadding:14;font.family:root.fam;font.pixelSize:11;color:root.secondary;background:null;selectByMouse:true;text:root.applicationMode?"Applications":root.location;onAccepted:{root.navigate(text);content.forceActiveFocus();}}
            }
            Rectangle{x:194;y:parent.height-28;width:parent.width-x-1;height:28;visible:root.showStatusBar;color:root.dark?"#292929":"#e9e9ec"
                Label{x:14;anchors.verticalCenter:parent.verticalCenter;font.pixelSize:11;color:root.secondary;text:(root.chosen().length?root.chosen().length+" of ":"")+root.entries.length+" items, "+(root.applicationMode?"installed":root.bytes(root.freeBytes)+" available")}
                Row{anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter;spacing:5
                    Tool{glyph:"new";tip:"New Folder";enabled:!root.applicationMode;width:24;height:24;onClicked:root.nameSheet("mkdir")}
                    Tool{glyph:"trash";tip:root.trashMode?"Delete Immediately…":"Move to Trash";width:24;height:24;enabled:!root.applicationMode && root.chosen().length>0;onClicked:root.trash()}
                }
            }
            MouseArea{x:parent.width-7;y:10;width:7;height:parent.height-20;cursorShape:Qt.SizeHorCursor;onPressed:win.startSystemResize(Qt.RightEdge)}
            MouseArea{x:10;y:parent.height-7;width:parent.width-20;height:7;cursorShape:Qt.SizeVerCursor;onPressed:win.startSystemResize(Qt.BottomEdge)}
            MouseArea{x:parent.width-10;y:parent.height-10;width:10;height:10;cursorShape:Qt.SizeFDiagCursor;onPressed:win.startSystemResize(Qt.RightEdge|Qt.BottomEdge)}
        }
        Shortcut{sequence:"Ctrl+N";onActivated:root.hub.finder.newWindow(root.location)}
        Shortcut{sequence:"Ctrl+L";onActivated:{root.showPathBar=true;pathField.forceActiveFocus();pathField.selectAll();}}
        Shortcut{sequence:"Ctrl+F";onActivated:{root.searchExpanded=true;search.forceActiveFocus();}}
        Shortcut{sequence:"Ctrl+C";enabled:!search.activeFocus && !pathField.activeFocus && !nameInput.activeFocus && !root.quickLook;onActivated:root.copy(false)}
        Shortcut{sequence:"Ctrl+X";enabled:!search.activeFocus && !pathField.activeFocus && !nameInput.activeFocus && !root.quickLook;onActivated:root.copy(true)}
        Shortcut{sequence:"Ctrl+V";enabled:!search.activeFocus && !pathField.activeFocus && !nameInput.activeFocus && !root.quickLook;onActivated:root.call("paste")}
        Shortcut{sequence:"Ctrl+A";enabled:!search.activeFocus && !pathField.activeFocus && !nameInput.activeFocus && !root.quickLook;onActivated:{var all={};for(var i=0;i<root.entries.length;i++)all[root.entries[i].path]=true;root.selected=all;}}
        Shortcut{sequence:"Ctrl+Shift+N";onActivated:root.nameSheet("mkdir")}
        Shortcut{sequence:"Ctrl+H";onActivated:root.hiddenFiles=!root.hiddenFiles}
        Shortcut{sequence:"Alt+Left";onActivated:root.goBack(-1)}
        Shortcut{sequence:"Alt+Right";onActivated:root.goBack(1)}
        Shortcut{sequence:"Alt+Up";onActivated:root.navigate(String(files.parentFolder))}
        Shortcut{sequence:"Ctrl+W";onActivated:win.close()}
        Shortcut{sequence:"Escape";onActivated:{if(root.sheet)root.sheet="";else if(root.quickLook)root.quickLook=false;else root.selected={};}}
        MacAlert {
            id: permanentDialog
            dark: root.dark; family: root.fam
            reduceMotion: root.hub && root.hub.bar ? root.hub.bar.reduceMotion : false
            heading: root.emptyingAll ? "Are You Sure You Want to Empty the Trash?" : "Delete These Items Immediately?"
            message: "These items will be permanently deleted. You can’t undo this action."
            iconName: "user-trash-full"; destructive: true
            actionText: root.emptyingAll ? "Empty Trash" : "Delete Immediately"
            cancelText: "Cancel"
            onActionRequested: { close();root.call(root.emptyingAll?"empty-trash":"delete-forever",{paths:root.permanentPaths}); }
        }
        MacAlert {
            id: errorDialog
            dark: root.dark; family: root.fam
            reduceMotion: root.hub && root.hub.bar ? root.hub.bar.reduceMotion : false
            heading: "Finder Can’t Complete the Action"
            message: root.message
            onActionRequested: accept()
            onClosed: { root.message=""; content.forceActiveFocus(); }
        }
        ContextMenuWindow{reduceMotion:root.hub && root.hub.bar?root.hub.bar.reduceMotion:false;id:sidebarMenu;dark:root.dark;family:root.fam;onTriggered:entry=>{if(entry.action==="unpin")root.call("favorites-remove",{paths:[entry.path]});else root.navigate(entry.path);}}
        ContextMenuWindow{reduceMotion:root.hub && root.hub.bar?root.hub.bar.reduceMotion:false;id:sortMenu;dark:root.dark;family:root.fam;onTriggered:entry=>root.runContext(entry)}
        ContextMenuWindow{reduceMotion:root.hub && root.hub.bar?root.hub.bar.reduceMotion:false;id:fileMenu;dark:root.dark;family:root.fam;onTriggered:entry=>root.runContext(entry)}
        MacAlert {
            id: nameDialog
            dark: root.dark; family: root.fam
            reduceMotion: root.hub && root.hub.bar ? root.hub.bar.reduceMotion : false
            heading: root.sheet==="rename"?"Rename":root.sheet==="tag"?"New Tag":"New Folder"
            iconName: root.sheet==="tag"?"tag":"folder"
            cancelText: "Cancel"
            actionText: root.sheet==="rename"?"Rename":root.sheet==="tag"?"Add Tag":"Create"
            actionEnabled: nameInput.text.trim()!==""
            onActionRequested: root.commitName()
            onCancelRequested: root.sheet=""
            onOpened: { nameInput.forceActiveFocus(); nameInput.selectAll(); }
            MacTextField { id: nameInput; width: parent.width; dark: root.dark; family: root.fam; selectByMouse: true; onAccepted: if(nameDialog.actionEnabled)root.commitName() }
        }
        Rectangle {
            anchors.fill:parent;visible:root.quickLook && !!root.preview;color:"#77000000";z:19
            MouseArea{anchors.fill:parent;onClicked:root.quickLook=false}
            Rectangle {
                anchors.centerIn:parent;width:Math.min(parent.width-80,760);height:Math.min(parent.height-70,560);radius:14;color:root.dark?"#242426":"#fafafa";border.width:1;border.color:root.dark?"#26ffffff":"#20000000"
                MouseArea{anchors.fill:parent}
                Label{x:20;y:16;width:parent.width-70;text:root.preview?root.preview.name:"";elide:Text.ElideMiddle;font.weight:Font.DemiBold}
                MacButton{reduceMotion:root.hub && root.hub.bar ? root.hub.bar.reduceMotion : false;dark:root.dark;family:root.fam;font.family:root.fam;anchors.right:parent.right;anchors.rightMargin:12;y:8;width:58;height:28;text:"Close";onClicked:root.quickLook=false}
                Image{x:20;y:54;width:parent.width-40;height:parent.height-108;visible:root.preview && root.preview.mime.indexOf("image/")===0;source:visible?root.preview.url:"";sourceSize:Qt.size(1000,700);fillMode:Image.PreserveAspectFit;asynchronous:true}
                ScrollView{x:20;y:54;width:parent.width-40;height:parent.height-108;visible:root.preview && root.preview.text!=="";TextArea{text:root.preview?root.preview.text:"";readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;font.family:"SF Mono";font.pixelSize:12;color:root.fg;background:null}}
                Column{anchors.centerIn:parent;spacing:12;visible:root.preview && !root.preview.text && root.preview.mime.indexOf("image/")!==0
                    Image{anchors.horizontalCenter:parent.horizontalCenter;width:72;height:72;source:Quickshell.iconPath(root.first()?root.icon(root.first()):"text-x-generic")}
                    Label{anchors.horizontalCenter:parent.horizontalCenter;text:root.preview?root.preview.mime:"";color:root.secondary}
                }
                Label{x:20;y:parent.height-34;text:root.preview?root.bytes(root.preview.size):"";color:root.secondary;font.pixelSize:12}
                MacButton{reduceMotion:root.hub && root.hub.bar ? root.hub.bar.reduceMotion : false;dark:root.dark;family:root.fam;font.family:root.fam;anchors.right:parent.right;anchors.rightMargin:14;y:parent.height-40;text:"Open";onClicked:root.activate(root.first())}
            }
        }
    }
}
