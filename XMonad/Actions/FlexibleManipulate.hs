{-# LANGUAGE FlexibleInstances #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.FlexibleManipulate
-- Description :  Move and resize floating windows without warping the mouse.
-- Copyright   :  (c) Michael Sloan
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  <mgsloan@gmail.com>
-- Stability   :  stable
-- Portability :  unportable
--
-- Move and resize floating windows without warping the mouse.
--
-----------------------------------------------------------------------------

-- Based on the FlexibleResize code by Lukas Mai (mauke).

module XMonad.Actions.FlexibleManipulate (
        -- * Usage
        -- $usage
        mouseWindow, discrete, linear, resize, position
) where

import XMonad
import XMonad.Prelude (fi)
import XMonad (whenJust)
import XMonad.River (moveResizeWindow, pointerPosition, windowRect)
import qualified Prelude as P
import Prelude (Double, Integer, Ord (..), const, fromIntegral, fst, id, otherwise, round, snd, ($))

-- $usage
-- First, add this import to your @xmonad.hs@:
--
-- > import qualified XMonad.Actions.FlexibleManipulate as Flex
--
-- Now set up the desired mouse binding, for example:
--
-- >     , ((modm, button1), (\w -> focus w >> Flex.mouseWindow Flex.linear w))
--
-- * Flex.'linear' indicates that positions between the edges and the
--   middle indicate a combination scale\/position.
--
-- * Flex.'discrete' indicates that there are discrete pick
--   regions. (The window is divided by thirds for each axis.)
--
-- * Flex.'resize' performs only a resize of the window, based on which
--   quadrant the mouse is in.
--
-- * Flex.'position' is similar to the built-in
--   'XMonad.Operations.mouseMoveWindow'.
--
-- You can also write your own function for this parameter. It should take
-- a value between 0 and 1 indicating position, and return a value indicating
-- the corresponding position if plain Flex.'linear' was used.
--
-- For detailed instructions on editing your mouse bindings, see
-- "XMonad.Doc.Extending#Editing_mouse_bindings".

discrete, linear, resize, position :: Double -> Double

-- | Manipulate the window based on discrete pick regions; the window
--   is divided into regions by thirds along each axis.
discrete x | x < 0.33 = 0
           | x > 0.66 = 1
           | otherwise = 0.5

-- | Scale\/reposition the window by factors obtained from the mouse
--   position by linear interpolation. Dragging precisely on a corner
--   resizes that corner; dragging precisely in the middle moves the
--   window without resizing; anything else is an interpolation
--   between the two.
linear = id

-- | Only resize the window, based on the window quadrant the mouse is in.
resize x = if x < 0.5 then 0 else 1

-- | Only reposition the window.
position = const 0.5

-- | Given an interpolation function, implement an appropriate window
--   manipulation action.
-- Under river both of the X11 queries this used are gone: the window's
-- geometry comes from the layout rather than the server, and the pointer's
-- position is whatever river last reported.  Size hints are no longer applied
-- here either -- 'XMonad.River.moveResizeWindow' does it, using the bounds
-- river reported for the window.
mouseWindow :: (Double -> Double) -> Window -> X ()
mouseWindow f w = whenX (isClient w) $ do
  mr <- windowRect w
  mp <- pointerPosition
  whenJust ((,) P.<$> mr P.<*> mp) $ \(r, (px, py)) -> do
    let wpos  = (fi (rect_x r), fi (rect_y r))
        wsize = (fi (rect_width r), fi (rect_height r))
        pointer = (fi px, fi py) :: Pnt

    let uv = (pointer - wpos) / wsize
        fc = mapP f uv
        mul = mapP (\x -> 2 P.- 2 P.* P.abs(x P.- 0.5)) fc --Fudge factors: interpolation between 1 when on edge, 2 in middle
        atl = ((1, 1) - fc) * mul
        abr = fc * mul
    mouseDrag (\ex ey -> do
        let offset = (fromIntegral ex, fromIntegral ey) - pointer
            npos = wpos + offset * atl
            nbr = (wpos + wsize) + offset * abr
            ntl = minP (nbr - (32, 32)) npos    --minimum size
            (nw, nh) = mapP (round :: Double -> Integer) (nbr - ntl)
        moveResizeWindow w (Rectangle (round $ fst ntl) (round $ snd ntl)
                                      (fromIntegral nw) (fromIntegral nh))
        float w)
        (float w)

    float w

-- I'd rather I didn't have to do this, but I hate writing component 2d math
type Pnt = (Double, Double)

mapP :: (a -> b) -> (a, a) -> (b, b)
mapP f (x, y) = (f x, f y)
zipP :: (a -> b -> c) -> (a,a) -> (b,b) -> (c,c)
zipP f (ax,ay) (bx,by) = (f ax bx, f ay by)

minP :: Ord a => (a,a) -> (a,a) -> (a,a)
minP = zipP min

infixl 6  +, -
infixl 7  *, /

(+), (-), (*) :: (P.Num a) => (a,a) -> (a,a) -> (a,a)
(+) = zipP (P.+)
(-) = zipP (P.-)
(*) = zipP (P.*)
(/) :: (P.Fractional a) => (a,a) -> (a,a) -> (a,a)
(/) = zipP (P./)
