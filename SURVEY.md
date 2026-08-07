# xmonad-contrib against the river backend

Upstream `xmonad-contrib` master built with `stack build xmonad-contrib:lib`
against `../xmonad-river` at `-f river`, with `-fkeep-going` so one failure
does not stop the run.

| | count |
| --- | --- |
| compiled | **103** |
| failed | 58 |
| skipped behind a failure | 171 |
| total | 332 |

The skipped ones are **unmeasured, not known-bad**: GHC never attempted them,
because a module they import failed first. The true number that would compile
is somewhere between 103 and 274.

Regenerate with `tests/survey.sh`.

## Failing modules, by cause

### other — 12 modules

- `XMonad.Actions.ConstrainedResize` (8) — Variable not in scope:
- `XMonad.Actions.FlexibleManipulate` (8) — Variable not in scope:
- `XMonad.Actions.FlexibleResize` (9) — Variable not in scope:
- `XMonad.Actions.FloatKeys` (16) — Variable not in scope:
- `XMonad.Actions.NoBorders` (4) — Variable not in scope:
- `XMonad.Hooks.BorderPerWindow` (1) — Variable not in scope:
- `XMonad.Hooks.FadeInactive` (4) — Variable not in scope: getAtom :: String -> X t2
- `XMonad.Hooks.WorkspaceByPos` (5) — Variable not in scope:
- `XMonad.Layout.FixedColumn` (1) — Variable not in scope:
- `XMonad.Layout.NoBorders` (1) — Variable not in scope:
- `XMonad.Layout.SimplestFloat` (5) — Variable not in scope:
- `XMonad.Layout.VoidBorders` (1) — Variable not in scope:

### Read instance for Window — 11 modules

- `XMonad.Actions.SwapPromote` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Layout.BoringWindows` (1) — • No instance for ‘Read Window’
- `XMonad.Layout.Columns` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Layout.DraggingVisualizer` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Layout.FocusTracking` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Layout.Hidden` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Layout.Maximize` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Layout.MosaicAlt` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Util.Minimize` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Util.PositionStore` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’
- `XMonad.Util.StickyWindows` (1) — • No instance for ‘Read XMonad.River.Wire.ObjectId’

### missing module or export — 10 modules

- `XMonad.Actions.GroupNavigation` (1) — Could not load module ‘Graphics.X11.Types’.
- `XMonad.Actions.Repeatable` (1) — Could not load module ‘Graphics.X11.Xlib.Extras’.
- `XMonad.Hooks.DebugKeyEvents` (2) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Hooks.Rescreen` (1) — Could not load module ‘Graphics.X11.Xrandr’.
- `XMonad.Layout.Gaps` (1) — Could not load module ‘Graphics.X11’.
- `XMonad.Layout.Reflect` (1) — Could not load module ‘Graphics.X11’.
- `XMonad.Util.Cursor` (1) — Could not load module ‘Graphics.X11.Xlib.Cursor’.
- `XMonad.Util.DynamicScratchpads` (1) — Could not load module ‘Graphics.X11.Types’.
- `XMonad.Util.NoTaskbar` (3) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Util.Ungrab` (1) — Module ‘XMonad.Operations’ does not export ‘unGrab’.

### X window properties — 9 modules

- `XMonad.Actions.UpdatePointer` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Hooks.SetWMName` (1) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.TaffybarPagerHints` (5) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.XPropManage` (3) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Layout.AvoidFloats` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Layout.LayoutScreens` (1) — Not in scope: type constructor or class ‘WindowAttributes’
- `XMonad.Util.DebugWindow` (19) — Not in scope: data constructor ‘WindowAttributes’
- `XMonad.Util.StringProp` (1) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.WindowState` (3) — Variable not in scope: stringProperty :: String -> Query String

### raw X events — 6 modules

- `XMonad.Actions.UpdateFocus` (3) — Not in scope: data constructor ‘MotionEvent’
- `XMonad.Hooks.OnPropertyChange` (3) — Not in scope: data constructor ‘PropertyEvent’
- `XMonad.Hooks.RefocusLast` (2) — Not in scope: data constructor ‘UnmapEvent’
- `XMonad.Hooks.ScreenCorners` (1) — Not in scope: data constructor ‘CrossingEvent’
- `XMonad.Hooks.ServerMode` (3) — Not in scope: data constructor ‘ClientMessageEvent’
- `XMonad.Util.Timer` (3) — Not in scope: data constructor ‘ClientMessageEvent’

### Xlib drawing and display — 5 modules

- `XMonad.Hooks.Qubes` (8) — Not in scope: type constructor or class ‘Pixel’
- `XMonad.Util.Font` (11) — Not in scope: type constructor or class ‘FontStruct’
- `XMonad.Util.NamedWindows` (16) — Variable not in scope: xFree :: b2 -> IO b3
- `XMonad.Util.Replace` (27) — Variable not in scope: openDisplay :: String -> IO t21
- `XMonad.Util.XSelection` (19) — Variable not in scope: openDisplay :: String -> IO t16

### small missing names — 4 modules

- `XMonad.Actions.Warp` (5) — Variable not in scope: none :: Position
- `XMonad.Actions.WindowNavigation` (12) — Not in scope: type constructor or class ‘Point’
- `XMonad.Hooks.CurrentWorkspaceOnTop` (2) — Variable not in scope: raiseWindow :: Display -> Window -> IO a0
- `XMonad.Util.Grab` (6) — Not in scope: type constructor or class ‘KeyCode’

### root window — 1 modules

- `XMonad.Actions.MouseGestures` (2) — Variable not in scope: theRoot :: XConf -> t0

## Skipped modules, by what blocks them

### `XMonad.Util.Font`, `XMonad.Util.XSelection` — 43 modules

`XMonad.Actions.DynamicProjects`, `XMonad.Actions.DynamicWorkspaces`, `XMonad.Actions.FloatSnap`, `XMonad.Actions.KeyRemap`, `XMonad.Actions.Launcher`, `XMonad.Actions.Prefix`, `XMonad.Actions.Search`, `XMonad.Actions.SpawnOn`, `XMonad.Actions.TagWindows`, `XMonad.Actions.WindowGo`, `XMonad.Hooks.FloatConfigureReq`, `XMonad.Hooks.Focus`, `XMonad.Hooks.ManageDocks`, `XMonad.Hooks.ManageHelpers`, `XMonad.Layout.BinarySpacePartition`, `XMonad.Layout.ComboP`, `XMonad.Layout.IM`, `XMonad.Layout.LayoutBuilder`, `XMonad.Layout.SortedLayout`, `XMonad.Layout.WorkspaceDir`, `XMonad.Prompt`, `XMonad.Prompt.AppLauncher`, `XMonad.Prompt.AppendFile`, `XMonad.Prompt.ConfirmPrompt`, `XMonad.Prompt.DirExec`, `XMonad.Prompt.Directory`, `XMonad.Prompt.Email`, `XMonad.Prompt.Input`, `XMonad.Prompt.Layout`, `XMonad.Prompt.Man`, `XMonad.Prompt.OrgMode`, `XMonad.Prompt.Pass`, `XMonad.Prompt.RunOrRaise`, `XMonad.Prompt.Shell`, `XMonad.Prompt.Ssh`, `XMonad.Prompt.Unicode`, `XMonad.Prompt.Workspace`, `XMonad.Prompt.XMonad`, `XMonad.Prompt.Zsh`, `XMonad.Util.Paste`, `XMonad.Util.RemoteWindows`, `XMonad.Util.SpawnOnce`, `XMonad.Util.WindowProperties`

### `XMonad.Util.Font`, `XMonad.Util.NamedWindows` (+2 more) — 36 modules

`XMonad.Actions.CopyWindow`, `XMonad.Actions.DynamicWorkspaceGroups`, `XMonad.Actions.GridSelect`, `XMonad.Actions.LinkWorkspaces`, `XMonad.Actions.MouseResize`, `XMonad.Actions.TopicSpace`, `XMonad.Actions.WindowBringer`, `XMonad.Hooks.DynamicIcons`, `XMonad.Hooks.StatusBar.PP`, `XMonad.Hooks.StatusBar.WorkspaceScreen`, `XMonad.Hooks.UrgencyHook`, `XMonad.Layout.BorderResize`, `XMonad.Layout.Decoration`, `XMonad.Layout.DecorationEx.Common`, `XMonad.Layout.DecorationEx.Geometry`, `XMonad.Layout.DecorationMadness`, `XMonad.Layout.DwmStyle`, `XMonad.Layout.FixedAspectRatio`, `XMonad.Layout.Groups.Examples`, `XMonad.Layout.Groups.Wmii`, `XMonad.Layout.IndependentScreens`, `XMonad.Layout.LayoutHints`, `XMonad.Layout.MultiToggle.TabBarDecoration`, `XMonad.Layout.NoFrillsDecoration`, `XMonad.Layout.ResizeScreen`, `XMonad.Layout.SideBorderDecoration`, `XMonad.Layout.SimpleDecoration`, `XMonad.Layout.SimpleFloat`, `XMonad.Layout.TabBarDecoration`, `XMonad.Layout.Tabbed`, `XMonad.Layout.TallMastersCombo`, `XMonad.Prompt.Theme`, `XMonad.Prompt.Window`, `XMonad.Util.ClickableWorkspaces`, `XMonad.Util.Loggers`, `XMonad.Util.Themes`

### `XMonad.Util.Font` — 15 modules

`XMonad.Actions.EasyMotion`, `XMonad.Actions.Navigation2D`, `XMonad.Actions.Submap`, `XMonad.Actions.UpKeys`, `XMonad.Config.Prime`, `XMonad.Layout.Combo`, `XMonad.Layout.DragPane`, `XMonad.Layout.LayoutCombinators`, `XMonad.Layout.MouseResizableTile`, `XMonad.Layout.WindowNavigation`, `XMonad.Util.Dzen`, `XMonad.Util.EZConfig`, `XMonad.Util.Image`, `XMonad.Util.NamedActions`, `XMonad.Util.XUtils`

### (no failing import found) — 9 modules

`XMonad.Config.Monad`, `XMonad.Doc`, `XMonad.Doc.Configuring`, `XMonad.Doc.Developing`, `XMonad.Doc.Extending`, `XMonad.Util.History`, `XMonad.Util.Invisible`, `XMonad.Util.TreeZipper`, `XMonad.Util.Types`

### `XMonad.Layout.BoringWindows`, `XMonad.Layout.DraggingVisualizer` (+7 more) — 8 modules

`XMonad.Layout.DecorationEx`, `XMonad.Layout.DecorationEx.DwmGeometry`, `XMonad.Layout.DecorationEx.Engine`, `XMonad.Layout.DecorationEx.LayoutModifier`, `XMonad.Layout.DecorationEx.TabbedGeometry`, `XMonad.Layout.DecorationEx.TextEngine`, `XMonad.Layout.DecorationEx.Widgets`, `XMonad.Layout.WindowSwitcherDecoration`

### `XMonad.Hooks.Rescreen`, `XMonad.Util.Font` (+3 more) — 5 modules

`XMonad.Actions.Profiles`, `XMonad.Hooks.DynamicBars`, `XMonad.Hooks.DynamicLog`, `XMonad.Hooks.StatusBar`, `XMonad.Util.Hacks`

### `XMonad.Hooks.SetWMName`, `XMonad.Util.Cursor` (+2 more) — 5 modules

`XMonad.Config.Desktop`, `XMonad.Config.Gnome`, `XMonad.Config.Kde`, `XMonad.Config.LXQt`, `XMonad.Config.Xfce`

### `XMonad.Actions.Repeatable` — 4 modules

`XMonad.Actions.CycleRecentWS`, `XMonad.Actions.CycleWindows`, `XMonad.Actions.CycleWorkspaceByScreen`, `XMonad.Actions.MostRecentlyUsed`

### `XMonad.Layout.BoringWindows`, `XMonad.Util.Font` (+2 more) — 3 modules

`XMonad.Actions.Minimize`, `XMonad.Hooks.Minimize`, `XMonad.Util.ExclusiveScratchpads`

### `XMonad.Util.Font`, `XMonad.Util.Timer` — 3 modules

`XMonad.Actions.ShowText`, `XMonad.Hooks.ShowWName`, `XMonad.Layout.ShowWName`

### `XMonad.Layout.BoringWindows`, `XMonad.Layout.Maximize` (+6 more) — 3 modules

`XMonad.Layout.ButtonDecoration`, `XMonad.Layout.DecorationAddons`, `XMonad.Layout.ImageButtonDecoration`

### `XMonad.Hooks.RefocusLast`, `XMonad.Util.Font` (+3 more) — 3 modules

`XMonad.Util.Loggers.NamedScratchpad`, `XMonad.Util.NamedScratchpad`, `XMonad.Util.Scratchpad`

### `XMonad.Hooks.SetWMName`, `XMonad.Util.Font` (+1 more) — 2 modules

`XMonad.Actions.ToggleFullFloat`, `XMonad.Hooks.EwmhDesktops`

### `XMonad.Hooks.Rescreen`, `XMonad.Hooks.SetWMName` (+6 more) — 2 modules

`XMonad.Config.Example`, `XMonad.Config.Sjanssen`

### `XMonad.Layout.BoringWindows`, `XMonad.Util.Font` (+3 more) — 2 modules

`XMonad.Hooks.WindowSwallowing`, `XMonad.Layout.SubLayouts`

### `XMonad.Layout.FocusTracking` — 2 modules

`XMonad.Layout.StateFull`, `XMonad.Layout.TrackFloating`

### `XMonad.Layout.DraggingVisualizer` — 1 modules

`XMonad.Actions.TiledWindowDragging`

### `XMonad.Util.Font`, `XMonad.Util.NamedWindows` — 1 modules

`XMonad.Actions.TreeSelect`

### `XMonad.Layout.BoringWindows`, `XMonad.Layout.Maximize` (+5 more) — 1 modules

`XMonad.Actions.WindowMenu`

### `XMonad.Hooks.SetWMName`, `XMonad.Util.Font` (+3 more) — 1 modules

`XMonad.Actions.WorkspaceNames`

### `XMonad.Hooks.Rescreen`, `XMonad.Hooks.ServerMode` (+5 more) — 1 modules

`XMonad.Config.Arossato`

### `XMonad.Hooks.CurrentWorkspaceOnTop`, `XMonad.Hooks.ServerMode` (+13 more) — 1 modules

`XMonad.Config.Bluetile`

### `XMonad.Actions.Warp`, `XMonad.Hooks.Rescreen` (+5 more) — 1 modules

`XMonad.Config.Dmwit`

### `XMonad.Hooks.SetWMName`, `XMonad.Layout.BoringWindows` (+5 more) — 1 modules

`XMonad.Config.Droundy`

### `XMonad.Hooks.SetWMName`, `XMonad.Util.Cursor` (+3 more) — 1 modules

`XMonad.Config.Mate`

### `XMonad.Hooks.FadeInactive`, `XMonad.Hooks.RefocusLast` (+7 more) — 1 modules

`XMonad.Config.Saegesser`

### `XMonad.Hooks.DebugKeyEvents`, `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugEvents`

### `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugStack`

### `XMonad.Hooks.OnPropertyChange` — 1 modules

`XMonad.Hooks.DynamicProperty`

### `XMonad.Hooks.FadeInactive` — 1 modules

`XMonad.Hooks.FadeWindows`

### `XMonad.Util.DebugWindow`, `XMonad.Util.Font` — 1 modules

`XMonad.Hooks.ManageDebug`

### `XMonad.Actions.FloatKeys`, `XMonad.Util.Font` (+4 more) — 1 modules

`XMonad.Hooks.Modal`

### `XMonad.Actions.FloatKeys` — 1 modules

`XMonad.Hooks.Place`

### `XMonad.Util.Font`, `XMonad.Util.NamedWindows` (+3 more) — 1 modules

`XMonad.Hooks.PositionStoreHooks`

### `XMonad.Layout.Reflect`, `XMonad.Util.Font` (+1 more) — 1 modules

`XMonad.Layout.Drawer`

### `XMonad.Hooks.SetWMName`, `XMonad.Layout.NoBorders` (+2 more) — 1 modules

`XMonad.Layout.Fullscreen`

### `XMonad.Actions.UpdatePointer` — 1 modules

`XMonad.Layout.MagicFocus`

### `XMonad.Layout.BoringWindows`, `XMonad.Util.Minimize` — 1 modules

`XMonad.Layout.Minimize`

### `XMonad.Hooks.FadeInactive`, `XMonad.Util.Font` (+1 more) — 1 modules

`XMonad.Layout.Monitor`

### `XMonad.Layout.NoBorders` — 1 modules

`XMonad.Layout.MultiToggle.Instances`

### `XMonad.Util.PositionStore` — 1 modules

`XMonad.Layout.PositionStoreFloat`

### `XMonad.Util.Font`, `XMonad.Util.Timer` (+1 more) — 1 modules

`XMonad.Layout.Stoppable`

