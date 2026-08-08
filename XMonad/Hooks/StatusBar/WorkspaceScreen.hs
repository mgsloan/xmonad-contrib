{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TypeApplications #-}

{- |
 Module      :  XMonad.Hooks.StatusBar.WorkspaceScreen
 Description :  Combine workspace names with screen information
 Copyright   :  (c) Yecine Megdiche <yecine.megdiche@gmail.com>
 License     :  BSD3-style (see LICENSE)

 Maintainer  :  Yecine Megdiche <yecine.megdiche@gmail.com>
 Stability   :  unstable
 Portability :  unportable

 In multi-head setup, it might be useful to have screen information of the
 visible workspaces combined with the workspace name, for example in a status
 bar. This module provides utility functions to do just that.
-}
module XMonad.Hooks.StatusBar.WorkspaceScreen
    (
    -- * Usage
    -- $usage
      combineWithScreen
    , combineWithScreenNumber
    , WorkspaceScreenCombiner
    -- * Limitations
    -- $limitations
    ) where

import           XMonad
import           XMonad.Hooks.StatusBar.PP
import           XMonad.Prelude
import qualified XMonad.StackSet               as W

{- $usage
 You can use this module with the following in your @xmonad.hs@:

 > import XMonad
 > import XMonad.Hooks.StatusBar
 > import XMonad.Hooks.StatusBar.PP
 > import XMonad.Hooks.StatusBar.WorkspaceScreen

 For example, to add the screen number in parentheses to each visible
 workspace number, you can use 'combineWithScreenNumber':

 > myWorkspaceScreenCombiner :: WorkspaceId -> String -> String
 > myWorkspaceScreenCombiner w sc = w <> wrap "(" ")" sc
 >
 > main = do
 >   mySB <- statusBarPipe "xmobar" (combineWithScreenNumber myWorkspaceScreenCombiner xmobarPP)
 >   xmonad $ withSB mySB def

 This will annotate the workspace names as following:

 > [1(0)] 2 3 4 <5(1)> 6 7 8 9

 For advanced cases, use 'combineWithScreen'.
-}

{- $limitations
 For simplicity, this module assumes xmonad screen ids match screen/monitor
 numbers as managed by the X server (for example, as given by @xrandr
 --listactivemonitors@). Thus, it may not work well when screens show an
 overlapping range of the framebuffer, e.g. when using a projector. This also
 means that it doesn't work with "XMonad.Layout.LayoutScreens".
 (This isn't difficult to fix, PRs welcome.)
-}

-- | Type synonym for a function that combines a workspace name with a screen.
type WorkspaceScreenCombiner = WorkspaceId -> WindowScreen -> String

-- Upstream also offers @combineWithScreenName@, which annotates a workspace
-- with its output's name -- @eDP-1@, @HDMI-1@ -- read from XRandR's monitor
-- list.  River's window management protocol does not report output names: an
-- output is a @river_output_v1@ with a position and a size, and the name lives
-- on the @wl_output@ this backend does not bind.  So only the screen number is
-- available, and only 'combineWithScreenNumber' is here.

-- | Combine a workspace name with the screen number it's visible on.
combineWithScreenNumber :: (WorkspaceId -> String -> String) -> PP -> X PP
combineWithScreenNumber c =
    combineWithScreen . return $ \w sc -> c w (show @Int . fi . W.screen $ sc)

-- | Combine a workspace name with a screen according to the given
-- 'WorkspaceScreenCombiner'.
combineWithScreen :: X WorkspaceScreenCombiner -> PP -> X PP
combineWithScreen xCombiner pp = do
    combiner <- xCombiner
    ss       <- withWindowSet (return . W.screens)
    return $ pp
        { ppRename = ppRename pp <=< \s w ->
            maybe s (combiner s) (find ((== W.tag w) . W.tag . W.workspace) ss)
        }
