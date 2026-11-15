"""Run the fixed updater on the host, outside Quickshell's proot tracer.

ptrace prevents setuid pkexec and FUSE mounts from working. The native backend
is a regular user process; policykit still authenticates every privileged task.
"""
import json
import os
from pathlib import Path
import subprocess


def update_command(arg):
    action = arg.get('action')
    required = {'check': 0, 'update': 0, 'update-source': 1, 'update-package': 2}
    if action not in required:
        raise ValueError('Unsupported update action')
    selection = [arg.get('source'), arg.get('package')][:required[action]]
    if any(not isinstance(value, str) or not value or len(value) > 512 for value in selection):
        raise ValueError('Choose an update source and package')
    # The updater validates sources and package identities before invoking pkexec.
    return ['/usr/bin/python3', str(Path(__file__).parent/'MacShell/assets/manage-updates.py'), action, *selection]


def stream_updates(arg):
    command = update_command(arg)
    env = os.environ.copy()
    for key in ['QT_PLUGIN_PATH', 'QML2_IMPORT_PATH', 'QML_IMPORT_PATH',
                'LD_LIBRARY_PATH', 'QT_QPA_PLATFORM_PLUGIN_PATH']:
        env.pop(key, None)
    env['PATH'] = '/usr/local/bin:/usr/bin:/bin'
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          stdin=subprocess.DEVNULL, text=True, env=env) as process:
        completed = False
        for line in process.stdout:
            try:
                event = json.loads(line)
            except ValueError:
                event = {'log': line.rstrip()}
            completed |= bool(event.get('done') or event.get('fatal'))
            yield event
        process.wait()
        if not completed:
            yield {'fatal': 'The update service stopped unexpectedly. Check again to retry.'}
