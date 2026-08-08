{-# LANGUAGE ScopedTypeVariables, GeneralizedNewtypeDeriving,
  FlexibleInstances, MultiParamTypeClasses, FlexibleContexts #-}
-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Util.WindowState
-- Description  :  Functions for saving per-window data.
-- Copyright    : (c) Dmitry Bogatov <KAction@gnu.org>
-- License      : BSD
--
-- Maintainer   : Dmitry Bogatov <KAction@gnu.org>
-- Stability    : unstable
-- Portability  : unportable
--
-- Functions for saving per-window data.
-----------------------------------------------------------------------------

module XMonad.Util.WindowState ( -- * Usage
                                 -- $usage
                                 get,
                                 put,
                                 StateQuery(..),
                                 runStateQuery,
                                 catchQuery ) where
import XMonad hiding (get, put, modify)
import Control.Monad.Reader(ReaderT(..))
import Control.Monad.State.Class
import Data.Typeable (typeOf)
import qualified Data.Map.Strict as M
import qualified XMonad.Util.ExtensibleState as XS
-- $usage
--
-- This module allow to store state data with some 'Window'.
--
-- Upstream implements it with X window properties, so the storage lives on the
-- window and is freed by the server when the window is destroyed.  Wayland has
-- no window properties, so here it is a map in xmonad's own state, keyed on
-- the window and the type of the value.  Two consequences worth knowing:
-- entries are dropped when the window is unmanaged rather than by anyone else,
-- and the data is not visible to other clients, which under X11 it was.
--
-- This module have advantage over "XMonad.Actions.TagWindows" in that it
-- hides from you implementation details and provides simple type-safe
-- interface.  Main datatype is 'StateQuery', which is simple wrapper around
-- 'Query', which is instance of MonadState, with 'put' and 'get' are
-- functions to acess data, stored in 'Window'.
--
-- To save some data in window you probably want to do following:
-- > (runStateQuery  (put $ Just value)  win) :: X ()
-- To retrive it, you can use
-- > (runStateQuery get win) :: X (Maybe YourValueType)
-- 'Query' can be promoted to 'StateQuery' simply by constructor,
-- and reverse is 'getQuery'.
--
-- For example, I use it to have all X applications @russian@ or @dvorak@
-- layout, but emacs have only @us@, to not screw keybindings. Use your
-- imagination!

-- | Wrapper around 'Query' with phantom type @s@, representing state, saved in
-- window.
newtype StateQuery s a = StateQuery {
      getQuery :: Query a
    } deriving (Monad, MonadIO, Applicative, Functor)

packIntoQuery :: (Window -> X a) -> Query a
packIntoQuery = Query . ReaderT

-- | Apply 'StateQuery' to 'Window'.
runStateQuery :: StateQuery s a -> Window ->  X a
runStateQuery = runQuery . getQuery

-- | Lifted to 'Query' version of 'catchX'
catchQuery :: Query a -> Query (Maybe a)
catchQuery q = packIntoQuery $ \win -> userCode $ runQuery q win

-- | Instance of MonadState for StateQuery.
instance (Show s, Read s, Typeable s) => MonadState (Maybe s) (StateQuery s) where
    get = StateQuery  $ read' <$> get' undefined where
        get'   :: Maybe s -> Query String
        get' x = packIntoQuery (getWindowState (typePropertyName x))
        read'  :: (Read s) => String -> Maybe s
        read' "" = Nothing
        read' s  = Just $ read s
    put = StateQuery . packIntoQuery <$> setWindowState' where
        setWindowState' val = setWindowState prop strValue where
            prop = typePropertyName val
            strValue = maybe "" show val

-- | The key a value of this type is filed under.
--
-- Still spelled as the X11 property name it used to be, so that a window whose
-- state was written by one build reads the same way in the other -- and so
-- that the name says where this came from.
typePropertyName :: (Typeable a) => a -> String
typePropertyName x = "_XMONAD_WINSTATE__" ++ show (typeOf x)

type PropertyName = String

-- | Per-window state, in place of the properties X11 stored it in.
newtype WindowStates = WindowStates (M.Map (PropertyName, Window) String)

instance ExtensionClass WindowStates where
    -- Deliberately not a PersistentExtension.  The X11 version survived a
    -- restart because the data was on the window and the server outlived
    -- xmonad; a river object id is per-connection and recycled, so a map keyed
    -- on one means nothing to the next window manager.
    initialValue = WindowStates M.empty

getWindowState :: PropertyName -> Window -> X String
getWindowState prop win =
    XS.gets $ \(WindowStates m) -> M.findWithDefault "" (prop, win) m

setWindowState :: PropertyName -> String -> Window -> X ()
setWindowState prop val win = XS.modify $ \(WindowStates m) ->
    WindowStates $ if null val then M.delete (prop, win) m
                               else M.insert (prop, win) val m
