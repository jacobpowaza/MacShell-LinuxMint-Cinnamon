#!/usr/bin/env bash
# Helper used to capture the README screenshots from the live desktop (1920x1080, X11).
Q=~/.local/share/macshell-cinnamon/runtime/qs; P=~/.local/share/macshell-cinnamon/app/MacShell
ipc(){ "$Q" ipc --newest -p "$P" call "$@" >/dev/null 2>&1; }
OUT=${OUT:-$HOME/macshell-release/assets/screenshots}
shot(){ sleep "${2:-1.5}"; gnome-screenshot -f "$OUT/$1.png" 2>/dev/null; }
