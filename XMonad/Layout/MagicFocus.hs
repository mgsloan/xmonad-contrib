{-# LANGUAGE FlexibleContexts, FlexibleInstances, MultiParamTypeClasses #-}

-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Layout.MagicFocus
-- Description :  Automagically put the focused window in the master area.
-- Copyright    : (c) Peter De Wachter <pdewacht@gmail.com>
-- License      : BSD
--
-- Maintainer   : Peter De Wachter <pdewacht@gmail.com>
-- Stability    : unstable
-- Portability  : unportable
--
-- Automagically put the focused window in the master area.
-----------------------------------------------------------------------------

module XMonad.Layout.MagicFocus
    (-- * Usage
     -- $usage
     magicFocus,
     disableFollowOnWS,
     MagicFocus,
    ) where

import XMonad
import qualified XMonad.StackSet as W
import XMonad.Layout.LayoutModifier

import XMonad.Actions.UpdatePointer (updatePointer)
import XMonad.Prelude(All(..))
import qualified Data.Map as M

-- $usage
-- You can use this module with the following in your @xmonad.hs@:
--
-- > import XMonad.Layout.MagicFocus
--
-- Then edit your @layoutHook@ by adding the magicFocus layout
-- modifier:
--
-- > myLayout = magicFocus (Tall 1 (3/100) (1/2)) ||| Full ||| etc..
-- > main = xmonad def { layoutHook = myLayout }
--
-- For more detailed instructions on editing the layoutHook see
-- <https://xmonad.org/TUTORIAL.html#customizing-xmonad the tutorial> and
-- "XMonad.Doc.Extending#Editing_the_layout_hook".

-- | Create a new layout which automagically puts the focused window
--   in the master area.
magicFocus :: l a -> ModifiedLayout MagicFocus l a
magicFocus = ModifiedLayout MagicFocus

data MagicFocus a = MagicFocus deriving (Show, Read)

instance LayoutModifier MagicFocus Window where
  modifyLayout MagicFocus (W.Workspace i l s) =
    runLayout (W.Workspace i l (s >>= Just . shift))

shift :: (Eq a) => W.Stack a -> W.Stack a
shift (W.Stack f u d) = W.Stack f [] (reverse u ++ d)

-- | An eventHook that overrides the normal focusFollowsMouse. When the mouse
-- it moved to another window, that window is replaced as the master, and the
-- mouse is warped to inside the new master.
--
-- It prevents infinite loops when focusFollowsMouse is true (the default), and
-- MagicFocus is in use when changing focus with the mouse.
--
-- This eventHook does nothing when there are floating windows on the current
-- workspace.
-- Upstream also offers @promoteWarp@, @promoteWarp'@ and @followOnlyIf@, three
-- event hooks that all key off the pointer entering a window -- X11's
-- @EnterNotify@.  River sends no such event.  Focus-follows-mouse is settled
-- by the compositor and reported to the window manager as a focus that has
-- already happened, so there is no crossing for a hook to intercept and
-- nothing for one to override.  'disableFollowOnWS' is kept because it is just
-- a predicate on the current workspace, and stays useful for anything else
-- that wants to ask the question.

-- | Disables focusFollow on the given workspaces:
disableFollowOnWS :: [WorkspaceId] -> X Bool
disableFollowOnWS wses = (`notElem` wses) <$> gets (W.currentTag . windowset)
