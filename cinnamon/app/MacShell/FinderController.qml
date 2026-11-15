import QtQuick
import Quickshell
import Quickshell.Io
Scope {
    id:manager
    property var hub:null
    property var windows:[]
    readonly property var current:windows.find(w=>w.active) || (windows.length?windows[windows.length-1]:null)
    FileInfo{id:infoApp;dark:manager.hub && manager.hub.bar?manager.hub.bar.darkMode:true;family:manager.hub && manager.hub.bar?manager.hub.bar.fontFamily:"SF Pro Text"}
    function info(path){infoApp.open(path);}
    function confirmEmpty(){
        var path=hub.trash.path,view=windows.find(w=>w.trashMode);
        if(!view){newWindow(path);view=windows[windows.length-1];}
        view.open(path);Qt.callLater(function(){view.confirmPermanent(true);});
    }
    Component{id:factory;FinderApp{hub:manager.hub}}
    function newWindow(path){
        var instance=factory.createObject(manager);
        windows=windows.concat([instance]);
        instance.closed.connect(function(){manager.windows=manager.windows.filter(w=>w!==instance);Qt.callLater(function(){instance.destroy();});});
        instance.open(path || Quickshell.env("HOME"));
    }
    function open(path){
        var match=windows.find(w=>!path || w.location===path);
        if(match)match.open(path || match.location);else newWindow(path);
    }
    IpcHandler {
        target:"finder"
        function open(path:string):void {manager.open(path);}
        function newWindow(path:string):void {manager.newWindow(path);}
        function close():void {if(manager.current)manager.current.closed();}
        function state():string {var state=manager.current?JSON.parse(manager.current.state()):{};state.windows=manager.windows.length;return JSON.stringify(state);}
        function view(mode:string):void {if(manager.current){manager.current.viewMode=mode;manager.current.listMode=mode==="list";}}
        function hidden(show:bool):void {if(manager.current)manager.current.hiddenFiles=show;}
        function search(text:string):void {if(manager.current)manager.current.setQuery(text);}
        function choose(index:int):void {if(manager.current)manager.current.select(index,0);}
        function navigate(path:string):void{if(manager.current)manager.current.navigate(path);}
        function tag(name:string):void{if(manager.current)manager.current.toggleTag(name);}
        function context(index:int,x:int,y:int):void{if(manager.current)manager.current.contextFor(index,x,y);}
        function preview():void {if(manager.current)manager.current.showPreview();}
    }
}
