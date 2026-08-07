# xmonad-contrib against the river backend

Upstream `xmonad-contrib` master built with `stack build xmonad-contrib:lib`
against `../xmonad-river` at `-f river`, with `-fkeep-going` so one failure
does not stop the run.

| | count |
| --- | --- |
| compiled | **170** |
| failed | 63 |
| skipped behind a failure | 101 |
| total | 334 |

The skipped ones are **unmeasured, not known-bad**: GHC never attempted them,
because a module they import failed first. The true number that would compile
is somewhere between 170 and 271.

Regenerate with `tests/survey.sh` after rebuilding `xmonad`.

## Failing modules, by cause

### other — 24 modules

- `XMonad.Actions.ConstrainedResize` (8) — Variable not in scope:
- `XMonad.Actions.FlexibleResize` (9) — Variable not in scope:
- `XMonad.Actions.FloatKeys` (16) — Variable not in scope:
- `XMonad.Actions.Navigation2D` (4) — Variable not in scope:
- `XMonad.Actions.NoBorders` (4) — Variable not in scope:
- `XMonad.Actions.TiledWindowDragging` (1) — ?
- `XMonad.Config.Prime` (6) — Not in scope: type constructor or class ‘EventMask’
- `XMonad.Hooks.BorderPerWindow` (1) — Variable not in scope:
- `XMonad.Hooks.FadeInactive` (4) — Variable not in scope: getAtom :: String -> X t2
- `XMonad.Hooks.FloatConfigureReq` (1) — Not in scope: data constructor ‘ConfigureRequestEvent’
- `XMonad.Hooks.ManageDocks` (1) — ?
- `XMonad.Hooks.SetWMName` (1) — ?
- `XMonad.Hooks.WorkspaceByPos` (5) — Variable not in scope:
- `XMonad.Layout.AvoidFloats` (1) — ?
- `XMonad.Layout.DragPane` (3) — Not in scope: data constructor ‘ButtonEvent’
- `XMonad.Layout.FixedColumn` (1) — Variable not in scope:
- `XMonad.Layout.NoBorders` (1) — ?
- `XMonad.Layout.Reflect` (1) — ?
- `XMonad.Layout.SimplestFloat` (5) — Variable not in scope:
- `XMonad.Layout.TrackFloating` (1) — Variable not in scope:
- `XMonad.Layout.VoidBorders` (1) — Variable not in scope:
- `XMonad.Prompt.Input` (1) — Variable not in scope:
- `XMonad.Prompt.RunOrRaise` (2) — Variable not in scope: getAtom :: String -> m t0
- `XMonad.Util.RemoteWindows` (7) — Variable not in scope: getAtom :: String -> X t2

### missing module or export — 15 modules

- `XMonad.Actions.GroupNavigation` (1) — Could not load module ‘Graphics.X11.Types’.
- `XMonad.Actions.Minimize` (1) — Module ‘XMonad.Util.WindowProperties’ does not export ‘getProp32’.
- `XMonad.Actions.Repeatable` (1) — Could not load module ‘Graphics.X11.Xlib.Extras’.
- `XMonad.Hooks.DebugKeyEvents` (2) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Hooks.Rescreen` (1) — Could not load module ‘Graphics.X11.Xrandr’.
- `XMonad.Hooks.UrgencyHook` (1) — Module ‘XMonad.Util.WindowProperties’ does not export ‘getProp32’.
- `XMonad.Layout.BinarySpacePartition` (1) — Module ‘XMonad.Hooks.ManageHelpers’ does not export ‘isMinimized’.
- `XMonad.Layout.Gaps` (1) — Could not load module ‘Graphics.X11’.
- `XMonad.Layout.MouseResizableTile` (1) — Could not load module ‘Graphics.X11’.
- `XMonad.Prompt.OrgMode` (1) — Module ‘XMonad.Prompt’ does not export ‘mkXPromptWithReturn’.
- `XMonad.Util.Cursor` (1) — Could not load module ‘Graphics.X11.Xlib.Cursor’.
- `XMonad.Util.DynamicScratchpads` (1) — Could not load module ‘Graphics.X11.Types’.
- `XMonad.Util.NoTaskbar` (3) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Util.Paste` (3) — Module ‘XMonad’ does not export ‘theRoot’.
- `XMonad.Util.Ungrab` (1) — Module ‘XMonad.Operations’ does not export ‘unGrab’.

### X window properties — 9 modules

- `XMonad.Actions.EasyMotion` (3) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Actions.ShowText` (4) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Actions.UpdatePointer` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Hooks.TaffybarPagerHints` (5) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.XPropManage` (3) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Layout.LayoutScreens` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Util.DebugWindow` (19) — Not in scope: data constructor ‘WindowAttributes’
- `XMonad.Util.StringProp` (1) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.WindowState` (3) — Variable not in scope: stringProperty :: String -> Query String

### Xlib drawing and display — 5 modules

- `XMonad.Actions.TreeSelect` (28) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Hooks.Qubes` (8) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Hooks.ShowWName` (3) — Variable not in scope: openDisplay :: String -> IO t0
- `XMonad.Layout.WindowNavigation` (1) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Util.Replace` (27) — Variable not in scope: openDisplay :: String -> IO t21

### raw X events — 5 modules

- `XMonad.Actions.UpdateFocus` (3) — Not in scope: data constructor ‘MotionEvent’
- `XMonad.Hooks.OnPropertyChange` (3) — Not in scope: data constructor ‘PropertyEvent’
- `XMonad.Hooks.RefocusLast` (2) — Not in scope: data constructor ‘UnmapEvent’
- `XMonad.Hooks.ScreenCorners` (1) — Not in scope: data constructor ‘CrossingEvent’
- `XMonad.Hooks.ServerMode` (3) — Not in scope: data constructor ‘ClientMessageEvent’

### small missing names — 3 modules

- `XMonad.Actions.WindowNavigation` (12) — Not in scope: type constructor or class ‘Point’
- `XMonad.Hooks.CurrentWorkspaceOnTop` (2) — Variable not in scope: raiseWindow :: Display -> Window -> IO a0
- `XMonad.Util.Grab` (6) — Not in scope: type constructor or class ‘KeyCode’

### root window — 2 modules

- `XMonad.Actions.MouseGestures` (2) — Variable not in scope: theRoot :: XConf -> t0
- `XMonad.Actions.UpKeys` (5) — Not in scope: ‘theRoot’

## Skipped modules, by what blocks them

### `XMonad.Hooks.UrgencyHook` — 35 modules

`XMonad.Actions.CopyWindow`, `XMonad.Actions.DynamicWorkspaceGroups`, `XMonad.Actions.GridSelect`, `XMonad.Actions.LinkWorkspaces`, `XMonad.Actions.MouseResize`, `XMonad.Actions.TopicSpace`, `XMonad.Actions.WindowBringer`, `XMonad.Hooks.DynamicIcons`, `XMonad.Hooks.StatusBar.PP`, `XMonad.Hooks.StatusBar.WorkspaceScreen`, `XMonad.Layout.BorderResize`, `XMonad.Layout.Decoration`, `XMonad.Layout.DecorationEx.Common`, `XMonad.Layout.DecorationEx.Geometry`, `XMonad.Layout.DecorationMadness`, `XMonad.Layout.DwmStyle`, `XMonad.Layout.FixedAspectRatio`, `XMonad.Layout.Groups.Examples`, `XMonad.Layout.Groups.Wmii`, `XMonad.Layout.IndependentScreens`, `XMonad.Layout.LayoutHints`, `XMonad.Layout.MultiToggle.TabBarDecoration`, `XMonad.Layout.NoFrillsDecoration`, `XMonad.Layout.ResizeScreen`, `XMonad.Layout.SideBorderDecoration`, `XMonad.Layout.SimpleDecoration`, `XMonad.Layout.SimpleFloat`, `XMonad.Layout.TabBarDecoration`, `XMonad.Layout.Tabbed`, `XMonad.Layout.TallMastersCombo`, `XMonad.Prompt.Theme`, `XMonad.Prompt.Window`, `XMonad.Util.ClickableWorkspaces`, `XMonad.Util.Loggers`, `XMonad.Util.Themes`

### `XMonad.Actions.Minimize`, `XMonad.Hooks.ManageDocks` (+1 more) — 11 modules

`XMonad.Layout.ButtonDecoration`, `XMonad.Layout.DecorationAddons`, `XMonad.Layout.DecorationEx`, `XMonad.Layout.DecorationEx.DwmGeometry`, `XMonad.Layout.DecorationEx.Engine`, `XMonad.Layout.DecorationEx.LayoutModifier`, `XMonad.Layout.DecorationEx.TabbedGeometry`, `XMonad.Layout.DecorationEx.TextEngine`, `XMonad.Layout.DecorationEx.Widgets`, `XMonad.Layout.ImageButtonDecoration`, `XMonad.Layout.WindowSwitcherDecoration`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.SetWMName` (+1 more) — 5 modules

`XMonad.Config.Desktop`, `XMonad.Config.Gnome`, `XMonad.Config.Kde`, `XMonad.Config.LXQt`, `XMonad.Config.Xfce`

### `XMonad.Actions.Repeatable` — 4 modules

`XMonad.Actions.CycleRecentWS`, `XMonad.Actions.CycleWindows`, `XMonad.Actions.CycleWorkspaceByScreen`, `XMonad.Actions.MostRecentlyUsed`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.Rescreen` (+1 more) — 4 modules

`XMonad.Actions.Profiles`, `XMonad.Hooks.DynamicBars`, `XMonad.Hooks.DynamicLog`, `XMonad.Hooks.StatusBar`

### `XMonad.Hooks.RefocusLast`, `XMonad.Hooks.UrgencyHook` — 3 modules

`XMonad.Util.Loggers.NamedScratchpad`, `XMonad.Util.NamedScratchpad`, `XMonad.Util.Scratchpad`

### `XMonad.Util.Paste` — 2 modules

`XMonad.Actions.KeyRemap`, `XMonad.Actions.Prefix`

### `XMonad.Hooks.SetWMName` — 2 modules

`XMonad.Actions.ToggleFullFloat`, `XMonad.Hooks.EwmhDesktops`

### `XMonad.Util.DebugWindow` — 2 modules

`XMonad.Hooks.DebugStack`, `XMonad.Hooks.ManageDebug`

### `XMonad.Hooks.FadeInactive` — 2 modules

`XMonad.Hooks.FadeWindows`, `XMonad.Layout.Monitor`

### `XMonad.Actions.Minimize` — 2 modules

`XMonad.Hooks.Minimize`, `XMonad.Util.ExclusiveScratchpads`

### `XMonad.Hooks.UrgencyHook`, `XMonad.Layout.WindowNavigation` — 2 modules

`XMonad.Hooks.WindowSwallowing`, `XMonad.Layout.SubLayouts`

### `XMonad.Layout.WindowNavigation` — 2 modules

`XMonad.Layout.Combo`, `XMonad.Layout.ComboP`

### `XMonad.Hooks.ManageDocks` — 1 modules

`XMonad.Actions.FloatSnap`

### `XMonad.Actions.Minimize`, `XMonad.Hooks.UrgencyHook` — 1 modules

`XMonad.Actions.WindowMenu`

### `XMonad.Hooks.SetWMName`, `XMonad.Hooks.UrgencyHook` — 1 modules

`XMonad.Actions.WorkspaceNames`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.Rescreen` (+3 more) — 1 modules

`XMonad.Config.Arossato`

### `XMonad.Actions.Minimize`, `XMonad.Hooks.CurrentWorkspaceOnTop` (+8 more) — 1 modules

`XMonad.Config.Bluetile`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.Rescreen` (+2 more) — 1 modules

`XMonad.Config.Dmwit`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.SetWMName` (+4 more) — 1 modules

`XMonad.Config.Droundy`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.Rescreen` (+5 more) — 1 modules

`XMonad.Config.Example`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.SetWMName` (+2 more) — 1 modules

`XMonad.Config.Mate`

### (no failing import found) — 1 modules

`XMonad.Config.Monad`

### `XMonad.Hooks.FadeInactive`, `XMonad.Hooks.ManageDocks` (+5 more) — 1 modules

`XMonad.Config.Saegesser`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.Rescreen` (+4 more) — 1 modules

`XMonad.Config.Sjanssen`

### `XMonad.Hooks.DebugKeyEvents`, `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugEvents`

### `XMonad.Hooks.OnPropertyChange` — 1 modules

`XMonad.Hooks.DynamicProperty`

### `XMonad.Actions.FloatKeys`, `XMonad.Hooks.UrgencyHook` (+1 more) — 1 modules

`XMonad.Hooks.Modal`

### `XMonad.Actions.FloatKeys` — 1 modules

`XMonad.Hooks.Place`

### `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.UrgencyHook` — 1 modules

`XMonad.Hooks.PositionStoreHooks`

### `XMonad.Layout.Reflect` — 1 modules

`XMonad.Layout.Drawer`

### `XMonad.Hooks.SetWMName`, `XMonad.Layout.NoBorders` — 1 modules

`XMonad.Layout.Fullscreen`

### `XMonad.Layout.DragPane`, `XMonad.Layout.WindowNavigation` — 1 modules

`XMonad.Layout.LayoutCombinators`

### `XMonad.Actions.UpdatePointer` — 1 modules

`XMonad.Layout.MagicFocus`

### `XMonad.Layout.NoBorders` — 1 modules

`XMonad.Layout.MultiToggle.Instances`

### `XMonad.Util.RemoteWindows` — 1 modules

`XMonad.Layout.Stoppable`

### `XMonad.Prompt.Input` — 1 modules

`XMonad.Prompt.Email`

### `XMonad.Hooks.FloatConfigureReq`, `XMonad.Hooks.ManageDocks` (+2 more) — 1 modules

`XMonad.Util.Hacks`

