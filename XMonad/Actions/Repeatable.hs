{-# LANGUAGE BlockArguments, LambdaCase, MultiWayIf #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.Repeatable
-- Description :  Actions you'd like to repeat.
-- Copyright   :  (c) 2022,2026 L. S. Leary
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  L.S.Leary.II@gmail.com
-- Stability   :  unstable
-- Portability :  unportable
--
-- This module factors out the shared logic of "XMonad.Actions.CycleRecentWS",
-- "XMonad.Actions.CycleWorkspaceByScreen", "XMonad.Actions.CycleWindows" and
-- "XMonad.Actions.MostRecentlyUsed".
--
-- See the source of these modules for usage examples.
--
-- These do not block under river, and so cannot return a value.  See $river.
--
-----------------------------------------------------------------------------

module XMonad.Actions.Repeatable (

  -- * Repeatable
  repeatable,
  repeatableSt,
  repeatableM,

  -- * Concludable
  NotOurEvent(..),
  Done(..),
  concludable,
  concludableSt,
  concludableM,

  -- * Differences under river
  -- $river

) where

-- base
import Data.IORef (newIORef, readIORef, writeIORef)

-- mtl
import Control.Monad.State (StateT(..))

-- xmonad
import XMonad
import XMonad.River (whileModifiersHeld)

-- $river
--
-- __These do not block, and so none of them returns a value.__
--
-- Under X11 this module grabbed the keyboard and sat in @maskEvent@ until a
-- modifier came up, which is what let it hand back an accumulated result and a
-- final state.  That is not merely awkward here, it is impossible: a binding
-- may only be created during a manage sequence and cannot fire until that
-- sequence has finished, so waiting inside one would be waiting for something
-- the compositor is not permitted to send.  The keys are captured, the call
-- returns, and the handler runs as they arrive.
--
-- Two things follow, and both are visible:
--
-- * Every function here returns @X ()@ where it used to return @X b@ or
--   @X (a, s)@.  No caller in xmonad-contrib used those values -- they were
--   @void@ed or discarded -- which is why the names survive at all.
--
-- * __Anything sequenced after a call runs before the keys are pressed.__ A
--   caller that cleans up afterwards has to do it in the handler instead;
--   "XMonad.Actions.MostRecentlyUsed" is the worked example, where the flag
--   guarding against re-entry is cleared on conclusion rather than on the next
--   line.
--
-- The mechanism is @river_xkb_bindings_seat_v1.modifiers_watch@, which reports
-- a change in the modifiers the window manager asked about and is exactly the
-- "and now it has been let go" signal this needs.  It arrived in version 3; on
-- anything older the handler is never installed and the action runs once.
-- 'XMonad.River.whileModifiersHeld' says so on stderr when that happens.

-- | An action that temporarily usurps and responds to key press/release
--   events, concluding when one of the modifier keys is released.
repeatable
  :: [KeySym]                      -- ^ The list of 'KeySym's under the
                                   --   modifiers used to invoke the action.
  -> KeySym                        -- ^ The keypress that invokes the action.
  -> (EventType -> KeySym -> X ()) -- ^ The keypress handler.
  -> X ()
repeatable = repeatableM id

-- | A more general variant of 'repeatable' with a stateful handler.
--
-- The final state is no longer returned; see $river.  A handler that needs to
-- act on it should do so as it goes.
repeatableSt
  :: Monoid a
  => s                                     -- ^ Initial state.
  -> [KeySym]                              -- ^ The list of 'KeySym's under the
                                           --   modifiers used to invoke the
                                           --   action.
  -> KeySym                                -- ^ The keypress that invokes the
                                           --   action.
  -> (EventType -> KeySym -> StateT s X a) -- ^ The keypress handler.
  -> X ()
repeatableSt iSt mods key handler = do
  -- The state has to outlive each call to the handler, and each call is a
  -- separate trip through the event loop rather than an iteration of a loop
  -- this function controls.  An IORef is what remains once the fold is gone.
  ref <- io (newIORef iSt)
  repeatableM id mods key $ \t s -> do
    st <- io (readIORef ref)
    (_, st') <- runStateT (handler t s) st
    io (writeIORef ref st')

-- | A more general variant of 'repeatable' with an arbitrary monadic handler.
--
-- The accumulated value is no longer returned; see $river.
repeatableM
  :: (MonadIO m, Monoid a)
  => (m a -> X b)                 -- ^ How to run the monad in 'X'.
  -> [KeySym]                     -- ^ The list of 'KeySym's under the
                                  --   modifiers used to invoke the action.
  -> KeySym                       -- ^ The keypress that invokes the action.
  -> (EventType -> KeySym -> m a) -- ^ The keypress handler.
  -> X ()
repeatableM run mods key handler =
  concludableM run mods key press event (pure ())
 where
  press t s = pure (Right (t, s))
  event (t, s) = Right <$> handler t s

data Done        = Done
data NotOurEvent = NotOurEvent

-- | A generalisation of 'repeatable' which may conclude early with
-- 'NotOurEvent' or 'Done'.
concludable
  :: [KeySym]
  -- ^ The list of 'KeySym's under the modifiers used to invoke the action.
  -> KeySym
  -- ^ The keypress that invokes the action.
  -> (EventType -> KeySym -> IO (Either NotOurEvent e))
  -- ^ Handle keypresses by translating them into custom events.
  -> (e -> X (Either Done ()))
  -- ^ The custom event handler.
  -> X ()
concludable mods key p e = concludableM id mods key p e (pure ())

-- | A more general variant of 'concludable' with a stateful handler.
concludableSt
  :: Monoid a
  => s
  -- ^ Initial state.
  -> [KeySym]
  -- ^ The list of 'KeySym's under the modifiers used to invoke the action.
  -> KeySym
  -- ^ The keypress that invokes the action.
  -> (EventType -> KeySym -> IO (Either NotOurEvent e))
  -- ^ Handle keypresses by translating them into custom events.
  -> (e -> StateT s X (Either Done a))
  -- ^ The custom event handler.
  -> X ()
  -> X ()
  -- ^ Run on conclusion.  New here: there is no "after" to put it in.
concludableSt iSt mods key pressHandler eventHandler onDone = do
  ref <- io (newIORef iSt)
  concludableM id mods key pressHandler
    (\ev -> do
       st <- io (readIORef ref)
       (r, st') <- runStateT (eventHandler ev) st
       io (writeIORef ref st')
       pure r)
    onDone

-- | A more general variant of 'concludable' with an arbitrary monadic
-- handler.
concludableM
  :: (MonadIO m, Monoid a)
  => (m a -> X b)
  -- ^ How to run the monad in 'X'.
  -> [KeySym]
  -- ^ The list of 'KeySym's under the modifiers used to invoke the action.
  -> KeySym
  -- ^ The keypress that invokes the action.
  -> (EventType -> KeySym -> IO (Either NotOurEvent e))
  -- ^ Handle keypresses by translating them into custom events.
  -> (e -> m (Either Done a))
  -- ^ The custom event handler.
  -> X ()
  -- ^ Run on conclusion.
  -> X ()
concludableM run mods key pressHandler eventHandler onDone = do
  done <- io (newIORef False)
  let conclude = io (writeIORef done True)
      capture = (modifierMask mods, key)
      onKey pressed sym = unlessM (io (readIORef done)) $ do
        -- The X11 version distinguished press from release by EventType and so
        -- does this; river's bindings report both.
        let t = if pressed then keyPress else keyRelease
        r <- io (pressHandler t sym)
        case r of
          -- Upstream put the event back on the queue so that whoever wanted it
          -- got it.  There is no queue to put anything back on, and the
          -- binding that delivered this exists only for the duration of the
          -- interaction, so the honest equivalent is to stop capturing.
          Left NotOurEvent -> conclude
          -- 'run' can only give back whatever @m@'s result is, so the Done
          -- signal cannot come out through it.  It comes out beside it.
          Right ev -> do
            _ <- run $ eventHandler ev >>= \case
              Left Done -> liftIO (writeIORef done True) >> pure mempty
              Right a   -> pure a
            pure ()
  whileModifiersHeld (modifierMask mods) [capture] onKey onDone
 where
  unlessM mb act = mb >>= \b -> if b then pure () else act

-- | Which modifier bits the given modifier keysyms stand for.
--
-- The interface is in terms of the keysyms a config writes -- @xK_Alt_L@ --
-- because that is what it has always taken, and X11 compared them against the
-- keysym of the key that was released.  river reports modifier /state/ rather
-- than the key that changed it, so the keysyms have to be turned into the mask
-- @modifiers_watch@ takes.  An unrecognised keysym contributes nothing, which
-- degrades to "never concludes on that one" rather than to a wrong mask.
modifierMask :: [KeySym] -> KeyMask
modifierMask = foldr (\s acc -> acc + bitFor s) 0
 where
  bitFor s = if
    | s `elem` [xK_Shift_L,   xK_Shift_R]                       -> shiftMask
    | s `elem` [xK_Control_L, xK_Control_R]                     -> controlMask
    | s `elem` [xK_Alt_L,     xK_Alt_R,   xK_Meta_L, xK_Meta_R] -> mod1Mask
    | s `elem` [xK_Super_L,   xK_Super_R, xK_Hyper_L, xK_Hyper_R] -> mod4Mask
    | otherwise                                                 -> 0
