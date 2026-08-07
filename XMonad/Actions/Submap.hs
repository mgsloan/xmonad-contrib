-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.Submap
-- Description :  Create a sub-mapping of key bindings.
-- Copyright   :  (c) Jason Creighton <jcreigh@gmail.com>
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  Jason Creighton <jcreigh@gmail.com>
-- Stability   :  unstable
-- Portability :  unportable
--
-- A module that allows the user to create a sub-mapping of key bindings.
--
-----------------------------------------------------------------------------

module XMonad.Actions.Submap (
                             -- * Usage
                             -- $usage
                             submap,
                             visualSubmap,
                             visualSubmapSorted,
                             submapDefault,

                             -- * Utilities
                             subName,

                             -- * Differences under river
                             -- $river
                            ) where
import qualified Data.Map as M
import XMonad hiding (keys)
import XMonad.Prelude (keyToString)
import XMonad.River (submapNextKey)
import XMonad.Util.XUtils

{- $usage

First, import this module into your @xmonad.hs@:

> import XMonad.Actions.Submap

Allows you to create a sub-mapping of keys. Example:

>    , ((modm, xK_a), submap . M.fromList $
>        [ ((0, xK_n),     spawn "mpc next")
>        , ((0, xK_p),     spawn "mpc prev")
>        , ((0, xK_z),     spawn "mpc random")
>        , ((0, xK_space), spawn "mpc toggle")
>        ])

So, for example, to run 'spawn \"mpc next\"', you would hit mod-a (to
trigger the submapping) and then 'n' to run that action. (0 means \"no
modifier\"). You are, of course, free to use any combination of
modifiers in the submapping. However, anyModifier will not work,
because that is a special value passed to XGrabKey() and not an actual
modifier.

For detailed instructions on editing your key bindings, see
<https://xmonad.org/TUTORIAL.html#customizing-xmonad the tutorial>.

-}

-- | Given a 'Data.Map.Map' from key bindings to X () actions, return
--   an action which waits for a user keypress and executes the
--   corresponding action, or does nothing if the key is not found in
--   the map.
submap :: M.Map (KeyMask, KeySym) (X ()) -> X ()
submap = submapDefault (return ())

-- | Like 'submap', but visualise the relevant options.
--
-- ==== __Example__
--
-- > import qualified Data.Map as Map
-- > import XMonad.Actions.Submap
-- >
-- > gotoLayout :: [(String, X ())]   -- for use with EZConfig
-- > gotoLayout =  -- assumes you have a layout named "Tall" and one named "Full".
-- >   [("M-l", visualSubmap def $ Map.fromList $ map (\(k, s, a) -> ((0, k), (s, a)))
-- >              [ (xK_t, "Tall", switchToLayout "Tall")     -- "M-l t" switches to "Tall"
-- >              , (xK_r, "Full", switchToLayout "Full")     -- "M-l r" switches to "full"
-- >              ])]
--
-- One could alternatively also write @gotoLayout@ as
--
-- > gotoLayout = [("M-l", visualSubmap def $ Map.fromList $
-- >                         [ ((0, xK_t), subName "Tall" $ switchToLayout "Tall")
-- >                         , ((0, xK_r), subName "Full" $ switchToLayout "Full")
-- >                         ])]
visualSubmap :: WindowConfig -- ^ The config for the spawned window.
             -> M.Map (KeyMask, KeySym) (String, X ())
                             -- ^ A map @keybinding -> (description, action)@.
             -> X ()
visualSubmap = visualSubmapSorted id

-- | Like 'visualSubmap', but is able to sort the descriptions.
-- For example,
--
-- > import Data.Ord (comparing, Down)
-- >
-- > visualSubmapSorted (sortBy (comparing Down)) def
--
-- would sort the @(key, description)@ pairs by their keys in descending
-- order.
visualSubmapSorted :: ([((KeyMask, KeySym), String)] -> [((KeyMask, KeySym), String)])
                             -- ^ A function to resort the descriptions
             -> WindowConfig -- ^ The config for the spawned window.
             -> M.Map (KeyMask, KeySym) (String, X ())
                             -- ^ A map @keybinding -> (description, action)@.
             -> X ()
-- The window cannot be closed by bracketing the wait, as the X11 version did
-- with 'withSimpleWindow': under river a submap returns before the key is
-- pressed, so bracketing would take the window away immediately.  It is torn
-- down by whichever branch ends the submap instead.
visualSubmapSorted sorted wc keys = do
    w <- showSimpleWindow wc descriptions
    let close = deleteWindow w
    submapNextKey (M.map ((close >>) . snd) keys) close
  where
    descriptions :: [String]
    descriptions =
        map (\(key, desc) -> keyToString key <> ": " <> desc)
            . sorted
            $ zip (M.keys keys) (map fst (M.elems keys))

-- | Give a name to an action.
subName :: String -> X () -> (String, X ())
subName = (,)

-- | Like 'submap', but executes a default action if the key did not match.
submapDefault :: X () -> M.Map (KeyMask, KeySym) (X ()) -> X ()
submapDefault = flip submapNextKey

-- $river
--
-- Two things about this module differ from the X11 original, both forced by
-- river having no keyboard grab.  See 'XMonad.River.submapNextKey', which is
-- what everything here is built on.
--
-- The first is that a submap returns immediately rather than when the key is
-- pressed: a binding may only be created during a manage sequence and cannot
-- fire until that sequence ends, so waiting inside one for a key would be
-- waiting for something river is not yet allowed to send.  Every use of
-- @submap@ in the wild puts it last in an action, including the one
-- 'XMonad.Util.EZConfig.mkKeymap' generates for a key sequence, so this is not
-- normally visible.
--
-- The second is that @submapDefaultWithKey@ is gone.  It passed the unmatched
-- key to the default action, and river will not say which key that was:
-- @river_xkb_bindings_seat_v1.ate_unbound_key@ reports that a key was
-- swallowed and carries no arguments.  'submapDefault', which ignores the key,
-- is unaffected.
