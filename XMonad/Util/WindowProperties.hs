-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.WindowProperties
-- Description :  EDSL for specifying window properties.
-- Copyright   :  (c) Roman Cheplyaka
-- License     :  BSD-style (see LICENSE)
--
-- Maintainer  :  Roman Cheplyaka <roma@ro-che.info>
-- Stability   :  unstable
-- Portability :  unportable
--
-- EDSL for specifying window properties; various utilities related to window
-- properties.
--
-----------------------------------------------------------------------------
module XMonad.Util.WindowProperties (
    -- * EDSL for window properties
    -- $edsl
    Property(..), hasProperty, focusedHasProperty, allWithProperty,
    propertyToQuery,
    -- * Differences under river
    -- $river
    )
where

import XMonad
import XMonad.Actions.TagWindows (hasTag)
import XMonad.Prelude (filterM)
import qualified XMonad.StackSet as W

-- $edsl
-- Allows to specify window properties, such as title, classname or
-- resource, and to check them.
--
-- In contrast to ManageHook properties, these are instances of Show and Read,
-- so they can be used in layout definitions etc. For example usage see "XMonad.Layout.IM"

-- | Most of the property constructors are quite self-explaining.
data Property = Title String
              | ClassName String
              | Resource String
              | And Property Property
              | Or  Property Property
              | Not Property
              | Const Bool
              | Tagged String -- ^ Tagged via "XMonad.Actions.TagWindows"
              deriving (Read, Show)
infixr 9 `And`
infixr 8 `Or`

-- | Does given window have this property?
hasProperty :: Property -> Window -> X Bool
hasProperty p = runQuery (propertyToQuery p)

-- | Does the focused window have this property?
focusedHasProperty :: Property -> X Bool
focusedHasProperty p = do
    ws <- gets windowset
    let ms = W.stack $ W.workspace $ W.current ws
    case ms of
        Just s  -> hasProperty p $ W.focus s
        Nothing -> return False

-- | Find all existing windows with specified property
--
-- The X11 version asked the server for the root window's children, which
-- included windows xmonad had never managed.  river tells a window manager
-- about every window there is, so the 'WindowSet' is the whole list -- with the
-- difference that windows xmonad does not manage are no longer among them.
allWithProperty :: Property -> X [Window]
allWithProperty prop = do
    wins <- gets (W.allWindows . windowset)
    hasProperty prop `filterM` wins

-- | Convert property to 'Query' 'Bool' (see "XMonad.ManageHook")
propertyToQuery :: Property -> Query Bool
propertyToQuery (Title s) = title =? s
propertyToQuery (Resource s) = resource =? s
propertyToQuery (ClassName s) = className =? s
propertyToQuery (And p1 p2) = propertyToQuery p1 <&&> propertyToQuery p2
propertyToQuery (Or p1 p2) = propertyToQuery p1 <||> propertyToQuery p2
propertyToQuery (Not p) = not <$> propertyToQuery p
propertyToQuery (Const b) = return b
propertyToQuery (Tagged s) = ask >>= \w -> liftX (hasTag s w)

-- $river
--
-- Wayland has no window properties, so the parts of this module that were
-- really \"read an X property\" are gone rather than stubbed.
--
-- * @getProp32@ and @getProp32s@ read a numeric property off a window by atom.
--   There is no atom, no property, and nothing to read.
--
-- * The @Role@ and @Machine@ constructors of 'Property' matched
--   @WM_WINDOW_ROLE@ and @WM_CLIENT_MACHINE@, likewise.
--
-- What remains works: river reports a window's title and @app_id@, which is
-- what 'Title', 'ClassName' and 'Resource' compare against -- @app_id@ standing
-- in for both halves of X11's @WM_CLASS@, since Wayland has only the one
-- string.  'Tagged' works because "XMonad.Actions.TagWindows" now keeps its
-- tags in xmonad's own state.
