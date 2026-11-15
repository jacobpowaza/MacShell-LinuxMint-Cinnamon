#!/usr/bin/python3
"""Stream update status as JSON lines. Installs only with the explicit 'update' action."""
import fcntl
import json
import re
from functools import lru_cache
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def emit(**event):
    print(json.dumps(event), flush=True)


def command(args, timeout=180):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, timeout=timeout, env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Command failed')
    return result.stdout


def sources():
    result = []
    if shutil.which('apt-get'):
        result.append(('system', 'System Software', 'Apps, security updates and system packages', 'internaldrive'))
    if shutil.which('flatpak'):
        for scope, label in [('user', 'Your Apps'), ('system', 'Shared Apps')]:
            result.append(('flatpak-' + scope, label, 'Flatpak apps and runtimes · ' + scope + ' installation', 'app.dashed'))
    if shutil.which('snap'):
        result.append(('snap', 'Snap Apps', 'Snap apps and runtimes', 'square.grid.2x2'))
    return result


@lru_cache(maxsize=1)
def app_catalog():
    from gi.repository import Gio
    result = {}
    for app in Gio.AppInfo.get_all():
        app_id = (app.get_id() or '').removesuffix('.desktop').lower()
        icon = app.get_icon()
        entry = {'name': app.get_display_name(), 'icon': icon.to_string() if icon else ''}
        if app_id:
            result[app_id] = entry
        executable = os.path.basename(app.get_executable() or '').lower()
        if executable:
            result.setdefault(executable, entry)
    return result


def package(ref, version='', current='', label=''):
    key = ref.split('/')[1] if '/' in ref else ref.split(':')[0]
    app = app_catalog().get(key.lower(), {})
    fallback = 'Runtime' if ref.startswith('runtime/') or key.startswith(('lib', 'python', 'locales', 'linux-firmware')) else 'System package'
    return {'id': ref, 'name': app.get('name') or label or key,
            'icon': app.get('icon', ''), 'version': version, 'current': current,
            'kind': fallback if not app else 'Application',
            'symbol': 'app.dashed' if app else 'globe' if key == 'locales' else 'internaldrive' if 'firmware' in key else 'curlybraces' if fallback == 'Runtime' else 'gearshape'}


def check(source):
    if source == 'system':
        result = []
        for line in command(['/usr/bin/apt', 'list', '--upgradable']).splitlines():
            match = re.match(r'([^/]+)/\S+\s+(\S+)\s+\S+\s+\[upgradable from: ([^]]+)\]', line)
            if match:
                name, version, current = match.groups()
                # apt omits the architecture in its display name. Keep each multiarch update distinct.
                arch = line.split()[2]
                result.append(package(name if ':' in name or arch == 'all' else name + ':' + arch, version, current))
        return result
    if source.startswith('flatpak-'):
        scope = source.split('-', 1)[1]
        result = []
        for line in command(['flatpak', 'remote-ls', '--' + scope, '--updates', '--columns=ref,name,version']).splitlines():
            if not line.strip():
                continue
            fields = line.split('\t')
            ref = fields[0]
            result.append(package(ref, fields[2] if len(fields)>2 else '', label=fields[1] if len(fields)>1 else ''))
        return result
    lines = command(['snap', 'refresh', '--list']).splitlines()
    return [] if not lines or 'All snaps up to date' in '\n'.join(lines) else [package(parts[0], parts[1]) for line in lines[1:] if len(parts := line.split()) >= 2]


def install_command(source, ref=None):
    if source == 'system':
        if ref:
            if not re.fullmatch(r'[a-z0-9][a-z0-9+.:~-]*', ref):
                raise ValueError('Invalid system package')
            return ['/usr/bin/pkexec', '/usr/bin/apt-get', '-y', '--only-upgrade',
                    '-o', 'Dpkg::Options::=--force-confold', 'install', '--', ref]
        return ['/usr/bin/pkexec', '/bin/sh', '-c',
                'export DEBIAN_FRONTEND=noninteractive; /usr/bin/apt-get update --error-on=any && /usr/bin/apt-get -y --with-new-pkgs -o Dpkg::Options::=--force-confold upgrade']
    if source in ('flatpak-user', 'flatpak-system'):
        args = ['flatpak', 'update', '--' + source.split('-', 1)[1], '--assumeyes', '--noninteractive']
        if ref:
            if not re.fullmatch(r'(app|runtime)/[A-Za-z0-9_.-]+/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+', ref):
                raise ValueError('Invalid Flatpak package')
            args.append(ref)
        return args
    if source == 'snap':
        if ref and not re.fullmatch(r'[a-z0-9][a-z0-9-]*', ref):
            raise ValueError('Invalid Snap package')
        return ['/usr/bin/pkexec', '/usr/bin/snap', 'refresh'] + ([ref] if ref else [])
    raise ValueError('Unsupported update source')


def install(source, ref=None):
    args = install_command(source, ref)
    # Use a file to avoid pipe deadlocks and retain useful errors without blocking the UI.
    with tempfile.TemporaryFile(mode='w+') as output:
        process = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT,
                                   stdin=subprocess.DEVNULL, env={**os.environ, 'LC_ALL': 'C'})
        offset = 0
        while True:
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                pass
            chunk = os.pread(output.fileno(), 1024 * 1024, offset)
            offset += len(chunk)
            lines = chunk.decode("utf-8", errors="replace")
            for line in lines.splitlines():
                if line.strip():
                    emit(log=line.rstrip())
                    # Follow the package manager's actual current item, including
                    # Update All; never animate every package in the group.
                    match = re.search(r'(?:Unpacking|Setting up) ([a-z0-9][a-z0-9+.:~-]*)', line)
                    flatpak = re.search(r'(?:Updating|Installing) ((?:app|runtime)/[A-Za-z0-9_./-]+)', line)
                    if match or flatpak:
                        emit(progress=True, source=source, package=(match or flatpak)[1], phase='Installing')
            if process.poll() is not None:
                break
        if process.returncode:
            output.seek(0)
            details = output.read().strip()
            raise RuntimeError(details or 'The package manager exited with status ' + str(process.returncode))


def error_summary(details):
    if 'cancel' in details.lower() or 'dismiss' in details.lower():
        return 'Administrator authorization was cancelled. Try again when you’re ready.'
    if 'pkexec must be setuid root' in details:
        return 'Administrator authorization could not start.'
    if 'lock' in details.lower():
        return 'Another package manager may be running. Wait for it to finish, then try again.'
    if 'Operation not permitted' in details or 'Permission denied' in details:
        return 'The system did not allow this update to finish.'
    return 'The update could not finish. View the error report for details.'


def main(action, selected_source=None, selected_package=None):
    available = sources()
    if selected_source and selected_source not in [s[0] for s in available]:
        emit(fatal="Unsupported update source.")
        return 1
    if action in ("update-source", "update-package") and not selected_source:
        emit(fatal="Choose an update source.")
        return 1
    if action == "update-package" and not selected_package:
        emit(fatal="Choose a package to update.")
        return 1
    lock_path = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / ('macshell-updates-' + str(os.getuid()) + '.lock')
    with lock_path.open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            emit(fatal='Another update operation is already running.')
            return 1
        failed = False
        for source, name, description, icon in available:
            if selected_source and source != selected_source:
                continue
            emit(progress=True, source=source, package=selected_package or '', phase='Checking' if action == 'check' else 'Updating')
            emit(source=source, name=name, description=description, icon=icon,
                 status='Checking…' if action == 'check' else 'Updating…', count=-1, error=False, details='')
            try:
                if action == 'update-package':
                    if selected_package not in [p['id'] for p in check(source)]:
                        raise ValueError('This update is no longer available. Check again.')
                    install(source, selected_package)
                elif action != 'check':
                    install(source)
                pending = check(source)
                emit(source=source, status=(str(len(pending)) + ' updates available') if pending else 'Up to date',
                     count=len(pending), packages=pending, details='', error=False)
            except Exception as exc:
                failed = True
                emit(source=source, status='Needs attention', count=-1, error=True,
                     details=error_summary(str(exc)), report=str(exc))
        emit(done=True, failed=failed, reboot=Path('/var/run/reboot-required').exists(), action=action)
        return int(failed)


if __name__ == '__main__':
    valid = {'check': 2, 'update': 2, 'update-source': 3, 'update-package': 4}
    if len(sys.argv) < 2 or len(sys.argv) != valid.get(sys.argv[1]):
        sys.exit('Usage: manage-updates.py check|update|update-source SOURCE|update-package SOURCE PACKAGE')
    sys.exit(main(*sys.argv[1:]))
