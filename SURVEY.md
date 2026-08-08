# xmonad-contrib against the river backend

Upstream `xmonad-contrib` master built with `stack build xmonad-contrib:lib`
against `../xmonad-river` at `-f river`, with `-fkeep-going` so one failure
does not stop the run.

| | count |
| --- | --- |
| compiled | **283** |
| failed | 25 |
| skipped behind a failure | 26 |
| total | 334 |

The skipped ones are **unmeasured, not known-bad**: GHC never attempted them,
because a module they import failed first. The true number that would compile
is somewhere between 283 and 309.

To bring this up to date after changing the backend or a module:

```
stack build --flag xmonad:river   # in ../xmonad-river, if it changed
tests/survey.sh                   # rewrites this file; ~10 min, builds all 334
python3 tests/expose-working.py   # enable/disable modules in the cabal to match
stack build xmonad-contrib:lib    # confirm the library still builds
```

The second step is not optional bookkeeping: the cabal file cannot name a
module it fails to build, so a module that starts compiling is not usable by a
config until it is enabled there. Disabled modules are commented out in place
rather than deleted, so the list below and the cabal file say the same thing.

## Failing modules, by cause

### other — 7 modules

- `XMonad.Actions.MouseResize` (2) — Not in scope: data constructor ‘ButtonEvent’
- `XMonad.Hooks.DebugKeyEvents` (2) — ?
- `XMonad.Hooks.FadeInactive` (4) — Variable not in scope: getAtom :: String -> X t2
- `XMonad.Hooks.FloatConfigureReq` (1) — Not in scope: data constructor ‘ConfigureRequestEvent’
- `XMonad.Hooks.Qubes` (5) — Variable not in scope: focusIn :: EventType
- `XMonad.Layout.BorderResize` (4) — Not in scope: type constructor or class ‘Glyph’
- `XMonad.Util.RemoteWindows` (7) — Variable not in scope: getAtom :: String -> X t2

### missing module or export — 7 modules

- `XMonad.Config.Monad` (2) — Could not find module ‘Data.Accessor’.
- `XMonad.Hooks.DynamicBars` (4) — Could not load module ‘Graphics.X11.Xinerama’.
- `XMonad.Hooks.EwmhDesktops` (1) — Module ‘XMonad.Util.WindowProperties’ does not export ‘getProp32’.
- `XMonad.Layout.MouseResizableTile` (1) — Could not load module ‘Graphics.X11’.
- `XMonad.Util.NoTaskbar` (3) — Could not load module ‘Graphics.X11.Xlib’.
- `XMonad.Util.Paste` (3) — Module ‘XMonad’ does not export ‘theRoot’.
- `XMonad.Util.Ungrab` (1) — Module ‘XMonad.Operations’ does not export ‘unGrab’.

### X window properties — 4 modules

- `XMonad.Hooks.TaffybarPagerHints` (5) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Hooks.XPropManage` (3) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.DebugWindow` (11) — Not in scope: type constructor or class ‘Atom’
- `XMonad.Util.StringProp` (1) — Not in scope: type constructor or class ‘Atom’

### raw X events — 4 modules

- `XMonad.Actions.UpdateFocus` (3) — Not in scope: data constructor ‘MotionEvent’
- `XMonad.Hooks.Minimize` (3) — Not in scope: data constructor ‘ClientMessageEvent’
- `XMonad.Hooks.ScreenCorners` (1) — Not in scope: data constructor ‘CrossingEvent’
- `XMonad.Hooks.ServerMode` (3) — Not in scope: data constructor ‘ClientMessageEvent’

### Xlib drawing and display — 2 modules

- `XMonad.Actions.TreeSelect` (13) — Not in scope: type constructor or class ‘GC’
- `XMonad.Util.Replace` (27) — Variable not in scope: openDisplay :: String -> IO t21

### root window — 1 modules

- `XMonad.Actions.EasyMotion` (1) — Not in scope: ‘theRoot’

## Skipped modules, by what blocks them

### `XMonad.Hooks.EwmhDesktops` — 11 modules

`XMonad.Actions.ToggleFullFloat`, `XMonad.Actions.WorkspaceNames`, `XMonad.Config.Desktop`, `XMonad.Config.Droundy`, `XMonad.Config.Example`, `XMonad.Config.Gnome`, `XMonad.Config.Kde`, `XMonad.Config.LXQt`, `XMonad.Config.Sjanssen`, `XMonad.Config.Xfce`, `XMonad.Layout.Fullscreen`

### `XMonad.Hooks.FadeInactive` — 3 modules

`XMonad.Config.Saegesser`, `XMonad.Hooks.FadeWindows`, `XMonad.Layout.Monitor`

### `XMonad.Util.Paste` — 2 modules

`XMonad.Actions.KeyRemap`, `XMonad.Actions.Prefix`

### `XMonad.Util.DebugWindow` — 2 modules

`XMonad.Hooks.DebugStack`, `XMonad.Hooks.ManageDebug`

### `XMonad.Actions.MouseResize` — 2 modules

`XMonad.Layout.DecorationMadness`, `XMonad.Layout.SimpleFloat`

### `XMonad.Actions.MouseResize`, `XMonad.Hooks.ServerMode` — 1 modules

`XMonad.Config.Arossato`

### `XMonad.Hooks.EwmhDesktops`, `XMonad.Hooks.Minimize` (+3 more) — 1 modules

`XMonad.Config.Bluetile`

### `XMonad.Hooks.EwmhDesktops`, `XMonad.Util.Ungrab` — 1 modules

`XMonad.Config.Mate`

### `XMonad.Hooks.DebugKeyEvents`, `XMonad.Util.DebugWindow` — 1 modules

`XMonad.Hooks.DebugEvents`

### `XMonad.Util.RemoteWindows` — 1 modules

`XMonad.Layout.Stoppable`

### `XMonad.Hooks.FloatConfigureReq` — 1 modules

`XMonad.Util.Hacks`

