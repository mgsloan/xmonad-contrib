{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses #-}
-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Hooks.ManageDocks
-- Description :  Automatically manage 'dock' type programs.
-- Copyright    : (c) Joachim Breitner <mail@joachim-breitner.de>
-- License      : BSD
--
-- Maintainer   : Joachim Breitner <mail@joachim-breitner.de>
-- Stability    : unstable
-- Portability  : unportable
--
-- This module provides tools to automatically manage 'dock' type programs,
-- such as gnome-panel, kicker, dzen, and xmobar.
--
-- Under river it does none of that, and does not need to.  See $river.

module XMonad.Hooks.ManageDocks (
    -- * Usage
    -- $usage
    docks, manageDocks, checkDock, AvoidStruts(..), avoidStruts, avoidStrutsOn, onAllDocks,
    module XMonad.Util.Types,

    -- * For developers of other modules ("XMonad.Actions.FloatSnap")
    calcGap,

    -- * Standalone hooks (deprecated)
    docksEventHook, docksStartupHook,

    -- * Differences under river
    -- $river
    ) where

import XMonad
import XMonad.Prelude (All (..))
import XMonad.Layout.LayoutModifier
import XMonad.Util.Types

import qualified Data.Set as S

-- $usage
-- To use this module, add 'docks' to your config:
--
-- > main = xmonad $ docks def
--
-- and apply 'avoidStruts' to your layout:
--
-- > layoutHook = avoidStruts (tall ||| Full)
--
-- Both are kept so that a config written for X11 still compiles and still
-- behaves correctly; neither does any work here.  See $river.

-- $river
--
-- This module existed to read @_NET_WM_STRUT@ and @_NET_WM_STRUT_PARTIAL@ off
-- dock windows and shrink the layout area to match.  Under river none of that
-- applies, and the reason is not that the feature is missing but that it has
-- moved:
--
-- * A Wayland panel is a /layer surface/, not a window.  It reserves space
--   with @zwlr_layer_surface_v1.set_exclusive_zone@, and river reports the
--   remainder as @river_layer_shell_output_v1.non_exclusive_area@.
--
-- * The window manager applies that in @syncScreens@, before any layout runs.
--   By the time a layout sees a screen rectangle, the panel has already been
--   subtracted from it.
--
-- So bars and docks stay uncovered without this module, and a config that
-- applies 'avoidStruts' gets the behaviour it asked for -- just from a
-- different place.  The names are kept as no-ops rather than removed because
-- removing them would break every config for no gain: the effect they ask for
-- is what actually happens.
--
-- What is /not/ kept is @ToggleStruts@ and @SetStruts@.  Those asked to change
-- which edges are avoided, and there is nothing here to change: the exclusive
-- zone is negotiated between the panel and the compositor, and a window
-- manager that pretended to toggle it would be lying.  A config sending them
-- fails to compile, which is the point.  "XMonad.Hooks.StatusBar"'s
-- @withEasySB@ and @defToggleStrutsKey@ are gone for the same reason -- their
-- whole purpose was to bind a key to @ToggleStruts@.

-- | Add support for docks.  A no-op; see $river.
docks :: XConfig a -> XConfig a
docks = id

-- | Detects if the given window is of type DOCK and if so, reveals
--   it, but does not manage it.
--
--   Always fails to match here: river does not offer layer surfaces to the
--   window manager as windows at all, so a dock never reaches a manage hook.
manageDocks :: ManageHook
manageDocks = idHook

-- | Checks if a window is a DOCK or DESKTOP window.  Always 'False'; see
-- 'manageDocks'.
checkDock :: Query Bool
checkDock = pure False

-- | Run an action on all dock windows.  There are none; see 'manageDocks'.
onAllDocks :: (Window -> X ()) -> X ()
onAllDocks _ = pure ()

-- | Event hook to handle strut changes.  A no-op; see $river.
docksEventHook :: Event -> X All
docksEventHook _ = pure (All True)

-- | Startup hook to handle strut changes.  A no-op; see $river.
docksStartupHook :: X ()
docksStartupHook = pure ()

-- | Goes through the list of windows and find the gap so that all
--   STRUT settings are satisfied.
--
--   The identity function here.  The screen rectangle a layout is handed has
--   already had the exclusive zone of any layer surface subtracted from it, so
--   there is no further gap to calculate.  Kept because
--   "XMonad.Actions.FloatSnap" asks for it.
calcGap :: S.Set Direction2D -> X (Rectangle -> Rectangle)
calcGap _ = pure id

-- | Adjust layout automagically: don't cover up any docks, status
--   bars, etc.
--
--   Which happens whether or not this is applied; see $river.
avoidStruts :: LayoutClass l a => l a -> ModifiedLayout AvoidStruts l a
avoidStruts = avoidStrutsOn [U,D,L,R]

-- | Adjust layout automagically: don't cover up docks, status bars,
--   etc. on the indicated sides of the screen.
avoidStrutsOn :: LayoutClass l a =>
                 [Direction2D]
              -> l a
              -> ModifiedLayout AvoidStruts l a
avoidStrutsOn ss = ModifiedLayout $ AvoidStruts (S.fromList ss)

-- | The set of edges is retained rather than dropped so that a layout
-- serialised by the X11 build still parses.
newtype AvoidStruts a = AvoidStruts (S.Set Direction2D) deriving ( Read, Show )

instance LayoutModifier AvoidStruts a where
    modifyLayout _ w r = runLayout w r
