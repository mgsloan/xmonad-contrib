# Future work

Things known to be wrong or missing, with enough detail to act on without
re-deriving the analysis. Each says where the fix goes: most of these live in
the fork (`../xmonad-river`) rather than here, because the failure is in the
backend that contrib sits on.

*Which* modules do not compile is in [SURVEY.md](SURVEY.md), which is generated
and stays current; §6 below says *why*, once per module, because a generated
first-error line does not distinguish "nobody has done this yet" from "this
cannot be done". Everything before §6 is about things that do compile and are
wrong.

---

## 1. A wedged prompt is still undetectable — NARROWED

**Repo:** `../xmonad-river` — `src-river/XMonad/River/Client.hs`

A prompt is a `zwlr_layer_surface_v1` with `keyboard_interactivity = exclusive`,
so the compositor delivers every keystroke to it for as long as its surface
exists. Three paths used to end the owning thread without destroying the
surface, and each left a session whose keyboard went somewhere nothing was
reading. Those are fixed: `clientMain` tears down under a handler, `csDraw` and
`csOnKey` are caught, and `XMonad/Prompt.hs` closes the client in a `finally`.

**Since closed: a prompt that was never able to read the keyboard at all.**
`watchStartup` gives a client `startupDeadlineMicros` — ten seconds — to become
usable, and closes it with a reason if it has not: the surface was never
configured, the seat has no keyboard, focus was never granted, or the keymap
never arrived. All four are settled within a round trip of the surface being
created, so none of them needs anyone to type; a prompt sitting in front of
someone reading it is untouched, which was the whole objection to a timeout.
Escalation is `Close` first, then `killThread` if the loop does not answer
within a second.

That work turned up a real bug in the same function: `setupKeyboard` called
`wl_seat.get_keyboard` unconditionally, which is a protocol error on a seat with
no keyboard capability, and the compositor answers it by dropping the
connection. A prompt opened before any input device existed died with a raw
`ProtocolError` traceback. It now waits for `wl_seat.capabilities`.

Also closed, and adjacent: `XMonad/Prompt.hs` blocked forever in `readChan` when
its client went away — compositor close, watchdog, or `closeAllPrompts` — so the
prompt thread leaked with its state. `keyChan` now carries `Maybe`, `csOnClose`
writes `Nothing`, and the loop stops with `successful` still `False`, so a
prompt closed out from under the user does not run its action.

**What is still not covered is a thread that is alive but never returns.** A
deadlock, a blocking read that never completes, an infinite loop in a completion
function — the thread exists, so no handler runs, and the grab persists exactly
as before. The startup watchdog does not see it: by then the prompt has proved
it *can* read the keyboard, and the watchdog is a one-shot. Nothing detects it.

### Sketch

Have the client record when it last completed a pass through its loop, and have
the window manager notice when a client holding a keyboard grab has stopped
making progress *while keys are arriving for it*.

Both halves of that condition matter. Elapsed time alone is not evidence: a
prompt waiting for someone to finish reading the screen is idle for minutes and
is working perfectly. What distinguishes wedged from idle is that keystrokes are
being delivered and not consumed.

- Client side: a timestamp bumped at the top of `loop`, and another bumped after
  `csOnKey` returns. Both in the registry that `closeAllClients` already walks,
  so no new plumbing.
- Window manager side: a periodic check — the mailbox loop already wakes on a
  timer-friendly `waitEither`, so this can ride along rather than needing a
  thread. If a client's key-handled timestamp has not moved in N seconds *and*
  its loop timestamp has not either, it is not merely waiting for input.
- On detection: log loudly, then close it. Closing a working prompt by mistake
  is a nuisance; leaving a wedged one is a session.

### Difficulty

The detection rule is the whole problem; the mechanism is easy. Getting it wrong
in the paranoid direction closes prompts people are using, which is worse than
the bug. Consider shipping it in log-only mode first and looking at whether it
ever fires.

### What would prove it

Extend the test in §3 to make the callback block forever rather than throw, and
assert the surface is destroyed anyway.

---

## 2. `mouseDrag` can leave a drag that never ends

**Repo:** `../xmonad-river` — `src-river/XMonad/Operations.hs` (`mouseDrag`),
`src-river/XMonad/River/WM.hs` (`addSeat`, `reapClosed`)

`mouseDrag` records `dragging = Just (motion, cleanup)` in `XState` and the only
thing that clears it is `river_seat_v1.op_release`:

```haskell
RiverSeatV1OpRelease -> do
  riverSeatV1OpEnd conn seat
  queueAction rt $ do
    drag <- gets dragging
    whenJust drag $ \(_, cleanup) -> cleanup
```

If that event never arrives, `dragging` stays `Just` forever. `mouseDrag` opens
with

```haskell
drag <- gets dragging
case drag of
    Just _ -> return () -- already dragging
```

so **every subsequent drag in the session is silently ignored**. Mouse-driven
move and resize stop working, with no error and nothing on screen to explain it.
The only recovery is a restart, and since the symptom is "dragging stopped
working" rather than "something broke", the connection to a drag that ended
badly minutes earlier is not obvious.

Ways `op_release` can fail to arrive:

- the seat is removed mid-drag (`rsRemoved`), which `reapClosed` handles by
  destroying the seat object — without clearing `dragging`;
- the dragged window closes mid-drag;
- any protocol-level unhappiness that makes river drop the operation.

There is a second, smaller bug in the same function: it picks the drag seat with
`M.elems seats` and takes the head **without filtering `rsRemoved`**, so a drag
can be started against a seat that is on its way out.

### Sketch

Cheap and worth doing regardless of the above:

- Clear `dragging` in `reapClosed` when the seat that owns it goes away, running
  `cleanup` so the caller's `done` action still fires. Callers use it to commit
  the float geometry, so skipping it loses the drag rather than merely ending it.
- Filter `rsRemoved` in `mouseDrag`'s seat selection.
- Consider a deadline, as `submapNextKey` now has: a drag that has not seen a
  delta in some generous interval is over, whatever river thinks. Less clearly
  correct than the submap case — a slow drag is real, where an abandoned submap
  is not — so this one may be better left out.

Severity is well below the keyboard case: it degrades one input path rather than
locking the session. But it is the same shape of bug, it is cheap, and the
diagnosis cost is high because the symptom appears long after the cause.

---

## 3. A prompt is now tested against a live river — PARTLY CLOSED

**Repo:** `../xmonad-river` — `tests/headless-prompt.sh`,
`tests/river-prompt-spec.hs`

The guarantee that a prompt cannot leave the keyboard grabbed used to rest on
reading the code. That is exactly how the bug got there: every path *looked*
like it terminated.

`tests/headless-prompt.sh` now starts a headless river with a window manager
beside it and runs `river-prompt-spec` inside, which drives `startClient`
directly. Four cases pass:

- a surface that never asked for a keyboard is not closed by the watchdog;
- a prompt that can never read the keyboard *is* closed, within its deadline;
- a `csDraw` that throws does not take the client down;
- `closeAllClients` closes a client — the escape hatch, fired rather than
  assumed.

River's own log is the independent oracle, as sketched below: the run
fails if `'xmonad-prompt' mapped` is not matched by a `destroyed`.

### What is still missing

**An idle prompt on a seat that has a keyboard.** The false-positive risk the
watchdog introduces is that it closes a working prompt, and the case above only
covers the half of that with `csKeyboard = False`. A headless seat has no
keyboard capability, so the real case cannot be staged: it needs a
`virtual-keyboard-unstable-v1` client to give the seat one, and this repo
generates no bindings for that protocol. The XML is in wlroots and `codegen/`
already knows how to consume one, so this is a contained piece of work rather
than a hard one.

**A callback that blocks forever** (§1) — still nothing to test against.

### The oracle, as designed and as built

River logs, at `-log-level debug`:

```
layer surface 'xmonad-prompt' mapped
layer surface 'xmonad-prompt' destroyed
```

The namespace is set by `clientMain` in `Client.hs`. `mapped` proves the grab was
actually taken — without it the test passes vacuously on a prompt that never
opened, which is the failure mode to design against here. `destroyed` proves it
was released.

### Two things the build of it learned

**The window manager has to be running.** River closes a layer surface whose
namespace no window manager has claimed — `window manager did not bind
river_layer_shell_v1, closing layer surface` — so the first version of the
harness, which ran the spec alone, failed every case for a reason that had
nothing to do with prompts. It starts xmonad beside the spec now.

**Do not try to synthesise input, and do not need to.** The watchdog's checks
are all answerable without a keystroke, which is what makes them testable at
all in a session that has no input device.

---

## 4. GridSelect's interaction model — INVERTED

**Repo:** here — `XMonad/Actions/GridSelect.hs`

Done, along with the twelve modules it gated: `Actions.WindowMenu`,
`Layout.ButtonDecoration`, `Layout.DecorationAddons`,
`Layout.ImageButtonDecoration`, `Layout.WindowSwitcherDecoration` and all of
`DecorationEx`.

What the port amounted to, for anyone converting a config or a similar module:

- `gs_navigate` is now `(KeySym, String, KeyMask) -> TwoD a (Navigation a)` --
  a handler for one key rather than the whole event loop. Keymap entries drop
  their `>> myNavigation` tail and end `>> pure Continue`.
- `Navigation a = Continue | Cancel | Select a` replaces the `Maybe a` that a
  returning loop used to mean. `select` with nothing under the cursor is
  `Cancel`, which is what `Nothing` meant.
- `makeXEventhandler` is gone; `shadowWithKeymap` stays, retyped.
- `substringSearch` is a mode rather than a nested loop: `td_searching` in
  `TwoDState`, which the top-level dispatch consults.
- `gridselect` and `gridselectWindow` take a continuation. Every other public
  wrapper already ended in `X ()` and consumed the result immediately, so their
  signatures did not change.
- `gs_cancelOnEmptyClick` is gone with the clicks; see §5.
- The surface is `startClient` with `csKeyboard = True` and an offscreen pixmap
  replayed by `csDraw`, exactly as `XMonad.Prompt` does it, and `drawWinBox`
  draws through `XMonad.Util.River.Compat` rather than Xlib.

### What is left

**A key event carries no modifier mask.** `csOnKey` reports a keysym and the
text it produces, and `gridselect` passes `0` as the mask, so a keymap entry
qualified by one never fires. That is why the built-in navigations lost their
`(shiftMask, xK_Tab)` bindings. `XMonad.Prompt` has the same gap, and its vim
keymaps are full of `shiftMask` entries that quietly do not work, which is the
more serious case.

The information exists: `XMonad.River.Client` tracks modifiers on the xkb
state -- it has to, or the keysym translation would be wrong -- and simply does
not pass them on. The fix is to widen `csOnKey` to take a mask, and to
translate xkb's modifier indices into xmonad's `KeyMask` bits with
`xkb_state_mod_name_is_active` against `"Shift"`, `"Control"`, `"Mod1"` and
`"Mod4"`. The indices are keymap-dependent, so it has to be by name.

**No test drives it.** It takes an exclusive keyboard grab, so §1 and §3 apply
to it exactly as they do to a prompt: a `gs_colorizer` or a custom navigation
that throws leaves the grab held. `gridselect` closes the client from a
single-shot `finish`, which covers the paths that end normally, but nothing
detects a handler that hangs.

## 5. Smaller things

- **`XMonad.Layout.Decoration` clicks do nothing.** `handleMouseFocusDrag` is a
  `warnUnimplemented`: river reports button presses against a `river_window_v1`,
  and a decoration is a surface the window manager drew, so river attributes the
  click to no window. Closing this needs the pointer position at the moment of
  press — `river_seat_v1.pointer_position` has the position but is motion, and
  `river_pointer_binding_v1.pressed` is the press but carries no position.
  Correlating them is guesswork. It gates title-bar dragging and every button
  widget in `ButtonDecoration` and `DecorationEx` -- both of which now compile
  and draw, so this is the whole of what is missing from them.
  `DecorationEx.Engine`'s own `handleMouseFocusDrag` is the same
  `warnUnimplemented`, and `GridSelect` lost `gs_cancelOnEmptyClick` to it.

- **`XMonad.Hooks.UrgencyHook` has no input path.** Only `askUrgent` and
  `doAskUrgent` can mark a window urgent; a window cannot mark itself. Wayland's
  equivalent of the `WM_HINTS` urgency flag is `xdg-activation-v1`, which river
  implements — but `handleRequestActivate` does nothing for a window, with the
  comment `TODO support xdg-activation with a rwm extension protocol`. When river
  grows that, the fix here is one event handler calling `markUrgent`.

- **Submap deadline is a fixed 60s.** `submapDeadlineMicros` in
  `src-river/XMonad/River.hs`. Fine for chords, arguably wrong for a config using
  a submap as a mode. Making it configurable means threading it through
  `XMonad.Actions.Submap`, which currently has no place to put it.

---

## 6. The 25 modules that still do not compile

One line each for every module SURVEY.md lists as failing, grouped by what
would have to change. The point of the grouping is that most of these are not
independent pieces of work: five are waiting on two capabilities. `EwmhDesktops`
is the largest single lever left, gating eleven further modules.

### Waiting on a capability river could plausibly grow — 5 modules

**Button presses on a window-manager surface** — §5's decoration problem, in
its other clothes. These modules create a surface, or an X11 input-only window,
and expect clicks on it.

- `XMonad.Actions.MouseResize`, `XMonad.Layout.BorderResize`,
  `XMonad.Layout.MouseResizableTile` — resize handles. All three additionally
  need `mkInputWindow`: an override-redirect input-only window, which has no
  Wayland counterpart at all, so even a solved click problem leaves them with
  nowhere to receive it. `XMonad.Layout.Decoration`'s surfaces are the nearest
  thing and are what a port would have to be rebuilt on.

**A drawing surface plus an inverted key loop.** §4 did this for `GridSelect`;
these two are the same shape and can follow the same path.

- `XMonad.Actions.EasyMotion` — same shape, one step harder: it grabs the
  keyboard and draws overlay windows on the root. The overlays can be
  window-manager surfaces as GridSelect's grid can, and the loop inverts the
  same way, but there is no root to draw the fallback on.
- `XMonad.Actions.TreeSelect` — same shape again, and it draws through Xlib and
  Xft directly rather than through `XMonad.Util.Font`, so its drawing code has
  to move onto `XMonad.Util.River.Compat` first.

### No Wayland counterpart, and no prospect of one — 19 modules

Not "unfinished". Each of these is *about* a piece of X11 that Wayland does not
have, so there is nothing to port them onto. They stay in the tree, disabled,
because upstream owns them and a rebase should not have to think about them.

**X properties as a public data channel.** A window's properties were readable
and writable by any client, which made them an IPC mechanism as much as a
description. Wayland has nothing of the kind — a compositor tells a client what
it needs to know and clients do not read each other's state.

- `XMonad.Util.StringProp`, `XMonad.Hooks.XPropManage`,
  `XMonad.Util.DebugWindow` — read or write arbitrary properties.
- `XMonad.Hooks.EwmhDesktops`, `XMonad.Hooks.TaffybarPagerHints` — publish the
  EWMH desktop/pager hints. `EwmhDesktops` gates eleven further modules,
  second only to `GridSelect`, and none of that is recoverable: the hints are
  the interface, and no Wayland panel reads them.
- `XMonad.Util.NoTaskbar` — sets `_NET_WM_STATE_SKIP_TASKBAR`.
- `XMonad.Hooks.FadeInactive` — sets `_NET_WM_WINDOW_OPACITY`, a convention
  between an X client and a compositing manager. River composites and offers
  the window manager no say in per-window opacity.
- `XMonad.Util.RemoteWindows` — decides whether a window is local by comparing
  `WM_CLIENT_MACHINE` against the hostname. Wayland has no network transparency
  to detect.
- `XMonad.Hooks.Qubes` — reads the `_QUBES_*` properties the Qubes GUI daemon
  sets on X windows. It is a port of Qubes' X integration, and would have to be
  rewritten against whatever Qubes does for Wayland.

**Clients talking to the window manager.** X11 let a client send the window
manager a message and let the window manager veto a client's own requests.
River is the only thing clients talk to.

- `XMonad.Hooks.ServerMode` — treats client messages as a command channel;
  `xmonadctl` is its client.
- `XMonad.Hooks.Minimize` — acts on a client's request to be iconified.
- `XMonad.Hooks.FloatConfigureReq` — intercepts a client's `ConfigureRequest`.
  River's `pointer_move_requested` / `pointer_resize_requested` are the
  client-initiated half of this and are unexercised (see the repo's `GAPS.md`),
  so there may be something here eventually, but not this module's shape.
- `XMonad.Util.Paste` — synthesises key events and sends them to a window.
  Wayland has no way to inject input; that is the point of its input model.

**Pointer crossing.** X11 reported the pointer entering and leaving each window
and let the window manager act on it. River settles focus-follows-mouse itself
and reports the result, so there is no crossing to intercept and nothing to
override.

- `XMonad.Actions.UpdateFocus`, `XMonad.Hooks.ScreenCorners`. The same wall
  took `promoteWarp` and `followOnlyIf` out of `XMonad.Layout.MagicFocus`,
  which otherwise compiles.

**Other.**

- `XMonad.Util.Ungrab` — a one-name re-export of `unGrab`, which
  `tests/api/unportable.txt` withholds deliberately: succeeding silently would
  be true about grabs and false about handing the keyboard to a screen locker.
  Deprecated upstream in any case.
- `XMonad.Util.Replace` — takes the `WM_S<n>` selection from a running X11
  window manager. River permits one window manager and answers a second with
  `unavailable`; there is no selection to steal.
- `XMonad.Hooks.DebugKeyEvents` — dumps the fields of an `XKeyEvent`.
- `XMonad.Hooks.DynamicBars` — driven by XRandR screen-change notifications.
  `XMonad.Hooks.Rescreen` is the ported equivalent of the mechanism and is what
  a rewrite would sit on, but the module's interface is XRandR's.

### Not about river at all — 1 module

- `XMonad.Config.Monad` — needs the `data-accessor` package, which is not in
  the resolver. It does not build against upstream xmonad here either.
