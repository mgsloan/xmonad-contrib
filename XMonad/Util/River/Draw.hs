----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.River.Draw
-- Description :  Drawing on window-manager surfaces, over cairo and pango.
-- License     :  BSD-style (see xmonad/LICENSE)
--
-- The river replacement for the Xlib drawing that "XMonad.Util.Font" and
-- "XMonad.Util.XUtils" are built on.
--
-- Why this lives in xmonad-contrib rather than in xmonad itself: upstream
-- xmonad has no font or graphics-context code at all -- @Util.Font@,
-- @Decoration@ and @Prompt@ are all contrib's, and contrib already keeps its
-- X11 text dependency behind the @use_xft@ flag.  The river split is the same
-- one.  xmonad-river stops at @XMonad.River.Surface@, which hands out a
-- surface and a block of ARGB32 pixels; everything above that -- cairo, pango,
-- and the C libraries they bind -- is here, so a config with no prompts and no
-- decorations never links them.
--
-- The fit is unusually good.  A @wl_shm@ buffer is a caller-owned block of
-- premultiplied ARGB32, and that is precisely what
-- 'withImageSurfaceForData' wants, so cairo draws straight into the memory the
-- compositor will read.  There is no intermediate image and no format
-- conversion anywhere in the path.
--
-----------------------------------------------------------------------------

module XMonad.Util.River.Draw
    ( -- * Fonts
      Font(..)
    , parseFont
    , measureText
    , fontMetrics
      -- * Drawing
    , Canvas(..)
    , withCanvas
    , fillCanvas
    , drawText
      -- * Colours
    , Colour
    , parseColour
    ) where

import Control.Monad.IO.Class (MonadIO)
import Data.Char (isDigit, isSpace)
import Foreign.Ptr (castPtr)
import Graphics.Rendering.Cairo
import qualified Graphics.Rendering.Pango as P

import XMonad.River.Buffer (Buffer (..))
import XMonad.River.Connection (Connection)
import qualified XMonad.River.Surface as R
import XMonad.River.Wire (ObjectId)

-- | A resolved font.
--
-- Pango descriptions are cheap to build and immutable, so unlike an X11
-- @FontStruct@ there is nothing to open and nothing to release.  That is why
-- @releaseXMF@ has nothing to do under river.
newtype Font = Font P.FontDescription

-- | Parse a font description.
--
-- Accepts pango's own syntax (@\"Sans Bold 12\"@) and the two spellings
-- xmonad configs actually contain, because a config should not have to be
-- rewritten to move backends:
--
-- * @\"xft:Sans-12\"@ -- the Xft form, by far the most common in the wild.
--   The @xft:@ prefix is dropped and the final @-12@ read as a size.
--
-- * An X Logical Font Description, @\"-*-fixed-medium-r-normal-*-13-...\"@.
--   These name a bitmap font that does not exist under Wayland and cannot be
--   translated, so they fall back to a default of the same rough size.  A
--   silent fallback is right here: the alternative is a window manager that
--   refuses to start because a decoration asked for a font from 1987.
parseFont :: MonadIO m => String -> m Font
parseFont s = liftIO (Font <$> P.fontDescriptionFromString (normalise s))
  where
    normalise str
      | "xft:" `isPrefix` str = xftToPango (drop 4 str)
      | take 1 str == "-"     = "Sans " ++ xlfdSize str
      | null (trim str)       = "Sans 10"
      | otherwise             = str

    isPrefix p str = take (length p) str == p
    trim = dropWhile isSpace . reverse . dropWhile isSpace . reverse

    -- "Sans-12:bold" -> "Sans bold 12".  Xft separates family from size with a
    -- dash and options with colons; pango wants them space separated with the
    -- size last.
    xftToPango str =
      let (before, opts) = break (== ':') str
          styles = [ w | o <- splitOn ':' (drop 1 opts)
                       , let w = takeWhile (/= '=') o
                       , w `elem` ["bold", "italic", "oblique", "light"] ]
      in case breakLast '-' before of
           Just (family, size) | all isDigit size && not (null size) ->
             unwords ([family] ++ styles ++ [size])
           _ -> unwords (before : styles)

    -- An XLFD's pixel size is the 7th dash-separated field.
    xlfdSize str = case drop 7 (splitOn '-' str) of
      (px:_) | all isDigit px, not (null px) -> px
      _ -> "10"

    splitOn c str = case break (== c) str of
      (w, [])     -> [w]
      (w, _:rest) -> w : splitOn c rest

    breakLast c str = case break (== c) (reverse str) of
      (_, [])       -> Nothing
      (rs, _:rrest) -> Just (reverse rrest, reverse rs)

-- | Width and height of a string, in pixels.
--
-- Measuring needs a pango context, and creating one needs a cairo surface, so
-- this renders onto a 1x1 scratch surface.  Cheap: nothing is rasterised,
-- because pango lays the text out and reports its extents without ever being
-- asked to draw it.
measureText :: MonadIO m => Font -> String -> m (Int, Int)
measureText (Font fd) str = liftIO $
  withImageSurface FormatARGB32 1 1 $ \surf ->
    renderWith surf $ do
      lay <- P.createLayout str
      liftIO $ do
        P.layoutSetFontDescription lay (Just fd)
        (_, P.PangoRectangle _ _ w h) <- P.layoutGetExtents lay
        pure (ceiling w, ceiling h)

-- | Ascent and descent of a font, in pixels.
--
-- Of the font as a whole rather than of any particular string, which is what
-- callers laying out a row of decorations want: every tab in a bar has to
-- share a baseline regardless of whether its title happens to contain a
-- descender.
fontMetrics :: MonadIO m => Font -> m (Int, Int)
fontMetrics (Font fd) = liftIO $
  withImageSurface FormatARGB32 1 1 $ \surf ->
    renderWith surf $ liftIO $ do
      ctx <- P.cairoCreateContext Nothing
      metrics <- P.contextGetMetrics ctx fd P.emptyLanguage
      pure ( ceiling (P.ascent metrics), ceiling (P.descent metrics) )

-- | An RGBA colour, each channel in @[0,1]@ as cairo takes it.
type Colour = (Double, Double, Double, Double)

-- | Parse @\"#rrggbb\"@ or @\"#rrggbbaa\"@.
--
-- Unlike X11 there is no colour name database to fall back on: Wayland has no
-- colormap and no server to ask, so @\"red\"@ cannot be resolved.  A handful of
-- names configs actually use are recognised anyway, and anything else becomes
-- opaque black rather than an error -- a typo in a config should not stop the
-- window manager starting.
parseColour :: String -> Colour
parseColour ('#':rest) = case rest of
  [r1,r2,g1,g2,b1,b2]       -> rgba (hex2 r1 r2) (hex2 g1 g2) (hex2 b1 b2) 255
  [r1,r2,g1,g2,b1,b2,a1,a2] -> rgba (hex2 r1 r2) (hex2 g1 g2) (hex2 b1 b2) (hex2 a1 a2)
  [r,g,b]                   -> rgba (hex1 r) (hex1 g) (hex1 b) 255
  _                         -> (0, 0, 0, 1)
  where
    rgba :: Int -> Int -> Int -> Int -> Colour
    rgba r g b a = (f r, f g, f b, f a)
    f :: Int -> Double
    f v = fromIntegral v / 255
    hex1 c = let v = hexDigit c in v * 16 + v
    hex2 a b = hexDigit a * 16 + hexDigit b
parseColour name = case lookup name named of
  Just c  -> c
  Nothing -> (0, 0, 0, 1)
  where
    named =
      [ ("black", (0,0,0,1)), ("white", (1,1,1,1))
      , ("red", (1,0,0,1)), ("green", (0,1,0,1)), ("blue", (0,0,1,1))
      , ("cyan", (0,1,1,1)), ("magenta", (1,0,1,1)), ("yellow", (1,1,0,1))
      , ("gray", (0.5,0.5,0.5,1)), ("grey", (0.5,0.5,0.5,1))
      ]

hexDigit :: Char -> Int
hexDigit c
  | c >= '0' && c <= '9' = fromEnum c - fromEnum '0'
  | c >= 'a' && c <= 'f' = fromEnum c - fromEnum 'a' + 10
  | c >= 'A' && c <= 'F' = fromEnum c - fromEnum 'A' + 10
  | otherwise = 0

-- | A surface being drawn, with its dimensions.
--
-- This is the river analogue of the @(Drawable, GC)@ pair Xlib drawing passes
-- around.  It carries no colours or line widths, because cairo keeps that
-- state in the 'Render' monad rather than in a server-side object.
data Canvas = Canvas
  { canvasWidth  :: !Int
  , canvasHeight :: !Int
  }

-- | Draw onto a window-manager surface at the given size, then present it.
--
-- Cairo is pointed straight at the buffer's mapped pixels, so what the
-- 'Render' action writes is what the compositor reads -- no copy, no
-- conversion.
withCanvas
  :: Connection -> R.Surface -> ObjectId -> Int -> Int
  -> (Canvas -> Render a) -> IO a
withCanvas conn surface shm width height draw =
  R.withSurfaceBuffer conn surface shm width height $ \buf ->
    -- Word8 and CUChar are the same byte; cairo's PixelData just spells it
    -- the C way.
    withImageSurfaceForData (castPtr (bufPixels buf)) FormatARGB32
        (bufWidth buf) (bufHeight buf) (bufStride buf) $ \img ->
      renderWith img (draw (Canvas (bufWidth buf) (bufHeight buf)))

-- | Fill the whole canvas with one colour.
fillCanvas :: Colour -> Canvas -> Render ()
fillCanvas (r, g, b, a) _ = do
  setOperator OperatorSource   -- replace rather than blend over stale pixels
  setSourceRGBA r g b a
  paint
  setOperator OperatorOver

-- | Draw a string with its top-left corner at the given position.
drawText :: Font -> Colour -> Int -> Int -> String -> Render ()
drawText (Font fd) (r, g, b, a) x y str = do
  setSourceRGBA r g b a
  lay <- P.createLayout str
  liftIO $ P.layoutSetFontDescription lay (Just fd)
  moveTo (fromIntegral x) (fromIntegral y)
  P.showLayout lay
