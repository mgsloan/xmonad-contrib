# xmonad-contrib against the river backend

Upstream `xmonad-contrib` master built with `stack build xmonad-contrib:lib`
against `../xmonad-river` at `-f river`, with `-fkeep-going` so one failure
does not stop the run.

| | count |
| --- | --- |
| compiled | **215** |
| failed | 62 |
| skipped behind a failure | 57 |
| total | 334 |

The skipped ones are **unmeasured, not known-bad**: GHC never attempted them,
because a module they import failed first. The true number that would compile
is somewhere between 215 and 272.

Regenerate with `tests/survey.sh` after rebuilding `xmonad`.

## Failing modules, by cause

### other — 30 modules

- `XMonad.Actions.FlexibleResize` (3) — Variable not in scope:
- `XMonad.Actions.FloatKeys` (4) — Variable not in scope:
- `XMonad.Actions.FloatSnap` (8) — Variable not in scope:
- `XMonad.Actions.GridSelect` (1) — ?
- `XMonad.Actions.GroupNavigation` (1) — • No instance for ‘NFData XMonad.River.Wire.ObjectId’
- `XMonad.Actions.MostRecentlyUsed` (1) — In the import of ‘XMonad’:
- `XMonad.Actions.MouseResize` (2) — Not in scope: data constructor ‘ButtonEvent’
- `XMonad.Actions.Navigation2D` (1) — Variable not in scope:
- `XMonad.Actions.TiledWindowDragging` (3) — Variable not in scope:
- `XMonad.Actions.TopicSpace` (1) — Variable not in scope: xmessage :: [Char] -> f ()
- `XMonad.Actions.UpdatePointer` (5) — Variable not in scope:
- `XMonad.Config.Prime` (6) — Not in scope: type constructor or class ‘EventMask’
- `XMonad.Hooks.EwmhDesktops` (1) — ?
- `XMonad.Hooks.FadeInactive` (4) — Variable not in scope: getAtom :: String -> X t2
- `XMonad.Hooks.FloatConfigureReq` (1) — Not in scope: data constructor ‘ConfigureRequestEvent’
- `XMonad.Hooks.PositionStoreHooks` (1) — ?
- `XMonad.Hooks.Qubes` (5) — Variable not in scope: focusIn :: EventType
- `XMonad.Hooks.WorkspaceByPos` (1) — Variable not in scope:
- `XMonad.Layout.BinarySpacePartition` (1) — ?
- `XMonad.Layout.BorderResize` (4) — Not in scope: type constructor or class ‘Glyph’
- `XMonad.Layout.DragPane` (3) — Not in scope: data constructor ‘ButtonEvent’
- `XMonad.Layout.IndependentScreens` (1) — ?
- `XMonad.Layout.MouseResizableTile` (1) — ?
- `XMonad.Layout.Tabbed` (3) — Not in scope: data constructor ‘ButtonEvent’
- `XMonad.Layout.TrackFloating` (1) — ?
- `XMonad.Prompt.Input` (1) — Variable not in scope:
- `XMonad.Prompt.OrgMode` (1) — ?
- `XMonad.Prompt.RunOrRaise` (2) — Variable not in scope: getAtom :: String -> m t0
- `XMonad.Util.RemoteWindows` (7) — Variable not in scope: getAtom :: String -> X t2
- `XMonad.Util.Ungrab` (1) — ?

### X window properties — 7 modules

- `XMonad.Actions.ShowText` (4) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.TaffybarPagerHints` (5) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.XPropManage` (3) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.DebugWindow` (11) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.NamedScratchpad` (1) — Variable not in scope: stringProperty :: String -> Query String
- `XMonad.Util.StringProp` (1) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.WindowState` (3) — Variable not in scope: stringProperty :: String -> Query String

### missing module or export — 7 modules

- `XMonad.Config.Monad` (2) — Could not find module ‘Data.Accessor’.
- `XMonad.Hooks.DebugKeyEvents` (2) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Hooks.StatusBar.WorkspaceScreen` (1) — Could not load module ‘Graphics.X11.Xrandr’.
- `XMonad.Layout.LayoutHints` (2) — Module ‘XMonad’ does not export ‘propertyNotify’.
- `XMonad.Util.ExclusiveScratchpads` (1) — Module ‘XMonad.Hooks.ManageHelpers’ does not export ‘isInProperty’.
- `XMonad.Util.NoTaskbar` (3) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Util.Paste` (3) — Module ‘XMonad’ does not export ‘theRoot’.

### root window — 5 modules

- `XMonad.Actions.EasyMotion` (1) — Not in scope: ‘theRoot’
- `XMonad.Actions.MouseGestures` (2) — Variable not in scope: theRoot :: XConf -> t0
- `XMonad.Actions.UpKeys` (5) — Not in scope: ‘theRoot’
- `XMonad.Hooks.StatusBar` (5) — Variable not in scope: theRoot :: XConf -> t3
- `XMonad.Layout.LayoutScreens` (1) — Variable not in scope: theRoot :: XConf -> Window

### raw X events — 5 modules

- `XMonad.Actions.UpdateFocus` (3) — Not in scope: data constructor ‘MotionEvent’
- `XMonad.Hooks.Minimize` (3) — Not in scope: data constructor ‘ClientMessageEvent’
- `XMonad.Hooks.OnPropertyChange` (3) — Not in scope: data constructor ‘PropertyEvent’
- `XMonad.Hooks.ScreenCorners` (1) — Not in scope: data constructor ‘CrossingEvent’
- `XMonad.Hooks.ServerMode` (3) — Not in scope: data constructor ‘ClientMessageEvent’

### small missing names — 4 modules

- `XMonad.Actions.ConstrainedResize` (2) — Variable not in scope: none :: Position
- `XMonad.Actions.WindowNavigation` (12) — Not in scope: type constructor or class ‘Point’
- `XMonad.Hooks.CurrentWorkspaceOnTop` (2) — Variable not in scope: raiseWindow :: Display -> Window -> IO a0
- `XMonad.Util.Grab` (6) — Not in scope: type constructor or class ‘KeyCode’

### Xlib drawing and display — 4 modules

- `XMonad.Actions.TreeSelect` (13) — Not in scope: type constructor or class ‘GC’
- `XMonad.Hooks.ShowWName` (3) — Variable not in scope: openDisplay :: String -> IO t0
- `XMonad.Layout.DecorationEx.Common` (2) — Not in scope: type constructor or class ‘Pixmap’
- `XMonad.Util.Replace` (27) — Variable not in scope: openDisplay :: String -> IO t21

## Skipped modules, by what blocks them

### `XMonad.Hooks.EwmhDesktops` — 8 modules

`XMonad.Actions.ToggleFullFloat`, `XMonad.Actions.WorkspaceNames`, `XMonad.Config.Desktop`, `XMonad.Config.Gnome`, `XMonad.Config.Kde`, `XMonad.Config.LXQt`, `XMonad.Config.Xfce`, `XMonad.Layout.Fullscreen`

### `XMonad.Actions.GridSelect` — 5 modules

`XMonad.Actions.WindowMenu`, `XMonad.Layout.ButtonDecoration`, `XMonad.Layout.DecorationAddons`, `XMonad.Layout.ImageButtonDecoration`, `XMonad.Layout.WindowSwitcherDecoration`

### `XMonad.Actions.GridSelect`, `XMonad.Layout.DecorationEx.Common` (+1 more) — 5 modules

`XMonad.Layout.DecorationEx`, `XMonad.Layout.DecorationEx.DwmGeometry`, `XMonad.Layout.DecorationEx.TabbedGeometry`, `XMonad.Layout.DecorationEx.TextEngine`, `XMonad.Layout.DecorationEx.Widgets`

### `XMonad.Layout.Tabbed` — 4 modules

`XMonad.Hooks.WindowSwallowing`, `XMonad.Layout.Groups.Examples`, `XMonad.Layout.Groups.Wmii`, `XMonad.Layout.SubLayouts`

### `XMonad.Hooks.StatusBar` — 3 modules

`XMonad.Actions.Profiles`, `XMonad.Hooks.DynamicBars`, `XMonad.Hooks.DynamicLog`

### `XMonad.Util.Paste` — 2 modules

`XMonad.Actions.KeyRemap`, `XMonad.Actions.Prefix`

### `XMonad.Util.DebugWindow` — 2 modules

`XMonad.Hooks.DebugStack`, `XMonad.Hooks.ManageDebug`

### `XMonad.Hooks.FadeInactive` — 2 modules

`XMonad.Hooks.FadeWindows`, `XMonad.Layout.Monitor`

### `XMonad.Actions.GridSelect`, `XMonad.Layout.DecorationEx.Common` — 2 modules

`XMonad.Layout.DecorationEx.Engine`, `XMonad.Layout.DecorationEx.LayoutModifier`

### `XMonad.Actions.MouseResize` — 2 modules

`XMonad.Layout.DecorationMadness`, `XMonad.Layout.SimpleFloat`

### `XMonad.Util.NamedScratchpad` — 2 modules

`XMonad.Util.Loggers.NamedScratchpad`, `XMonad.Util.Scratchpad`

### `XMonad.Actions.TopicSpace` — 1 modules

`XMonad.Actions.DynamicWorkspaceGroups`

### `XMonad.Layout.IndependentScreens` — 1 modules

`XMonad.Actions.LinkWorkspaces`

### `XMonad.Actions.MouseResize`, `XMonad.Hooks.ServerMode` (+2 more) — 1 modules

`XMonad.Config.Arossato`

### `XMonad.Actions.GridSelect`, `XMonad.Hooks.CurrentWorkspaceOnTop` (+7 more) — 1 modules

`XMonad.Config.Bluetile`

### `XMonad.Hooks.StatusBar`, `XMonad.Layout.IndependentScreens` — 1 modules

`XMonad.Config.Dmwit`

### `XMonad.Hooks.EwmhDesktops`, `XMonad.Layout.DragPane` (+1 more) — 1 modules

`XMonad.Config.Droundy`

### `XMonad.Hooks.EwmhDesktops`, `XMonad.Hooks.StatusBar` (+1 more) — 1 modules

`XMonad.Config.Example`

### `XMonad.Hooks.EwmhDesktops`, `XMonad.Util.Ungrab` — 1 modules

`XMonad.Config.Mate`

### `XMonad.Hooks.FadeInactive`, `XMonad.Hooks.StatusBar` (+1 more) — 1 modules

`XMonad.Config.Saegesser`

### `XMonad.Hooks.EwmhDesktops`, `XMonad.Hooks.StatusBar` (+2 more) — 1 modules

`XMonad.Config.Sjanssen`

### `XMonad.Hooks.DebugKeyEvents`, `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugEvents`

### `XMonad.Hooks.OnPropertyChange` — 1 modules

`XMonad.Hooks.DynamicProperty`

### `XMonad.Actions.FloatKeys`, `XMonad.Util.Grab` — 1 modules

`XMonad.Hooks.Modal`

### `XMonad.Actions.FloatKeys` — 1 modules

`XMonad.Hooks.Place`

### `XMonad.Layout.LayoutHints` — 1 modules

`XMonad.Layout.FixedAspectRatio`

### `XMonad.Layout.DragPane` — 1 modules

`XMonad.Layout.LayoutCombinators`

### `XMonad.Actions.UpdatePointer` — 1 modules

`XMonad.Layout.MagicFocus`

### `XMonad.Util.RemoteWindows` — 1 modules

`XMonad.Layout.Stoppable`

### `XMonad.Prompt.Input` — 1 modules

`XMonad.Prompt.Email`

### `XMonad.Hooks.FloatConfigureReq`, `XMonad.Hooks.StatusBar` — 1 modules

`XMonad.Util.Hacks`

