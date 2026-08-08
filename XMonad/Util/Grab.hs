{-# LANGUAGE LambdaCase #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.Grab
-- Description :  Utilities for grabbing/ungrabbing keys.
-- Copyright   :  (c) 2018  L. S. Leary
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  L. S. Leary
-- Stability   :  unstable
-- Portability :  unportable
--
-- This module should not be directly used by users. Its purpose is to
-- facilitate grabbing and ungrabbing keys.
--------------------------------------------------------------------------------

-- --< Imports & Exports >-- {{{

module XMonad.Util.Grab
  (
 -- * Usage
 -- $Usage
    grab
  , ungrab
  ) where

-- core
import           XMonad
import qualified XMonad.River                  as River

import qualified Data.Map                      as M
-- base

-- }}}

-- --< Usage >-- {{{

-- $Usage
--
-- This module should not be directly used by users. Its purpose is to
-- facilitate grabbing and ungrabbing keys.

-- }}}

-- --< Public Utils >-- {{{

-- | Capture exactly these keys, running the given action for each.
--
-- The river answer to X11's @grabKey@, and it takes a keymap where upstream
-- took a list of keys.  That is forced and it is also better.  Under X11 a
-- grab only routed the key to the window manager, which then looked the action
-- up in its own tables from a @KeyEvent@; river has no @KeyEvent@ to look
-- anything up from -- a key arrives because a binding exists for it, and the
-- binding is where the action lives.  So the action comes with the key.
--
-- Replaces the whole captured set, as upstream's @grab@ did.  See
-- 'XMonad.River.grabKeys' for what that costs and what it does not.
grab :: M.Map (KeyMask, KeySym) (X ()) -> X ()
grab = River.grabKeys

-- | Release everything 'grab' captured, restoring the plain configuration.
ungrab :: X ()
ungrab = River.ungrabKeys

-- Upstream also offers @grabKP@, @ungrabKP@, @grabUngrab@ and
-- @customRegrabEvHook@.  None of them survives, and the reasons differ:
--
-- * @grabKP@ and @ungrabKP@ take a @KeyCode@, which is why callers had to run
--   @mkGrabs@ first.  River binds a keysym directly and this backend never
--   reads the keymap, so there are no keycodes to take.  'grab' is the whole
--   interface.
--
-- * @grabUngrab@ took a set to grab and a set to release.  Releasing
--   individually is meaningless when 'grab' replaces the set outright.
--
-- * @customRegrabEvHook@ re-grabbed after a @MappingNotifyEvent@, X11's
--   "the keymap changed" event.  River does not report keymap changes to the
--   window manager at all, and its bindings are by keysym, so a new layout
--   moves them with it rather than stranding them on old keycodes.  There is
--   nothing to re-grab.

-- }}}
