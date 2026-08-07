{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE RecordWildCards #-}
-- |
-- Module      :  XMonad.Hooks.Rescreen
-- Description :  Custom hooks for screen (xrandr) configuration changes.
-- Copyright   :  (c) 2021 Tomáš Janoušek <tomi@nomi.cz>
-- License     :  BSD3
-- Maintainer  :  Tomáš Janoušek <tomi@nomi.cz>
--
-- Custom hooks for screen (xrandr) configuration changes.
--
module XMonad.Hooks.Rescreen (
    -- * Usage
    -- $usage
    addAfterRescreenHook,
    addRandrChangeHook,
    setRescreenWorkspacesHook,
    RescreenConfig(..),
    rescreenHook,

    -- * Differences under river
    -- $river
    ) where

import XMonad
import XMonad.Prelude
import qualified XMonad.Util.ExtensibleConf as XC

-- $usage
-- This module provides a replacement for the screen configuration change
-- handling in core that enables attaching custom hooks to screen (xrandr)
-- configuration change events. These can be used to restart/reposition status
-- bars or systrays automatically after xrandr
-- ('XMonad.Hooks.StatusBar.dynamicSBs' uses this module internally), as well
-- as to actually invoke xrandr or autorandr when an output is (dis)connected.
--
-- To use this, include the following in your @xmonad.hs@:
--
-- > import XMonad.Hooks.Rescreen
--
-- define your custom hooks:
--
-- > myAfterRescreenHook :: X ()
-- > myAfterRescreenHook = spawn "fbsetroot -solid red"
--
-- > myRandrChangeHook :: X ()
-- > myRandrChangeHook = spawn "autorandr --change"
--
-- and hook them into your 'xmonad' config:
--
-- > main = xmonad $ …
-- >               . addAfterRescreenHook myAfterRescreenHook
-- >               . addRandrChangeHook myRandrChangeHook
-- >               . …
-- >               $ def{…}
--
-- See documentation of 'rescreenHook' for details about when these hooks are
-- called.

-- | Hook configuration for 'rescreenHook'.
data RescreenConfig = RescreenConfig
    { afterRescreenHook :: X () -- ^ hook to invoke after 'rescreen'
    , randrChangeHook :: X () -- ^ hook for other randr changes, e.g. (dis)connects
    , rescreenWorkspacesHook :: Last (X ()) -- ^ hook to invoke instead of 'rescreen'
    }

instance Default RescreenConfig where
    def = RescreenConfig
        { afterRescreenHook = mempty
        , randrChangeHook = mempty
        , rescreenWorkspacesHook = mempty
        }

instance Semigroup RescreenConfig where
    RescreenConfig arh rch rwh <> RescreenConfig arh' rch' rwh' =
        RescreenConfig (arh <> arh') (rch <> rch') (rwh <> rwh')

instance Monoid RescreenConfig where
    mempty = def

-- | Attach custom hooks to screen (xrandr) configuration change events.
-- Replaces the built-in rescreen handling of xmonad core with:
--
-- 1. listen to 'RRScreenChangeNotifyEvent' in addition to 'ConfigureEvent' on
--    the root window
-- 2. whenever such event is received:
-- 3. clear any other similar events (Xorg server emits them in bunches)
-- 4. if any event was 'ConfigureEvent', 'rescreen' and invoke 'afterRescreenHook'
-- 5. if there was no 'ConfigureEvent', invoke 'randrChangeHook' only
--
-- 'afterRescreenHook' is useful for restarting/repositioning status bars and
-- systray.
--
-- 'randrChangeHook' may be used to automatically trigger xrandr (or perhaps
-- autorandr) when outputs are (dis)connected.
--
-- 'rescreenWorkspacesHook' allows tweaking the 'rescreen' implementation,
-- to change the order workspaces are assigned to physical screens for
-- example.
--
-- 'rescreenDelay' makes xmonad wait a bit for events to settle (after the
-- first event is received) — useful when multiple @xrandr@ invocations are
-- being used to change the screen layout.
--
-- Note that 'rescreenHook' is safe to use several times, 'rescreen' is still
-- done just once and hooks are invoked in sequence (except
-- 'rescreenWorkspacesHook', which has a replace rather than sequence
-- semantics), also just once.
rescreenHook :: RescreenConfig -> XConfig l -> XConfig l
rescreenHook = XC.once hook . catchUserCode
  where
    hook c = c
        { startupHook = startupHook c <> rescreenStartupHook
        , handleEventHook = handleEventHook c <> rescreenEventHook }
    catchUserCode rc@RescreenConfig{..} = rc
        { afterRescreenHook = userCodeDef () afterRescreenHook
        , randrChangeHook = userCodeDef () randrChangeHook
        , rescreenWorkspacesHook = flip catchX rescreen <$> rescreenWorkspacesHook
        }

-- | Shortcut for 'rescreenHook'.
addAfterRescreenHook :: X () -> XConfig l -> XConfig l
addAfterRescreenHook h = rescreenHook def{ afterRescreenHook = h }

-- | Shortcut for 'rescreenHook'.
addRandrChangeHook :: X () -> XConfig l -> XConfig l
addRandrChangeHook h = rescreenHook def{ randrChangeHook = h }

-- | Shortcut for 'rescreenHook'.
setRescreenWorkspacesHook :: X () -> XConfig l -> XConfig l
setRescreenWorkspacesHook h = rescreenHook def{ rescreenWorkspacesHook = pure h }

-- | Startup hook.  Nothing to select: river reports output changes to every
-- window manager, there being no event mask to ask for them with.
rescreenStartupHook :: X ()
rescreenStartupHook = mempty

-- | Event hook with custom rescreen\/randr hooks. See 'rescreenHook' for more.
rescreenEventHook :: Event -> X All
rescreenEventHook = \case
    ScreenLayoutChanged -> All False <$ XC.with layoutChanged
    OutputAdded _       -> All False <$ XC.with randrChangeHook
    OutputRemoved _     -> All False <$ XC.with randrChangeHook
    _                   -> mempty
  where
    layoutChanged RescreenConfig{..} =
        fromMaybe rescreen (getLast rescreenWorkspacesHook) >> afterRescreenHook

-- $river
--
-- The hooks are the same; what triggers them is not, and it is simpler.
--
-- X11 gave a window manager two overlapping signals -- @ConfigureNotify@ on
-- the root window and @RRScreenChangeNotify@ -- emitted in bursts, and left it
-- to work out which meant "the screen layout changed" and which meant "a
-- monitor was plugged in".  That is what this module was for.  river reports
-- outputs directly, so the two questions have two separate answers:
--
-- * 'afterRescreenHook' and 'rescreenWorkspacesHook' run on
--   'ScreenLayoutChanged', which the window manager sends only when the screen
--   rectangles genuinely differ from what the 'WindowSet' already had.
--
-- * 'randrChangeHook' runs on @OutputAdded@ and @OutputRemoved@ -- an output
--   appearing or going away, whether or not the layout changed as a result.
--
-- @setRescreenDelay@ and the @rescreenDelay@ field are gone.  They existed to
-- wait out Xorg\'s duplicate events; there is no burst to wait out, and the
-- delay was a @threadDelay@ on the thread that owns the compositor connection,
-- which here would stall the whole window manager.
