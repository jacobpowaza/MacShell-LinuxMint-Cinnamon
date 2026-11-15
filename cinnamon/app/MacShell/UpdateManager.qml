import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: manager
    visible: false
    property var notifications: null
    property var sources: []
    property var expanded: ({})
    property string activeSource: ""
    property string activePackage: ""
    property string phase: ""
    property string action: ""
    property string status: "Check for app and system updates."
    property string log: ""
    property var errors: []
    property string report: ""
    property string reportSummary: ""
    property bool checked: false
    property bool reboot: false
    property bool busy: false
    property string pending: ""
    signal reportRequested()
    function sourceBusy(source) { return busy && activeSource === source; }
    function packageBusy(source, id) {
        if (!sourceBusy(source) || !activePackage) return false;
        if (activePackage === id) return true;
        // apt omits architecture for a native-architecture package in progress.
        if (source !== "system" || activePackage.indexOf(":") >= 0) return false;
        var group=sources.find(s=>s.source===source),matches=group?(group.packages || []).filter(p=>p.id.split(":")[0]===activePackage):[];
        return matches.length===1 && matches[0].id===id;
    }
    function run(nextAction, source, packageId) {
        if (busy) return;
        action = nextAction; activeSource = ""; activePackage = "";
        phase = ""; log = ""; errors = []; report = ""; reportSummary = "";
        status = action !== "check" ? "Updating software… Administrator authorization may be requested." : "Checking for updates…";
        busy = true;
        pending = JSON.stringify({op:"updates",arg:{action:action,source:source || "",package:packageId || ""}});
        if (channel.connected) drain(); else channel.connected = true;
    }
    function drain() { if (!pending) return; channel.write(pending+"\n"); channel.flush(); pending=""; }
    function finishReport() {
        if (!errors.length) return;
        reportSummary = errors.length === 1 ? errors[0].summary : errors.length+" update sources need attention.";
        report = "Software Update Report\n"+new Date().toLocaleString()+"\nAction: "+action+"\n\n"+
            errors.map(e=>e.name+"\n"+e.summary+"\n\n"+e.report).join("\n\n────────────────────────\n\n")+
            (log ? "\n\nActivity log\n────────────────────────\n"+log : "");
        var savedReport=report,savedSummary=reportSummary;
        if (notifications) notifications.notifReceive({appName:"Updates",summary:"Software update needs attention",
            body:reportSummary+"\nView full error report",appIcon:"software-update-urgent",urgency:1,expireTimeout:10,
            actions:[{identifier:"default",invoke:function(){manager.report=savedReport;manager.reportSummary=savedSummary;manager.reportRequested();}}]});
    }
    function receive(event) {
        if (event.log) log = (log + "\n" + event.log).slice(-524288);
        if (event.progress) { activeSource=event.source; activePackage=event.package || ""; phase=event.phase || "Updating"; return; }
        if (event.source) {
            var list=sources.slice(), index=list.findIndex(s=>s.source===event.source);
            if (index<0) list.push(event); else list[index]=Object.assign({},list[index],event);
            sources=list;
            if (event.error) errors=errors.concat([{name:list[index<0?list.length-1:index].name || event.source,summary:event.details,report:event.report || event.details}]);
            if (event.count>=0 || event.error) {activeSource="";activePackage="";}
        }
        if (event.fatal || event.ok===false) {
            status=event.fatal || event.error; errors=errors.concat([{name:"Update service",summary:status,report:status}]);
            busy=false;activeSource="";activePackage="";finishReport();
        }
        if (event.done) {
            checked=true;reboot=!!event.reboot;busy=false;activeSource="";activePackage="";
            status=event.failed?"Some updates need attention.":action!=="check"?"Update finished.":"Check complete.";
            finishReport();
        }
    }
    Socket {
        id: channel
        path: Quickshell.env("XDG_RUNTIME_DIR")+"/macshell-cinnamon-port/native.sock"
        connected: true
        onConnectedChanged: {
            if (connected) manager.drain();
            else if (manager.busy && !manager.pending) manager.receive({fatal:"Connection to the update service was lost. Check again for the latest status."});
        }
        parser: SplitParser { onRead: data=>{try{manager.receive(JSON.parse(data));}catch(e){manager.receive({fatal:"Unable to read update status."});}} }
    }
}
