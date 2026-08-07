-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Hooks.SetWMName
-- Description :  Set the WM name to a given string.
-- Copyright   :  © 2007 Ivan Tarasov <Ivan.Tarasov@gmail.com>
-- License     :  BSD
--
-- Maintainer  :  Ivan.Tarasov@gmail.com
-- Stability   :  experimental
-- Portability :  unportable
--
-- Sets the WM name to a given string, so that it could be detected using
-- _NET_SUPPORTING_WM_CHECK protocol.
--
-- May be useful for making Java GUI programs work, just set WM name to \"LG3D\"
-- and use Java 1.6u1 (1.6.0_01-ea-b03 works for me) or later.
--
-- To your @xmonad.hs@ file, add the following line:
--
-- > import XMonad.Hooks.SetWMName
--
-- Then edit your @startupHook@:
--
-- > startupHook = setWMName "LG3D"
--
-- For details on the problems with running Java GUI programs in non-reparenting
-- WMs, see <http://bugs.sun.com/bugdatabase/view_bug.do?bug_id=6429775> and
-- related bugs.
--
-- Setting WM name to "compiz" does not solve the problem, because of yet
-- another bug in AWT code (related to insets). For LG3D insets are explicitly
-- set to 0, while for other WMs the insets are \"guessed\" and the algorithm
-- fails miserably by guessing absolutely bogus values.
--
-- For detailed instructions on editing your hooks, see
-- <https://xmonad.org/TUTORIAL.html the tutorial> and "XMonad.Doc.Extending".
-----------------------------------------------------------------------------

module XMonad.Hooks.SetWMName (
      setWMName
    , getWMName
    )
  where

import XMonad

-- $river
--
-- __Both of these do nothing under river, and cannot do anything.__
--
-- This module exists to work around a bug in Java's AWT.  A non-reparenting
-- window manager made AWT guess window insets, and it guessed absurdly; naming
-- the window manager @LG3D@ made AWT take a path where the insets are
-- hard-coded to zero.  The naming was done by putting
-- @_NET_SUPPORTING_WM_CHECK@ and @_NET_WM_NAME@ on the root window, and on a
-- 1x1 override-redirect window created for the purpose.
--
-- None of that has a counterpart here.  There is no root window, no window
-- properties, no @_NET_@ anything -- EWMH is an X11 protocol built on root
-- window properties, and river has neither.  Nor is there anyone to read it:
-- a Java program on a Wayland session either speaks Wayland, in which case it
-- never asks, or runs under XWayland, whose root window belongs to XWayland's
-- own window manager and not to this process.
--
-- They are kept, rather than removed, because the alternative helps nobody.
-- Removing them would break every config that carries @setWMName \"LG3D\"@ in
-- its startup hook -- which is most configs that ever needed it, since the
-- line is harmless to leave in -- and the breakage would be at a call site
-- whose author would then have to discover all of the above.  The deprecation
-- says it at the call site instead, at compile time, and the config keeps
-- building.

-- | Set the window manager name.  A no-op; see the module description.
setWMName :: String -> X ()
setWMName _ = pure ()
{-# DEPRECATED setWMName
      "Does nothing under river: there is no root window to name, and no \
      \Java AWT reading it. Safe to delete." #-}

-- | Get the window manager name.
--
-- Always @\"\"@.  There is nothing storing a name to return, and inventing one
-- so that @setWMName x >> getWMName@ appears to round-trip would be a lie
-- about state that does not exist.
getWMName :: X String
getWMName = pure ""
{-# DEPRECATED getWMName
      "Does nothing under river and always returns \"\". See setWMName." #-}
