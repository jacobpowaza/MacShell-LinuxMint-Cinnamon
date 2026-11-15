# MacShell on Cinnamon/X11

The target is the actual [0-ss/MacShell](https://github.com/0-ss/MacShell) aesthetic and source UI on Linux Mint Cinnamon/X11. Source authority remains `../sources/MacShell` commit `51db0bab6997da310d2aacfaa7084740ec44ad4a`. Intentional user-approved changes are static SF typography, a functional Finder application, grouped dock icons, native application control styling, the full macOS wallpaper catalog, shared home Trash operations, and macOS popup motion. The old `../cinnamon-adaptation/app.py` recreation is stopped and excluded from the deliverable.

## Current experience

Static SF Pro Text supplies interface text; SF Pro Display supplies display roles, SF Pro Rounded the clock role, and SF Mono code/text preview. The variable SF face that produced incorrect spacing was removed from the active font directory. Fonts are installed locally under `~/.local/share/fonts/macshell-sf`, not bundled with this port; see FONT-PROVENANCE.md. Open Runde remains an upstream fallback, not the active default.

Finder is the default `inode/directory` handler (`org.macshell.Finder.desktop`) and replaces Thunar in default dock pins. Desktop folders, the bar's file action, and dock Trash open Finder. The global menu bar recognizes the source Qt Finder window, labels it Finder, and selects file actions. It supports multiple windows, grid/list views, search, hidden files, navigation, Quick Look, new folders, rename, copy/cut/paste, Trash, and Put Back from home Trash. It is a new MacShell adaptation, not a full macOS Finder feature clone. Existing FileManager1 owners or already-running applications may still route files to an older file manager.

Settings offers all 124 image entries from `LAYTAT/macOS-Wallpapers` (including two HEIC originals), alongside the 12 existing Mint entries. Cached metadata lists without network access; thumbnails can use the remote proxy, and explicit refresh uses the GitHub tree API. Selecting an uncached image downloads and verifies only that original before applying it through Cinnamon and persisting the selection. Cached originals appear locally in the grid and work offline. The catalog grid uses one Tab stop, arrow-key navigation, Return/Space activation, accessible Button names/actions and a visible focus border. HEIC uses installed libheif to extract the primary still as JPEG; time-of-day playback is not implemented.

Finder and the dock share the home XDG Trash backend. Finder exposes Empty Trash, Delete Immediately and Put Back; the dock opens the Finder confirmation. Destructive confirmations initially focus Cancel, and native failures remain visible. External-volume Trash is not aggregated. Validation preserved the existing 86 user items.

Approved popup motion adds restrained alert scale/elevation and fades, menu entrances, tooltip fades and pointer feedback. Reduce Motion removes scale/elevation and shortens fades. Live motion checks and the wallpaper/Trash fixture tests passed; scoped evidence is in `.impeccable/wallpapers-trash-motion/DEBUG-REPORT.md`.

The dock shows one icon per app in stable order across focus changes. Window preview cells default off (`showThumbs: false`) and remain optional. The source glass menu exposes every grouped window through bounded scrolling and keyboard navigation. Default pins are Finder, Firefox, Terminal, and the actual source Settings app; Settings and Clock also have actual source-app desktop entries.

`~/.themes/MacShell-Apps` adapts native GTK3/GTK4 controls and surfaces using existing WhiteSur-Dark coverage plus source palette and static SF typography. GTK4 imports unpacked resources while preserving prior user CSS. This does not rewrite every application's layout; Firefox/Electron and custom-rendered interfaces retain their own layout behavior.

## Lock and recovery

The native MacLock adapter currently owns `org.cinnamon.ScreenSaver` and runs as an active daemon under Cinnamon. The user confirmed real password unlock works. MacShell visuals are embedded in the original Cinnamon Stage; stock GTK password entry, PAM, grabs, and authentication authority remain in use. Sleep/watchdog and actual display DPMS tests passed, followed by observed unlocked GetActive false. These are scoped results, not a full physical S3 suspend test or a universal security guarantee.

Future D-Bus activation uses `macshell-lock-native.service` with a fallback Exec and `--hold`. Autostart starts only when no owner exists and never kills an active locker. Readiness timeout/F12 provide native fallback. The supervised `~/.local/bin/macshell-lock-test` checks current GetActive before testing.

## Runtime and limits

Portable Nix/proot Quickshell 0.3.2 and Qt 6.12 remain. Host NVIDIA driver support is available through `../port-runtime/qs`, with Intel/Mesa fallback. Source materials and geometry remain authoritative; full 1:1 behavior, all interactions, mixed scaling, multi-monitor behavior, and physical suspend recovery remain unproven. Earlier process-performance measurements predate Finder, static SF, and the active lock daemon; they are not current-build metrics.

Start: `~/.local/bin/macshell-cinnamon` or `~/.local/bin/macshell-cinnamon-start`. Restore: `~/.local/bin/macshell-mint-restore`. Restore guards against stopping active authentication and restores prior GTK CSS/font values, D-Bus/autostart files, and the saved Finder MIME association from `backup/sf-finder/finder-mime.txt`; it removes this port's own app entries. See PORT-STATUS.md for evidence boundaries.

## Idle/wake locker recovery

The session locker is explicitly isolated from application GTK dialog modules through `MACSHELL_SECURE_SURFACE=1` before GTK initialization. Its user service restarts unexpected exits, session autostart has no added delay, and the MacShell start command invokes the no-owner locker guard. The older popup adapter caused the 13:56 crash; a fresh isolated locker owns the screensaver name again. Current recovery checks and limits are recorded in `.impeccable/lock-recovery/RESULTS.md`. Pre-login startup remains LightDM/Slick Greeter, outside this user-session locker; system login configuration was not modified.

## Settings and Updates — November 13

The window and launcher are named Settings. General opens an Updates subpage, omitted from the sidebar; General stays selected while viewing it. Update sources disclose package cards with application icons or SF Symbol component fallbacks, versions, and individual Update actions. Collapsed source headers expose Update All for that source; the page also offers a global Update All. The manager supports APT, user/system Flatpak, and Snap when installed, preserves disclosure state across updates, streams progress/errors, and reports restart requirements. APT checks use the existing local catalog; a system-wide update refreshes it before upgrading. MacShell releases remain a separate link to preserve local desktop customizations. No upgrades were executed during validation. Backend scope, metadata, multiarch identity, argument validation, failure and cancellation tests: `python3 tests/update-manager.py`.
