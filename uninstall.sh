#!/usr/bin/env bash
# MacShell for Linux Mint Cinnamon — uninstaller
#
# Restores the settings and files that install.sh recorded on its first run, stops MacShell and
# removes what the installer added. Your own files (Desktop, Documents, clipboard history, ...) are never touched.
#
#   bash ~/.local/share/macshell-cinnamon/uninstall.sh [--keep-runtime] [--purge] [--yes] [--dry-run]
set -Eeuo pipefail
PREFIX="${MACSHELL_PREFIX:-$HOME/.local/share/macshell-cinnamon}"
BINDIR="${MACSHELL_BINDIR:-$HOME/.local/bin}"
ASSUME_YES=0 DRY_RUN=0 KEEP_RUNTIME=0 PURGE=0
for a in "$@"; do case "$a" in
  -y|--yes) ASSUME_YES=1;; --dry-run) DRY_RUN=1;; --keep-runtime) KEEP_RUNTIME=1;; --purge) PURGE=1;;
  -h|--help) sed -n '2,7p' "$0"; echo "  --keep-runtime  keep the downloaded Quickshell runtime (saves a re-download)"; echo "  --purge         also delete cached wallpapers and the MacShell icon theme"; exit 0;;
  *) echo "unknown option: $a" >&2; exit 2;; esac; done
if [ -t 1 ]; then B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; N=$'\033[0m'; else B= G= Y= N=; fi
step(){ printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
ok(){ printf '    %s✓%s %s\n' "$G" "$N" "$*"; }
warn(){ printf '    %s!%s %s\n' "$Y" "$N" "$*" >&2; }
run(){ if [ "$DRY_RUN" = 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }
STATE(){ MACSHELL_PREFIX="$PREFIX" python3 "$PREFIX/installer/macshell_state.py" "$@"; }

[ -d "$PREFIX" ] || { echo "MacShell does not appear to be installed ($PREFIX not found)."; exit 0; }
if [ "$ASSUME_YES" = 0 ] && [ "$DRY_RUN" = 0 ]; then
  if [ -r /dev/tty ]; then printf 'Uninstall MacShell and restore your previous desktop settings? [y/N] ' >/dev/tty; read -r a </dev/tty; case "$a" in y|Y|yes) ;; *) echo aborted; exit 1;; esac
  else echo "Not interactive; pass --yes to confirm." >&2; exit 1; fi
fi

step "Stopping MacShell"
locker_active=0
if command -v gdbus >/dev/null; then
  out="$(gdbus call --session --dest org.cinnamon.ScreenSaver --object-path /org/cinnamon/ScreenSaver --method org.cinnamon.ScreenSaver.GetActive 2>/dev/null || true)"
  case "$out" in *true*) locker_active=1;; esac
fi
units=(macshell-source.service macshell-native.service)
if [ "$locker_active" = 1 ]; then warn "the screen is locked right now; the lock service is left running until you log out"; else units+=(macshell-lock-native.service); fi
run systemctl --user stop "${units[@]}" 2>/dev/null || true
ok "services stopped"

if [ -f "$PREFIX/app/native-gtk/install.py" ]; then
  step "Removing the optional GTK dialog adapter"
  run /usr/bin/python3 "$PREFIX/app/native-gtk/install.py" --remove >/dev/null 2>&1 || warn "could not remove the dialog adapter setting"
fi

step "Restoring your previous settings and files"
if [ -f "$PREFIX/backup/manifest.json" ]; then
  if [ "$DRY_RUN" = 1 ]; then STATE status; else STATE restore | sed 's/^/    /'; fi
  ok "restored from the first-run backup"
else
  warn "no backup manifest found; nothing could be restored automatically (use Settings to choose a theme/panel)"
fi

step "Removing MacShell files"
run rm -f "$BINDIR/macshell-cinnamon-uninstall"
run rm -rf "$HOME/.local/share/fonts/macshell"
[ "$DRY_RUN" = 1 ] || { command -v fc-cache >/dev/null && fc-cache -f >/dev/null 2>&1 || true; }
if [ "$PURGE" = 1 ]; then run rm -rf "$HOME/.local/share/icons/MacShell-Tahoe" "$HOME/.local/share/macshell/wallpapers" "$HOME/.cache/macshell"; fi
run systemctl --user daemon-reload
if command -v gdbus >/dev/null && [ "$DRY_RUN" = 0 ]; then
  gdbus call --session --dest org.Cinnamon --object-path /org/Cinnamon --method org.Cinnamon.Eval \
   "imports.gi.Gio.DBus.session.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',new imports.gi.GLib.Variant('(su)',['org.freedesktop.Notifications',0]),null,imports.gi.Gio.DBusCallFlags.NONE,-1,null);" >/dev/null 2>&1 || true
fi
if [ "$DRY_RUN" = 0 ]; then
  if [ "$KEEP_RUNTIME" = 1 ]; then
    find "$PREFIX" -mindepth 1 -maxdepth 1 ! -name runtime ! -name clipboard -exec rm -rf {} +
    ok "kept $PREFIX/runtime (delete it later to free about 3 GB)"
  else
    find "$PREFIX" -mindepth 1 -maxdepth 1 ! -name clipboard -exec rm -rf {} +
    rmdir "$PREFIX" 2>/dev/null || true
    ok "removed $PREFIX (clipboard history, if any, was left in place)"
  fi
fi
printf '\n%sMacShell has been uninstalled.%s If the top bar still looks wrong, log out and back in.\n' "$G" "$N"
