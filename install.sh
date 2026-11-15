#!/usr/bin/env bash
# MacShell for Linux Mint Cinnamon — installer
#
#   curl -fsSL https://raw.githubusercontent.com/jacobpowaza/MacShell-LinuxMint-Cinnamon/main/install.sh | bash
#
# or, to read it first:
#   curl -fsSLO https://raw.githubusercontent.com/jacobpowaza/MacShell-LinuxMint-Cinnamon/main/install.sh
#   less install.sh && bash install.sh
#
# Everything lives in your home directory. sudo is used for exactly one thing: `apt-get install`
# of missing system packages (and only after you confirm). Re-running is safe; the first-run backup
# of your settings is never overwritten, and uninstall.sh restores it.
set -Eeuo pipefail

REPO="jacobpowaza/MacShell-LinuxMint-Cinnamon"
REF="${MACSHELL_REF:-main}"
PREFIX="${MACSHELL_PREFIX:-$HOME/.local/share/macshell-cinnamon}"
BINDIR="${MACSHELL_BINDIR:-$HOME/.local/bin}"
NIX_PORTABLE_URL="https://github.com/DavHau/nix-portable/releases/download/v012/nix-portable-x86_64"
NIX_PORTABLE_SHA256="b409c55904c909ac3aeda3fb1253319f86a89ddd1ba31a5dec33d4a06414c72a"
NIXPKGS_REV="d4f25a3e562008648d45bcf2d70bcc7422cad84e"   # provides Quickshell 0.3.2 + Mesa 26.3
MACOS_LIKE_URL="https://github.com/Scrimas/MacOS-Like.git"
MACOS_LIKE_REV="838dfd392b24d2e5886b6618bee63f84328baa52"
WALLPAPER_ID="macos-2bfe43a4da034917"                     # "Yosemite" from the bundled wallpaper catalog
MIN_FREE_GB=6

ASSUME_YES=0 DRY_RUN=0 NO_START=0 NO_SETTINGS=0 NO_RUNTIME=0 NO_WALLPAPER=0 KEEP_PANEL=0 FORCE=0 NATIVE_DIALOGS=0 SKIP_DEPS=0
SRC_DIR="" TMP_DIR=""
WARNINGS=()

if [ -t 1 ]; then B=$'\033[1m'; D=$'\033[2m'; R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; C=$'\033[36m'; N=$'\033[0m'; else B= D= R= G= Y= C= N=; fi
step()  { printf '\n%s==>%s %s%s%s\n' "$C" "$N" "$B" "$*" "$N"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %s✓%s %s\n' "$G" "$N" "$*"; }
warn()  { printf '    %s!%s %s\n' "$Y" "$N" "$*" >&2; WARNINGS+=("$*"); }
die()   { printf '\n%sError:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }
trap 'rc=$?; [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; if [ $rc -ne 0 ]; then printf "\n%sInstallation stopped (exit %s).%s Re-run the installer to resume; uninstall.sh can undo anything already applied.\nSee README → Troubleshooting.\n" "$R" "$rc" "$N" >&2; fi; exit $rc' EXIT
run() { if [ "$DRY_RUN" = 1 ]; then printf '    %s[dry-run]%s %s\n' "$D" "$N" "$*"; else "$@"; fi; }

usage() {
cat <<EOF
MacShell for Linux Mint Cinnamon — installer

Usage: install.sh [options]

  -y, --yes            do not ask questions (needed when piped from curl without a terminal)
      --dry-run        show what would happen; change nothing
      --no-start       install but do not start MacShell or hide the Cinnamon panel
      --no-settings    do not touch gsettings/dconf (themes are installed but not selected)
      --no-wallpaper   keep your current wallpaper
      --keep-panel     keep the Cinnamon panel visible (MacShell's menu bar is shown as well)
      --no-runtime     skip downloading the Quickshell runtime (use an existing one in \$PREFIX/runtime)
      --native-dialogs also build the experimental GTK dialog adapter (needs gcc and libgtk-3-dev)
      --skip-deps      do not check or install apt packages (you promise they are present)
      --force          continue on unsupported distribution / session (not recommended)
      --ref REF        install from a branch, tag or commit of $REPO (default: main)
  -h, --help           show this help

Environment: MACSHELL_PREFIX (default ~/.local/share/macshell-cinnamon), MACSHELL_REF
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1;; --dry-run) DRY_RUN=1;; --no-start) NO_START=1;; --no-settings) NO_SETTINGS=1;;
    --no-wallpaper) NO_WALLPAPER=1;; --keep-panel) KEEP_PANEL=1;; --no-runtime) NO_RUNTIME=1;;
    --native-dialogs) NATIVE_DIALOGS=1;; --skip-deps) SKIP_DEPS=1;; --force) FORCE=1;;
    --ref) REF="${2:?--ref needs a value}"; shift;;
    -h|--help) usage; exit 0;; *) usage >&2; die "unknown option: $1";;
  esac; shift
done

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    local a; printf '    %s [y/N] ' "$1" >/dev/tty; read -r a </dev/tty || return 1
    case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac
  fi
  return 1
}

locate_sources() {
  step "Locating MacShell sources"
  local self="${BASH_SOURCE[0]:-}"
  if [ -n "$self" ] && [ -f "$self" ]; then
    local d; d="$(cd "$(dirname "$self")" && pwd)"
    if [ -f "$d/cinnamon/app/native.py" ]; then SRC_DIR="$d"; ok "using local checkout: $d"; return; fi
  fi
  command -v curl >/dev/null || die "curl is required (sudo apt install curl)."
  command -v tar  >/dev/null || die "tar is required."
  TMP_DIR="$(mktemp -d)"
  info "downloading $REPO@$REF"
  if [ "$DRY_RUN" = 1 ]; then SRC_DIR="$TMP_DIR"; info "[dry-run] would download and extract the repository"; return; fi
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$TMP_DIR" --strip-components=1 \
    || die "could not download $REPO@$REF. Check your internet connection and that the ref exists."
  [ -f "$TMP_DIR/cinnamon/app/native.py" ] || die "downloaded archive does not look like MacShell (cinnamon/app/native.py missing)."
  SRC_DIR="$TMP_DIR"; ok "sources ready"
}

preflight() {
  step "Checking compatibility"
  [ "$(id -u)" != 0 ] || die "do not run the installer as root. It installs into your home directory and asks for sudo only when needed."
  [ "$(uname -m)" = x86_64 ] || die "only x86_64 is supported (found $(uname -m))."
  local id="" ver="" pretty=""
  if [ -r /etc/os-release ]; then . /etc/os-release; id="${ID:-}"; ver="${VERSION_ID:-}"; pretty="${PRETTY_NAME:-$id}"; fi
  info "distribution : ${pretty:-unknown}"
  if [ "$id" = linuxmint ] && [ "${ver%%.*}" -ge 22 ] 2>/dev/null; then ok "Linux Mint $ver is supported"
  elif [ "$id" = linuxmint ]; then
    [ "$FORCE" = 1 ] || die "Linux Mint $ver is older than 22 (Cinnamon 6 / Ubuntu 24.04 base); it is untested. Use --force to try anyway."
    warn "Linux Mint $ver is untested"
  else
    [ "$FORCE" = 1 ] || die "this port targets Linux Mint 22.x Cinnamon (found: ${pretty:-unknown}). Use --force to try anyway."
    warn "unsupported distribution (${pretty:-unknown}); continuing because of --force"
  fi
  local de="${XDG_CURRENT_DESKTOP:-}"
  case "$de" in *[Cc]innamon*) ok "desktop environment: $de";;
    *) [ "$FORCE" = 1 ] || die "run this from inside a Cinnamon session (XDG_CURRENT_DESKTOP='${de}')."; warn "not a Cinnamon session";; esac
  if [ "${XDG_SESSION_TYPE:-}" = x11 ]; then ok "session type: X11"
  else [ "$FORCE" = 1 ] || die "MacShell's adapter needs an X11 session (found '${XDG_SESSION_TYPE:-unknown}'). Log out and choose the Cinnamon (X11) session."; warn "session is not X11"; fi
  if command -v cinnamon >/dev/null; then
    local cv; cv="$(cinnamon --version 2>/dev/null | awk '{print $2}')"
    info "Cinnamon     : ${cv:-unknown}"
    [ "${cv%%.*}" -ge 6 ] 2>/dev/null || warn "Cinnamon ${cv:-?} is older than 6.0; untested"
  else [ "$FORCE" = 1 ] || die "the 'cinnamon' command was not found."; fi
  systemctl --user show-environment >/dev/null 2>&1 || die "the systemd user session is not reachable (systemctl --user failed)."
  [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ] || die "no D-Bus session bus; run this from a graphical session."
  mkdir -p "$(dirname "$PREFIX")"
  local free; free=$(df -Pk "$(dirname "$PREFIX")" | awk 'NR==2{printf "%d", $4/1048576}')
  if [ "${free:-0}" -ge "$MIN_FREE_GB" ]; then ok "free disk space: ${free} GB (need about $MIN_FREE_GB GB)"
  else die "only ${free} GB free in $(dirname "$PREFIX"); about $MIN_FREE_GB GB are needed (the Quickshell runtime alone is about 3 GB)."; fi
  if [ "$NO_RUNTIME" = 0 ]; then
    curl -fsSI --max-time 15 https://github.com >/dev/null 2>&1 || die "cannot reach github.com; check your internet connection."
    curl -fsSI --max-time 15 https://cache.nixos.org/nix-cache-info >/dev/null 2>&1 || die "cannot reach cache.nixos.org (needed to download Quickshell)."
    ok "network: github.com and cache.nixos.org reachable"
  fi
}

APT_REQUIRED=(python3 python3-xlib python3-gi python3-gi-cairo python3-pil python3-cairo gir1.2-gtk-3.0 wmctrl x11-xserver-utils xclip jq curl git fontconfig libglib2.0-bin dconf-cli xdg-utils)
APT_OPTIONAL=(ffmpeg brightnessctl)
deps() {
  step "Checking system packages"
  if [ "$SKIP_DEPS" = 1 ]; then info "--skip-deps: not checking"; return; fi
  local missing=() opt=() p
  for p in "${APT_REQUIRED[@]}"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep 'install ok installed' >/dev/null || missing+=("$p"); done
  for p in "${APT_OPTIONAL[@]}"; do dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep 'install ok installed' >/dev/null || opt+=("$p"); done
  [ ${#opt[@]} -gt 0 ] && info "optional, not installed (screen recording / brightness keys): ${opt[*]}"
  if [ ${#missing[@]} -eq 0 ]; then ok "all required packages are installed"; return; fi
  info "missing packages: ${missing[*]}"
  command -v apt-get >/dev/null || die "apt-get not found; install these packages manually: ${missing[*]}"
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would run: sudo apt-get install -y ${missing[*]}"; return; fi
  if confirm "Install them now with sudo apt-get?"; then
    sudo apt-get install -y "${missing[@]}" || die "apt-get failed. Install the packages above manually and re-run."
    ok "installed ${#missing[@]} package(s)"
  else
    die "missing packages. Install with:  sudo apt-get install -y ${missing[*]}   (then re-run, or pass --yes)"
  fi
}

STATE() { MACSHELL_PREFIX="$PREFIX" python3 "$PREFIX/installer/macshell_state.py" "$@"; }
put_file() {
  local mode="${3:-}"
  run env MACSHELL_PREFIX="$PREFIX" python3 "$PREFIX/installer/macshell_state.py" file "$1" "$2" ${mode:+--mode "$mode"} --subst "PREFIX=$PREFIX" "BINDIR=$BINDIR" "HOME=$HOME"
}

runtime() {
  step "Setting up the Quickshell runtime"
  local rt="$PREFIX/runtime"
  run mkdir -p "$rt"
  if [ "$NO_RUNTIME" = 1 ]; then
    [ -x "$rt/qs" ] || die "--no-runtime was given but $rt/qs does not exist."
    ok "keeping existing runtime"; return
  fi
  if [ -f "$rt/store-paths.env" ] && . "$rt/store-paths.env" 2>/dev/null && [ -x "$rt/nix/.nix-portable${QS_STORE:-/x}/bin/quickshell" ]; then
    ok "runtime already present ($(basename "$QS_STORE")); keeping it"
  else
    local np="$rt/nix-portable"
    if [ ! -x "$np" ] || ! echo "$NIX_PORTABLE_SHA256  $np" | sha256sum -c --quiet 2>/dev/null; then
      info "downloading nix-portable v012 (68 MB)"
      if [ "$DRY_RUN" != 1 ]; then
        curl -fL $([ -t 2 ] && echo --progress-bar || echo -sS) -o "$np.part" "$NIX_PORTABLE_URL" && echo "$NIX_PORTABLE_SHA256  $np.part" | sha256sum -c --quiet \
          || { rm -f "$np.part"; die "nix-portable download failed its SHA-256 check."; }
        mv "$np.part" "$np"; chmod +x "$np"
      fi
    fi
    info "downloading Quickshell + Mesa from cache.nixos.org (about 1.5 GB, 3 GB on disk; a few minutes the first time)"
    if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would run nix-portable build for quickshell, mesa, libglvnd @ nixpkgs $NIXPKGS_REV"; return; fi
    local out
    out="$(NP_LOCATION="$rt/nix" NP_RUNTIME=proot NP_GIT=/usr/bin/git "$np" nix build --no-link --print-out-paths \
        --extra-experimental-features 'nix-command flakes' \
        "github:NixOS/nixpkgs/$NIXPKGS_REV#quickshell" "github:NixOS/nixpkgs/$NIXPKGS_REV#mesa" "github:NixOS/nixpkgs/$NIXPKGS_REV#libglvnd")" \
      || die "the Nix build failed. Re-running the installer resumes the download. See README → Troubleshooting → 'Quickshell download fails'."
    local qs mesa glvnd
    qs="$(grep -m1 -- '-quickshell-' <<<"$out")"; mesa="$(grep -m1 -E -- '-mesa-[0-9.]+$' <<<"$out")"; glvnd="$(grep -m1 -- '-libglvnd-' <<<"$out")"
    [ -n "$qs" ] && [ -n "$mesa" ] && [ -n "$glvnd" ] || die "unexpected nix output: $out"
    printf 'QS_STORE=%s\nMESA_STORE=%s\nGLVND_STORE=%s\n' "$qs" "$mesa" "$glvnd" > "$rt/store-paths.env"
    ok "Quickshell runtime built: $(basename "$qs")"
  fi
  [ "$DRY_RUN" = 1 ] && return
  . "$rt/store-paths.env"
  sed -e "s#@PREFIX@#$PREFIX#g" -e "s#@QS_STORE@#$QS_STORE#g" -e "s#@MESA_STORE@#$MESA_STORE#g" -e "s#@GLVND_STORE@#$GLVND_STORE#g" \
      "$SRC_DIR/cinnamon/templates/runtime/qs" > "$rt/qs.new"
  chmod 755 "$rt/qs.new"; mv "$rt/qs.new" "$rt/qs"
  install -m 644 "$SRC_DIR/cinnamon/templates/runtime/refresh-nvidia.py" "$rt/refresh-nvidia.py"
  local v; v="$("$rt/qs" --version 2>&1 | head -1)" || true
  case "$v" in Quickshell*) ok "$v";; *) die "Quickshell did not start: $v";; esac
}

payload() {
  step "Installing MacShell files to $PREFIX"
  run mkdir -p "$PREFIX/installer"
  run install -m 755 "$SRC_DIR/cinnamon/installer/macshell_state.py" "$PREFIX/installer/macshell_state.py"
  run install -m 755 "$SRC_DIR/uninstall.sh" "$PREFIX/uninstall.sh"
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would replace $PREFIX/app with the MacShell payload"; return; fi
  rm -rf "$PREFIX/app.new"; cp -a "$SRC_DIR/cinnamon/app" "$PREFIX/app.new"
  find "$PREFIX/app.new" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
  rm -rf "$PREFIX/app.old"; [ -d "$PREFIX/app" ] && mv "$PREFIX/app" "$PREFIX/app.old"
  mv "$PREFIX/app.new" "$PREFIX/app"; rm -rf "$PREFIX/app.old"
  printf '%s\n' "$REF" > "$PREFIX/VERSION"
  ok "application files installed"
}

sf_fonts_present() { local l; l="$(fc-list 2>/dev/null || true)"; grep -qi 'SF Pro Text' <<<"$l"; }

assets() {
  step "Installing themes, icons and fonts"
  local T="$SRC_DIR/cinnamon/templates"
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would install MacShell-Apps / MacShell-Cinnamon themes, Rounded Corners extension, Open Runde fonts, MacShell-Tahoe icons"; return; fi
  for t in MacShell-Apps MacShell-Cinnamon; do STATE tree "$SRC_DIR/cinnamon/themes/$t" "$HOME/.themes/$t"; done
  put_file "$T/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css" 644
  put_file "$T/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css" 644
  ok "GTK/Cinnamon themes (WhiteSur-based, GPL-3.0) installed"
  STATE tree "$SRC_DIR/cinnamon/extensions/RoundedCorners@klangman" "$HOME/.local/share/cinnamon/extensions/RoundedCorners@klangman"
  ok "Rounded Corners extension installed"
  mkdir -p "$HOME/.local/share/fonts/macshell"
  cp -f "$SRC_DIR"/cinnamon/app/MacShell/assets/fonts/*.otf "$HOME/.local/share/fonts/macshell/"
  if sf_fonts_present; then ok "Apple SF fonts found on this system; they will be used"
  else
    put_file "$T/fontconfig/60-macshell-fallback.conf" "$HOME/.config/fontconfig/conf.d/60-macshell-fallback.conf" 644
    info "SF fonts are not installed (they cannot be redistributed); Open Runde is used instead"
  fi
  fc-cache -f "$HOME/.local/share/fonts/macshell" >/dev/null 2>&1 || true
  icons
}

icons() {
  local dest="$HOME/.local/share/icons/MacShell-Tahoe"
  if [ -f "$dest/.macshell-built" ]; then ok "icon theme MacShell-Tahoe already built"; return; fi
  if [ -d "$dest" ]; then warn "existing $dest is not ours; leaving it untouched"; return; fi
  info "fetching the MacOS-Like / MacTahoe icon theme (GPL-3.0)"
  local work; work="$(mktemp -d)"
  ( cd "$work" && git clone --quiet --filter=blob:none --no-checkout "$MACOS_LIKE_URL" mac && cd mac \
      && git sparse-checkout set --no-cone /vendor/MacTahoe /vendor/MacTahoe-dark /prebuilt/Dark /LICENSE \
      && git checkout --quiet "$MACOS_LIKE_REV" ) \
    || { rm -rf "$work"; warn "could not fetch the icon theme; the desktop will keep your current icon theme"; return; }
  rm -rf "$dest.partial"
  python3 -I - "$work/mac" "$dest.partial" <<'PY' || { rm -rf "$work" "$dest.partial"; warn "icon theme assembly failed; your current icon theme is kept"; return; }
import shutil, sys
src, dst = sys.argv[1:]
for part in ("vendor/MacTahoe", "vendor/MacTahoe-dark", "prebuilt/Dark"):
    shutil.copytree(f"{src}/{part}", dst, dirs_exist_ok=True, symlinks=False, ignore_dangling_symlinks=True)
shutil.copy2(f"{src}/LICENSE", f"{dst}/LICENSE")
PY
  mv "$dest.partial" "$dest"
  sed -i -e 's/^Name=MacTahoe-dark/Name=MacShell-Tahoe/' -e 's/^Inherits=.*/Inherits=Mint-Y,Adwaita,hicolor/' "$dest/index.theme"
  gtk-update-icon-cache -f "$dest" >/dev/null 2>&1 || true
  touch "$dest/.macshell-built"; rm -rf "$work"
  ok "icon theme MacShell-Tahoe installed"
}

integrate() {
  step "Installing launchers, services and autostart entries"
  local T="$SRC_DIR/cinnamon/templates" f
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would write $BINDIR/macshell-*, systemd user units, autostart and desktop entries (existing files are backed up)"; return; fi
  mkdir -p "$BINDIR"
  for f in macshell-cinnamon macshell-cinnamon-start macshell-cinnamon-apps macshell-lock-start; do put_file "$T/bin/$f" "$BINDIR/$f" 755; done
  ln -sf "$PREFIX/uninstall.sh" "$BINDIR/macshell-cinnamon-uninstall"
  for f in macshell-native macshell-source macshell-lock-native; do put_file "$T/systemd/$f.service" "$HOME/.config/systemd/user/$f.service" 644; done
  for f in macshell-cinnamon macshell-lock-native; do put_file "$T/autostart/$f.desktop" "$HOME/.config/autostart/$f.desktop" 644; done
  for f in Finder Settings Clock; do put_file "$T/applications/org.macshell.$f.desktop" "$HOME/.local/share/applications/org.macshell.$f.desktop" 644; done
  put_file "$T/dbus/org.cinnamon.ScreenSaver.service" "$HOME/.local/share/dbus-1/services/org.cinnamon.ScreenSaver.service" 644
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
  systemctl --user daemon-reload
  case ":$PATH:" in *":$BINDIR:"*) ;; *) warn "$BINDIR is not on your PATH; log out and back in";; esac
  ok "launchers and services installed"
}

native_dialogs() {
  [ "$NATIVE_DIALOGS" = 1 ] || return 0
  step "Building the experimental GTK dialog adapter"
  command -v gcc >/dev/null && pkg-config --exists gtk+-3.0 || { warn "gcc and libgtk-3-dev are required for --native-dialogs; skipped"; return 0; }
  [ "$DRY_RUN" = 1 ] && return 0
  ( cd "$PREFIX/app/native-gtk" && gcc -std=c11 -fPIC -shared -Wall -Wextra -Werror macshell-dialogs.c -o libmacshell-dialogs.so \
      -Wl,-z,defs -Wl,-z,relro,-z,now -l:libgtk-3.so.0 -l:libgdk-3.so.0 -l:libgmodule-2.0.so.0 -l:libgobject-2.0.so.0 -l:libglib-2.0.so.0 \
      && /usr/bin/python3 install.py ) && ok "dialog adapter enabled" || warn "dialog adapter build failed (optional; skipped)"
}

settings() {
  step "Applying desktop settings (originals are backed up first)"
  if [ "$NO_SETTINGS" = 1 ]; then info "--no-settings: skipped"; return; fi
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would set: Cinnamon theme, GTK theme, icon theme, fonts, window buttons, keybindings, default file manager"; return; fi
  local font="Open Runde 10" tfont="Open Runde Semibold 10"
  if sf_fonts_present; then font="SF Pro Text 10"; tfont="SF Pro Text Semibold 10"; fi
  local icontheme="MacShell-Tahoe"
  [ -f "$HOME/.local/share/icons/MacShell-Tahoe/.macshell-built" ] || icontheme="$(gsettings get org.cinnamon.desktop.interface icon-theme | tr -d "'")"
  STATE gset org.cinnamon.theme name "'MacShell-Cinnamon'"
  STATE gset org.cinnamon.desktop.interface gtk-theme "'MacShell-Apps'"
  STATE gset org.cinnamon.desktop.interface icon-theme "'$icontheme'"
  STATE gset org.cinnamon.desktop.interface font-name "'$font'"
  STATE gset org.cinnamon.desktop.wm.preferences theme "'MacShell-Apps'"
  STATE gset org.cinnamon.desktop.wm.preferences button-layout "'close,minimize,maximize:'"
  STATE gset org.cinnamon.desktop.wm.preferences titlebar-font "'$tfont'"
  STATE gset org.nemo.desktop show-desktop-icons false || true
  STATE gadd org.cinnamon enabled-extensions "RoundedCorners@klangman" || warn "could not enable the Rounded Corners extension"
  local kb="/org/cinnamon/desktop/keybindings/custom-keybindings" kf; kf="$(mktemp)"
  printf "[/]\nname='MacShell Apps'\ncommand='%s/macshell-cinnamon-apps'\nbinding=['Super_L','Super_R']\n" "$BINDIR" > "$kf"
  STATE dconf "$kb/macshell-apps/" "$kf" || warn "could not register the Super-key shortcut"
  printf "[/]\nname='MacShell Spotlight'\ncommand='%s/macshell-cinnamon spotlight'\nbinding=['<Super><Alt>space']\n" "$BINDIR" > "$kf"
  STATE dconf "$kb/macshell-cinnamon-spotlight/" "$kf" || warn "could not register the Spotlight shortcut"
  rm -f "$kf"
  STATE gadd org.cinnamon.desktop.keybindings custom-list macshell-apps
  STATE gadd org.cinnamon.desktop.keybindings custom-list macshell-cinnamon-spotlight
  STATE mime inode/directory org.macshell.Finder.desktop || warn "could not make Finder the default folder handler"
  ok "theme, icons, fonts ($font), window buttons, shortcuts and Finder default applied"
}

wallpaper() {
  if [ "$NO_WALLPAPER" = 1 ] || [ "$NO_SETTINGS" = 1 ]; then return 0; fi
  if [ "$DRY_RUN" = 1 ]; then info "[dry-run] would download the Yosemite wallpaper and set it"; return; fi
  step "Setting the default wallpaper"
  local path
  path="$(cd "$PREFIX/app" && python3 -I - "$WALLPAPER_ID" <<'PY' 2>/dev/null
import sys; sys.path.insert(0,'.')
import wallpaper_catalog as w
print(w.request({'action':'download','id':sys.argv[1]}))
PY
)" || path=""
  if [ -n "$path" ] && [ -f "$path" ]; then
    STATE gset org.cinnamon.desktop.background picture-uri "'file://$path'"; STATE gset org.cinnamon.desktop.background picture-options "'zoom'"
    ok "wallpaper: $(basename "$path")"
  else warn "wallpaper download failed; your current wallpaper was kept (pick one later in Settings)"; fi
}

shell_healthy() {
  systemctl --user is-active --quiet macshell-native.service && systemctl --user is-active --quiet macshell-source.service \
    && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/macshell-cinnamon-port/native.sock" ] \
    && "$PREFIX/runtime/qs" ipc --newest -p "$PREFIX/app/MacShell" show >/dev/null 2>&1
}
start() {
  step "Starting MacShell"
  if [ "$NO_START" = 1 ]; then info "--no-start: not starting. Start later with:  $BINDIR/macshell-cinnamon start"; return; fi
  [ "$DRY_RUN" = 1 ] && { info "[dry-run] would start the services and verify them"; return; }
  systemctl --user import-environment DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP 2>/dev/null || true
  systemctl --user restart macshell-native.service macshell-source.service
  local i; for i in $(seq 1 45); do shell_healthy && break; sleep 1; done
  if ! shell_healthy; then
    warn "MacShell did not become ready in 45 s; your Cinnamon panel was left in place. Logs: journalctl --user -u macshell-source.service -u macshell-native.service"
    return
  fi
  ok "MacShell is running"
  "$BINDIR/macshell-lock-start" >/dev/null 2>&1 && ok "lock screen service ready" || warn "lock screen service could not be started (Cinnamon's stock lock is unchanged)"
  if [ "$NO_SETTINGS" = 0 ] && [ "$KEEP_PANEL" = 0 ]; then
    STATE gset org.cinnamon panels-enabled "@as []" && ok "Cinnamon panel hidden (MacShell's menu bar replaces it)"
  fi
}

summary() {
  printf '\n%s✓ MacShell is installed.%s\n\n' "$G" "$N"
  cat <<EOF
  Location      $PREFIX
  Commands      macshell-cinnamon {start|stop|restart|control|spotlight|settings|finder|widgets}
  Shortcuts     Super = applications · Super+Alt+Space = Spotlight
  Backups       $PREFIX/backup  (first-run originals; never overwritten by re-running)
  Logs          journalctl --user -u macshell-source.service -u macshell-native.service
  Uninstall     bash $PREFIX/uninstall.sh      (restores your previous desktop settings)

EOF
  if [ ${#WARNINGS[@]} -gt 0 ]; then printf '  %sNotes (%d):%s\n' "$Y" "${#WARNINGS[@]}" "$N"; printf '   - %s\n' "${WARNINGS[@]}"; echo; fi
  if [ "$NO_START" = 1 ]; then printf '  Not started (--no-start). Run: macshell-cinnamon start\n\n'; fi
}

main() {
  printf '%sMacShell for Linux Mint Cinnamon%s — installer%s\n' "$B" "$N" "$([ "$DRY_RUN" = 1 ] && echo '  [dry-run]' || true)"
  locate_sources; preflight; deps; payload; runtime; assets; integrate; native_dialogs; settings; wallpaper; start
  if [ "$DRY_RUN" = 1 ]; then printf '\n%sDry run complete; nothing was changed.%s\n' "$B" "$N"; return; fi
  summary
}
main "$@"
