"""Exercise update orchestration without installing or authenticating."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
from unittest.mock import patch

file=Path(__file__).resolve().parents[1]/'MacShell/assets/manage-updates.py'
spec=importlib.util.spec_from_file_location('updates',file)
u=importlib.util.module_from_spec(spec);spec.loader.exec_module(u)
providers=[('system','System','Packages','internaldrive'),('flatpak-user','Apps','Apps','app.dashed')]
pending=[{'id':'example:amd64','name':'Example','version':'2','current':'1','icon':'example'}]

def run(action, check, *selection):
    out=io.StringIO()
    with patch.object(u,'sources',return_value=providers), patch.object(u,'check',side_effect=check), patch.object(u,'install') as install, contextlib.redirect_stdout(out):
        result=u.main(action,*selection)
    return result,[json.loads(l) for l in out.getvalue().splitlines()],install

result,events,install=run('check',lambda source:pending)
assert result==0 and not install.called and events[-1]['done']
assert all(e['count']==1 for e in events if 'count' in e and e['count']>=0)
assert any(e.get('packages')==pending for e in events)
result,events,install=run('update',lambda source:[])
assert result==0 and install.call_count==2 and not events[-1]['failed']
result,events,install=run('update-source',lambda source:[], 'flatpak-user')
install.assert_called_once_with('flatpak-user')
assert all(e.get('source','flatpak-user')=='flatpak-user' for e in events)
result,events,install=run('update-package',lambda source:pending, 'system','example:amd64')
install.assert_called_once_with('system','example:amd64')
result,events,install=run('update-package',lambda source:pending, 'system','--dangerous')
assert result==1 and not install.called

def failure(source):
    if source=='system':raise RuntimeError('package database locked')
    return []
result,events,install=run('check',failure)
assert result==1 and events[-1]['failed']
assert any(e.get('source')=='flatpak-user' and e.get('status')=='Up to date' for e in events)
assert any(e.get('error') and 'locked' in e['report'] for e in events)
with patch.object(u,'app_catalog',return_value={}), patch.object(u,'command',return_value='Listing...\napp/stable 2 amd64 [upgradable from: 1]\napp/stable 2 i386 [upgradable from: 1]\n'):
    packages=u.check('system')
    assert [p['id'] for p in packages]==['app:amd64','app:i386']
    assert packages[0]['version']=='2' and packages[0]['current']=='1'
with patch.object(u,'app_catalog',return_value={}), patch.object(u,'command',return_value='app/org.example.App/x86_64/stable\tExample App\t2\n') as command:
    assert u.check('flatpak-user')[0]['name']=='Example App'
    assert '--user' in command.call_args.args[0]
assert u.install_command('system','example:amd64')[-2:]==['--','example:amd64']
assert '--user' in u.install_command('flatpak-user','app/org.example.App/x86_64/stable')
for source,ref in [('system','--remove'),('system','app;reboot'),('flatpak-user','--system'),('snap','--classic')]:
    try:u.install_command(source,ref)
    except ValueError:pass
    else:raise AssertionError((source,ref))
out=io.StringIO()
with patch.object(u,'sources',return_value=providers), patch.object(u,'check',return_value=[]), patch.object(u,'install',side_effect=[RuntimeError('Authorization cancelled'),None]) as install, contextlib.redirect_stdout(out):
    assert u.main('update')==1 and install.call_count==2
assert 'Authorization cancelled' in out.getvalue()
print('PASS: read-only checks, all/group/package update scopes, package metadata, multiarch identity, Flatpak scopes, argument validation, cancellation and failure recovery')

# Progress follows the current source; completed groups stop animating.
assert [e['source'] for e in events if e.get('progress')]==['system','flatpak-user']
assert u.error_summary('pkexec must be setuid root')=='Administrator authorization could not start.'
assert 'cancelled' in u.error_summary('Authorization cancelled')
# The host bridge only accepts the fixed updater and known action shapes.
import sys
sys.path.insert(0,str(file.parents[2]))
import update_bridge as bridge
assert bridge.update_command({'action':'update-package','source':'system','package':'cmake:amd64'})[-3:]==['update-package','system','cmake:amd64']
for arg in [{'action':'shell'},{'action':'update-package','source':'system'},{'action':'update-source','source':''}]:
    try:bridge.update_command(arg)
    except ValueError:pass
    else:raise AssertionError(arg)
# A real host child reads its own tracer state; no installation or authentication.
with patch.object(bridge,'update_command',return_value=['/usr/bin/python3','-c',"import json;print(json.dumps({'done':True,'tracer':next(x for x in open('/proc/self/status') if x.startswith('TracerPid:')).strip()}))"]):
    event=list(bridge.stream_updates({'action':'check'}))[-1]
    assert event['tracer']=='TracerPid:\t0',event
print('PASS: native update bridge runs outside ptrace; input validation, source progress, readable summaries and complete error reports')
