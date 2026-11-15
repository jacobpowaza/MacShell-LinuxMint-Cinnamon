# Native GTK3 confirmations

This adapts real GtkMessageDialog confirmations used by GTK applications. It preserves application text, response IDs, default actions and modality; this is not an external QML substitute. GTK4, custom dialogs, file choosers and credential-entry dialogs are outside the layout hook.

Build:

```sh
gcc -std=c11 -fPIC -shared -Wall -Wextra -Werror macshell-dialogs.c -o libmacshell-dialogs.so -Wl,-z,defs -Wl,-z,relro,-z,now -l:libgtk-3.so.0 -l:libgdk-3.so.0 -l:libgmodule-2.0.so.0 -l:libgobject-2.0.so.0 -l:libglib-2.0.so.0
```

Install: `/usr/bin/python3 install.py`. It preserves unrelated Cinnamon XSettings overrides and modules, copies an immutable content-hashed library into the user's GTK3 module directory and enables it in the current session. Never overwrite a loaded shared library. `g_module_check_init` makes the module resident because GTK emission hooks outlive a dynamic setting change. The selected-path gate prevents old resident versions from transforming future dialogs.

Disable: `/usr/bin/python3 install.py --remove`. Existing dialogs retain their layout; future dialogs skip the hook. Native theme CSS remains part of MacShell-Apps.

Check: `/usr/bin/python3 stress-test.py` in a disposable test process. It exercises 70 create/destroy/removal/reload operations and verifies a stacked undecorated dialog still produces the original native Cancel response. Actual Terminal close-confirmation rendering was not independently captured; a real GTK3 confirmation fixture was inspected. A prior nonresident version caused Terminal crashes during module replacement and has been replaced by the resident implementation. No application close confirmations are automatically accepted.
