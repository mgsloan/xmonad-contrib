-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.ConstrainedResize
-- Description :  Constrain the aspect ratio of a floating window.
-- Copyright   :  (c) Dougal Stanton
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  <dougal@dougalstanton.net>
-- Stability   :  stable
-- Portability :  unportable
--
-- Lets you constrain the aspect ratio of a floating
-- window (by, say, holding shift while you resize).
--
-- Useful for making a nice circular XClock window.
--
-----------------------------------------------------------------------------

module XMonad.Actions.ConstrainedResize (
        -- * Usage
        -- $usage
        XMonad.Actions.ConstrainedResize.mouseResizeWindow
) where

import XMonad
import XMonad.River (moveResizeWindow)

-- $usage
--
-- You can use this module with the following in your @xmonad.hs@:
--
-- > import qualified XMonad.Actions.ConstrainedResize as Sqr
--
-- Then add something like the following to your mouse bindings:
--
-- >     , ((modm, button3),               (\w -> focus w >> Sqr.mouseResizeWindow w False))
-- >     , ((modm .|. shiftMask, button3), (\w -> focus w >> Sqr.mouseResizeWindow w True ))
--
-- The line without the shiftMask replaces the standard mouse resize
-- function call, so it's not completely necessary but seems neater
-- this way.
--
-- For detailed instructions on editing your mouse bindings, see
-- "XMonad.Doc.Extending#Editing_mouse_bindings".

-- | Resize (floating) window with optional aspect ratio constraints.
--
-- The pointer is warped to the window's bottom-right corner, as it was under
-- X11 -- there the warp was relative to the window, and here it is the same
-- point named in river's global coordinates, which is the only space river
-- talks about.  Size hints need no application here because
-- 'XMonad.River.moveResizeWindow' applies them.
mouseResizeWindow :: Window -> Bool -> X ()
mouseResizeWindow w c = whenX (isClient w) $ withDisplay $ \d ->
  withWindowAttributes d w $ \wa -> do
    warpPointer (wa_x wa + fromIntegral (wa_width wa))
                (wa_y wa + fromIntegral (wa_height wa))
    mouseDrag (\ex ey -> do
                 let x = max 1 (ex - wa_x wa)
                     y = max 1 (ey - wa_y wa)
                     (dw, dh) = if c then (max x y, max x y) else (x,y)
                 moveResizeWindow w (Rectangle (wa_x wa) (wa_y wa)
                                               (fromIntegral dw) (fromIntegral dh))
                 float w)
              (float w)
