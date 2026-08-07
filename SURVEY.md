# xmonad-contrib against the river backend

Upstream `xmonad-contrib` master built with `stack build xmonad-contrib:lib`
against `../xmonad-river` at `-f river`, with `-fkeep-going` so one failure
does not stop the run.

| | count |
| --- | --- |
| compiled | **135** |
| failed | 54 |
| skipped behind a failure | 145 |
| total | 334 |

The skipped ones are **unmeasured, not known-bad**: GHC never attempted them,
because a module they import failed first. The true number that would compile
is somewhere between 135 and 280.

Regenerate with `tests/survey.sh` after rebuilding `xmonad`.

## Failing modules, by cause

### other — 22 modules

- `XMonad.Actions.ConstrainedResize` (8) — Variable not in scope:
- `XMonad.Actions.FlexibleManipulate` (8) — Variable not in scope:
- `XMonad.Actions.FlexibleResize` (9) — Variable not in scope:
- `XMonad.Actions.FloatKeys` (16) — Variable not in scope:
- `XMonad.Actions.NoBorders` (4) — Variable not in scope:
- `XMonad.Hooks.BorderPerWindow` (1) — Variable not in scope:
- `XMonad.Hooks.DebugKeyEvents` (2) — ?
- `XMonad.Hooks.FadeInactive` (4) — Variable not in scope: getAtom :: String -> X t2
- `XMonad.Hooks.ScreenCorners` (1) — ?
- `XMonad.Hooks.WorkspaceByPos` (5) — Variable not in scope:
- `XMonad.Layout.AvoidFloats` (1) — ?
- `XMonad.Layout.DragPane` (3) — Not in scope: data constructor ‘ButtonEvent’
- `XMonad.Layout.FixedColumn` (1) — ?
- `XMonad.Layout.Gaps` (1) — ?
- `XMonad.Layout.LayoutScreens` (1) — ?
- `XMonad.Layout.NoBorders` (1) — ?
- `XMonad.Layout.Reflect` (1) — ?
- `XMonad.Layout.SimplestFloat` (5) — Variable not in scope:
- `XMonad.Layout.TrackFloating` (1) — Variable not in scope:
- `XMonad.Layout.VoidBorders` (1) — Variable not in scope:
- `XMonad.Util.Cursor` (1) — ?
- `XMonad.Util.StringProp` (1) — ?

### X window properties — 9 modules

- `XMonad.Actions.EasyMotion` (3) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Actions.ShowText` (4) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Actions.TiledWindowDragging` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Actions.UpdatePointer` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Hooks.SetWMName` (1) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.TaffybarPagerHints` (5) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.XPropManage` (3) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.DebugWindow` (19) — Not in scope: data constructor ‘WindowAttributes’
- `XMonad.Util.WindowState` (3) — Variable not in scope: stringProperty :: String -> Query String

### missing module or export — 7 modules

- `XMonad.Actions.GroupNavigation` (1) — Could not load module ‘Graphics.X11.Types’.
- `XMonad.Actions.Repeatable` (1) — Could not load module ‘Graphics.X11.Xlib.Extras’.
- `XMonad.Hooks.Rescreen` (1) — Could not load module ‘Graphics.X11.Xrandr’.
- `XMonad.Layout.MouseResizableTile` (1) — Could not load module ‘Graphics.X11’.
- `XMonad.Util.DynamicScratchpads` (1) — Could not load module ‘Graphics.X11.Types’.
- `XMonad.Util.NoTaskbar` (3) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Util.Ungrab` (1) — Module ‘XMonad.Operations’ does not export ‘unGrab’.

### Xlib drawing and display — 6 modules

- `XMonad.Actions.TreeSelect` (28) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Hooks.Qubes` (8) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Hooks.ShowWName` (3) — Variable not in scope: openDisplay :: String -> IO t0
- `XMonad.Layout.WindowNavigation` (1) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Prompt` (23) — Not in scope: type constructor or class ‘GC’
- `XMonad.Util.Replace` (27) — Variable not in scope: openDisplay :: String -> IO t21

### raw X events — 4 modules

- `XMonad.Actions.UpdateFocus` (3) — Not in scope: data constructor ‘MotionEvent’
- `XMonad.Hooks.OnPropertyChange` (3) — Not in scope: data constructor ‘PropertyEvent’
- `XMonad.Hooks.RefocusLast` (2) — Not in scope: data constructor ‘UnmapEvent’
- `XMonad.Hooks.ServerMode` (3) — Not in scope: data constructor ‘ClientMessageEvent’

### small missing names — 4 modules

- `XMonad.Actions.Warp` (5) — Variable not in scope: none :: Position
- `XMonad.Actions.WindowNavigation` (12) — Not in scope: type constructor or class ‘Point’
- `XMonad.Hooks.CurrentWorkspaceOnTop` (2) — Variable not in scope: raiseWindow :: Display -> Window -> IO a0
- `XMonad.Util.Grab` (6) — Not in scope: type constructor or class ‘KeyCode’

### root window — 2 modules

- `XMonad.Actions.MouseGestures` (2) — Variable not in scope: theRoot :: XConf -> t0
- `XMonad.Actions.Submap` (4) — Not in scope: ‘theRoot’

## Skipped modules, by what blocks them

### `XMonad.Prompt` — 91 modules

`XMonad.Actions.CopyWindow`, `XMonad.Actions.DynamicProjects`, `XMonad.Actions.DynamicWorkspaceGroups`, `XMonad.Actions.DynamicWorkspaces`, `XMonad.Actions.FloatSnap`, `XMonad.Actions.GridSelect`, `XMonad.Actions.Launcher`, `XMonad.Actions.LinkWorkspaces`, `XMonad.Actions.Minimize`, `XMonad.Actions.MouseResize`, `XMonad.Actions.Search`, `XMonad.Actions.SpawnOn`, `XMonad.Actions.TagWindows`, `XMonad.Actions.TopicSpace`, `XMonad.Actions.WindowBringer`, `XMonad.Actions.WindowGo`, `XMonad.Actions.WindowMenu`, `XMonad.Hooks.DynamicIcons`, `XMonad.Hooks.FloatConfigureReq`, `XMonad.Hooks.Focus`, `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.ManageHelpers`, `XMonad.Hooks.Minimize`, `XMonad.Hooks.PositionStoreHooks`, `XMonad.Hooks.StatusBar.PP`, `XMonad.Hooks.StatusBar.WorkspaceScreen`, `XMonad.Hooks.UrgencyHook`, `XMonad.Layout.BinarySpacePartition`, `XMonad.Layout.BorderResize`, `XMonad.Layout.ButtonDecoration`, `XMonad.Layout.Decoration`, `XMonad.Layout.DecorationAddons`, `XMonad.Layout.DecorationEx`, `XMonad.Layout.DecorationEx.Common`, `XMonad.Layout.DecorationEx.DwmGeometry`, `XMonad.Layout.DecorationEx.Engine`, `XMonad.Layout.DecorationEx.Geometry`, `XMonad.Layout.DecorationEx.LayoutModifier`, `XMonad.Layout.DecorationEx.TabbedGeometry`, `XMonad.Layout.DecorationEx.TextEngine`, `XMonad.Layout.DecorationEx.Widgets`, `XMonad.Layout.DecorationMadness`, `XMonad.Layout.DwmStyle`, `XMonad.Layout.FixedAspectRatio`, `XMonad.Layout.Groups.Examples`, `XMonad.Layout.Groups.Wmii`, `XMonad.Layout.IM`, `XMonad.Layout.ImageButtonDecoration`, `XMonad.Layout.IndependentScreens`, `XMonad.Layout.LayoutBuilder`, `XMonad.Layout.LayoutHints`, `XMonad.Layout.MultiToggle.TabBarDecoration`, `XMonad.Layout.NoFrillsDecoration`, `XMonad.Layout.ResizeScreen`, `XMonad.Layout.SideBorderDecoration`, `XMonad.Layout.SimpleDecoration`, `XMonad.Layout.SimpleFloat`, `XMonad.Layout.SortedLayout`, `XMonad.Layout.Stoppable`, `XMonad.Layout.TabBarDecoration`, `XMonad.Layout.Tabbed`, `XMonad.Layout.TallMastersCombo`, `XMonad.Layout.WindowSwitcherDecoration`, `XMonad.Layout.WorkspaceDir`, `XMonad.Prompt.AppLauncher`, `XMonad.Prompt.AppendFile`, `XMonad.Prompt.ConfirmPrompt`, `XMonad.Prompt.DirExec`, `XMonad.Prompt.Directory`, `XMonad.Prompt.Email`, `XMonad.Prompt.Input`, `XMonad.Prompt.Layout`, `XMonad.Prompt.Man`, `XMonad.Prompt.OrgMode`, `XMonad.Prompt.Pass`, `XMonad.Prompt.RunOrRaise`, `XMonad.Prompt.Shell`, `XMonad.Prompt.Ssh`, `XMonad.Prompt.Theme`, `XMonad.Prompt.Unicode`, `XMonad.Prompt.Window`, `XMonad.Prompt.Workspace`, `XMonad.Prompt.XMonad`, `XMonad.Prompt.Zsh`, `XMonad.Util.ClickableWorkspaces`, `XMonad.Util.ExclusiveScratchpads`, `XMonad.Util.Loggers`, `XMonad.Util.RemoteWindows`, `XMonad.Util.SpawnOnce`, `XMonad.Util.Themes`, `XMonad.Util.WindowProperties`

### `XMonad.Actions.Submap` — 8 modules

`XMonad.Actions.KeyRemap`, `XMonad.Actions.Navigation2D`, `XMonad.Actions.Prefix`, `XMonad.Actions.UpKeys`, `XMonad.Config.Prime`, `XMonad.Util.EZConfig`, `XMonad.Util.NamedActions`, `XMonad.Util.Paste`

### `XMonad.Hooks.Rescreen`, `XMonad.Prompt` — 5 modules

`XMonad.Actions.Profiles`, `XMonad.Hooks.DynamicBars`, `XMonad.Hooks.DynamicLog`, `XMonad.Hooks.StatusBar`, `XMonad.Util.Hacks`

### `XMonad.Hooks.SetWMName`, `XMonad.Prompt` (+1 more) — 5 modules

`XMonad.Config.Desktop`, `XMonad.Config.Gnome`, `XMonad.Config.Kde`, `XMonad.Config.LXQt`, `XMonad.Config.Xfce`

### `XMonad.Actions.Repeatable` — 4 modules

`XMonad.Actions.CycleRecentWS`, `XMonad.Actions.CycleWindows`, `XMonad.Actions.CycleWorkspaceByScreen`, `XMonad.Actions.MostRecentlyUsed`

### `XMonad.Hooks.SetWMName`, `XMonad.Prompt` — 3 modules

`XMonad.Actions.ToggleFullFloat`, `XMonad.Actions.WorkspaceNames`, `XMonad.Hooks.EwmhDesktops`

### `XMonad.Layout.WindowNavigation`, `XMonad.Prompt` — 3 modules

`XMonad.Hooks.WindowSwallowing`, `XMonad.Layout.ComboP`, `XMonad.Layout.SubLayouts`

### `XMonad.Hooks.RefocusLast`, `XMonad.Prompt` — 3 modules

`XMonad.Util.Loggers.NamedScratchpad`, `XMonad.Util.NamedScratchpad`, `XMonad.Util.Scratchpad`

### `XMonad.Hooks.Rescreen`, `XMonad.Hooks.ServerMode` (+2 more) — 1 modules

`XMonad.Config.Arossato`

### `XMonad.Hooks.CurrentWorkspaceOnTop`, `XMonad.Hooks.ServerMode` (+6 more) — 1 modules

`XMonad.Config.Bluetile`

### `XMonad.Actions.Warp`, `XMonad.Hooks.Rescreen` (+2 more) — 1 modules

`XMonad.Config.Dmwit`

### `XMonad.Hooks.SetWMName`, `XMonad.Layout.DragPane` (+3 more) — 1 modules

`XMonad.Config.Droundy`

### `XMonad.Actions.Submap`, `XMonad.Hooks.Rescreen` (+4 more) — 1 modules

`XMonad.Config.Example`

### `XMonad.Hooks.SetWMName`, `XMonad.Prompt` (+2 more) — 1 modules

`XMonad.Config.Mate`

### (no failing import found) — 1 modules

`XMonad.Config.Monad`

### `XMonad.Hooks.FadeInactive`, `XMonad.Hooks.RefocusLast` (+4 more) — 1 modules

`XMonad.Config.Saegesser`

### `XMonad.Hooks.Rescreen`, `XMonad.Hooks.SetWMName` (+3 more) — 1 modules

`XMonad.Config.Sjanssen`

### `XMonad.Hooks.DebugKeyEvents`, `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugEvents`

### `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugStack`

### `XMonad.Hooks.OnPropertyChange` — 1 modules

`XMonad.Hooks.DynamicProperty`

### `XMonad.Hooks.FadeInactive` — 1 modules

`XMonad.Hooks.FadeWindows`

### `XMonad.Actions.Submap`, `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.ManageDebug`

### `XMonad.Actions.FloatKeys`, `XMonad.Actions.Submap` (+2 more) — 1 modules

`XMonad.Hooks.Modal`

### `XMonad.Actions.FloatKeys` — 1 modules

`XMonad.Hooks.Place`

### `XMonad.Layout.WindowNavigation` — 1 modules

`XMonad.Layout.Combo`

### `XMonad.Layout.Reflect`, `XMonad.Prompt` — 1 modules

`XMonad.Layout.Drawer`

### `XMonad.Hooks.SetWMName`, `XMonad.Layout.NoBorders` (+1 more) — 1 modules

`XMonad.Layout.Fullscreen`

### `XMonad.Layout.DragPane`, `XMonad.Layout.WindowNavigation` — 1 modules

`XMonad.Layout.LayoutCombinators`

### `XMonad.Actions.UpdatePointer` — 1 modules

`XMonad.Layout.MagicFocus`

### `XMonad.Hooks.FadeInactive`, `XMonad.Prompt` — 1 modules

`XMonad.Layout.Monitor`

### `XMonad.Layout.NoBorders` — 1 modules

`XMonad.Layout.MultiToggle.Instances`

