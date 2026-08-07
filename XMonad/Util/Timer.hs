{-# LANGUAGE MultiWayIf #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.Timer
-- Description :  A module for setting up timers.
-- Copyright   :  (c) 2009 Andrea Rossato
-- License     :  BSD-style (see xmonad/LICENSE)
--
-- Maintainer  :  andrea.rossato@unibz.it
-- Stability   :  unstable
-- Portability :  unportable
--
-- The river implementation.  Signatures are upstream's; the wakeup mechanism
-- is not, because X11's is not available.
--
-- Upstream forks a thread, sleeps, and then posts a client message to the root
-- window.  Nothing in that is an X /timer/ -- the X server times nothing, and
-- @threadDelay@ does the waiting.  What X11 supplied was the last step: any
-- process could post an event to the root window, and the window manager's
-- loop was already reading that socket, so a background thread had a way in
-- for free.
--
-- Wayland has no such relay: the compositor will not carry messages between a
-- window manager and its own threads.  So the channel is ours --
-- "XMonad.River.Mailbox" -- and 'startTimer' posts to it instead.  The
-- structure is otherwise identical, including that the fork-and-sleep is still
-- what measures the time.
--
-----------------------------------------------------------------------------

module XMonad.Util.Timer
    ( -- * Usage
      -- $usage
      startTimer
    , handleTimer
    , TimerId
    ) where

import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (void)
import Data.Unique
import XMonad
import XMonad.River (postAction)

-- $usage
-- See "XMonad.Layout.ShowWName" or "XMonad.Actions.ShowText" for usage examples.

-- | A unique identifier for a timer, so that a handler can tell its own timer
-- from somebody else's.
type TimerId = Int

-- | Start a timer, returning its id.
--
-- The thread is plain 'forkIO' rather than xmonad's 'xfork': there is no
-- separate process here to reset signal handlers in, and the whole point is to
-- come back to /this/ process's event loop.
startTimer :: Rational -> X TimerId
startTimer s = do
  c <- ask
  io $ do
    u <- hashUnique <$> newUnique
    void . forkIO $ do
      threadDelay (fromEnum $ s * 1000000)
      postAction c (broadcastMessage (TimerFired u))
    pure u

-- | Run an action if the event is this timer expiring.
--
-- Upstream matches a @ClientMessageEvent@ carrying the id.  River's event type
-- carries a constructor for it instead, which is the same thing without the
-- atom interning: a message the window manager sends itself.
handleTimer :: TimerId -> Event -> X (Maybe a) -> X (Maybe a)
handleTimer ti (TimerFired u) action
  | u == ti = action
handleTimer _ _ _ = return Nothing
