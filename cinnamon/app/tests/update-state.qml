import QtQuick
import Quickshell
import "../MacShell" as Shell
Scope {
    id:test
    property int notices:0
    property var lastNotice:null
    property int reports:0
    Shell.UpdateManager {
        id:manager
        notifications:QtObject{function notifReceive(n){test.notices++;test.lastNotice=n;}}
        onReportRequested:test.reports++
    }
    function check(condition,label){if(!condition)throw new Error(label);}
    Timer{interval:200;running:true;onTriggered:{
        try{
            manager.busy=true;manager.action="update"
            manager.receive({source:"system",name:"System Software",count:-1})
            manager.receive({progress:true,source:"system",package:"cmake:amd64",phase:"Installing"})
            check(manager.packageBusy("system","cmake:amd64"),"active package spinner")
            check(!manager.packageBusy("system","other"),"other packages stay still")
            check(!manager.sourceBusy("flatpak-user"),"other groups stay still")
            manager.receive({source:"system",count:0,packages:[]})
            check(!manager.sourceBusy("system"),"completed source stops spinning")
            manager.receive({progress:true,source:"flatpak-system",package:"",phase:"Checking"})
            check(manager.sourceBusy("flatpak-system"),"next source starts spinning")
            manager.receive({source:"flatpak-system",name:"Shared Apps",error:true,details:"The system did not allow this update to finish.",report:"Complete diagnostic line\nsecond line"})
            manager.receive({done:true,failed:true})
            check(!manager.busy && !manager.activeSource,"failure clears all spinners")
            check(test.notices===1,"one failure notification")
            check(manager.report.indexOf("Complete diagnostic line\nsecond line")>=0,"full report preserved")
            test.lastNotice.actions[0].invoke()
            check(test.reports===1,"notification opens report")
            console.log("PASS: only active source/package spins; completion and errors clear progress; notification action opens full report")
        }catch(e){console.error("FAIL: "+e);}
        Qt.quit()
    }}
}
