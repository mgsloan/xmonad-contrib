{-# LANGUAGE CPP             #-}
{-# LANGUAGE LambdaCase      #-}
{-# LANGUAGE TupleSections   #-}
{-# LANGUAGE RecordWildCards #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.XUtils
-- Description :  A module for painting on the screen.
-- Copyright   :  (c) 2007 Andrea Rossato
--                    2010 Alejandro Serrano
-- License     :  BSD-style (see xmonad/LICENSE)
--
-- Maintainer  :  andrea.rossato@unibz.it
-- Stability   :  unstable
-- Portability :  unportable
--
-- A module for painting on the screen
--
-----------------------------------------------------------------------------

module XMonad.Util.XUtils
    ( -- * Usage:
      -- $usage
      withSimpleWindow
    , showSimpleWindow
    , showMessageWindow
    , WindowConfig(..)
    , WindowRect(..)
    , averagePixels
    , createNewWindow
    , showWindow
    , showWindows
    , hideWindow
    , hideWindows
    , deleteWindow
    , deleteWindows
    , paintWindow
    , paintAndWrite
    , paintTextAndIcons
    , stringToPixel
    , pixelToString
    , fi
    ) where

import XMonad.Prelude
import XMonad
import XMonad.Util.River.Compat
    ( Drawable, EventMask, GC, Pixel, commitDrawable, copyArea
    , createDrawableWindow, createGC, createPixmap, destroyDrawable, drawOn
    , fillRectangle, freeGC, freePixmap, mapDrawable, pixelFromString
    , pixelToColour, setForeground, unmapDrawable )
import qualified XMonad.Util.River.Draw as D
import XMonad.River (submapNextKey, warnUnimplemented)
import XMonad.River.Wire (nullObject)
import XMonad.Util.Font
import XMonad.Util.Image
import qualified XMonad.StackSet as W
import Data.Bits ((.&.))
import qualified Data.Map as M

-- $usage
-- See "XMonad.Layout.Tabbed" or "XMonad.Layout.DragPane" or
-- "XMonad.Layout.Decoration" for usage examples

-- | Compute the weighted average the colors of two given 'Pixel' values.
--
-- This function masks out any alpha channel in the passed pixels, and the
-- result has no alpha channel. X11 mishandles @Pixel@ values with alpha
-- channels and throws errors while producing black pixels.
-- | Blend two colours.
--
-- Upstream round-trips through the server: queryColors to resolve both
-- pixels, then allocColor to get one back.  A Pixel is the colour itself
-- here, so this is arithmetic.
averagePixels :: Pixel -> Pixel -> Double -> X Pixel
averagePixels p1 p2 f =
    let (r1,g1,b1,a1) = pixelToColour p1
        (r2,g2,b2,a2) = pixelToColour p2
        mix x1 x2 = x1 * f + x2 * (1 - f)
    in pure (pixelFromString (mix r1 r2, mix g1 g2, mix b1 b2, mix a1 a2))

-- | Create a simple window given a rectangle. If Nothing is given
-- only the exposureMask will be set, otherwise the Just value.
-- Use 'showWindow' to map and hideWindow to unmap.
-- | Create a window-manager surface for the given rectangle.
--
-- The event mask is accepted and ignored: river delivers exactly the events
-- the management protocol defines and there is no mask to select, the same
-- treatment @clientMask@ gets.  The override-redirect flag goes too --
-- a surface with the shell-surface role is never laid out as a window, so
-- there is nothing to redirect around.
--
-- The returned id is the shell surface's, which is why every @Window@-typed
-- signature downstream keeps working.  It is not a river window, and
-- 'XMonad.Util.River.Compat.isDrawable' is how anything that might send a
-- window request tells the difference.
createNewWindow :: Rectangle -> Maybe EventMask -> String -> Bool -> X Window
createNewWindow r _ col _ = do
  d  <- asks display
  mc <- asks riverCompositor
  mgr <- asks riverManager
  case mc of
    Nothing -> do
      warnUnimplemented "createNewWindow"
        "wl_compositor is unavailable, so window manager surfaces (prompts, decorations) cannot be created and this returns a null id."
      pure nullObject
    Just compositor -> do
      win <- io (createDrawableWindow d compositor mgr r)
      -- The background colour is painted rather than set as a window
      -- attribute: there is no server-side background to set.
      io $ drawOn win $ \_ -> D.fillRect (D.parseColour col) 0 0
             (fromIntegral (rect_width r)) (fromIntegral (rect_height r))
      pure win

-- | Map a window
showWindow :: Window -> X ()
showWindow w = do
  d <- asks display
  shm <- asks riverShm
  io (mapDrawable w)
  -- Mapping alone shows nothing: a wl_surface with no buffer is not mapped,
  -- so whatever has been queued has to be presented too.
  mapM_ (\s -> io (commitDrawable d s w)) shm

-- | the list version
showWindows :: [Window] -> X ()
showWindows = mapM_ showWindow

-- | unmap a window
hideWindow :: Window -> X ()
hideWindow w = do
  d <- asks display
  io (unmapDrawable d w)

-- | the list version
hideWindows :: [Window] -> X ()
hideWindows = mapM_ hideWindow

-- | destroy a window
deleteWindow :: Window -> X ()
deleteWindow w = do
  d <- asks display
  io (destroyDrawable d w)

-- | the list version
deleteWindows :: [Window] -> X ()
deleteWindows = mapM_ deleteWindow

-- | Fill a window with a rectangle and a border
paintWindow :: Window     -- ^ The window where to draw
            -> Dimension  -- ^ Window width
            -> Dimension  -- ^ Window height
            -> Dimension  -- ^ Border width
            -> String     -- ^ Window background color
            -> String     -- ^ Border color
            -> X ()
paintWindow w wh ht bw c bc =
    paintWindow' w (Rectangle 0 0 wh ht) bw c bc Nothing Nothing

-- | Fill a window with a rectangle and a border, and write
-- | a number of strings to given positions
paintAndWrite :: Window     -- ^ The window where to draw
              -> XMonadFont -- ^ XMonad Font for drawing
              -> Dimension  -- ^ Window width
              -> Dimension  -- ^ Window height
              -> Dimension  -- ^ Border width
              -> String     -- ^ Window background color
              -> String     -- ^ Border color
              -> String     -- ^ String color
              -> String     -- ^ String background color
              -> [Align]    -- ^ String 'Align'ments
              -> [String]   -- ^ Strings to be printed
              -> X ()
paintAndWrite w fs wh ht bw bc borc ffc fbc als strs = do
    d <- asks display
    strPositions <- forM (zip als strs) $
        uncurry (stringPosition d fs (Rectangle 0 0 wh ht))
    let ms = Just (fs,ffc,fbc, zip strs strPositions)
    paintWindow' w (Rectangle 0 0 wh ht) bw bc borc ms Nothing

-- | Fill a window with a rectangle and a border, and write
-- | a number of strings and a number of icons to given positions
paintTextAndIcons :: Window      -- ^ The window where to draw
                  -> XMonadFont  -- ^ XMonad Font for drawing
                  -> Dimension   -- ^ Window width
                  -> Dimension   -- ^ Window height
                  -> Dimension   -- ^ Border width
                  -> String      -- ^ Window background color
                  -> String      -- ^ Border color
                  -> String      -- ^ String color
                  -> String      -- ^ String background color
                  -> [Align]     -- ^ String 'Align'ments
                  -> [String]    -- ^ Strings to be printed
                  -> [Placement] -- ^ Icon 'Placements'
                  -> [[[Bool]]]  -- ^ Icons to be printed
                  -> X ()
paintTextAndIcons w fs wh ht bw bc borc ffc fbc als strs i_als icons = do
    d <- asks display
    strPositions <- forM (zip als strs) $ uncurry (stringPosition d fs (Rectangle 0 0 wh ht))
    let iconPositions = zipWith (iconPosition (Rectangle 0 0 wh ht)) i_als icons
        ms = Just (fs,ffc,fbc, zip strs strPositions)
        is = Just (ffc, fbc, zip iconPositions icons)
    paintWindow' w (Rectangle 0 0 wh ht) bw bc borc ms is

-- | The config for a window, as interpreted by 'showSimpleWindow'.
--
-- The font @winFont@ can either be specified in the TODO format or as an
-- xft font.  For example:
--
-- > winFont = "xft:monospace-20"
--
-- or
--
-- > winFont = "-misc-fixed-*-*-*-*-20-*-*-*-*-*-*-*"
data WindowConfig = WindowConfig
  { winFont :: !String      -- ^ Font to use.
  , winBg   :: !String      -- ^ Background color.
  , winFg   :: !String      -- ^ Foreground color.
  , winRect :: !WindowRect  -- ^ Position and size of the rectangle.
  }

instance Default WindowConfig where
  def = WindowConfig
    {
#ifdef XFT
      winFont = "xft:monospace-20"
#else
      winFont = "-misc-fixed-*-*-*-*-20-*-*-*-*-*-*-*"
#endif
    , winBg   = "black"
    , winFg   = "white"
    , winRect = CenterWindow
    }

-- | What kind of window we should be.
data WindowRect
  = CenterWindow         -- ^ Centered, big enough to fit all the text.
  | CustomRect Rectangle -- ^ Completely custom dimensions.

-- | Create a window, then fill and show it with the given text.  If you
-- are looking for a version of this function that also takes care of
-- destroying the window, refer to 'withSimpleWindow'.
showSimpleWindow :: WindowConfig -- ^ Window config.
                 -> [String]     -- ^ Lines of text to show.
                 -> X Window
showSimpleWindow WindowConfig{..} strs = do
  let pad = 20
  font <- initXMF winFont
  dpy  <- asks display
  Rectangle sx sy sw sh <- getRectangle winRect

  -- Text extents for centering all fonts
  extends <- maximum . map (uncurry (+)) <$> traverse (textExtentsXMF font) strs
  -- Height and width of entire window
  height <- pure . fi $ (1 + length strs) * fi extends
  width  <- (+ pad) . fi . maximum <$> traverse (textWidthXMF dpy font) strs

  let -- x and y coordinates that specify the upper left corner of the window
      x = sx + (fi sw - width  + 2) `div` 2
      y = sy + (fi sh - height + 2) `div` 2
      -- y position of first string
      yFirst = (height + 2 * extends) `div` fi (2 + length strs)
      -- (x starting, y starting) for all strings
      strPositions = map (pad `div` 2, ) [yFirst, yFirst + extends ..]

  w <- createNewWindow (Rectangle x y (fi width) (fi height)) Nothing "" True
  let ms = Just (font, winFg, winBg, zip strs strPositions)
  showWindow w
  paintWindow' w (Rectangle 0 0 (fi width) (fi height)) 0 winBg "" ms Nothing
  releaseXMF font
  pure w
 where
  getRectangle :: WindowRect -> X Rectangle
  getRectangle = \case
    CenterWindow -> gets $ screenRect . W.screenDetail . W.current . windowset
    CustomRect r -> pure r

-- | Like 'showSimpleWindow', but fully manage the window; i.e., destroy
-- it after the given function finishes its execution.
withSimpleWindow :: WindowConfig -> [String] -> X a -> X a
withSimpleWindow wc strs doStuff = do
  w <- showSimpleWindow wc strs
  doStuff <* deleteWindow w

-- | Show some lines of text until any key is pressed.
--
-- This is what the modules that reached for @xmessage@ want, and @xmessage@ is
-- an X11 client that will not be there.  Rather than shell out to something
-- else that might not be installed either, the window manager draws it, the
-- same way it draws a prompt.
--
-- Dismissal reuses the submap machinery with no keys in it: a submap that
-- recognises nothing takes the next key press, finds it unbound, and runs the
-- default action -- which here is to take the window away.  See
-- 'XMonad.River.submapNextKey'.
showMessageWindow :: WindowConfig -> [String] -> X ()
showMessageWindow wc strs = do
  w <- showSimpleWindow wc strs
  submapNextKey M.empty (deleteWindow w)

-- This stuff is not exported

-- | Paints a titlebar with some strings and icons
-- drawn inside it.
-- Not exported.
paintWindow' :: Window -> Rectangle -> Dimension -> String -> String
                -> Maybe (XMonadFont,String,String,[(String, (Position, Position))])
                -> Maybe (String, String, [((Position, Position), [[Bool]])]) -> X ()
paintWindow' win (Rectangle _ _ wh ht) bw color b_color strStuff iconStuff = do
  d  <- asks display
  shm <- asks riverShm
  -- Upstream composes into a pixmap and copies it over the window, so a
  -- partial repaint is never shown.  The same shape works here and costs
  -- nothing: a pixmap is a list of operations, and copying it is appending
  -- that list, so there is no offscreen buffer and no blit.
  p  <- io $ createPixmap wh ht
  gc <- io createGC

  [color', b_color'] <- mapM (stringToPixel d) [color, b_color]
  -- The border first, then the interior over it, exactly as upstream: a
  -- border is the part of the outer rectangle the inner one does not cover.
  io $ setForeground gc b_color'
  io $ fillRectangle p gc 0 0 wh ht
  io $ setForeground gc color'
  io $ fillRectangle p gc (fi bw) (fi bw) (wh - (bw * 2)) (ht - (bw * 2))

  whenJust strStuff $ \(xmf, fc, bc, strAndPos) ->
    forM_ strAndPos $ \(s, (x, y)) ->
        printStringXMF d p xmf gc fc bc x y s

  whenJust iconStuff $ \(fc, bc, iconAndPos) ->
    forM_ iconAndPos $ \((x, y), icon) ->
      drawIcon d p gc fc bc x y icon

  io $ copyArea p win 0 0
  io $ freePixmap p
  io $ freeGC gc
  mapM_ (\sh -> io (commitDrawable d sh win)) shm
