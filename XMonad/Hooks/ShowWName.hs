{-# LANGUAGE InstanceSigs #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Hooks.ShowWName
-- Description :  Like 'XMonad.Layout.ShowWName', but as a logHook
-- Copyright   :  (c) 2022  Tony Zorman
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  Tony Zorman <soliditsallgood@mailbox.org>
--
-- Flash the names of workspaces name when switching to them.  This is a
-- reimplementation of "XMonad.Layout.ShowWName" as a logHook.
-----------------------------------------------------------------------------

module XMonad.Hooks.ShowWName (
  -- * Usage
  -- $usage
  showWNameLogHook,
  SWNConfig(..),
  flashName,
) where

import qualified XMonad.StackSet             as W
import qualified XMonad.Util.ExtensibleState as XS

import XMonad
import XMonad.Layout.ShowWName (SWNConfig (..))
import XMonad.Prelude
import XMonad.River (postAction)
import XMonad.Util.XUtils (WindowConfig (..), deleteWindow, showSimpleWindow)

import Control.Concurrent (forkIO, threadDelay)

{- $usage

You can use this module with the following in your
@xmonad.hs@:

> import XMonad.Hooks.ShowWName
>
> main :: IO ()
> main = xmonad $ def
>   { logHook = showWNameLogHook def
>   }

Whenever a workspace gains focus, the above logHook will flash its name.
You can customise the duration of the flash, as well as colours by
customising the 'SWNConfig' argument that 'showWNameLogHook' takes.

Alternatively, you can also bind 'flashName' to a key and manually
invoke it when you want to know which workspace you are on.
-}

-- | LogHook for flashing the name of a workspace upon entering it.
showWNameLogHook :: SWNConfig -> X ()
showWNameLogHook cfg = do
  LastShown s <- XS.get
  foc         <- withWindowSet (pure . W.currentTag)
  unless (s == foc) $ do
    flashName cfg
    XS.put (LastShown foc)

-- | Flash the name of the currently focused workspace.
--
-- The X11 version forked a process, opened a /second/ connection to the server
-- from it, slept, and destroyed the window through that connection.  There is
-- no second connection to open here -- river permits one window manager -- and
-- the surface belongs to this one.  So the wait happens on a thread and the
-- destruction is posted back to the event loop, which is the only thing
-- allowed to touch the connection.  See 'XMonad.River.postAction'.
flashName :: SWNConfig -> X ()
flashName cfg = do
  n <- withWindowSet (pure . W.currentTag)
  w <- showSimpleWindow cfg' [n]
  c <- ask
  void . io . forkIO $ do
    threadDelay (fromEnum $ swn_fade cfg * 1000000) -- 1_000_000 needs GHC 8.6.x and up
    postAction c (deleteWindow w)
 where
  cfg' :: WindowConfig
  cfg' = def{ winFont = swn_font cfg, winBg = swn_bgcolor cfg, winFg = swn_color cfg }

-- | Last shown workspace.
newtype LastShown = LastShown WorkspaceId
  deriving (Show, Read)

instance ExtensionClass LastShown where
  initialValue :: LastShown
  initialValue  = LastShown ""

  extensionType :: LastShown -> StateExtension
  extensionType = PersistentExtension
