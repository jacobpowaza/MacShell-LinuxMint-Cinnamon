# MacShell popup and native-surface inventory

Audit: 2026-11-13. Scope: active source port, installed Cinnamon/GTK themes, shell external-dialog call sites, installed Cinnamon settings modules and Mint utilities. This is a source/configuration inventory with representative live render checks, not a claim that every dialog in every installed application was opened.

## Applied macOS styling

- Shared `MacAlert.qml`: rounded 28px neutral surface, SF text, 64px semantic icon, left-aligned heading/body, wrapped scrollable messages, full-width stacked pill actions, destructive tint, focus indicators, modal dimming, Escape cancellation. Follows the shell's Light/Dark appearance.
- Finder operation errors; New Folder, Rename and New Tag sheets; Settings update alert now use that component.
- Finder toolbar and Gallery tooltips use `MacToolTip.qml` rather than Qt's default tooltip.
- GTK3/GTK4: message/error/warning/confirmation dialogs, ordinary dialog surfaces/action areas, file chooser surfaces, popovers, context menus, combo menus, separators, disabled/hover/focus states and tooltips receive the native popup stylesheet.
- Cinnamon: generic confirmation/notification dialogs, authorization and mount-password prompts, Run dialog, end-session dialog, mount/process-blocking dialogs, audio-device prompts, popup/submenus, fallback notifications, OSDs, workspace switcher, application switcher and resize overlays receive matching typography/surfaces/actions.

GTK and Cinnamon follow the existing dark native theme. QML alerts follow MacShell Light/Dark. The light reference has not been forced onto the user's dark desktop.

## Still native: exact shell handoffs

These are the remaining Linux dialog **layouts/behaviors**, even when their GTK controls now have MacShell colors and rounded buttons. They are not custom MacShell QML pickers.

| Surface | Entry point | What remains native |
|---|---|---|
| Desktop folder chooser | `MacShell/Desktop.qml`, directory picker | Zenity/Yad chooser; KDialog fallback if installed |
| Widget image chooser | `MacShell/MacWidgets.qml`, picture selection | Native file list, breadcrumbs, filters, Open/Cancel layout |
| Screenshot save-folder chooser | `MacShell/MacDock.qml`, screenshot settings | Native directory picker |
| Profile picture chooser | `MacShell/MacDock.qml`, user/avatar settings | Native image picker |
| Wallpaper folder chooser | `MacShell/MacBar.qml`, wallpaper folder | Native directory picker |
| Keyboard Shortcuts… | `MacShell/MacBar.qml`, Help/menu action | Opens the original Cinnamon Keyboard settings window, including shortcut-edit/capture dialogs |
| Open files / associated apps | Finder, desktop, widgets, clipboard, settings Open Folder actions via `xdg-open` | The receiving application's own menus/dialogs; MacShell cannot impose its QML layout through this handoff |

The dormant upstream Installer still invokes `pkexec pacman`: it retains its original authorization/install path and is not a Mint package installer. It was not invoked.

## Still native: Cinnamon dialog structure

These use the new Cinnamon theme but retain native widget ordering, horizontal multi-action rows, existing semantic icons and authentication behavior:

1. Authorization / Polkit prompts, identity selection, password entry and failure messages.
2. Network and keyring secret prompts.
3. Removable/encrypted-drive password, mount question, busy-process and unmount dialogs.
4. Log Out, Restart, Shut Down, session inhibitors and timeout prompts.
5. Run Command, completion and command-error views.
6. Audio-device selection.
7. Generic system confirmations, warnings and notifications.
8. Extension/applet/desklet confirmations and error dialogs.
9. Cinnamon fallback applet menus, panel menus, window menus, submenus and tooltips.
10. Native volume/brightness/workspace/switcher/resize overlays.

The MacLock password stage remains the existing native Cinnamon/PAM stage. This change does not replace its credential entry or recovery path. The login screen before the user session is also outside these per-user themes.

## Still native: installed Cinnamon settings windows

MacShell already exposes many settings directly. Opening these original modules still uses Cinnamon's own GTK layout and secondary dialogs. The active GTK theme applies to normal user-session windows. The complete installed module list is:

accessibility, actions, applets, backgrounds, calendar, default, desklets, desktop, display, effects, extensions, fonts, general, gestures, hotcorner, keyboard, mouse, nightlight, notifications, panel, power, privacy, screensaver, sound, startup, themes, thunderbolt, user, windows, workspaces.

## Still native: installed Mint and desktop utilities

Their application menus, context menus, preferences, About/help windows, confirmation/error dialogs, file choosers and task wizards retain application-owned layouts. User-session GTK controls inherit the theme; privileged/sandboxed applications require separate verification. Installed entry points:

| Application | Launch command |
|---|---|
| Bluetooth Adapters | `blueman-adapters` |
| Bluetooth Manager | `blueman-manager` |
| Network | `cinnamon-settings network` |
| Users and Groups | `cinnamon-settings-users` |
| Disk Image Mounter | `gnome-disk-image-mounter %U` |
| Disk Image Writer | `gnome-disks --restore-disk-image %U` |
| Firewall Configuration | `gufw` |
| Backup Tool | `mintbackup` |
| Driver Manager | `driver-manager` |
| Software Manager | `mintinstall` |
| Input method | `mintlocale-im` |
| Languages | `mintlocale` |
| System Information | `mintreport-tray` |
| System Information | `mintreport` |
| Software Sources | `pkexec mintsources` |
| USB Stick Formatter | `mintstick -m format` |
| USB Image Writer | `mintstick -m iso` |
| System Administration | `pkexec mintsysadm` |
| Update Manager | `mintupdate` |
| Welcome Screen | `mintwelcome` |
| Files | `nemo %U` |
| Onboard Settings | `onboard-settings` |
| Onboard | `onboard` |
| Disks | `gnome-disks` |
| Passwords and Keys | `seahorse %u` |
| Printers | `system-config-printer` |
| Bulk Rename | `thunar --bulk-rename %F` |
| File Manager Settings | `thunar-settings` |
| Removable Drives and Media | `thunar-volman-settings` |
| Thunar File Manager | `thunar %U` |
| Timeshift | `timeshift-launcher` |
| Advanced Network Configuration | `nm-connection-editor` |

**Privileged theme gap:** Users and Groups, Software Sources and Timeshift launch through `pkexec` (verified in their launchers/desktop files). Their root-owned GTK windows are not guaranteed to read this user's local theme; these can still show stock Mint styling. Firewall/driver/package administration can also cross a privilege boundary. No root theme or system authentication code was modified.

## Application-owned / isolated style gaps

- Firefox's browser permission prompts, download/print UI, toolbar/context menus and web content are browser-owned. A GTK file chooser opened from Firefox is covered only when it uses the host GTK theme.
- Electron applications currently in the session (Claude, Discord and the terminal host) draw application menus, dialogs and popovers using their own UI. The shell's GTK/Cinnamon changes do not rewrite those surfaces.
- Qt5/Qt6 applications outside MacShell, Java, Wine and custom-drawn applications are not given a universal theme by this change. No qt5ct/qt6ct/Kvantum configuration is present in this user's config directories.
- Flatpak/sandboxed applications may use their own runtime theme or a portal chooser. These were not launched or visually certified.
- GTK2 retains the existing MacShell-Apps/WhiteSur legacy theme; this new stylesheet targets GTK3/GTK4. Legacy GTK2 popups are not certified against the new alert geometry.

These are distinct from stock Mint styling confirmed on screen: they are known coverage boundaries. It would be inaccurate to label every application-owned menu as visibly stock Mint without opening it.

## Verification and evidence

- Live Finder: New Folder via Ctrl+Shift+N and Return created exactly one temporary fixture folder. Escape cancelled the next sheet without a filesystem change. A failed navigation opened the error alert; Return dismissed it and cleared its message.
- GTK3 full theme resource registration + CSS parse: passed. GTK4 popup CSS parse: passed.
- QML shell and standalone alert preview loaded successfully.
- Visually inspected: reference-shaped Light and Dark destructive alerts, real Finder naming/error dialogs, GTK warning dialog and real Cinnamon generic notification dialog.
- Review correction: small action text now passes 4.5:1 contrast (primary normal 5.06, hover 4.68; destructive dark 5.62/hover 4.52; light 4.87). Reviewer scored all original contrast findings resolved.
- Evidence: `.impeccable/popups/macos-light-alert.png`, `macos-dark-alert.png`, `finder-name.png`, `finder-error.png`, `gtk-alert.png`, `cinnamon-dialog.png`. Finder/Cinnamon captures predate the final contrast-only adjustment.
- Native GTK preserves horizontal action layouts and its warning icon; it is themed, not a pixel-identical copy of the QML alert.

Implementation lives in `MacShell/MacAlert.qml`, `MacShell/MacToolTip.qml`, `popup-native.css`, and `popup-cinnamon.css`. Installed CSS is under `~/.themes/MacShell-Apps/gtk-{3,4}.0/macshell-popups.css` and appended to `~/.themes/MacShell-Cinnamon/cinnamon/cinnamon.css`; GTK4 user CSS imports the popup stylesheet while preserving prior content. Pre-edit files are in `revision-backups/popup-styling/`.
