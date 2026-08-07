{-# LANGUAGE LambdaCase #-}
-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Hooks.ManageHelpers
-- Description  : Helper functions to be used in manageHook.
-- Copyright    : (c) Lukas Mai
-- License      : BSD
--
-- Maintainer   : Lukas Mai <l.mai@web.de>
-- Stability    : unstable
-- Portability  : unportable
--
-- This module provides helper functions to be used in @manageHook@. Here's
-- how you might use this:
--
-- > import XMonad.Hooks.ManageHelpers
-- > main =
-- >     xmonad def{
-- >         ...
-- >         manageHook = composeOne [
-- >             isKDETrayWindow -?> doIgnore,
-- >             transience,
-- >             isFullscreen -?> doFullFloat,
-- >             resource =? "stalonetray" -?> doIgnore
-- >         ],
-- >         ...
-- >     }
--
-- Here's how you can define more helpers like the ones from this module:
--
-- > -- some function you want to transform into an infix operator
-- > f :: a -> b -> Bool
-- >
-- > -- a new helper
-- > q ***? x = fmap (\a -> f a x) q   -- or: (\b -> f x b)
-- > -- or
-- > q ***? x = fmap (`f` x) q         -- or: (x `f`)
--
-- Any existing operator can be "lifted" in the same way:
--
-- > q ++? x = fmap (++ x) q

module XMonad.Hooks.ManageHelpers (
    Side(..),
    composeOne,
    (-?>), (/=?), (^?), (~?), ($?), (<==?), (</=?), (-->>), (-?>>),
    currentWs,
    windowTag,
    isFullscreen,
    isMinimized,
    isDialog,
    pid,
    transientTo,
    maybeToDefinite,
    MaybeManageHook,
    transience,
    transience',
    sameBy,
    shiftToSame,
    shiftToSame',
    doRectFloat,
    doFullFloat,
    doCenterFloat,
    doSideFloat,
    doFloatAt,
    doFloatDep,
    doHideIgnore,
    doSink,
    doFocus,
    Match,
    -- * Differences under river
    -- $river
) where

import XMonad
import XMonad.Prelude
import qualified XMonad.StackSet as W
import XMonad.River (RiverWindow (..))
import XMonad.Util.Minimize (Minimized (..))
import qualified XMonad.Util.ExtensibleState as XS

import Data.IORef (readIORef)
import qualified Data.Map.Strict as M
import System.Posix (ProcessID)

-- | What river has told us about a window, if it is one river manages.
askRiverWindow :: Query (Maybe RiverWindow)
askRiverWindow = ask >>= \w -> liftX $ do
    known <- io . readIORef =<< asks riverWindows
    pure (M.lookup w known)

-- $river
--
-- The queries here that were really \"read an X property off the window\" are
-- gone, because Wayland has no window properties: @isInProperty@,
-- @isKDETrayWindow@, @isNotification@, @desktop@ and @clientLeader@.
--
-- 'isMinimized' is the exception: minimizing is xmonad's own idea rather than
-- X's, so it survives by asking "XMonad.Util.Minimize" instead of the
-- property that module used to publish.
--
-- 'isNotification' deserves a word, because its absence is not a gap so much
-- as a category error here: a notification under Wayland is a layer surface,
-- and river never offers layer surfaces to the window manager as windows.  A
-- notification will not reach a manage hook at all, so there is nothing for
-- the query to have matched.
--
-- The three that remain are backed by things river does report:
-- 'pid' by @river_window_v1.unreliable_pid@, 'transientTo' and 'isDialog' by
-- its @parent@ event, and 'isFullscreen' by @fullscreen_requested@.
--
-- @doRaise@ and @doLower@ are gone for a different reason.  They restacked one
-- window against the rest, and under river there is nothing to restack
-- against: the window manager re-derives the whole stacking order from the
-- layout on every render sequence, so a raise recorded in a manage hook would
-- be overwritten before it was ever shown.

-- | Denotes a side of a screen. @S@ stands for South, @NE@ for Northeast
-- etc. @C@ stands for Center.
data Side = SC | NC | CE | CW | SE | SW | NE | NW | C
    deriving (Read, Show, Eq)

-- | A ManageHook that may or may not have been executed; the outcome is embedded in the Maybe
type MaybeManageHook = Query (Maybe (Endo WindowSet))
-- | A grouping type, which can hold the outcome of a predicate Query.
-- This is analogous to group types in regular expressions.
-- TODO: create a better API for aggregating multiple Matches logically
data Match a = Match Bool a

-- | An alternative 'ManageHook' composer. Unlike 'composeAll' it stops as soon as
-- a candidate returns a 'Just' value, effectively running only the first match
-- (whereas 'composeAll' continues and executes all matching rules).
composeOne :: (Monoid a, Monad m) => [m (Maybe a)] -> m a
composeOne = foldr try (return mempty)
    where
    try q z = do
        x <- q
        maybe z return x

infixr 0 -?>, -->>, -?>>

-- | q \/=? x. if the result of q equals x, return False
(/=?) :: (Eq a, Functor m) => m a -> a -> m Bool
q /=? x = fmap (/= x) q

-- | q ^? x. if the result of @x `isPrefixOf` q@, return True
(^?) :: (Eq a, Functor m) => m [a] -> [a] -> m Bool
q ^? x = fmap (x `isPrefixOf`) q

-- | q ~? x. if the result of @x `isInfixOf` q@, return True
(~?) :: (Eq a, Functor m) => m [a] -> [a] -> m Bool
q ~? x = fmap (x `isInfixOf`) q

-- | q $? x. if the result of @x `isSuffixOf` q@, return True
($?) :: (Eq a, Functor m) => m [a] -> [a] -> m Bool
q $? x = fmap (x `isSuffixOf`) q

-- | q <==? x. if the result of q equals x, return True grouped with q
(<==?) :: (Eq a, Functor m) => m a -> a -> m (Match a)
q <==? x = fmap (`eq` x) q
    where
    eq q' x' = Match (q' == x') q'

-- | q <\/=? x. if the result of q notequals x, return True grouped with q
(</=?) :: (Eq a, Functor m) => m a -> a -> m (Match a)
q </=? x = fmap (`neq` x) q
    where
    neq q' x' = Match (q' /= x') q'

-- | A helper operator for use in 'composeOne'. It takes a condition and an action;
-- if the condition fails, it returns 'Nothing' from the 'Query' so 'composeOne' will
-- go on and try the next rule.
(-?>) :: (Functor m, Monad m) => m Bool -> m a -> m (Maybe a)
p -?> f = do
    x <- p
    if x then fmap Just f else return Nothing

-- | A helper operator for use in 'composeAll'. It takes a condition and a function taking a grouped datum to action.  If 'p' is true, it executes the resulting action.
(-->>) :: (Monoid b, Monad m) => m (Match a) -> (a -> m b) -> m b
p -->> f = do
    Match b m <- p
    if b then f m else return mempty

-- | A helper operator for use in 'composeOne'.  It takes a condition and a function taking a groupdatum to action.  If 'p' is true, it executes the resulting action.  If it fails, it returns 'Nothing' from the 'Query' so 'composeOne' will go on and try the next rule.
(-?>>) :: (Functor m, Monad m) => m (Match a) -> (a -> m b) -> m (Maybe b)
p -?>> f = do
    Match b m <- p
    if b then fmap  Just (f m) else return Nothing

-- | Return the current workspace
currentWs :: Query WorkspaceId
currentWs = liftX (withWindowSet $ return . W.currentTag)

-- | Return the workspace tag of a window, if already managed
windowTag :: Query (Maybe WorkspaceId)
windowTag = ask >>= \w -> liftX $ withWindowSet $ return . W.findTag w

-- | A predicate to check whether a window wants to fill the whole screen.
-- See also 'doFullFloat'.
--
-- Backed by @river_window_v1.fullscreen_requested@, which river sends before
-- the manage sequence it triggers -- so a manage hook gets the current answer.
-- Note that this is what the window /asked/ for; honouring it is still the
-- window manager's decision, exactly as under X11.
isFullscreen :: Query Bool
isFullscreen = maybe False rwFullscreen <$> askRiverWindow

-- | A predicate to check whether a window is hidden (minimized).
-- See also "XMonad.Actions.Minimize".
--
-- Under X11 this read @_NET_WM_STATE_HIDDEN@, which
-- "XMonad.Actions.Minimize" set alongside its own bookkeeping.  Here it
-- consults that bookkeeping directly -- which is where the answer always
-- actually lived, the property being a copy published for other clients to
-- read.
isMinimized :: Query Bool
isMinimized = ask >>= \w -> liftX $
    XS.gets (elem w . minimizedStack)

-- | A predicate to check whether a window is a dialog.
--
-- Under X11 this read @_NET_WM_WINDOW_TYPE@.  Wayland has no window type; what
-- it has is @xdg_toplevel.set_parent@, which river forwards as its @parent@
-- event, and a toplevel with a parent is what a dialog is in practice.  The
-- two agree on the cases that matter -- a modal dialog sets both -- and differ
-- on a window that declares the type without setting a parent.
isDialog :: Query Bool
isDialog = isJust <$> transientTo

-- | This function returns 'Just' the process id of the window's client if
-- known, 'Nothing' otherwise.
--
-- Backed by @river_window_v1.unreliable_pid@.  river calls it unreliable
-- because a client may lie about it or be proxied; @_NET_WM_PID@ was no better
-- and for the same reason.
pid :: Query (Maybe ProcessID)
pid = fmap fromIntegral . (rwPid =<<) <$> askRiverWindow

-- | A predicate to check whether a window is Transient.
-- It holds the result which might be the window it is transient to
-- or it might be 'Nothing'.
transientTo :: Query (Maybe Window)
transientTo = (rwParent =<<) <$> askRiverWindow

-- | A convenience 'MaybeManageHook' that will check to see if a window
-- is transient, and then move it to its parent.
transience :: MaybeManageHook
transience = transientTo </=? Nothing -?>> maybe idHook doShiftTo

-- | 'transience' set to a 'ManageHook'
transience' :: ManageHook
transience' = maybeToDefinite transience

-- | For a given window, 'sameBy' returns all windows that have a matching
-- property (e.g. those obtained from Queries of 'clientLeader' and 'pid').
sameBy :: Eq prop => Query (Maybe prop) -> Query [Window]
sameBy prop = prop >>= \case
    Nothing -> pure []
    propVal -> ask >>= \w -> liftX . withWindowSet $ \s ->
        filterM (fmap (propVal ==) . runQuery prop) (W.allWindows s \\ [w])

-- | 'MaybeManageHook' that moves the window to the same workspace as the
-- first other window that has the same value of a given 'Query'. Useful
-- Queries for this include 'clientLeader' and 'pid'.
shiftToSame :: Eq prop => Query (Maybe prop) -> MaybeManageHook
shiftToSame prop = sameBy prop </=? [] -?>> maybe idHook doShiftTo . listToMaybe

-- | 'shiftToSame' set to a 'ManageHook'
shiftToSame' :: Eq prop => Query (Maybe prop) -> ManageHook
shiftToSame' = maybeToDefinite . shiftToSame

-- | converts 'MaybeManageHook's to 'ManageHook's
maybeToDefinite :: (Monoid a, Functor m) => m (Maybe a) -> m a
maybeToDefinite = fmap (fromMaybe mempty)

-- | Move the window to the same workspace as another window.
doShiftTo :: Window -> ManageHook
doShiftTo target = doF . shiftTo =<< ask
  where shiftTo w s = maybe s (\t -> W.shiftWin t w s) (W.findTag target s)

-- | Floats the new window in the given rectangle.
doRectFloat :: W.RationalRect  -- ^ The rectangle to float the window in. 0 to 1; x, y, w, h.
            -> ManageHook
doRectFloat r = ask >>= \w -> doF (W.float w r)

-- | Floats the window and makes it use the whole screen. Equivalent to
-- @'doRectFloat' $ 'W.RationalRect' 0 0 1 1@.
doFullFloat :: ManageHook
doFullFloat = doRectFloat $ W.RationalRect 0 0 1 1

-- | Floats a new window using a rectangle computed as a function of
--   the rectangle that it would have used by default.
doFloatDep :: (W.RationalRect -> W.RationalRect) -> ManageHook
doFloatDep move = ask >>= \w -> doF . W.float w . move . snd =<< liftX (floatLocation w)

-- | Floats a new window with its original size, and its top left
--   corner at a specific point on the screen (both coordinates should
--   be in the range 0 to 1).
doFloatAt :: Rational -> Rational -> ManageHook
doFloatAt x y = doFloatDep move
  where
    move (W.RationalRect _ _ w h) = W.RationalRect x y w h

-- | Floats a new window with its original size on the specified side of a
-- screen
doSideFloat :: Side -> ManageHook
doSideFloat side = doFloatDep move
  where
    move (W.RationalRect _ _ w h) = W.RationalRect cx cy w h
      where cx
              | side `elem` [SC,C ,NC] = (1-w)/2
              | side `elem` [SW,CW,NW] = 0
              | otherwise = {- side `elem` [SE,CE,NE] -} 1-w
            cy
              | side `elem` [CE,C ,CW] = (1-h)/2
              | side `elem` [NE,NC,NW] = 0
              | otherwise = {- side `elem` [SE,SC,SW] -} 1-h

-- | Floats a new window with its original size, but centered.
doCenterFloat :: ManageHook
doCenterFloat = doSideFloat C

-- | Hides window and ignores it.
doHideIgnore :: ManageHook
doHideIgnore = ask >>= \w -> liftX (hide w) >> doF (W.delete w)

-- | Sinks a window
doSink :: ManageHook
doSink = doF . W.sink =<< ask

-- | Focus a window (useful in 'XMonad.Hooks.EwmhDesktops.setActivateHook').
doFocus :: ManageHook
doFocus = doF . W.focusWindow =<< ask
