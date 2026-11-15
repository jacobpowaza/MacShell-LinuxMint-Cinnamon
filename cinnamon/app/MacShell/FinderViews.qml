import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell

Item{
    id:views
    required property var finder
    property string mode:"columns"
    readonly property var selected: {finder.selected;return finder.first();}
    function revealIndex(index){if(mode==="columns")firstColumn.positionViewAtIndex(index,ListView.Contain);else if(mode==="gallery")film.positionViewAtIndex(index,ListView.Contain);}
    function isImage(entry){return entry && /\.(png|jpe?g|webp|gif|bmp|svg)$/i.test(entry.name);}
    function context(item,index,x,y){var p=item.mapToGlobal(x,y);finder.contextFor(index,p.x,p.y);}
    FolderListModel{id:children;folder:views.selected && views.selected.directory?"file://"+views.selected.path:views.finder.folderUrl;showDotAndDotDot:false;showDirsFirst:true;showHidden:views.finder.hiddenFiles;sortCaseSensitive:false}
    Row{
        anchors.fill:parent;visible:views.mode==="columns"
        ListView{
            id:firstColumn;width:Math.min(240,views.width*0.35);height:parent.height;clip:true;model:views.mode==="columns"?views.finder.entries:[]
            delegate:Rectangle{
                required property var modelData;required property int index
                width:firstColumn.width;height:30;color:views.finder.selected[modelData.path]?views.finder.accent:"transparent"
                Image{x:10;y:5;width:20;height:20;sourceSize:Qt.size(64,64);source:Quickshell.iconPath(views.finder.icon(modelData))}
                Text{x:38;width:parent.width-58;anchors.verticalCenter:parent.verticalCenter;text:modelData.name;elide:Text.ElideMiddle;font.family:views.finder.fam;font.pixelSize:13;color:views.finder.selected[modelData.path]?"white":views.finder.fg}
                Text{visible:modelData.directory;anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter;text:"›";color:views.finder.secondary;font.pixelSize:16}
                FinderDragArea{anchors.fill:parent;finder:views.finder;entry:modelData;rowIndex:index}
            }
            LiquidScrollBar{flick:firstColumn;anchors{right:parent.right;top:parent.top;bottom:parent.bottom}dark:views.finder.dark}
        }
        Rectangle{width:1;height:parent.height;color:views.finder.dark?"#26ffffff":"#20000000"}
        ListView{
            id:secondColumn;width:Math.min(240,views.width*0.35);height:parent.height;clip:true
            visible:views.selected && views.selected.directory
            model:visible?children:null
            delegate:Rectangle{
                required property string fileName;required property string filePath;required property bool fileIsDir
                width:secondColumn.width;height:30;color:secondHover.hovered?(views.finder.dark?"#20ffffff":"#10000000"):"transparent"
                Image{x:10;y:5;width:20;height:20;sourceSize:Qt.size(64,64);source:Quickshell.iconPath(fileIsDir?"folder":"text-x-generic")}
                Text{x:38;width:parent.width-50;anchors.verticalCenter:parent.verticalCenter;text:fileName;elide:Text.ElideMiddle;color:views.finder.fg;font.family:views.finder.fam;font.pixelSize:13}
                HoverHandler{id:secondHover}
                TapHandler{onTapped:views.finder.activate({name:fileName,path:filePath,directory:fileIsDir})}
            }
            LiquidScrollBar{flick:secondColumn;anchors{right:parent.right;top:parent.top;bottom:parent.bottom}dark:views.finder.dark}
        }
        Rectangle{visible:secondColumn.visible;width:1;height:parent.height;color:views.finder.dark?"#26ffffff":"#20000000"}
        Column{
            width:views.width-firstColumn.width-(secondColumn.visible?secondColumn.width+2:1);spacing:12
            Item{width:1;height:35}
            Image{anchors.horizontalCenter:parent.horizontalCenter;width:Math.min(150,parent.width-32);height:150;fillMode:Image.PreserveAspectFit;source:views.selected?(views.isImage(views.selected)?views.selected.url:Quickshell.iconPath(views.finder.icon(views.selected))):"";asynchronous:true}
            Text{width:parent.width-24;anchors.horizontalCenter:parent.horizontalCenter;text:views.selected?views.selected.name:"Select an item";color:views.finder.fg;font.family:views.finder.fam;font.pixelSize:14;font.weight:Font.DemiBold;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap}
            Text{anchors.horizontalCenter:parent.horizontalCenter;text:views.selected?(views.selected.directory?"Folder":views.finder.bytes(views.selected.size)):"";color:views.finder.secondary;font.family:views.finder.fam;font.pixelSize:12}
        }
    }
    Item{
        anchors.fill:parent;visible:views.mode==="gallery"
        Image{anchors{left:parent.left;right:parent.right;top:parent.top;bottom:film.top;margins:24}source:views.selected?(views.isImage(views.selected)?views.selected.url:Quickshell.iconPath(views.finder.icon(views.selected))):"";fillMode:Image.PreserveAspectFit;sourceSize:Qt.size(1000,600);asynchronous:true}
        Text{anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:film.top;anchors.bottomMargin:4;text:views.selected?views.selected.name:"Select an item to preview";color:views.finder.fg;font.family:views.finder.fam;font.pixelSize:13}
        ListView{
            id:film;anchors{left:parent.left;right:parent.right;bottom:parent.bottom;margins:12}height:90;orientation:ListView.Horizontal;spacing:8;clip:true;model:views.mode==="gallery"?views.finder.entries:[]
            delegate:Rectangle{
                required property var modelData;required property int index
                width:80;height:80;radius:9;color:views.finder.selected[modelData.path]?(views.finder.dark?"#3b5372":"#d6e6fa"):"transparent"
                Image{anchors.fill:parent;anchors.margins:12;source:views.isImage(modelData)?modelData.url:Quickshell.iconPath(views.finder.icon(modelData));sourceSize:Qt.size(100,100);fillMode:Image.PreserveAspectFit;asynchronous:true}
                FinderDragArea{anchors.fill:parent;finder:views.finder;entry:modelData;rowIndex:index}
                MacToolTip { reduceMotion:views.finder.hub && views.finder.hub.bar?views.finder.hub.bar.reduceMotion:false; visible: filmHover.hovered; text: modelData.name; dark: views.finder.dark; family: views.finder.fam }
                HoverHandler{id:filmHover}
            }
        }
    }
}
