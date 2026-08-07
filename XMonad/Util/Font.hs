----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.Font
-- Description :  A module for abstracting a font facility, over pango.
-- Copyright   :  (c) 2007 Andrea Rossato and Spencer Janssen
-- License     :  BSD-style (see xmonad/LICENSE)
--
-- Maintainer  :  andrea.rossato@unibz.it
-- Stability   :  unstable
-- Portability :  unportable
--
-- The river implementation.  Upstream abstracts over X core fonts and Xft;
-- there is one backend here, pango, because Wayland has no font server to
-- choose between.  Every exported signature is upstream's, so callers --
-- "XMonad.Layout.Decoration", "XMonad.Prompt", "XMonad.Actions.GridSelect" and
-- the rest -- need no changes.
--
-- Two of upstream's exports are gone rather than stubbed:
-- @initCoreFont@\/@releaseCoreFont@ and @initUtf8Font@\/@releaseUtf8Font@
-- return an X11 @FontStruct@ and @FontSet@, which name server-side objects
-- that do not exist here and cannot be faked into existence.  'initXMF' is
-- what everything actually calls.
--
-----------------------------------------------------------------------------

module XMonad.Util.Font
    ( -- * Usage:
      -- $usage
      XMonadFont(..)
    , initXMF
    , releaseXMF
    , Align (..)
    , stringPosition
    , textWidthXMF
    , textExtentsXMF
    , printStringXMF
    , stringToPixel
    , pixelToString
    , fi
    ) where

import XMonad
import XMonad.Prelude
import Data.Int (Int32)
import Text.Printf (printf)

import XMonad.Util.River.Compat
    (Drawable, GC, Pixel, drawOn, gcBackground, pixelFromString, pixelToColour)
import qualified XMonad.Util.River.Draw as D

-- | A font, as pango understands it.
--
-- One constructor where upstream has three.  Pango descriptions are immutable
-- and cheap, so unlike an X11 @FontStruct@ there is nothing to open and
-- nothing to release -- which is why 'releaseXMF' has nothing to do.
newtype XMonadFont = XMonadFont D.Font

-- $usage
-- See "XMonad.Layout.Tabbed" or "XMonad.Prompt" for usage examples

-- | Get the Pixel value for a named color: if an invalid name is
-- given the black pixel will be returned.
--
-- Under X11 this asked the server to resolve the name against a colormap.
-- There is no server and no colormap here, so the string is parsed directly;
-- see 'XMonad.Util.River.Draw.parseColour' for which names survive.
stringToPixel :: (Functor m, MonadIO m) => Display -> String -> m Pixel
stringToPixel _ s = pure (pixelFromString (D.parseColour s))

-- | Convert a @Pixel@ into a @String@.
--
-- Upstream drops the alpha channel here, because X11 mishandles it and
-- produces black.  That is an X server bug rather than a property of colour,
-- and it does not apply: the channel is kept.
pixelToString :: (MonadIO m) => Display -> Pixel -> m String
pixelToString _ p =
  let (r, g, b, _) = pixelToColour p
  in pure (printf "#%02x%02x%02x" (ch r) (ch g) (ch b))
  where
    ch :: Double -> Int
    ch v = round (v * 255)

-- | Get a font.
--
-- Accepts pango's own syntax, the @xft:@ spelling most configs contain, and an
-- XLFD -- which names a bitmap font that does not exist under Wayland and so
-- falls back to a default of the same rough size.  Silently, because a window
-- manager that refuses to start over a decoration's font choice is worse than
-- one that picks a reasonable substitute.
initXMF :: String -> X XMonadFont
initXMF s = XMonadFont <$> D.parseFont s

-- | Nothing to release.  Kept so call sites need not change.
releaseXMF :: XMonadFont -> X ()
releaseXMF _ = pure ()

textWidthXMF :: MonadIO m => Display -> XMonadFont -> String -> m Int
textWidthXMF _ (XMonadFont f) s = fst <$> D.measureText f s

-- | Ascent and descent.
--
-- Of the font rather than of the string, which is what callers laying out a
-- row of decorations need: every tab in a bar has to share a baseline whether
-- or not its title happens to contain a descender.
textExtentsXMF :: MonadIO m => XMonadFont -> String -> m (Int32, Int32)
textExtentsXMF (XMonadFont f) _ = do
  (a, d) <- D.fontMetrics f
  pure (fi a, fi d)

-- | String position
data Align = AlignCenter | AlignRight | AlignLeft | AlignRightOffset Int
                deriving (Show, Read)

-- | Return the string x and y 'Position' in a 'Rectangle', given a
-- font and the 'Align'ment.
--
-- Unchanged from upstream: it is arithmetic over measurements, and the
-- measurements now come from pango.
stringPosition :: (Functor m, MonadIO m) => Display -> XMonadFont -> Rectangle -> Align -> String -> m (Position,Position)
stringPosition dpy fs (Rectangle _ _ w h) al s = do
  width <- textWidthXMF dpy fs s
  (a,d) <- textExtentsXMF fs s
  let y = fi $ ((h - fi (a + d)) `div` 2) + fi a
      x = case al of
            AlignCenter -> fi (w `div` 2) - fi (width `div` 2)
            AlignLeft   -> 1
            AlignRight  -> fi (w - (fi width + 1))
            AlignRightOffset offset -> fi (w - (fi width + 1)) - fi offset
  return (x,y)

-- | Draw a string on a drawable.
--
-- The @y@ upstream passes is a baseline, because that is what
-- @drawImageString@ took; pango positions a layout by its top-left corner, so
-- the ascent is subtracted here.  Getting this wrong shifts every decoration's
-- text down by most of a line, which is the sort of thing that looks like a
-- font problem and is not.
--
-- Nothing is rasterised now.  The operation is queued on the drawable and
-- replayed when it is committed, which is what lets a caller paint a window in
-- one function and write into it in another -- exactly as an unflushed X
-- connection behaved.
printStringXMF :: (Functor m, MonadIO m) => Display -> Drawable -> XMonadFont -> GC -> String -> String
            -> Position -> Position -> String  -> m ()
printStringXMF _ d (XMonadFont f) gc fc bc x y s = io $ do
  (w, h) <- D.measureText f s
  (a, _) <- D.fontMetrics f
  let fg = D.parseColour fc
      top = fromIntegral y - a
  -- drawImageString filled the background behind the text; a bare drawString
  -- did not.  Callers rely on the filling version, so the rectangle goes down
  -- first -- and the background colour comes from the argument rather than the
  -- GC, matching upstream, which sets both and then uses the image variant.
  bgPixel <- gcBackground gc
  let bg = if null bc then pixelToColour bgPixel else D.parseColour bc
  drawOn d $ \_ -> do
    D.fillRect bg (fromIntegral x) top w h
    D.drawText f fg (fromIntegral x) top s
