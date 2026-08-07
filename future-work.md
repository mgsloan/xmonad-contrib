# Future work

Things known to be wrong or missing, with enough detail to act on without
re-deriving the analysis. Each says where the fix goes: most of these live in
the fork (`../xmonad-river`) rather than here, because the failure is in the
backend that contrib sits on.

For what does not yet *compile*, see [SURVEY.md](SURVEY.md), which is generated
and stays current. This file is for things that compile and are wrong.

---

## 1. A wedged prompt is still undetectable

**Repo:** `../xmonad-river` — `src-river/XMonad/River/Client.hs`

A prompt is a `zwlr_layer_surface_v1` with `keyboard_interactivity = exclusive`,
so the compositor delivers every keystroke to it for as long as its surface
exists. Three paths used to end the owning thread without destroying the
surface, and each left a session whose keyboard went somewhere nothing was
reading. Those are fixed: `clientMain` tears down under a handler, `csDraw` and
`csOnKey` are caught, and `XMonad/Prompt.hs` closes the client in a `finally`.

**What is not covered is a thread that is alive but never returns.** A deadlock,
a blocking read that never completes, an infinite loop in a completion function
— the thread exists, so no handler runs, and the grab persists exactly as
before. Nothing detects it.

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

## 3. No test kills a prompt mid-flight

**Repo:** `../xmonad-river` — `tests/`

The guarantee that a prompt cannot leave the keyboard grabbed currently rests on
reading the code. That is exactly how the bug got there: every path *looked*
like it terminated. A test that actually kills a client and observes the
compositor is the only thing that would have caught it, and the only thing that
will catch its return.

### The oracle

River logs, at `-log-level debug`:

```
layer surface 'xmonad-prompt' mapped
layer surface 'xmonad-prompt' destroyed
```

The namespace is set by `clientMain` in `Client.hs`. `mapped` proves the grab was
actually taken — without it the test passes vacuously on a prompt that never
opened, which is the failure mode to design against here. `destroyed` proves it
was released.

### Shape

`tests/headless-river.sh` and `tests/headless-restart.sh` already set up river on
a headless backend; this needs the same scaffolding and a different payload.

The awkward part is that a prompt is normally opened by a keybinding, and there
is no input in a headless session. Do not try to synthesise input. Instead write
a small test executable that links the library and drives `startClient`
directly:

1. `startClient` with `csKeyboard = True`; wait for `mapped` in river's log.
2. Break it, one case per run:
   - `csDraw` throws;
   - `csOnKey` throws — needs a key, so possibly skip;
   - `killThread` on the client thread (what `closeAllClients` does);
   - the callback blocks forever (§1; expected to fail until that is built).
3. Assert `destroyed` follows within a few seconds.

Case 3 is worth having even though `closeAllClients` is the mechanism being
tested rather than an accident: it is the escape hatch, and an escape hatch that
has never been fired is a guess.

A second, cruder check worth adding to the existing harness: assert that
`'xmonad-prompt' mapped` is never left without a matching `destroyed` at the end
of any run. That costs nothing and covers prompts opened incidentally by other
tests.

---

## 4. Smaller things

- **`XMonad.Layout.Decoration` clicks do nothing.** `handleMouseFocusDrag` is a
  `warnUnimplemented`: river reports button presses against a `river_window_v1`,
  and a decoration is a surface the window manager drew, so river attributes the
  click to no window. Closing this needs the pointer position at the moment of
  press — `river_seat_v1.pointer_position` has the position but is motion, and
  `river_pointer_binding_v1.pressed` is the press but carries no position.
  Correlating them is guesswork. It gates title-bar dragging and every button
  widget in `ButtonDecoration` and `DecorationEx`.

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
