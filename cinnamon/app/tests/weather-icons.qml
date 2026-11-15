import QtQuick
import QtQuick.Window
import Quickshell
Scope {
 Window {
  id:window;title:"MacShell Owned Weather Icons QA";visible:true;width:1080;height:360;color:"#34343b"
  flags:Qt.Tool|Qt.FramelessWindowHint
  Row{x:18;y:10;spacing:20
   Repeater{model:["sun","moon","partly","partlyNight","cloud","fog","rain","snow","storm"]
    Column{required property string modelData;width:96;spacing:4
     WeatherIcon{kind:parent.modelData;size:80}
     Text{text:parent.modelData;color:"white";font.pixelSize:12}
    }
   }
  }
  Row{x:18;y:130;spacing:24
   Repeater{model:["cloud","rain","snow","storm","partly"]
    WeatherWidget{required property string modelData;size:"small";style:"normal";scaleF:1;darkGlass:false;city:"Cupertino";hasData:true;temp:18;hi:21;lo:12;kind:modelData;cond:modelData}
   }
  }
 }
}
