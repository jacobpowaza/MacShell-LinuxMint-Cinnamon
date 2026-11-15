# Port status

Snapshot: 2026-11-13. Source commit `51db0bab6997da310d2aacfaa7084740ec44ad4a`; approved overrides are static SF fonts, functional Finder, grouped dock, native GTK controls, compositor-rounded native windows, and the native widget/menu/Cinnamon workflows recorded below. Full 1:1 parity remains unproven.

| Area | Current result | Boundary |
| --- | --- | --- |
| Typography | Static SF Text/Display/Rounded/Mono roles active; variable SF removed after spacing complaint | Local font installation, no binaries bundled; Open Runde fallback only |
| Finder | Default directory handler; desktop folders/bar Files/dock Trash integration; actual operations and multiwindow lifecycle | New adaptation, not full macOS clone; an existing FileManager1 owner may still open an older file manager |
| Dock | Finder default pin; one icon per app; all grouped windows accessible; stable focus order and right-click geometry | Exact geometry and targeted choices 9–12/30/Escape checked; broad multi-monitor behavior unverified |
| Native apps | GTK3/GTK4 source-palette/static-SF controls; red/yellow/green titlebuttons; global eligible-window corner rounding | Fullscreen/maximized stay square; custom app-owned titlebars need per-app support; app layouts remain app-owned |
| Lock | Active adapter owns Cinnamon screensaver D-Bus; user confirmed real password unlock; stock Stage/PAM authority retained | No universal security or full physical S3 suspend claim |
| Sleep/display | Simulated sleep freeze and awake fallback passed; actual 6-second DPMS off/on restored display with locker active and MacShell ready; subsequent unlock observed | DPMS and simulation are not physical suspend coverage |
| Source shell | Original shaders, Control Center tiles, settings/clock, widget geometry retained | Broad interactions, providers, compositing, multi-monitor/scaling not exhaustive |
| GPU | Host NVIDIA context previously confirmed RTX A400/OpenGL 4.6; Intel/Mesa fallback | Nix/proot remains; no current FPS guarantee |

## Current evidence

`.impeccable/final-checks/finder-filesystem.txt` reports PASS for own home-cache fixtures: Unicode rename, overwrite refusal, file/folder copy, cut/move, preview, home Trash and Put Back. The test uses SECONDARY clipboard so the user's clipboard is preserved. `.impeccable/final-checks/finder-ui.txt` reports static SF, grid/list, search, hidden files, Quick Look, keyboard mkdir/rename, navigation/Back, filtering/deletion Shift-range regressions, and retained rename selection passing.

Current Finder/static-SF screenshots: `.impeccable/finder-review/finder-grid.png`, `finder-list.png`, `finder-quick-look.png`, and `settings-static-sf.png`. Reviewer found static type/material/ground matched and the scoped Finder ceiling reached without another material regression; the remaining documentation drift is addressed here. `lock-container-preview.png` predates the last static-font correction and is preview evidence only, not proof of current lock typography.

`.impeccable/final-checks/lock-sleep-simulation.txt` records both sleep-pause/live-wake and awake-frozen-visual fallback passing. `.impeccable/final-checks/lock-dpms.txt` records: Display restored, Locker active true, MacShell ready true. The user subsequently unlocked and GetActive false was observed. Lock/wake review marked all three findings resolved and recommended ship to supervised retest, not an unconditional security certification.

Earlier native/dock tests remain in `tests/native-window-actions.py`, `dock-grouping.py`, and `dock-menu-selection.py`; 30-window focus positions 9–12/30 and Escape passed. This documentation pass inspected code/evidence without rerunning live tests.

## Window-decoration adjustment — 2026-11-13

Cinnamon’s `RoundedCorners@klangman` extension supplies eligible-window top/bottom rounding (12px) and a matching shadow (size20); fullscreen/maximized windows and docks/menus are excluded. The extension came from `linuxmint/cinnamon-spices-extensions` commit `0555e12ee945fa260097db2ce5031d306a34f14c`; local provenance is `~/.local/share/macshell-mint/sources/RoundedCorners/SOURCE.json`. GTK3/GTK4 CSS and MacShell-Apps Metacity assets supply the matching red/yellow/green controls. Custom app-owned titlebars require per-app integration; this is not an all-app button guarantee.

The dock surface now stays full monitor height, retains native click-through and the existing exclusive zone, and freezes actual rendered icon scales on menu open. `.impeccable/window-decoration/validation.txt` records native GTK3 frame, GTK3 CSD, GTK4 CSD, Settings/Clock minimize and reopen, exact dock/menu geometry, and targeted 30-window choices9/10/11/12/30 plus Escape passing. `dock-geometry.json` records identical global dock/icon rectangles before/open/pointer-in-menu. Screenshots in that directory show the three native frame cases, dock before/menu, and Settings credits. This documentation pass checked evidence and source without rerunning live tests.

Settings About now credits [jacobpowaza](https://github.com/jacobpowaza) as “Contributor — Ported MacShell to Linux Mint Cinnamon,” with an avatar and provenance note. Window-control tests are `tests/window-controls.py` and `tests/dock-menu-stability.py`; `dock-menu-selection.py` checks Escape against the stable surface. Prior lock/suspend limitations and historical performance qualification remain unchanged; no new benchmark ran.

## Historical performance only

`.impeccable/performance/summary.json` belongs to the earlier 2026-11-13 build **before Finder, static SF, and the running lock daemon**: RSS 1293.5→897.9 MiB and CPU 46.7→19.6% of one core, three-final-sample medians (30.6% RSS / 58.0% CPU reduction). It is not a fresh metric or current-build guarantee. Eight-second process ticks omit exited helpers; summed service-process RSS can double-count shared driver mappings. Measurements used an active desktop and do not measure FPS, latency, or leaks.

Start/restore entry points remain `~/.local/bin/macshell-cinnamon[-start]` and `~/.local/bin/macshell-mint-restore`. Restore protects active authentication and restores backed-up app CSS/fonts, D-Bus/autostart files, and MIME association; it removes own Finder/app entries. Window-decoration restore also recovers the pre-adjustment GTK3/GTK4 CSS and the backed-up Cinnamon enabled-extensions value from `backup/settings.json`.

## Native Finder, widget and Cinnamon workflow revision — 2026-11-13

This approved extension retains upstream glass, static SF, and the Cinnamon/X11 application. User screenshot references and incumbent source are authority; no separately authored five-block direction contract, FORM seed or QUALITY BAR card was supplied. No generated comp or web detector is claimed.

| Area | Finished behavior | Evidence and boundary |
| --- | --- | --- |
| Widget gallery | Bottom-left frosted provider/search browser; proportional native Small/Medium/Large previews with captions and Done; move/resize/configure only in editing | `tests/widget-edit-workflow.py` passes actual pointer movement, small→medium corner resizing and prior desktop-state restoration; rerun after grip fix passed. Photos preview uses a placeholder until an image is chosen. |
| Widget configuration | Contextual per-widget Weather city and Clock IANA timezone editor; Escape editor→gallery→closed | Final owned-panel workflow, backend DST/timezone and Warsaw/Tokyo forecast checks in `VALIDATION.md` |
| Resize affordance | White curved edit grip now has contrasting dark under-stroke, retaining 36×36 hit area | `VERDICT.md`: light/dark recaptures resolve the one material finding; disposition ship covers this scored fix only |
| Spotlight | Immediate keyboard input without field click | Exact native focus and query=calc in `tests/spotlight-focus.py` |
| Finder | Four views (Icon/List/Columns/Gallery), Shared/Recents/Favorites, persistent Tags, SF symbols, compact toolbar and frost | Current captures and backend checks; new adaptation, not a full macOS Finder clone |
| Finder pointer workflows | Actual file/blank context menus; native Xdnd move/Control-copy and external GTK target; Favorites drop pins persistently without moving; marquee and filename-tight selection | `tests/finder-pointer-workflow.py`, `finder-drag-drop.py`, earlier `finder-drag-gtk.py`; owned fixtures only |
| Finder feedback | Persistent notification footer removed; failures use dismissible modal error dialog; optional path/status bars remain | Current Finder source and captures |
| Shell menus | Shared desktop-glass source material with compact SF icon rows, separators, native focus/dismissal and pointer placement | Current Finder/widget menu captures and actual pointer tests; third-party custom app menus remain toolkit-specific |
| Settings and identity | Actual Cinnamon controls in existing categories, two-way preferences and Default Applications; About Linux Mint Cinnamon/jacobpowaza; Mint bar logo | General/Keyboard/Default Applications/About captures; `tests/settings-live-sync.py` passes external keyboard/clock→UI and General UI→native switch with values restored. Top-bar logo has source coverage, not a fresh full-bar capture. Privileged tasks retain native authorization dialogs. |
| Wallpapers | Twelve-image catalog; originals downloaded only on selection, hash/image verified and atomically cached with provenance | `tests/tahoe-backend.py`: listing requires no network/original download, one selected original and cache reuse tested; thumbnails may fetch while picker is open |

Evidence root: `.impeccable/tahoe-workflow/`. Read `REVIEW-PACKET.md`, `VALIDATION.md`, initial `FINISH-REVIEW.md` and the subsequent `VERDICT.md` together: the initial review found only grip contrast materially deficient within its inspected evidence; the final verdict resolves only that finding. Motion was inspected in code, not live; popup/picker black padding is transparent native capture padding. Final eight-minute journal check reported no new QML ERROR/TypeError/ReferenceError/Invalid messages. This documentation pass inspected source and recorded results, without independently rerunning UI tests.

The separate secure locker was unchanged and not operated. Earlier password/PAM, DPMS and supervised-retest evidence and all physical suspend/security limitations remain as documented above. No new RAM/FPS benchmark, universal menu replacement, all-admin-dialog embedding, mixed-scaling or broad multi-monitor acceptance is asserted.


## Widget motion and Settings refinement — 2026-11-13

Live refinement adds continuous pointer-following widget size previews and restrained settling, all-condition local weather glyphs, an animated dock-style widget context menu, and sequenced background-window fade → gallery entrance. Native opacity properties and the prior desktop state are restored. Settings now has quieter grouped cards, compact inline fields, animated disclosure sections/chevrons and switches. Reduced Motion disables the added motion.

Final owned-window pointer/keyboard checks passed for gallery/editor/menu focus and Escape, intermediate resize geometry and opacity restoration, actual native field saving, Spotlight typing, and Finder context/selection/Favorites dragging. Details and captures: `.impeccable/widget-motion/VALIDATION.md`; refreshed pane captures remain in `.impeccable/tahoe-workflow/`. Existing shared Finder menus and secure lock implementation are retained; no new performance, mixed-monitor or suspend claim.

## Lock recovery after GTK module replacement

A long-running locker crashed on the previously loaded nonresident dialog adapter; its restart encountered another owner of the screensaver name. The adapter is now excluded before GTK initialization in secure locker processes. Current daemon ownership, secure-environment isolation, simulated wake recovery, frozen-viewer fallback and unit validation pass. See `.impeccable/lock-recovery/RESULTS.md`. LightDM/Slick Greeter is a separate system login surface; neither a reboot nor physical suspend/resume has been tested for this recovery.

## Settings and Updates — November 13

The window and launcher are named Settings. General opens an Updates subpage, omitted from the sidebar; General stays selected while viewing it. Update sources disclose package cards with application icons or SF Symbol component fallbacks, versions, and individual Update actions. Collapsed source headers expose Update All for that source; the page also offers a global Update All. The manager supports APT, user/system Flatpak, and Snap when installed, preserves disclosure state across updates, streams progress/errors, and reports restart requirements. APT checks use the existing local catalog; a system-wide update refreshes it before upgrading. MacShell releases remain a separate link to preserve local desktop customizations. No upgrades were executed during validation. Backend scope, metadata, multiarch identity, argument validation, failure and cancellation tests: `python3 tests/update-manager.py`.
