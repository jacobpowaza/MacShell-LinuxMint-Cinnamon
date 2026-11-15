---
name: MacShell Cinnamon source port
description: Preserve the upstream MacShell QML visual system on Cinnamon/X11.
colors:
  accent: "#0A84FF"
  switch-on: "#30D158"
  danger: "#FF453A"
  window-close: "#FF5F57"
  window-minimize: "#FEBC2E"
  window-maximize: "#28C840"
  dark-content: "#1E1E1E"
  dark-sidebar: "#292929"
  dark-card: "#2B2B2D"
  dark-text: "#F5F5F7"
  light-content: "#F5F5F7"
  light-sidebar: "#E9E9EC"
  light-card: "#FFFFFF"
  light-text: "#1D1D1F"
  switch-knob: "#DCDDDA"
  border-tint-fallback: "#8A9AB5"
  alert-dark-surface: "#2C2C2C"
  alert-light-surface: "#F2F2F2"
  alert-dark-body: "#EDEDF0"
  alert-light-body: "#262628"
  alert-primary: "#006BDD"
  alert-primary-hover: "#0070E8"
  alert-primary-pressed: "#0065CC"
  alert-destructive-dark: "#603531"
  alert-destructive-dark-hover: "#75403B"
  alert-destructive-dark-text: "#FFAAA3"
  alert-destructive-light: "#F5CDCF"
  alert-destructive-light-text: "#AA2420"
  alert-secondary-dark: "#49494E"
  alert-secondary-dark-hover: "#56565B"
  alert-secondary-dark-pressed: "#626267"
  alert-secondary-light: "#DDDDE1"
  alert-secondary-light-hover: "#D2D2D7"
  alert-secondary-light-pressed: "#C8C8CD"
  popup-focus: "#8CBEFF"
  glass-button-accent-tint: "#005AC8"
  glass-button-neutral-dark-tint: "#454545"
  glass-button-neutral-light-tint: "#DEDEDE"
  glass-button-destructive-light-tint: "#F1C8CB"
  glass-button-destructive-dark-text: "#FFC0B8"
  tooltip-dark: "#38383B"
typography:
  alert-heading:
    fontFamily: "SF Pro Text"
    fontSize: "17px"
    fontWeight: 700
  alert-body:
    fontFamily: "SF Pro Text"
    fontSize: "13px"
    lineHeight: 1.15
  alert-action:
    fontFamily: "SF Pro Text"
    fontSize: "13px"
    fontWeight: 500
  tooltip:
    fontFamily: "SF Pro Text"
    fontSize: "12px"
  native-document:
    fontFamily: "SF Pro Text"
    fontSize: "10pt"
  native-monospace:
    fontFamily: "SF Mono"
    fontSize: "11pt"
  native-desktop:
    fontFamily: "SF Pro Text"
    fontSize: "10pt"
  native-window-title:
    fontFamily: "SF Pro Text"
    fontSize: "10pt"
    fontWeight: 600
  native-app:
    fontFamily: "SF Pro Text"
    fontSize: "13px"
  settings-body:
    fontFamily: "SF Pro Text"
    fontSize: "13px"
    fontWeight: 400
  settings-label:
    fontFamily: "SF Pro Text"
    fontSize: "12px"
  segmented-label:
    fontFamily: "SF Pro Text"
    fontSize: "12px"
    fontWeight: 600
rounded:
  alert: "28px"
  gtk-dialog: "26px"
  tooltip: "8px"
  dock: "18px"
  settings-button: "10px"
  slider-track: "2px"
  native-sidebar-selection: "7px"
  native-menu: "12px"
  native-menu-item: "6px"
  native-window: "12px"
  native-window-control: "50%"
spacing:
  alert-padding: "22px"
  alert-action-gap: "8px"
  dock-icons: "6px"
  dock-horizontal: "10px"
  dock-top: "8px"
  dock-bottom: "9px"
  control-center: "6px"
  control-center-slider: "10px"
  native-sidebar-row-padding: "5px 8px"
  native-sidebar-row-margin: "2px 7px"
  native-menu-padding: "5px"
  native-menu-item-padding: "5px 9px"
  finder-grid-cell-minimum: "124px"
  finder-grid-row: "116px"
  finder-list-row: "30px"
components:
  alert-dark:
    backgroundColor: "{colors.alert-dark-surface}"
    textColor: "{colors.dark-text}"
    rounded: "{rounded.alert}"
    padding: "{spacing.alert-padding}"
    width: "320px"
  alert-primary-action:
    backgroundColor: "{colors.alert-primary}"
    textColor: "{colors.light-card}"
    typography: "{typography.alert-action}"
    height: "36px"
    rounded: "18px"
  alert-destructive-dark-action:
    backgroundColor: "{colors.alert-destructive-dark}"
    textColor: "{colors.alert-destructive-dark-text}"
    typography: "{typography.alert-action}"
    height: "36px"
    rounded: "18px"
  finder-grid-cell:
    width: "{spacing.finder-grid-cell-minimum}"
    height: "{spacing.finder-grid-row}"
  shell-action-menu:
    width: "244px"
    rounded: "11px"
    padding: "5px"
  shell-action-menu-row:
    height: "22px"
    typography: "{typography.settings-body}"
  widget-gallery-sidebar:
    width: "200px"
  native-window-control:
    width: "14px"
    height: "14px"
    rounded: "{rounded.native-window-control}"
  finder-sidebar:
    width: "174px"
    backgroundColor: "{colors.dark-sidebar}"
  finder-list-row:
    height: "{spacing.finder-list-row}"
    typography: "{typography.settings-body}"
  native-sidebar-selection:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.light-card}"
    rounded: "{rounded.native-sidebar-selection}"
    padding: "{spacing.native-sidebar-row-padding}"
  native-menu:
    rounded: "{rounded.native-menu}"
    padding: "{spacing.native-menu-padding}"
  switch:
    backgroundColor: "{colors.switch-on}"
    width: "46px"
    height: "21px"
  slider:
    width: "230px"
    height: "22px"
  segmented:
    height: "28px"
    typography: "{typography.segmented-label}"
  settings-button:
    height: "24px"
    rounded: "{rounded.settings-button}"
    typography: "{typography.settings-body}"
---

# Design System: MacShell Cinnamon source port

## Overview

**Creative North Star: "Upstream MacShell, preserved"**

The visual authority is the actual 0-ss/MacShell source. This document records the incumbent system and the approved extensions to native GTK app controls and compositor-rounded window corners. The intentional behavioral override is one dock icon per application with optional window-preview cells off by default. The original source aesthetic remains pinned, with approved static SF typography, the functional Finder app, shared shell action menus, native widget editing and Cinnamon preferences, and reference-led macOS alerts and native popup styling and motion, the full wallpaper catalog and shared home Trash operations. Compact typography, shader glass, responsive dock magnification, and independently composed Control Center tiles carry that system.

**Key Characteristics:**

- Actual upstream QML geometry and assets.
- Wallpaper and window textures refracted through source shaders.
- Compact controls with elastic interaction motion.

## Colors

The frontmatter records source defaults, not a forced palette. User settings and wallpaper sampling may change accent and border tint.

Primary accent marks selection and menu highlights. Switch green indicates an enabled switch; danger red marks destructive actions. Dark and light content, sidebar, card, and text pairs come from the Settings theme object in `MacShell/MacDock.qml`. Secondary text uses source alpha colors over the current surface rather than a universal opaque gray. The dock keeps its own dark appearance, and widgets retain their own style independently of global Light/Dark.

Native GTK3/GTK4 windows use the dark content, sidebar, text, and accent tokens from this same system. `~/.themes/MacShell-Apps` extends existing WhiteSur-Dark coverage; GTK4 imports unpacked theme resources with user CSS preserved. This changes native controls and surfaces, not every application layout.

The approved popup extension uses dedicated alert tokens rather than changing the source accent: primary action blue is `alert-primary`, with its own hover/pressed states. QML alerts follow MacShell Light/Dark; GTK/Cinnamon popups follow the installed dark native theme. Destructive actions use tinted surface/text pairs, and cancel actions use neutral capsules. Native destructive hover uses the darker-theme hover token; QML destructive actions keep their same tint across pointer states.

**The Source Rule.** Preserve source color expressions and shader parameters; do not replace them with a flattened imitation.

## Typography

Static SF faces are the active user-requested override: SF Pro Text Regular/Medium/Semibold/Bold for UI, SF Pro Display Light/Regular/Semibold/Bold for display roles, SF Pro Rounded for the clock, and SF Mono for code and Quick Look text. Source component sizes remain intact. `shell.qml` explicitly loads static SF Pro Text Regular and the hub's bold family uses SF Pro Text with weight selection.

The ambiguous variable `SF-Pro.ttf` was moved out of the active directory to `../font-downloads/SF-Pro-variable-disabled.ttf` after the user reported wide spacing. Do not reactivate it or synthesize tracking to compensate. Static named faces are installed at `~/.local/share/fonts/macshell-sf`; binaries are not bundled. FONT-PROVENANCE.md records their local provenance and license boundary. Existing Open Runde assets remain upstream fallbacks only.

Native GTK CSS uses the native-app pixel role. Cinnamon desktop/document settings use the recorded 10pt role, WM titles use semibold, and native monospace uses SF Mono 11pt. Point settings are not pixel CSS.

## Layout

`MacAlert.qml` is centered, content-sized, at most 320px wide and bounded to parent width minus 32px, with 22px padding. A 64px semantic icon precedes a 20px gap, then left-aligned heading and wrapped message separated by 12px. Message height scrolls within a parent-height budget; optional details have 16px top padding and 8px spacing. Actions begin after 18px, fill the content width at 36px high, and stack with an 8px gap. GTK3 MessageDialog uses the native compact-layout adapter described below; Cinnamon multi-action rows retain their toolkit ordering.

All dimensions here are source logical pixels before scaling. The menu bar defaults to 28 high. The dock defaults to 52-pixel icons, 1.7 peak magnification, and a 6-pixel outer margin; padding and icon spacing are in frontmatter. Its width follows app count and separators. The review confirmed that the context menu sits fully above the dock and neighboring icon magnification follows the intentional source cosine profile.

The dock groups windows by application and preserves running order as focus changes. Its default pins are Finder, Firefox, Terminal, and Settings. `showThumbs` defaults false. Grouped windows use the source glass menu with a bounded vertical Flickable, LiquidScrollBar, and Up/Down/Enter/Escape controls; every window remains reachable beyond the first eight. The dock window stays at full monitor height so opening a context menu cannot move its coordinate origin. Native ShapeInput preserves click-through outside the active input region, expanding the outside-click region while the menu is open; the bottom exclusive zone is unchanged. Actual rendered icon scales are frozen when the menu opens, preserving the dock and icon rectangles while the pointer moves into the menu.

Control Center defaults to the source `tiles` composition. Its row cell height is 66; tiles span source grid positions rather than becoming a generic settings list. Widgets default to `widgetScale: 1.0`: small 185×185, medium 395×185, large 375×385. The grid uses cell 179, gaps 28 horizontal/23 vertical, margins 21 left/right,56 top,24 bottom. `MacWidgets.qml` performs placement and overlap checks. Do not rescale these to make an approximation look similar.

`MacBar.qml` derives bar and popup scales from UI scale and bar height. Cinnamon's monitor-scale guard can fall back to native behavior; multiple monitors and mixed scaling are not validated.

## Elevation & Depth

Alerts use an opaque neutral surface rather than the source glass shader. QML shadow: radius 28px, blur 36px, 12px downward offset, `#44000000`; surface border is 1px with dark `#38ffffff` or light `#99ffffff`. Modal dimming is dark `#65000000` or light `#35000000`. Cinnamon dialogs use `0 12px 36px rgba(0,0,0,0.35)` and a 1px white 0.18-alpha border. QML alerts enter with a 150ms fade, scale from 0.94 to 1 and settle elevation over 280ms OutQuint; exit fades over 120ms toward scale 0.98. Reduce Motion removes scale/elevation and shortens fades.

Liquid glass is implemented by source `.frag`/`.qsb` shaders and captured textures, with fallback frosted surfaces where the source defines them. `GlassSlab.qml` refracts a local picture; shared shell glass also depends on backdrop capture. Blur, tint, refraction, rim, grain, and saturation are separate source parameters, not a CSS backdrop-filter recipe. The dock adds its own blur boost. Source material and motion details are recorded in `.impeccable/design.json`.

The Settings sidebar has a Cinnamon-specific backdrop adapter: `CinnamonFrost.qml` refreshes a native composite of wallpaper and application captures below Settings, with Gaussian blur 24, beneath the unchanged source sidebar tint. This replaces the compositor frost expected by upstream, not the source Liquid Glass shader. Its 600ms refresh and initial capture warmup are platform limitations. A settled 23:00 review capture showed the backing gray through the tint with the underlying text blurred; this verifies that scoped material case only.

Native Qt/X11 window masks also clip drawing. `CinnamonMask.qml` serializes the source region boolean composition; `native.py` installs X11 ShapeInput while leaving drawing unmasked. This preserves click-through independently of the visible glass. It is an adapter requirement, not a visual redesign.

Finder follows the source Settings palette and frost language: a compact toolbar, inset frosted sidebar, responsive icon grid, compact list rows, source LiquidScrollBar, and SF Mono Quick Look text. Current sidebar and list dimensions are in frontmatter; grid width distributes whole columns from the recorded minimum and uses the recorded row height. Its outer frame has a radius of 22 and inset sidebar a radius of 17. Path-based selection and anchors survive model rebuilds, filtering, deletion, and rename; focus returns after modal closure. Window creation is lazy, Ctrl+N opens another window, and closing destroys that window. This is a functional source-style adaptation, not an upstream Finder file or a full macOS feature clone.

## Shapes

Native window corners use the approved compositor radius in frontmatter through Cinnamon’s `RoundedCorners@klangman` extension. Top and bottom rounding apply to eligible normal windows across toolkits; fullscreen and maximized windows remain square, and docks/menus are excluded. GTK decoration CSS and the MacShell-Apps Metacity theme complement that compositor treatment. This window silhouette does not change the source component radii.

The dock radius, settings-button radius, and slider track radius are in frontmatter. Switch tracks and segmented capsules use half-height radius; the segmented inset is 2 and each label has 14 horizontal padding. Slider knobs deform during interaction. Preserve the source component's own radius rules rather than applying one global card radius.

## Components

- `MacAlert.qml`: approved extension based on `/tmp/codex-clipboard-0F5NSD.png`; used by Finder operation errors, New Folder/Rename/New Tag sheets and Settings update alerts. Uses the frontmatter alert geometry, SF Pro Text 17px bold heading, 13px body with 1.15 line height, and 13px medium primary-action text. Opening focuses the primary action for ordinary dialogs and Cancel for destructive confirmations; Return/Enter activates the focused action, Escape cancels, and visible focus gets a 2px border. A disabled primary action uses 0.45 opacity. Optional cancellation uses a regular-weight neutral capsule. Semantic icon and wrapped/scrollable message preserve error meaning and long paths.
- `MacToolTip.qml`: Finder toolbar/Gallery tooltips use 12px SF Pro Text, 7px padding, 8px corners, 550ms delay and appearance-aware surface/text. Native GTK/Cinnamon tooltips use 6px 9px padding and the same dark tooltip token.
- `popup-native.css` / `popup-cinnamon.css`: approved native extension covers GTK3/GTK4 dialogs and file chooser surfaces, popovers, context/combo menus and tooltips; Cinnamon confirmations, authorization/mount-password prompts, Run/end-session dialogs, fallback notifications, menus and system overlays. GTK dialog radius is 26px; Cinnamon dialog radius is 28px. Native action capsules use minimum height 20px plus 8px 18px padding. Popup menus keep 12px corners and 5px padding; GTK rows use minimum height 22px and 3px 9px padding, while Cinnamon rows retain 5px 9px padding. Native focus uses `popup-focus`; disabled/menu-insensitive treatment remains toolkit-specific. Cinnamon notifications/overlays use 20px corners. These are opaque or near-opaque native surfaces, not shader-glass replacements.

Approved popup motion keeps the existing geometry and materials: alert pointer color transitions take 130ms and pressed scale takes 120ms; menu hover takes 100ms, ordinary menu entrance 190ms and dock menu entrance 220ms. Tooltips fade in/out over 120/80ms after their existing delay. Native GTK/Cinnamon hover transitions take 130ms. Reduce Motion removes scale/elevation and shortens fades. `.impeccable/wallpapers-trash-motion/motion-check.json` records passing live checks; `settings-final.png`, `trash-confirmation.png` and `DEBUG-REPORT.md` in that directory record the catalog and Trash scope. `tests/trash-operations.py`, `tests/wallpaper-catalog.py` and `tests/finder-filesystem.py` passed; live checks applied a real desktop wallpaper, decoded a 6016×6016 HEIC primary image and reused a cached original offline.

Native popup coverage is per-user and toolkit-bound. Native file chooser lists/breadcrumbs/filter/action layouts, Cinnamon authentication/PAM and dialog ordering remain intact. Root windows launched through `pkexec`, the login screen, application-owned Firefox/Electron/custom UI, external Qt/Java/Wine, sandbox runtimes/portals and GTK2 are not certified by these styles. No root theme or authentication code changed. `POPUP-AUDIT.md` inventories exact handoffs and residual native surfaces. Live QML/Finder/GTK/Cinnamon checks and GTK3/GTK4 CSS parses passed; the final shell logged Configuration Loaded. `.impeccable/popups/REVIEW.md` records the reviewer pass with all original small-action contrast findings resolved after the final color adjustment. Evidence is representative, not universal application certification.

- `FinderApp.qml` / `FinderController.qml` / `FinderViews.qml` / `FinderDragArea.qml`: functional multiwindow file manager with Icon, List, Columns and Gallery views; Shared and Recents above Favorites; persistent Tags; SF toolbar/action symbols and source frost. Actual automatic native Xdnd exports file URIs: move, Control-copy and an external GTK target have fixture-test evidence. Dropping a folder into Favorites pins persistently without moving it. Icon view rubber-band selection uses a translucent rectangle and selected filenames receive tight blue labels. No persistent notification footer is shown; failures use a dismissible modal error dialog. Optional path/status bars remain user-selectable.
- `WidgetManager.qml` / `WidgetVisual.qml` / `WidgetData.qml`: bottom-left frosted gallery with provider/search sidebar and proportionally scaled native Small/Medium/Large previews, independent captions and Done. Gallery maximum is 1000×550; its sidebar width is in frontmatter. Photos shows a photo placeholder until an image is chosen. Opening the gallery enters editing; movement, corner resizing and configuration are edit-only. Outside editing, widget context action is Edit Widgets. The contextual editor changes each Weather widget's city or Clock widget's IANA timezone independently. Escape returns editor focus to the gallery; Done/Escape closes editing and restores the prior showing-desktop state.
- The edit resize grip preserves the reference's rounded white curve with a restrained dark under-stroke. `MacWidgets.qml` paints a 7px `#99000000` stroke beneath a 4.5px `#f7f7fb` curve in an edit-only 36×36 hit area; footprint resizing still rejects overlap. The under-stroke fixes the light Clock contrast finding without changing the grip gesture. The final light/dark recaptures resolve the contrast finding; `.impeccable/tahoe-workflow/VERDICT.md` ships that scored fix only, without expanding the prior review scope.
- `ContextMenuWindow.qml` / `TahoeActionMenu.qml` / `MacMenuItem.qml`: shared source desktop-glass material across shell action menus, SF SVG icons, separators, highlight states, keyboard navigation, screen-bounded pointer placement, native focus and dismissal. Menu and row dimensions are in frontmatter. This is shell/menu integration; third-party custom application menus retain toolkit-specific behavior.
- `MacBar.qml` Spotlight requests exact native focus when opened: typing starts immediately without clicking the field.
- `NativeSettingsSection.qml`, `MintInputSync.qml` and `MintSharedSync.qml`: actual Cinnamon controls appear in existing Settings categories, including Default Applications. Two-way native sync is covered by targeted keyboard/clock and General switch tests. Privileged administration retains native authorization dialogs. About names Linux Mint Cinnamon and credits jacobpowaza; the top bar uses the Mint logo. Official local SF SVG provenance remains in `../symbols`.
- `wallpaper_catalog.py`, `wallpaper-catalog.json` and the Settings picker: all 124 repository image entries from `LAYTAT/macOS-Wallpapers`, including two HEIC originals, plus the 12 existing Mint entries. Cached metadata listing performs no network access or original download; explicit refresh uses the GitHub tree API and thumbnails can use the remote proxy. Selection verifies the Git blob SHA and image data, enforces a 128MiB limit and atomically caches one original with provenance. Cached originals appear locally in the grid and are reusable offline. HEIC uses installed libheif to extract the primary still as JPEG, without time-of-day playback. `CinnamonWallpaper.qml` waits for the existing native wallpaper operation to apply Gio `picture-uri` before persisting selection; still images bypass the old Wayland path. Invalid downloads leave the current wallpaper intact. Catalog tiles expose an accessible Button role, name and action; the grid uses one Tab stop, arrow-key navigation, Return/Space activation and a visible focus border. A live Tab → Right → Return workflow applied a cached image to the real desktop, then restored the original; evidence is `.impeccable/wallpapers-trash-motion/settings-keyboard-final.png` and `wallpaper-keyboard-focus.png` in that directory.
- `trash_service.py`: shared home XDG Trash status/count, purge-all, selected deletion and Put Back for Finder and dock. Finder offers Empty Trash in its toolbar/context menu and Delete Immediately/Put Back for selected items; dock emptying opens the Finder confirmation. Prevalidation and safe symlink handling guard operations; native errors are surfaced and destructive dialogs focus Cancel. External-volume Trash is not aggregated. The existing 86 user items were preserved during validation.
- MacLock: actual upstream lock visuals with static SF override embedded in Cinnamon Stage; preserve stock password entry/PAM authority. Readiness deadline, F12 fallback, and wake handling are functional recovery controls, not replacement authentication.

- Native GTK3/GTK4 controls: source typography and palette applied through the app theme, with sidebar selection, menu, and menu-item geometry in frontmatter. Circular close/minimize/maximize controls use the three window-action colors and a 14px minimum GTK size; native framed windows use the matching Metacity assets. Inactive and hover states follow the toolkit/theme. Coverage depends on the toolkit and application; app-owned custom titlebars require per-app integration.
- Settings and Clock titlebars: yellow controls invoke real minimization; opening either app again restores its window. Their source titlebar geometry remains intact.

- `GlassSwitch.qml`: click, drag, and flick switch; glass knob while held or moving; disabled opacity0.45.
- `GlassSlider.qml`: thin 4-pixel track and deforming knob; height40 when end labels are present; disabled opacity0.4.
- `GlassSegmented.qml`: label-driven width and elastic leading/trailing edges; disabled opacity0.45.
- `MacDock.qml`: source Settings button, compact rows, theme object, dock, and settings application.
- `MacBar.qml`: source menu bar, Control Center tiles, menus, notifications, Spotlight, and capture surfaces.
- `MacWidgets.qml` and widget QML files: original placements, content, style modes, and source shaders.

The HTML/CSS examples in the sidecar are documentation swatches of resting states. They cannot render the QML shader, texture capture, or elastic geometry and must never replace the application components.

## Do's and Don'ts

### Do

- Preserve source geometry, font bindings, shaders, and assets, with the approved one-icon-per-app dock behavior.
- Translate platform behavior through adapters and verify it against the actual source UI.
- Label unverified or approximated behavior explicitly.

### Don't

- Substitute a visually similar shell or generic glass controls.
- Claim full parity from screenshots or a successful startup.
- Generalize the confirmed password unlock and DPMS tests into a full security or physical suspend guarantee.


## Widget and Settings motion refinement — 2026-11-13

Widget corner resizing follows the pointer continuously with a 65ms OutCubic response; on release it resolves to a collision-checked Small/Medium/Large footprint with a restrained 300ms OutBack settle. The rendered card reflows at its actual dimensions; text is not scaled horizontally. Pointer state is initialized before enabling resize geometry to prevent a first-frame collapse. Movement and resize grips remain edit-only.

Opening the widget gallery first fades visible applications on the current workspace over approximately 208ms. The native adapter preserves each existing X11 opacity property (including absence), restores it in a finally block after showing the desktop, and acknowledges completion before the gallery appears. The gallery surface fades in over 170ms with a 22px/320ms OutCubic rise; dismissal fades/slides before restoring the desktop state. Reduced Motion disables these transitions. WidgetContextMenu.qml uses the same DockGlassPanel and SF row styling as the source menus, in a widget-local Tool window. Its glass and rows fade/scale together (160ms/200ms), with a 110ms fade out; this avoids Qt native popup keyboard grabs across the widget gallery and editor. Existing Finder and other source menu implementations are retained.

Settings source cards and native preference groups use 12px corners and quiet separators. Native groups use 42px disclosure headers, 16px inter-group spacing, 260ms clipped height expansion, 180ms content fade and 220ms chevron rotation. Switches animate thumb and tint. Numeric fields are compact (112px); valid field edits save on Return or focus loss. No extra Set button is required. Real native preferences and authorization behavior remain unchanged.

Weather conditions use local Canvas glyphs for all nine supported conditions, including cloudy, mixed, fog, rain, snow and thunderstorms. Initial/availability/size changes repaint them; cloud paths use separate filled subpaths to avoid connecting artifacts. No remote icon request is needed.

## Glass popup buttons

`MacGlassButtonSurface.qml` is the shared background for MacAlert actions and MacButton. It uses the existing GlassSlab/liquidglass shader against a small local material texture, with directional highlight, refractive capsule rim, fine grain, inner edge and a 2px contact shadow. It does not capture the desktop per button. Accent/destructive/neutral base tints are recorded above; rendered colors vary with the shader. The alert's dark destructive label is the lighter glass-button text token to preserve contrast over the highlight. The surface tracks hover over 160ms and press over 110ms (OutCubic), changing rim, sheen, refraction and shadow depth; Reduce Motion snaps those material transitions. Geometry, actions, Cancel default, keyboard focus and existing popup entrance/exit are preserved.

GTK3/GTK4 and Cinnamon native dialog buttons approximate the same material with layered gradients, inset catchlights and short contact shadows. They do not run the QML refraction shader. Evidence: `.impeccable/glass-buttons/` contains Light/Dark resting alerts and accent resting/hover/pressed captures; GTK3/GTK4 CSS parses and QML shader startup passed.

## Native GTK confirmation integration

The approved native alert extension is `native-gtk/macshell-dialogs.c`, loaded through Cinnamon XSettings Gtk/Modules. It changes the real GTK3 MessageDialog layout using public GTK APIs: 320px minimum width, one 20px outer content inset, 6px text/icon inset, 20px icon gap, 12px heading/body gap, 18px action-group separation and 8px action gap. GTK's extra 30px content margins, 12px icon margins and container borders are removed. Ordinary preferences windows, file choosers and credential dialogs are not replaced. Existing message content, response IDs and default action remain application-owned; buttons become full-width stacked actions and a message dialog with actions omits its redundant titlebar.

Dark alerts use a neutral #2c2c2c and light QML alerts #f2f2f2. Glass highlights and edge opacity were subdued against the supplied macOS reference. Native GTK3 styles use gradients/inner rims, while QML retains source shader refraction. The adapter is process-resident so XSettings module changes cannot unload registered callbacks, and inactive module versions stop transforming dialogs. Installs use immutable content-hashed libraries. A prior nonresident test version caused a Terminal process failure; it was disabled and corrected. The current implementation passes 70 lifecycle/removal/reload iterations and an unchanged native Cancel response. Evidence is `.impeccable/native-gtk/compact-final.png`; `native-gtk/install.py --remove` disables future layout application. Already-created dialogs retain their current layout. GTK4 custom/Adwaita dialogs are outside this GTK3 layout adapter.
