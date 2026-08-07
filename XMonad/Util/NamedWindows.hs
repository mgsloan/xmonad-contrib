-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.NamedWindows
-- Description :  Associate the X titles of windows with them.
-- Copyright   :  (c) David Roundy <droundy@darcs.net>
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  none
-- Stability   :  unstable
-- Portability :  unportable
--
-- This module allows you to associate the X titles of windows with
-- them.
--
-----------------------------------------------------------------------------

module XMonad.Util.NamedWindows (
                                   -- * Usage
                                   -- $usage
                                   NamedWindow,
                                   getName,
                                   getNameWMClass,
                                   withNamedWindow,
                                   unName
                                  ) where

import XMonad.Prelude ( (>=>) )

import qualified XMonad.StackSet as W ( peek )


import XMonad
import XMonad.ManageHook (className, title)

-- $usage
-- See "XMonad.Layout.Tabbed" for an example of its use.


data NamedWindow = NW !String !Window
instance Eq NamedWindow where
    (NW s _) == (NW s' _) = s == s'
instance Ord NamedWindow where
    compare (NW s _) (NW s' _) = compare s s'
instance Show NamedWindow where
    show (NW n _) = n

-- | The name a window reports for itself.
--
-- Upstream reads @_NET_WM_NAME@, falling back to @WM_NAME@, falling back to
-- the resource name from the class hint.  All three collapse here, because
-- river reports one title -- and it is the same string: @xdg_toplevel.set_title@
-- is where an X11 client\'s @WM_NAME@ ends up under Xwayland too.
--
-- One consequence of the collapse: nothing distinguishes a client that set no
-- title from one that set an empty string.  Both are @""@.
--
-- The title is accumulated from an event rather than read on demand, so
-- calling this the instant a window appears can return @""@ where the client
-- has simply not sent its title yet.  X11 raced the same way -- a client that
-- had not set @WM_NAME@ yet gave nothing either -- just at a different moment.
getName :: Window -> X NamedWindow
getName w = NW <$> runQuery title w <*> pure w

-- | The name from the window\'s class rather than its title.
--
-- @WM_CLASS@ becomes @app_id@.  Note X11 distinguished the two halves of
-- @WM_CLASS@ -- instance and class -- and Wayland has only the one string, so
-- this and @XMonad.ManageHook.appName@ agree where under X11 they might not.
getNameWMClass :: Window -> X NamedWindow
getNameWMClass w = NW <$> runQuery className w <*> pure w

unName :: NamedWindow -> Window
unName (NW _ w) = w

withNamedWindow :: (NamedWindow -> X ()) -> X ()
withNamedWindow f = do ws <- gets windowset
                       whenJust (W.peek ws) (getName >=> f)
