from pathlib import Path
import tempfile,subprocess
base=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="macshell-update-test-") as directory:
    path=Path(directory)
    (path/"UpdateManager.qml").write_text((base/"MacShell/UpdateManager.qml").read_text())
    (path/"shell.qml").write_text((base/"tests/update-state.qml").read_text().replace('"../MacShell"','"."'))
    result=subprocess.run([str(base.parent/"runtime/qs"),"-p",directory,"--no-color"],capture_output=True,text=True,timeout=15)
    output=result.stdout+result.stderr
    assert "PASS:" in output and "FAIL:" not in output,output
    print(next(line for line in output.splitlines() if "PASS:" in line))
