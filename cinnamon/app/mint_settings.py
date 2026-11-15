"""Typed live Cinnamon preferences and installed Mint settings panels."""
from pathlib import Path
import re,os
from functools import lru_cache
from gi.repository import Gio, GLib

PREFIXES = ('org.cinnamon.',)
SCHEMAS = Gio.SettingsSchemaSource.get_default()

def setting(schema, key=None):
    if not schema.startswith(PREFIXES):
        raise ValueError('Only Cinnamon preferences are supported')
    spec = SCHEMAS.lookup(schema, True)
    if not spec or not spec.get_path():
        raise ValueError('Preference schema is unavailable')
    if key is not None and not spec.has_key(key):
        raise ValueError('Preference is unavailable')
    return spec, Gio.Settings.new_full(spec, None, None)

def panels():
    out=[]
    for app in Gio.AppInfo.get_all():
        if not isinstance(app, Gio.DesktopAppInfo): continue
        categories=(app.get_categories() or '').split(';')
        if 'Settings' not in categories or not app.should_show(): continue
        icon=app.get_icon()
        out.append({'id':app.get_id(), 'name':app.get_display_name(), 'description':app.get_description() or '', 'icon':icon.get_names()[0] if isinstance(icon,Gio.ThemedIcon) else icon.to_string() if icon else 'preferences-system'})
    return sorted(out,key=lambda x:x['name'].casefold())

def snapshot(schema):
    spec, values=setting(schema)
    out=[]
    for key in sorted(spec.list_keys()):
        sk=spec.get_key(key); value=values.get_value(key)
        bounds=sk.get_range().unpack()
        out.append({'key':key, 'name':sk.get_summary() or key.replace('-', ' ').capitalize(), 'description':sk.get_description() or '', 'type':value.get_type_string(), 'value':value.unpack(), 'writable':values.is_writable(key), 'range':bounds})
    return out

DEFAULT_TYPES=[('Web browser','x-scheme-handler/https'),('Email','x-scheme-handler/mailto'),('File manager','inode/directory'),('Text files','text/plain'),('Images','image/jpeg'),('PDF documents','application/pdf'),('Music','audio/mpeg'),('Videos','video/mp4')]
def default_apps():
    out=[]
    for label,mime in DEFAULT_TYPES:
        current=Gio.AppInfo.get_default_for_type(mime,False)
        apps=[a for a in Gio.AppInfo.get_all_for_type(mime) if a.get_id()]
        if current and current.get_id() not in [a.get_id() for a in apps]:apps.insert(0,current)
        options=[{'id':a.get_id(),'name':a.get_display_name()} for a in apps]
        out.append({'name':label,'key':mime,'schema':'','type':'application','value':current.get_id() if current else '', 'options':options, 'writable':True,'description':'','range':['type',None]})
    return out

MODULE_CATEGORIES = {'general':'general','accessibility':'general','actions':'general','default':'apps','desktop':'dock','effects':'appearance','fonts':'appearance','themes':'appearance','panel':'dock','applets':'menubar','extensions':'general','desklets':'widgets','power':'battery','nightlight':'displays','notifications':'notifications','privacy':'general','screensaver':'lockscreen','startup':'general','windows':'dock','workspaces':'dock','gestures':'trackpad','hotcorner':'dock','calendar':'general','keyboard':'keyboard','mouse':'mouse','sound':'sound','user':'users','thunderbolt':'general','display':'displays','backgrounds':'wallpaper'}
@lru_cache(maxsize=1)
def module_keys():
    result={}
    for file in Path('/usr/share/cinnamon/cinnamon-settings/modules').glob('cs_*.py'):
        module=file.stem[3:];category=MODULE_CATEGORIES.get(module,'general');text=file.read_text()
        for label,schema,key in re.findall(r'GSettings\w+\(\_\("([^"\n]+)"\),\s*"(org\.cinnamon[^"\n]+)",\s*"([^"\n]+)"',text):
            if 'touchpad' in schema:cat='trackpad'
            else:cat=category
            result[(schema,key)]=(cat,label)
    return result

def category_for(schema,key):
    exact=module_keys().get((schema,key))
    if exact:return exact[0]
    s=schema.lower()
    for term,cat in [('keybinding','keyboard'),('keyboard','keyboard'),('input-source','keyboard'),('touchpad','trackpad'),('mouse','mouse'),('power','battery'),('color','displays'),('xrandr','displays'),('xsettings','displays'),('notification','notifications'),('sound','sound'),('screensaver','lockscreen'),('background','wallpaper'),('interface','appearance'),('theme','appearance'),('media-keys','keyboard'),('wm.','dock'),('muffin','dock'),('peripherals','general')]:
        if term in s:return cat
    return 'general'

def category_snapshot(category):
    groups={}
    for schema in sorted(SCHEMAS.list_schemas(True)[0]):
        if not schema.startswith(PREFIXES) or not SCHEMAS.lookup(schema,True).get_path():continue
        if 'wayland' in schema.lower() and os.environ.get('XDG_SESSION_TYPE')!='wayland':continue
        for row in snapshot(schema):
            if category_for(schema,row['key'])!=category:continue
            # Display preferences that Mint actually exposes, not Cinnamon's internal bookkeeping.
            direct=(schema,row['key']) in module_keys()
            public=any(term in schema for term in ['.peripherals.','.keybindings','.plugins.power','.desktop.privacy','.desktop.notifications','.desktop.sound','.screensaver'])
            if not direct and not public:continue
            if row['key'] in ['last-command','last-monitor','idle-activation-enabled'] and not direct:continue
            # These controls are already present and connected at the top of their MacShell panes.
            if schema.endswith('.peripherals.keyboard') and row['key'] in ['delay','repeat-interval']:continue
            if schema.endswith('.peripherals.mouse') and row['key'] in ['speed','natural-scroll']:continue
            if schema.endswith('.peripherals.touchpad') and row['key'] in ['speed','natural-scroll','tap-to-click','disable-while-typing']:continue
            row['schema']=schema
            if (schema,row['key']) in module_keys():row['name']=module_keys()[(schema,row['key'])][1]
            label=schema.removeprefix('org.cinnamon.').removeprefix('desktop.').replace('settings-daemon.plugins.','').replace('.',' · ').replace('-',' ').title()
            label={'Launcher':'Memory','Sessionmanager':'Shutdown and Logout','Muffin':'Compositor','A11Y · Applications':'Accessibility','A11Y · Keyboard':'Keyboard Accessibility','A11Y · Magnifier':'Zoom','A11Y · Mouse':'Pointer Accessibility','Wm · Preferences':'Windows','Peripherals · Keyboard':'Typing','Peripherals · Mouse':'Pointer','Peripherals · Touchpad':'Trackpad','Peripherals · Touchscreen':'Touchscreen','Keybindings':'Shortcuts','Keybindings · Wm':'Window Shortcuts','Keybindings · Media Keys':'Media Shortcuts','Power':'Power and Sleep','Screensaver':'Screen Lock','Privacy':'Privacy','Notifications':'Notifications','Sound':'Sound Effects','Cinnamon':'Desktop'}.get(label,label)
            if label=='Muffin · Keybindings':label='Window Shortcuts'
            if label=='Settings Daemon · Peripherals · Keyboard':label='Keyboard Indicators'
            if label=='Interface' and category=='keyboard':label='Keyboard Layout'
            if label=='Interface' and category=='general':label='General Options'
            if row['key']=='unredirect-fullscreen-windows':row['description']='Let full-screen apps bypass compositing for better performance. Turn off if you see screen tearing.'
            if row['key']=='memory-limit':row['description']='Maximum Cinnamon memory use, in MB.'
            if row['key']=='check-frequency':row['description']='How often to check memory use, in seconds.'
            if row['key']=='quit-time-delay':row['description']='Countdown before logout or shutdown, in seconds.'
            if label.startswith('Keybindings · '):label=label.replace('Keybindings · ','')+' Shortcuts' 
            groups.setdefault(label,[]).append(row)
    if category=='apps':groups['Default Applications']=default_apps()
    return sorted([{'title':label,'rows':rows} for label,rows in groups.items()],key=lambda g:(["Compositor","Memory","Shutdown and Logout"].index(g['title']) if category=='general' and g['title'] in ["Compositor","Memory","Shutdown and Logout"] else 20,g['title']))

def sync_gtk4_theme(name):
    if '/' in name or name in ['.','..']:return
    file=Path.home()/'.config/gtk-4.0/gtk.css'
    target=Path.home()/'.themes'/name/'gtk-4.0/gtk.css'
    if not target.exists():target=Path('/usr/share/themes')/name/'gtk-4.0/gtk.css'
    if not file.exists() or not target.exists():return
    text=file.read_text()
    if 'MacShell-Apps/gtk-4.0/gtk.css' not in text and 'Mint-Y-Aqua-Mac/gtk-4.0/gtk.css' not in text:return
    replacement='@import url("'+target.as_uri()+'");'
    updated=re.sub(r'@import url\("file:[^"\n]+/(?:MacShell-Apps|Mint-Y-Aqua-Mac)/gtk-4.0/gtk.css"\);',lambda m:replacement,text,count=1)
    if updated!=text:file.write_text(updated)

SHARED = {
    'showDate':('org.cinnamon.desktop.interface','clock-show-date'),
    'showSeconds':('org.cinnamon.desktop.interface','clock-show-seconds'),
    'use24h':('org.cinnamon.desktop.interface','clock-use-24h'),
    'reduceMotion':('org.cinnamon.desktop.interface','enable-animations'),
    'nightOn':('org.cinnamon.settings-daemon.plugins.color','night-light-enabled'),
    'nightTemp':('org.cinnamon.settings-daemon.plugins.color','night-light-temperature'),
    'notifDnd':('org.cinnamon.desktop.notifications','display-notifications'),
}

def request(arg):
    action=arg.get('action','list')
    if action=='category':return {'category':arg['category'],'groups':category_snapshot(str(arg['category']))}
    if action=='category-write':
        if not arg.get('schema'):
            app=Gio.DesktopAppInfo.new(str(arg['value']))
            if not app or arg['key'] not in [m for _,m in DEFAULT_TYPES]:raise ValueError('Choose an installed default application')
            app.set_as_default_for_type(arg['key'])
            if arg['key']=='x-scheme-handler/https':app.set_as_default_for_type('x-scheme-handler/http')
        else:request(dict(arg,action='write'))
        return {'category':arg['category'],'groups':category_snapshot(str(arg['category']))}
    if action=='list':
        names=SCHEMAS.list_schemas(True)[0]
        return {'panels':panels(), 'schemas':sorted(s for s in names if s.startswith(PREFIXES) and SCHEMAS.lookup(s,True).get_path())}
    if action=='read': return snapshot(str(arg['schema']))
    if action=='write':
        spec, values=setting(str(arg['schema']),str(arg['key']))
        key=str(arg['key']); sk=spec.get_key(key)
        value=GLib.Variant(sk.get_value_type().dup_string(),arg['value'])
        if not sk.range_check(value): raise ValueError('Value is outside the supported range')
        if not values.is_writable(key) or not values.set_value(key,value): raise ValueError('This setting is read-only')
        Gio.Settings.sync();return snapshot(str(arg['schema']))
    if action=='shared':
        result={name:(not setting(schema)[1].get_value(key).unpack() if name in ['reduceMotion','notifDnd'] else setting(schema)[1].get_value(key).unpack()) for name,(schema,key) in SHARED.items()}
        _,interface=setting('org.cinnamon.desktop.interface')
        result['fontFamily']=re.sub(r'\s+\d+(?:\.\d+)?$','',interface.get_string('font-name'))
        theme_name=interface.get_string('gtk-theme')
        sync_gtk4_theme(theme_name)
        theme=theme_name.lower()
        result['darkMode']='dark' in theme or theme=='macshell-apps'
        return result
    if action=='shared-write':
        for name,value in arg.get('values',{}).items():
            if name=='fontFamily':
                _,interface=setting('org.cinnamon.desktop.interface');old=interface.get_string('font-name');size=re.search(r'\d+(?:\.\d+)?$',old);interface.set_string('font-name',str(value)+' '+(size[0] if size else '10'));continue
            if name=='darkMode':
                _,interface=setting('org.cinnamon.desktop.interface');_,wm=setting('org.cinnamon.desktop.wm.preferences');name='MacShell-Apps' if value else 'Mint-Y-Aqua-Mac';interface.set_string('gtk-theme',name);wm.set_string('theme',name)
                gn=Gio.Settings.new('org.gnome.desktop.interface');gn.set_string('color-scheme','prefer-dark' if value else 'prefer-light');continue
            if name not in SHARED: continue
            schema,key=SHARED[name]
            request({'action':'write','schema':schema,'key':key,'value':not value if name in ['reduceMotion','notifDnd'] else value})
        return request({'action':'shared'})
    if action=='input':
        _,kb=setting('org.cinnamon.desktop.peripherals.keyboard')
        _,mouse=setting('org.cinnamon.desktop.peripherals.mouse')
        _,tp=setting('org.cinnamon.desktop.peripherals.touchpad')
        return {'kbRepeatRate':round(1000/max(1,kb.get_uint('repeat-interval'))), 'kbRepeatDelay':kb.get_uint('delay'), 'mouseSens':mouse.get_double('speed'), 'mouseNatural':mouse.get_boolean('natural-scroll'), 'tpNatural':tp.get_boolean('natural-scroll'), 'tpTap':tp.get_boolean('tap-to-click'), 'tpDwt':tp.get_boolean('disable-while-typing'), 'tpScroll':tp.get_double('speed')}
    raise ValueError('Unknown settings action')
