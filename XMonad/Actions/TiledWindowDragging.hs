-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.TiledWindowDragging
-- Description :  Change the position of windows by dragging them.
-- Copyright   :  (c) 2020 Leon Kowarschick
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  Leon Kowarschick. <thereal.elkowar@gmail.com>
-- Stability   :  unstable
-- Portability :  unportable
--
-- Provides an action that allows you to change the position of windows by dragging them around.
--
-----------------------------------------------------------------------------

module XMonad.Actions.TiledWindowDragging
  (
  -- * Usage
  -- $usage
    dragWindow
  )
where

import           XMonad
import           XMonad.Prelude
import           XMonad.River                   ( pointerPosition
                                                , windowUnderPointer
                                                )
import qualified XMonad.StackSet               as W
import           XMonad.Layout.DraggingVisualizer

-- $usage
-- You can use this module with the following in your @xmonad.hs@:
--
-- > import XMonad.Actions.TiledWindowDragging
-- > import XMonad.Layout.DraggingVisualizer
--
-- then edit your 'layoutHook' by adding the draggingVisualizer to your layout:
--
-- > myLayout = draggingVisualizer $ layoutHook def
--
-- Then add a mouse binding for 'dragWindow':
--
-- > , ((modMask .|. shiftMask, button1), dragWindow)
--
-- For detailed instructions on editing your mouse bindings, see
-- "XMonad.Doc.Extending#Editing_mouse_bindings".



-- | Create a mouse binding for this to be able to drag your windows around.
-- You need "XMonad.Layout.DraggingVisualizer" for this to look good.
dragWindow :: Window -> X ()
dragWindow window = whenX (isClient window) $ withDisplay $ \dpy ->
  withWindowAttributes dpy window $ \wa -> do
    focus window
    (offsetX, offsetY)                    <- getPointerOffset window
    let (winX, winY, winWidth, winHeight)  = getWindowPlacement wa

    mouseDrag
        (\posX posY ->
          let rect = Rectangle (fi (fi winX + (posX - fi offsetX)))
                               (fi (fi winY + (posY - fi offsetY)))
                               (fi winWidth)
                               (fi winHeight)
          in  sendMessage $ DraggingWindow window rect
        )
        (sendMessage DraggingStopped >> performWindowSwitching window)


-- | get the pointer offset relative to the given windows root coordinates
--
-- Despite the name the X11 version read @queryPointer@'s root-relative pair
-- rather than its window-relative one, so the window argument only ever chose
-- which screen the answer was measured against.  River has a single coordinate
-- space, so the argument has nothing left to select and the answer is the
-- same.
getPointerOffset :: Window -> X (Int, Int)
getPointerOffset _ = do
    (oX, oY) <- fromMaybe (0, 0) <$> pointerPosition
    return (fi oX, fi oY)

-- | return a tuple of windowX, windowY, windowWidth, windowHeight
getWindowPlacement :: WindowAttributes -> (Int, Int, Int, Int)
getWindowPlacement wa = (fi $ wa_x wa, fi $ wa_y wa, fi $ wa_width wa, fi $ wa_height wa)

performWindowSwitching :: Window -> X ()
performWindowSwitching win = do
    -- @queryPointer@'s third result, the window under the pointer.  River has
    -- no such query; see 'XMonad.River.windowUnderPointer'.  Landing on no
    -- window swaps @win@ with itself, which is what the X11 version did when
    -- the answer was @none@.
    selWin                        <- fromMaybe win <$> windowUnderPointer
    ws                            <- gets windowset
    let allWindows = W.index ws
    when ((win `elem` allWindows) && (selWin `elem` allWindows)) $ do
        let allWindowsSwitched = map (switchEntries win selWin) allWindows
        (ls, t : rs)          <- pure $ break (== win) allWindowsSwitched
        let newStack           = W.Stack t (reverse ls) rs
        windows $ W.modify' $ const newStack
   where
    switchEntries a b x | x == a    = b
                        | x == b    = a
                        | otherwise = x
