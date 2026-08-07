{-# LANGUAGE LambdaCase #-}
----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.River.Compat
-- Description :  The Xlib drawing vocabulary, over river surfaces and cairo.
-- License     :  BSD-style (see xmonad/LICENSE)
--
-- Enough of Xlib's drawing API to let "XMonad.Util.XUtils", "XMonad.Prompt",
-- "XMonad.Layout.Decoration" and their users keep the code they already have.
--
-- The names here are X11's on purpose, which is the opposite of the rule
-- xmonad-river follows.  The difference is that these are not pretending: each
-- one does what its X11 counterpart did, by a different route.  What is
-- reproduced is the /model/, not the implementation.
--
-- == Why this works at all
--
-- Two coincidences, and neither is luck:
--
-- * __A window-manager surface has an ObjectId, and so does a window.__ Under
--   river @Window@ /is/ @ObjectId@, and a @river_shell_surface_v1@ has one
--   too.  So 'createNewWindow' can hand back a real id and every
--   @Window@-typed signature in contrib survives untouched -- 'paintWindow',
--   @DecoWin@, all of it.  Which id belongs to which world is decided by the
--   registry below rather than by the type.
--
-- * __X11 drawing was always deferred.__ @drawImageString@ did not put pixels
--   on a screen; it queued a request on a connection that was flushed later.
--   Cairo insists drawing happen inside a live render context, which at first
--   looks incompatible with contrib's habit of painting a window in one
--   function and writing text into it in another.  It is not: operations are
--   accumulated per drawable and replayed inside 'renderWith' at commit.  That
--   is the same deferral X11 had, expressed differently.
--
-- The second point is what makes a compatible API possible.  Without it there
-- would be nowhere for @printStringXMF@ to draw.
--
-- == What is not reproduced
--
-- * Reading pixels back.  There is no @getImage@; nothing in contrib wants one.
-- * Event masks.  Accepted and ignored, as @clientMask@ already is.
-- * Errors surface at commit rather than at the call that caused them.
--
-----------------------------------------------------------------------------

module XMonad.Util.River.Compat
    ( -- * Drawables
      Drawable
    , Pixmap
    , Point(..)
    , EventMask
    , createDrawableWindow
    , createPixmap
    , freePixmap
    , destroyDrawable
    , mapDrawable
    , unmapDrawable
    , moveResizeDrawable
    , commitDrawable
    , drawableSize
    , isDrawable
      -- * Graphics contexts
    , GC
    , createGC
    , freeGC
    , setForeground
    , setBackground
    , gcForeground
    , gcBackground
      -- * Colours
    , Pixel
    , pixelFromString
    , pixelToColour
      -- * Drawing
    , fillRectangle
    , drawRectangle
    , copyArea
    , drawOn
    , renderDrawableInto
    ) where

import Control.Monad (forM_, when)
import Data.Bits (shiftL, shiftR, (.&.), (.|.))
import Data.IORef
import Data.Word (Word32, Word64)
import Graphics.Rendering.Cairo (Render)
import System.IO.Unsafe (unsafePerformIO)
import qualified Data.Map.Strict as M
import Foreign.Ptr (castPtr)
import Graphics.Rendering.Cairo (withImageSurfaceForData)
import qualified Graphics.Rendering.Cairo as C

import XMonad.River.Connection (Connection)
import XMonad.River.Types (Dimension, Position, Rectangle (..), Window)
import XMonad.River.Wire (ObjectId (..))
import qualified XMonad.River.Surface as R

import XMonad.River.Buffer (Buffer (..))
import XMonad.Util.River.Draw (Canvas (..), Colour, withCanvas)

-- | An event mask.
--
-- Present only so that 'XMonad.Util.XUtils.createNewWindow' keeps its
-- signature.  River delivers exactly the events the management protocol
-- defines and there is nothing to select, so a value of this type carries no
-- information and is always ignored -- the same treatment @clientMask@ and
-- @rootMask@ get, and for the same reason.
type EventMask = Word64

-- | A point, as X11 spelled it.
--
-- Two coordinates; it ports without argument.  Defined here rather than in
-- xmonad-river because nothing but drawing code uses it, and xmonad itself has
-- no drawing code.
data Point = Point { pt_x :: !Position, pt_y :: !Position }
  deriving (Eq, Show, Read)

-- | Something that can be drawn on.  A window or an offscreen pixmap, as in
-- X11, and as in X11 the same type.
type Drawable = Window

-- | An offscreen drawable.  Used by "XMonad.Prompt" and
-- "XMonad.Layout.DecorationEx.Engine" to compose a frame before showing it, so
-- the user never sees a half-drawn one.
type Pixmap = Drawable

-- | A packed colour.
--
-- X11's @Pixel@ was an index into a colormap, resolved by the server.  Wayland
-- has neither, so this is the colour itself: @0xAARRGGBB@.  Every contrib
-- caller obtains one from a string via @stringToPixel@, so nothing notices the
-- difference.
type Pixel = Word32

data Backing
  = OnScreen R.Surface
    -- ^ A real window-manager surface, which the compositor shows.
  | Offscreen
    -- ^ A pixmap.  It needs no buffer of its own: its operations are copied
    -- into another drawable by 'copyArea', and operations compose by
    -- concatenation.  Allocating shared memory for something never shown would
    -- be work with no purpose.

data DrawableState = DrawableState
  { dsBacking :: !Backing
  , dsRect    :: !(IORef Rectangle)
  , dsOps     :: !(IORef [Canvas -> Render ()])
    -- ^ Reversed: newest first, so appending is cheap and 'commitDrawable'
    -- pays the one reversal.
  , dsMapped  :: !(IORef Bool)
  }

-- | Every drawable the window manager owns, by id.
--
-- Global for the same reason X11's were server-side: 'printStringXMF' and
-- friends run in @MonadIO@ rather than @X@, so there is no reader to carry it
-- in, and an id has to be resolvable from anywhere it can be passed.
{-# NOINLINE drawables #-}
drawables :: IORef (M.Map ObjectId DrawableState)
drawables = unsafePerformIO (newIORef M.empty)

-- | Is this id one of ours, rather than a window some client owns?
--
-- The one question the type cannot answer.  Anything that would send a river
-- window request -- closing, focusing, laying out -- must ask first: a
-- decoration id reaching @river_window_v1.close@ is a protocol error, not a
-- no-op.
isDrawable :: Drawable -> IO Bool
isDrawable d = M.member d <$> readIORef drawables

lookupDrawable :: Drawable -> IO (Maybe DrawableState)
lookupDrawable d = M.lookup d <$> readIORef drawables

-- | Create a window-manager surface and register it as a drawable.
createDrawableWindow
  :: Connection -> ObjectId -> ObjectId -> Rectangle -> IO Drawable
createDrawableWindow conn compositor manager r = do
  surf <- R.newSurface conn compositor manager
  R.moveSurface conn surf (rect_x r) (rect_y r)
  rref <- newIORef r
  ops  <- newIORef []
  mref <- newIORef False
  let st = DrawableState (OnScreen surf) rref ops mref
      -- The shell surface's id is the drawable's id, so callers get something
      -- indistinguishable from a Window and every signature keeps working.
      oid = R.surfShell surf
  modifyIORef' drawables (M.insert oid st)
  pure oid

-- | An offscreen drawable of the given size.
--
-- The depth argument X11 required is gone: there is one format here, ARGB32.
createPixmap :: Dimension -> Dimension -> IO Pixmap
createPixmap w h = do
  rref <- newIORef (Rectangle 0 0 w h)
  ops  <- newIORef []
  mref <- newIORef False
  -- Ids for offscreen drawables come from a counter well above anything the
  -- compositor will allocate, so they cannot collide with a real object.
  oid <- atomicModifyIORef' pixmapCounter $ \(ObjectId n) -> (ObjectId (n + 1), ObjectId n)
  modifyIORef' drawables (M.insert oid (DrawableState Offscreen rref ops mref))
  pure oid

{-# NOINLINE pixmapCounter #-}
pixmapCounter :: IORef ObjectId
pixmapCounter = unsafePerformIO (newIORef (ObjectId 0xff000000))

freePixmap :: Pixmap -> IO ()
freePixmap = forget

-- | Drop a drawable, destroying its surface if it has one.
destroyDrawable :: Connection -> Drawable -> IO ()
destroyDrawable conn d = do
  lookupDrawable d >>= \case
    Just DrawableState { dsBacking = OnScreen surf } -> R.destroySurface conn surf
    _ -> pure ()
  forget d

forget :: Drawable -> IO ()
forget d = modifyIORef' drawables (M.delete d)

drawableSize :: Drawable -> IO (Maybe Rectangle)
drawableSize d = lookupDrawable d >>= traverse (readIORef . dsRect)

-- | Show a drawable.  Nothing appears until the next 'commitDrawable', because
-- a surface with no buffer attached is not mapped.
mapDrawable :: Drawable -> IO ()
mapDrawable d = withDrawable d $ \st -> writeIORef (dsMapped st) True

-- | Hide a drawable.
unmapDrawable :: Connection -> Drawable -> IO ()
unmapDrawable conn d = withDrawable d $ \st -> do
  writeIORef (dsMapped st) False
  case dsBacking st of
    -- Attaching a null buffer is how a wl_surface is unmapped.
    OnScreen surf -> R.hideSurface conn surf
    Offscreen -> pure ()

moveResizeDrawable :: Connection -> Drawable -> Rectangle -> IO ()
moveResizeDrawable conn d r = withDrawable d $ \st -> do
  writeIORef (dsRect st) r
  case dsBacking st of
    OnScreen surf -> R.moveSurface conn surf (rect_x r) (rect_y r)
    Offscreen -> pure ()

withDrawable :: Drawable -> (DrawableState -> IO ()) -> IO ()
withDrawable d k = lookupDrawable d >>= mapM_ k

-- | Queue a drawing operation.
--
-- This is the deferral the module header describes: nothing is rasterised
-- here, which is what lets a caller paint a window in one function and write
-- text into it in another.
-- Atomic because two threads reach it: a prompt builds its frame on its own
-- thread while the client thread drains the queue to present it.  Nothing else
-- in this module is concurrent, but this one operation is.
drawOn :: Drawable -> (Canvas -> Render ()) -> IO ()
drawOn d op = withDrawable d $ \st ->
  atomicModifyIORef' (dsOps st) $ \ops -> (op : ops, ())

-- | Replay everything queued and present the result.
--
-- The operation list is cleared, so a drawable that is painted every frame
-- does not accumulate.
commitDrawable :: Connection -> ObjectId -> Drawable -> IO ()
commitDrawable conn shm d = withDrawable d $ \st -> case dsBacking st of
  Offscreen -> pure ()   -- nothing to show; it exists to be copied
  OnScreen surf -> do
    shown <- readIORef (dsMapped st)
    when shown $ do
      ops <- atomicModifyIORef' (dsOps st) $ \os -> ([], reverse os)
      Rectangle _ _ w h <- readIORef (dsRect st)
      withCanvas conn surf shm (fromIntegral w) (fromIntegral h) $ \canvas ->
        forM_ ops ($ canvas)

-- | Copy one drawable onto another.
--
-- Operations compose by concatenation, so this appends the source's queue to
-- the destination's rather than moving pixels.  That is exactly what contrib
-- wants: every call site draws a frame into a pixmap and copies the whole
-- thing to a window at the origin, to avoid showing a partial repaint.
copyArea :: Drawable -> Drawable -> Position -> Position -> IO ()
copyArea src dst dx dy =
  withDrawable src $ \s -> withDrawable dst $ \t -> do
    ops <- reverse <$> readIORef (dsOps s)
    let shifted op canvas
          | dx == 0 && dy == 0 = op canvas
          | otherwise = do
              C.save
              C.translate (fromIntegral dx) (fromIntegral dy)
              op canvas
              C.restore
    modifyIORef' (dsOps t) (reverse (map shifted ops) ++)

-- | Replay a drawable's queued operations into a buffer of a client's own.
--
-- The bridge between the two ways a window manager can put something on the
-- screen.  Decorations use surfaces the window manager owns and commits
-- itself; a prompt is an ordinary Wayland client on its own connection,
-- because that is the only way to get real keyboard input, and it presents its
-- own buffers.  Both want the same drawing code, so a prompt builds its frame
-- in an offscreen drawable exactly as a decoration would and hands it here.
renderDrawableInto :: Drawable -> Buffer -> IO ()
renderDrawableInto d buf = withDrawable d $ \st -> do
  ops <- atomicModifyIORef' (dsOps st) $ \os -> ([], reverse os)
  withImageSurfaceForData (castPtr (bufPixels buf)) C.FormatARGB32
      (bufWidth buf) (bufHeight buf) (bufStride buf) $ \img ->
    C.renderWith img $
      forM_ ops ($ Canvas (bufWidth buf) (bufHeight buf))

--------------------------------------------------------------------------------
-- Graphics contexts

-- | A graphics context.
--
-- X11's was a server-side object holding everything a drawing call needed.
-- Contrib only ever sets three of its fields -- foreground, background and
-- font -- and cairo keeps that state in the render monad rather than in an
-- object, so this is just somewhere to put them between the call that sets one
-- and the call that reads it.
newtype GC = GC (IORef (Pixel, Pixel))

createGC :: IO GC
createGC = GC <$> newIORef (0xff000000, 0xffffffff)

-- | Nothing to release; kept so call sites need not change.
freeGC :: GC -> IO ()
freeGC _ = pure ()

setForeground :: GC -> Pixel -> IO ()
setForeground (GC r) p = modifyIORef' r (\(_, b) -> (p, b))

setBackground :: GC -> Pixel -> IO ()
setBackground (GC r) p = modifyIORef' r (\(f, _) -> (f, p))

gcForeground :: GC -> IO Pixel
gcForeground (GC r) = fst <$> readIORef r

gcBackground :: GC -> IO Pixel
gcBackground (GC r) = snd <$> readIORef r

--------------------------------------------------------------------------------
-- Colours

-- | @0xAARRGGBB@ from @\"#rrggbb\"@, defaulting to opaque.
pixelFromString :: Colour -> Pixel
pixelFromString (r, g, b, a) =
  (chan a `shiftL` 24) .|. (chan r `shiftL` 16) .|. (chan g `shiftL` 8) .|. chan b
  where chan v = round (v * 255) .&. 0xff

pixelToColour :: Pixel -> Colour
pixelToColour p =
  ( f ((p `shiftR` 16) .&. 0xff)
  , f ((p `shiftR` 8) .&. 0xff)
  , f (p .&. 0xff)
  , let a = (p `shiftR` 24) .&. 0xff
        -- A Pixel with no alpha channel set is opaque, not invisible.  X11
        -- pixels had no alpha at all, so a config that computed one by hand
        -- will have left the top byte clear.
    in if a == 0 then 1 else f a
  )
  where f v = fromIntegral v / 255

--------------------------------------------------------------------------------
-- Drawing primitives

fillRectangle :: Drawable -> GC -> Position -> Position -> Dimension -> Dimension -> IO ()
fillRectangle d gc x y w h = do
  col <- pixelToColour <$> gcForeground gc
  drawOn d $ \_ -> rect col x y w h True

drawRectangle :: Drawable -> GC -> Position -> Position -> Dimension -> Dimension -> IO ()
drawRectangle d gc x y w h = do
  col <- pixelToColour <$> gcForeground gc
  drawOn d $ \_ -> rect col x y w h False

rect :: Colour -> Position -> Position -> Dimension -> Dimension -> Bool -> Render ()
rect (r, g, b, a) x y w h filled = do
  C.setSourceRGBA r g b a
  C.rectangle (fromIntegral x) (fromIntegral y) (fromIntegral w) (fromIntegral h)
  if filled then C.fill else C.setLineWidth 1 >> C.stroke
