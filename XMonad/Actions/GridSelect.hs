{-# LANGUAGE ScopedTypeVariables, GeneralizedNewtypeDeriving, FlexibleInstances, TupleSections, LambdaCase #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Actions.GridSelect
-- Description :  Display items in a 2D grid and select from it with the keyboard or the mouse.
-- Copyright   :  Clemens Fruhwirth <clemens@endorphin.org>
-- License     :  BSD-style (see LICENSE)
--
-- Maintainer  :  Clemens Fruhwirth <clemens@endorphin.org>
-- Stability   :  unstable
-- Portability :  unportable
--
-- GridSelect displays items(e.g. the opened windows) in a 2D grid and lets
-- the user select from it with the cursor/hjkl keys or the mouse.
--
-----------------------------------------------------------------------------

module XMonad.Actions.GridSelect (
    -- * Usage
    -- $usage

    -- ** Customizing
    -- *** Using a common GSConfig
    -- $commonGSConfig

    -- *** Custom keybindings
    -- $keybindings

    -- * Configuration
    GSConfig(..),
    def,
    TwoDPosition,
    buildDefaultGSConfig,

    -- * Variations on 'gridselect'
    gridselect,
    gridselectWindow,
    withSelectedWindow,
    bringSelected,
    goToSelected,
    gridselectWorkspace,
    gridselectWorkspace',
    spawnSelected,
    runSelectedAction,

    -- * Colorizers
    HasColorizer(defaultColorizer),
    fromClassName,
    stringColorizer,
    colorRangeFromClassName,
    stringToRatio,

    -- * Navigation Mode assembly
    TwoD,
    Navigation(..),
    shadowWithKeymap,

    -- * Built-in Navigation Mode
    defaultNavigation,
    substringSearch,
    navNSearch,

    -- * Navigation Components
    setPos,
    move,
    moveNext, movePrev,
    select,
    cancel,
    transformSearchString,

    -- * Rearrangers
    -- $rearrangers
    Rearranger,
    noRearranger,
    searchStringRearrangerGenerator,

    -- * Screenshots
    -- $screenshots

    -- * Types
    TwoDState,
    ) where
import Control.Arrow ((***))
import Data.Ord (comparing)
import Control.Monad.State
import Data.List as L
import qualified Data.Map as M
import Data.IORef
import XMonad hiding (liftX)
import XMonad.Prelude
import XMonad.Util.Font
import XMonad.River (postAction)
import XMonad.River.Client (Anchor (AnchorCentre), ClientHandle (..),
                            ClientSpec (..), startClient)
import XMonad.Util.River.Compat (Drawable, GC, createGC, createPixmap,
                                 drawRectangle, fillRectangle, freeGC,
                                 freePixmap, renderDrawableInto, setBackground,
                                 setForeground)
import XMonad.StackSet as W
import XMonad.Layout.Decoration
import XMonad.Util.NamedWindows
import XMonad.Actions.WindowBringer (bringWindow)
import Text.Printf
import System.Random (mkStdGen, randomR)
import Data.Word (Word8)
import qualified Data.List.NonEmpty as NE

-- $usage
--
-- You can use this module with the following in your @xmonad.hs@:
--
-- >    import XMonad.Actions.GridSelect
--
-- Then add a keybinding, e.g.
--
-- >    , ((modm, xK_g), goToSelected def)
--
-- This module also supports displaying arbitrary information in a grid and letting
-- the user select from it. E.g. to spawn an application from a given list, you
-- can use the following:
--
-- >   , ((modm, xK_s), spawnSelected def ["xterm","gmplayer","gvim"])

-- $commonGSConfig
--
-- It is possible to bind a @gsconfig@ at top-level in your configuration. Like so:
--
-- > -- the top of your config
-- > {-# LANGUAGE NoMonomorphismRestriction #-}
-- > import XMonad
-- > ...
-- > gsconfig1 = def { gs_cellheight = 30, gs_cellwidth = 100 }
--
-- An example where 'buildDefaultGSConfig' is used instead of 'def'
-- in order to specify a custom colorizer is @gsconfig2@ (found in
-- "XMonad.Actions.GridSelect#Colorizers"):
--
-- > gsconfig2 colorizer = (buildDefaultGSConfig colorizer) { gs_cellheight = 30, gs_cellwidth = 100 }
--
-- > -- | A green monochrome colorizer based on window class
-- > greenColorizer = colorRangeFromClassName
-- >                      black            -- lowest inactive bg
-- >                      (0x70,0xFF,0x70) -- highest inactive bg
-- >                      black            -- active bg
-- >                      white            -- inactive fg
-- >                      white            -- active fg
-- >   where black = minBound
-- >         white = maxBound
--
-- Then you can bind to:
--
-- >     ,((modm, xK_g), goToSelected $ gsconfig2 myWinColorizer)
-- >     ,((modm, xK_p), spawnSelected (gsconfig2 defaultColorizer) ["xterm","gvim"])

-- $keybindings
--
-- You can build you own navigation mode and submodes by combining the
-- exported action ingredients and assembling them using 'shadowWithKeymap'.
--
-- > myNavigation :: (KeySym, String, KeyMask) -> TwoD a (Navigation a)
-- > myNavigation = shadowWithKeymap navKeyMap navDefaultHandler
-- >  where navKeyMap = M.fromList [
-- >           ((0,xK_Escape), cancel)
-- >          ,((0,xK_Return), select)
-- >          ,((0,xK_Left)  , move (-1,0)  >> pure Continue)
-- >          ,((0,xK_h)     , move (-1,0)  >> pure Continue)
-- >          ,((0,xK_Right) , move (1,0)   >> pure Continue)
-- >          ,((0,xK_l)     , move (1,0)   >> pure Continue)
-- >          ,((0,xK_Down)  , move (0,1)   >> pure Continue)
-- >          ,((0,xK_j)     , move (0,1)   >> pure Continue)
-- >          ,((0,xK_Up)    , move (0,-1)  >> pure Continue)
-- >          ,((0,xK_y)     , move (-1,-1) >> pure Continue)
-- >          ,((0,xK_i)     , move (1,-1)  >> pure Continue)
-- >          ,((0,xK_n)     , move (-1,1)  >> pure Continue)
-- >          ,((0,xK_m)     , move (1,-1)  >> pure Continue)
-- >          ,((0,xK_space) , setPos (0,0) >> pure Continue)
-- >          ]
-- >        -- The navigation handler ignores unknown key symbols
-- >        navDefaultHandler = const (pure Continue)
--
-- Upstream, each entry ends by recursing into @myNavigation@ and the whole
-- thing is wrapped in @makeXEventhandler@, because there the navigation /is/
-- the event loop. Here the backend calls it once per key, so an entry says
-- what to do and then says whether to carry on. Converting a navigation
-- written for upstream is that substitution and nothing else -- except that
-- @substringSearch@ is entered by the built-in navigations rather than by
-- calling it directly, since a submode is now state rather than a nested
-- loop.
--
-- You can then define @gsconfig3@ which may be used in exactly the same manner as @gsconfig1@:
--
-- > gsconfig3 = def
-- >    { gs_cellheight = 30
-- >    , gs_cellwidth = 100
-- >    , gs_navigate = myNavigation
-- >    }

-- $screenshots
--
-- Selecting a workspace:
--
-- <<http://haskell.org/wikiupload/a/a9/Xmonad-gridselect-workspace.png>>
--
-- Selecting a window by title:
--
-- <<http://haskell.org/wikiupload/3/35/Xmonad-gridselect-window-aavogt.png>>

-- | The 'Default' instance gives a basic configuration for 'gridselect', with
-- the colorizer chosen based on the type.
--
-- If you want to replace the 'gs_colorizer' field, use 'buildDefaultGSConfig'
-- instead of 'def' to avoid ambiguous type variables.
data GSConfig a = GSConfig {
      gs_cellheight :: Integer,
      gs_cellwidth :: Integer,
      gs_cellpadding :: Integer,
      gs_colorizer :: a -> Bool -> X (String, String),
      gs_font :: String,
      gs_navigate :: (KeySym, String, KeyMask) -> TwoD a (Navigation a),
      -- ^ Customize key bindings for a GridSelect.
      --
      -- Upstream this is @TwoD a (Maybe a)@ -- the whole event loop, supplied
      -- by the config, each keymap entry ending by recursing into it.  It
      -- cannot be a loop here: nothing may block the window manager's thread,
      -- and a key cannot even arrive until the action that opened the grid has
      -- returned.  So this is the handler for /one/ key, and it says whether
      -- to carry on; see 'Navigation'.  Converting a custom navigation is
      -- mechanical -- drop the @>> myNavigation@ tail from each entry and end
      -- it @>> pure Continue@ instead.
      gs_rearranger :: Rearranger a,
      gs_originFractX :: Double,
      gs_originFractY :: Double,
      gs_bordercolor :: String
      -- Upstream also has gs_cancelOnEmptyClick, for a click that lands on no
      -- cell.  There are no clicks: the grid is a layer surface the window
      -- manager drew, and river reports button presses against windows it
      -- manages, so it attributes a click on the grid to nothing.  The field
      -- is gone rather than ignored -- see XMonad.Layout.Decoration's
      -- handleMouseFocusDrag, which is the same wall.
}

-- | What a key handler says should happen next.
--
-- Upstream says this with @Maybe a@ returned from a loop: returning at all
-- ends the grid, @Just@ selects and @Nothing@ cancels, and "keep going" is
-- expressed by not returning -- by recursing into the loop instead.  With the
-- loop inverted there is no recursion to stand for it, so it gets a
-- constructor.
data Navigation a
    = Continue    -- ^ Stay open and wait for the next key.
    | Cancel      -- ^ Close, selecting nothing.
    | Select a    -- ^ Close, selecting this element.

-- | That is 'fromClassName' if you are selecting a 'Window', or
-- 'defaultColorizer' if you are selecting a 'String'. The catch-all instance
-- @HasColorizer a@ uses the 'focusedBorderColor' and 'normalBorderColor'
-- colors.
class HasColorizer a where
    defaultColorizer :: a -> Bool -> X (String, String)

instance HasColorizer Window where
    defaultColorizer = fromClassName

instance HasColorizer String where
    defaultColorizer = stringColorizer

instance {-# OVERLAPPABLE #-} HasColorizer a where
    defaultColorizer _ isFg =
        let getColor = if isFg then focusedBorderColor else normalBorderColor
        in asks $ (, "black") . getColor . config

instance HasColorizer a => Default (GSConfig a) where
    def = buildDefaultGSConfig defaultColorizer

type TwoDPosition = (Integer, Integer)

type TwoDElementMap a = [(TwoDPosition,(String,a))]

data TwoDState a = TwoDState { td_curpos :: TwoDPosition
                             , td_availSlots :: [TwoDPosition]
                             , td_elements :: [(String,a)]
                             , td_gsconfig :: GSConfig a
                             , td_font :: XMonadFont
                             , td_paneX :: Integer
                             , td_paneY :: Integer
                             , td_frame :: Drawable
                               -- ^ The offscreen drawable the grid is composed
                               -- in, replayed into the client's buffer on
                               -- every redraw.  Upstream draws straight onto
                               -- an override-redirect window; a surface here
                               -- belongs to a client on its own connection,
                               -- and this is where the two meet.  Same
                               -- arrangement "XMonad.Prompt" uses.
                             , td_gc :: GC
                             , td_searchString :: String
                             , td_searching :: Bool
                               -- ^ Whether the substring-search submode is
                               -- active.  Upstream expresses the submode by
                               -- being inside a second, nested event loop;
                               -- with one handler per key there is no nesting
                               -- to be inside, so the mode is state.
                             , td_elementmap :: TwoDElementMap a
                             }

generateElementmap :: TwoDState a -> X (TwoDElementMap a)
generateElementmap s = do
    rearrangedElements <- rearranger searchString sortedElements
    return $ zip positions rearrangedElements
  where
    TwoDState {td_availSlots = positions,
               td_gsconfig = gsconfig,
               td_searchString = searchString} = s
    GSConfig {gs_rearranger = rearranger} = gsconfig
    -- Filter out any elements that don't contain the searchString (case insensitive)
    filteredElements = L.filter ((searchString `isInfixOfI`) . fst) (td_elements s)
    -- Sorts the elementmap
    sortedElements = orderElementmap searchString filteredElements
    -- Case Insensitive version of isInfixOf
    needle `isInfixOfI` haystack = upper needle `isInfixOf` upper haystack
    upper = map toUpper


-- | We enforce an ordering such that we will always get the same result. If the
-- elements position changes from call to call of gridselect, then the shown
-- positions will also change when you search for the same string. This is
-- especially the case when using gridselect for showing and switching between
-- workspaces, as workspaces are usually shown in order of last visited.  The
-- chosen ordering is "how deep in the haystack the needle is" (number of
-- characters from the beginning of the string and the needle).
orderElementmap :: String  -> [(String,a)] -> [(String,a)]
orderElementmap searchString elements = if not $ null searchString then sortedElements else elements
  where
    upper = map toUpper
    -- Calculates a (score, element) tuple where the score is the depth of the (case insensitive) needle.
    calcScore element = ( length $ takeWhile (not . isPrefixOf (upper searchString)) (tails . upper . fst $ element)
                        , element)
    -- Use the score and then the string as the parameters for comparing, making
    -- it consistent even when two strings that score the same, as it will then be
    -- sorted by the strings, making it consistent.
    compareScore = comparing (\(score, (str,_)) -> (score, str))
    sortedElements = map snd . sortBy compareScore $ map calcScore elements


newtype TwoD a b = TwoD { unTwoD :: StateT (TwoDState a) X b }
    deriving (Functor, Applicative, Monad, MonadState (TwoDState a))

liftX ::  X a1 -> TwoD a a1
liftX = TwoD . lift

diamondLayer :: (Enum a, Num a, Eq a) => a -> [(a, a)]
diamondLayer 0 = [(0,0)]
diamondLayer n =
  -- tr = top right
  --  r = ur ++ 90 degree clock-wise rotation of ur
  let tr = [ (x,n-x) | x <- [0..n-1] ]
      r  = tr ++ map (\(x,y) -> (y,-x)) tr
  in r ++ map (negate *** negate) r

diamond :: (Enum a, Num a, Eq a) => Stream (a, a)
diamond = fromList $ concatMap diamondLayer [0..]

diamondRestrict :: Integer -> Integer -> Integer -> Integer -> [(Integer, Integer)]
diamondRestrict x y originX originY =
  L.filter (\(x',y') -> abs x' <= x && abs y' <= y) .
  map (\(x', y') -> (x' + fromInteger originX, y' + fromInteger originY)) .
  takeS 1000 $ diamond

findInElementMap :: (Eq a) => a -> [(a, b)] -> Maybe (a, b)
findInElementMap pos = find ((== pos) . fst)

-- | Draw one cell into the offscreen frame.
--
-- No 'withDisplay': "XMonad.Util.River.Compat" takes no @Display@, because
-- there is no server to send to -- an operation is recorded against the
-- drawable and replayed when the frame is presented.  'initColor' is gone with
-- the colormap it allocated against; 'stringToPixel' answers the same
-- question, which is all any caller ever wanted from it.
drawWinBox :: Drawable -> XMonadFont -> (String, String) -> String -> Integer -> Integer -> String -> Integer -> Integer -> Integer -> X ()
drawWinBox win font (fg,bg) bc ch cw text x y cp =
  withDisplay $ \dpy -> do
  gc <- io createGC
  bordergc <- io createGC
  fgcolor <- stringToPixel dpy fg
  bgcolor <- stringToPixel dpy bg
  bordercolor <- stringToPixel dpy bc
  io $ do
    setForeground gc fgcolor
    setBackground gc bgcolor
    setForeground bordergc bordercolor
    fillRectangle win gc (fromInteger x) (fromInteger y) (fromInteger cw) (fromInteger ch)
    drawRectangle win bordergc (fromInteger x) (fromInteger y) (fromInteger cw) (fromInteger ch)
  stext <- shrinkWhile (shrinkIt shrinkText)
           (\n -> do size <- liftIO $ textWidthXMF dpy font n
                     return $ size > fromInteger (cw-(2*cp)))
           text
  -- calculate the offset to vertically centre the text based on the ascender and descender
  (asc,desc) <- liftIO $ textExtentsXMF font stext
  let offset = ((ch - fromIntegral (asc + desc)) `div` 2) + fromIntegral asc
  printStringXMF dpy win font gc bg fg (fromInteger (x+cp)) (fromInteger (y+offset)) stext
  io $ freeGC gc
  io $ freeGC bordergc

updateAllElements :: TwoD a ()
updateAllElements =
    do
      s <- get
      updateElements (td_elementmap s)

grayoutElements :: Int -> TwoD a ()
grayoutElements skip =
    do
      s <- get
      updateElementsWithColorizer grayOnly $ drop skip (td_elementmap s)
    where grayOnly _ _ = return ("#808080", "#808080")

updateElements :: TwoDElementMap a -> TwoD a ()
updateElements elementmap = do
      s <- get
      updateElementsWithColorizer (gs_colorizer (td_gsconfig s)) elementmap

updateElementsWithColorizer :: (a -> Bool -> X (String, String)) -> TwoDElementMap a -> TwoD a ()
updateElementsWithColorizer colorizer elementmap = do
    TwoDState { td_curpos = curpos,
                td_frame = win,
                td_gsconfig = gsconfig,
                td_font = font,
                td_paneX = paneX,
                td_paneY = paneY} <- get
    let cellwidth = gs_cellwidth gsconfig
        cellheight = gs_cellheight gsconfig
        paneX' = div (paneX-cellwidth) 2
        paneY' = div (paneY-cellheight) 2
        updateElement (pos@(x,y),(text, element)) = liftX $ do
            colors <- colorizer element (pos == curpos)
            drawWinBox win font
                       colors
                       (gs_bordercolor gsconfig)
                       cellheight
                       cellwidth
                       text
                       (paneX'+x*cellwidth)
                       (paneY'+y*cellheight)
                       (gs_cellpadding gsconfig)
    mapM_ updateElement elementmap

-- $noevents
--
-- Upstream has a @stdHandle@ for the events that are not keys, and a
-- @makeXEventhandler@ that blocks in @maskEvent@ and dispatches between the
-- two.  Neither survives, and neither is missed:
--
-- * @ExposeEvent@ told the window manager to repaint. A Wayland compositor
--   owns damage and repaint; the frame is presented when it is drawn and
--   nobody asks for it back.
--
-- * @ButtonEvent@ selected a cell by clicking it. River reports button
--   presses against windows it manages, and the grid is a surface the window
--   manager drew, so it has no window to attribute a click to. Same wall as
--   'XMonad.Layout.Decoration.handleMouseFocusDrag'.
--
-- * @makeXEventhandler@ was the loop. It cannot block here -- this is the
--   thread that would have to deliver the keys -- so 'gs_navigate' is called
--   once per key instead, from the client's callback.

-- | When the map contains (KeySym,KeyMask) tuple for the given event,
-- the associated action in the map associated shadows the default key
-- handler
shadowWithKeymap :: M.Map (KeyMask, KeySym) a -> ((KeySym, String, KeyMask) -> a) -> (KeySym, String, KeyMask) -> a
shadowWithKeymap keymap dflt keyEvent@(ks,_,m') = fromMaybe (dflt keyEvent) (M.lookup (m',ks) keymap)

-- Helper functions to use for key handler functions

-- | Closes gridselect returning the element under the cursor.
--
-- With nothing under the cursor this cancels, which is what returning
-- @Nothing@ meant upstream.
select :: TwoD a (Navigation a)
select = do
  s <- get
  return $ maybe Cancel (Select . snd . snd)
         $ findInElementMap (td_curpos s) (td_elementmap s)

-- | Closes gridselect returning no element.
cancel :: TwoD a (Navigation a)
cancel = return Cancel

-- | Sets the absolute position of the cursor.
setPos :: (Integer, Integer) -> TwoD a ()
setPos newPos = do
  s <- get
  let elmap = td_elementmap s
      newSelectedEl = findInElementMap newPos (td_elementmap s)
      oldPos = td_curpos s
  when (isJust newSelectedEl && newPos /= oldPos) $ do
    put s { td_curpos = newPos }
    updateElements (catMaybes [findInElementMap oldPos elmap, newSelectedEl])

-- | Moves the cursor by the offsets specified
move :: (Integer, Integer) -> TwoD a ()
move (dx,dy) = do
  s <- get
  let (x,y) = td_curpos s
      newPos = (x+dx,y+dy)
  setPos newPos

moveNext :: TwoD a ()
moveNext = do
  position <- gets td_curpos
  elems <- gets td_elementmap
  let n = length elems
      m = case findIndex (\p -> fst p == position) elems of
               Nothing -> Nothing
               Just k | k == n-1 -> Just 0
                      | otherwise -> Just (k+1)
  whenJust m $ \i ->
      setPos (fst $ elems !! i)

movePrev :: TwoD a ()
movePrev = do
  position <- gets td_curpos
  elems <- gets td_elementmap
  let n = length elems
      m = case findIndex (\p -> fst p == position) elems of
               Nothing -> Nothing
               Just 0  -> Just (n-1)
               Just k  -> Just (k-1)
  whenJust m $ \i ->
      setPos (fst $ elems !! i)

-- | Apply a transformation function the current search string
transformSearchString :: (String -> String) -> TwoD a ()
transformSearchString f = do
          s <- get
          let oldSearchString = td_searchString s
              newSearchString = f oldSearchString
          when (newSearchString /= oldSearchString) $ do
            -- FIXME curpos might end up outside new bounds
            let s' = s { td_searchString = newSearchString }
            m <- liftX $ generateElementmap s'
            let s'' = s' { td_elementmap = m }
                oldLen = length $ td_elementmap s
                newLen = length $ td_elementmap s''
            -- All the elements in the previous element map should be
            -- grayed out, except for those which will be covered by
            -- elements in the new element map.
            when (newLen < oldLen) $ grayoutElements newLen
            put s''
            updateAllElements

-- | By default gridselect used the defaultNavigation action, which
-- binds left,right,up,down and vi-style h,l,j,k navigation. Return
-- quits gridselect, returning the selected element, while Escape
-- cancels the selection. Slash enters the substring search mode. In
-- substring search mode, every string-associated keystroke is
-- added to a search string, which narrows down the object
-- selection. Substring search mode comes back to regular navigation
-- via Return, while Escape cancels the search. If you want that
-- navigation style, add 'defaultNavigation' as 'gs_navigate' to your
-- 'GSConfig' object. This is done by 'buildDefaultGSConfig' automatically.
defaultNavigation :: (KeySym, String, KeyMask) -> TwoD a (Navigation a)
defaultNavigation stroke = do
  searching <- gets td_searching
  if searching then substringSearch stroke
               else shadowWithKeymap navKeyMap navDefaultHandler stroke
  where navKeyMap = M.fromList [
           ((0,xK_Escape)     , cancel)
          ,((0,xK_Return)     , select)
          ,((0,xK_slash)      , enterSearch)
          ,((0,xK_Left)       , move (-1,0) >> pure Continue)
          ,((0,xK_h)          , move (-1,0) >> pure Continue)
          ,((0,xK_Right)      , move (1,0) >> pure Continue)
          ,((0,xK_l)          , move (1,0) >> pure Continue)
          ,((0,xK_Down)       , move (0,1) >> pure Continue)
          ,((0,xK_j)          , move (0,1) >> pure Continue)
          ,((0,xK_Up)         , move (0,-1) >> pure Continue)
          ,((0,xK_k)          , move (0,-1) >> pure Continue)
          ,((0,xK_Tab)        , moveNext >> pure Continue)
          ,((0,xK_n)          , moveNext >> pure Continue)
          ,((0,xK_p)          , movePrev >> pure Continue)
          ]
        -- The navigation handler ignores unknown key symbols, therefore we const
        navDefaultHandler = const (pure Continue)

-- | This navigation style combines navigation and search into one mode at the cost of losing vi style
-- navigation. With this style, there is no substring search submode,
-- but every typed character is added to the substring search.
navNSearch :: (KeySym, String, KeyMask) -> TwoD a (Navigation a)
navNSearch = shadowWithKeymap navNSearchKeyMap navNSearchDefaultHandler
  where navNSearchKeyMap = M.fromList [
           ((0,xK_Escape)     , cancel)
          ,((0,xK_Return)     , select)
          ,((0,xK_Left)       , move (-1,0) >> pure Continue)
          ,((0,xK_Right)      , move (1,0) >> pure Continue)
          ,((0,xK_Down)       , move (0,1) >> pure Continue)
          ,((0,xK_Up)         , move (0,-1) >> pure Continue)
          ,((0,xK_Tab)        , moveNext >> pure Continue)
          ,((0,xK_BackSpace)  , transformSearchString (\s -> if s == "" then "" else init s) >> pure Continue)
          ]
        -- The navigation handler ignores unknown key symbols, therefore we const
        navNSearchDefaultHandler (_,s,_) = do
          transformSearchString (++ s)
          pure Continue

-- | Enter the substring-search submode.
enterSearch :: TwoD a (Navigation a)
enterSearch = do
  XMonad.modify $ \s -> s { td_searching = True }
  pure Continue

-- | Navigation submode used for substring search. It returns to the
-- surrounding navigation style when the user hits Return.
--
-- Upstream this takes the navigation to return to and nests a second event
-- loop inside the first, leaving it by returning. There is no nesting here --
-- one handler runs per key, and it has already returned by the time the next
-- arrives -- so entering and leaving the submode set and clear
-- 'td_searching', which the top-level dispatch consults.
substringSearch :: (KeySym, String, KeyMask) -> TwoD a (Navigation a)
substringSearch = shadowWithKeymap searchKeyMap searchDefaultHandler
  where searchKeyMap = M.fromList [
           ((0,xK_Escape)   , transformSearchString (const "") >> leaveSearch)
          ,((0,xK_Return)   , leaveSearch)
          ,((0,xK_BackSpace), transformSearchString (\s -> if s == "" then "" else init s) >> pure Continue)
          ]
        searchDefaultHandler (_,s,_) = do
          transformSearchString (++ s)
          pure Continue
        leaveSearch = do
          XMonad.modify $ \s -> s { td_searching = False }
          pure Continue


-- FIXME probably move that into Utils?
-- Conversion scheme as in http://en.wikipedia.org/wiki/HSV_color_space
hsv2rgb :: Fractional a => (Integer,a,a) -> (a,a,a)
hsv2rgb (h,s,v) =
    let hi = div h 60 `mod` 6 :: Integer
        f = ((fromInteger h/60) - fromInteger hi) :: Fractional a => a
        q = v * (1-f)
        p = v * (1-s)
        t = v * (1-(1-f)*s)
    in case hi of
         0 -> (v,t,p)
         1 -> (q,v,p)
         2 -> (p,v,t)
         3 -> (p,q,v)
         4 -> (t,p,v)
         5 -> (v,p,q)
         _ -> error "The world is ending. x mod a >= a."

-- | Default colorizer for Strings
stringColorizer :: String -> Bool -> X (String, String)
stringColorizer s active =
    let seed x = toInteger (sum $ map ((*x).fromEnum) s) :: Integer
        (r,g,b) = hsv2rgb (seed 83 `mod` 360,
                           fromInteger (seed 191 `mod` 1000)/2500+0.4,
                           fromInteger (seed 121 `mod` 1000)/2500+0.4)
    in if active
         then return ("#faff69", "black")
         else return ("#" ++ concatMap (twodigitHex.(round :: Double -> Word8).(*256)) [r, g, b], "white")

-- | Colorize a window depending on it's className.
fromClassName :: Window -> Bool -> X (String, String)
fromClassName w active = runQuery className w >>= flip defaultColorizer active

twodigitHex :: Word8 -> String
twodigitHex = printf "%02x"

-- | A colorizer that picks a color inside a range,
-- and depending on the window's class.
colorRangeFromClassName :: (Word8, Word8, Word8) -- ^ Beginning of the color range
                        -> (Word8, Word8, Word8) -- ^ End of the color range
                        -> (Word8, Word8, Word8) -- ^ Background of the active window
                        -> (Word8, Word8, Word8) -- ^ Inactive text color
                        -> (Word8, Word8, Word8) -- ^ Active text color
                        -> Window -> Bool -> X (String, String)
colorRangeFromClassName startC endC activeC inactiveT activeT w active =
    do classname <- runQuery className w
       if active
         then return (rgbToHex activeC, rgbToHex activeT)
         else return (rgbToHex $ mix startC endC
                  $ stringToRatio classname, rgbToHex inactiveT)
    where rgbToHex :: (Word8, Word8, Word8) -> String
          rgbToHex (r, g, b) = '#':twodigitHex r
                               ++twodigitHex g++twodigitHex b

-- | Creates a mix of two colors according to a ratio
-- (1 -> first color, 0 -> second color).
mix :: (Word8, Word8, Word8) -> (Word8, Word8, Word8)
        -> Double -> (Word8, Word8, Word8)
mix (r1, g1, b1) (r2, g2, b2) r = (mix' r1 r2, mix' g1 g2, mix' b1 b2)
    where  mix' a b = truncate $ (fi a * r) + (fi b * (1 - r))

-- | Generates a Double from a string, trying to
-- achieve a random distribution.
-- We create a random seed from the hash of all characters
-- in the string, and use it to generate a ratio between 0 and 1
stringToRatio :: String -> Double
stringToRatio "" = 0
stringToRatio s = let gen = mkStdGen $ foldl' (\t c -> t * 31 + fromEnum c) 0 s
                  in fst $ randomR (0, 1) gen

-- | Brings up a 2D grid of elements in the center of the screen, and one can
-- select an element with cursors keys. The selection is handed to the given
-- function once the user has made it, or 'Nothing' if they cancelled.
--
-- Upstream this answers @X (Maybe a)@, having run the grid to completion
-- before returning. It cannot here, for the reason set out on 'gs_navigate':
-- the grid takes the keyboard through a layer surface on its own connection,
-- and this thread is the one that has to keep servicing that connection. So
-- the answer is handed forward instead of back. Every wrapper below --
-- 'goToSelected', 'spawnSelected', 'runSelectedAction' and the rest -- already
-- ended in @X ()@ and consumed the result immediately, so their signatures are
-- unchanged.
gridselect :: GSConfig a -> [(String,a)] -> (Maybe a -> X ()) -> X ()
gridselect _ [] cont = cont Nothing
gridselect gsconfig elements cont = do
    xconf <- ask
    scr <- gets $ screenRect . W.screenDetail . W.current . windowset
    font <- initXMF (gs_font gsconfig)
    let screenWidth = toInteger $ rect_width scr
        screenHeight = toInteger $ rect_height scr

    -- The grid is composed in an offscreen drawable and replayed into whatever
    -- buffer the client presents, exactly as a prompt does it.  Drawing and
    -- presenting are on different threads and this drawable is where they meet.
    frame <- io $ createPixmap (rect_width scr) (rect_height scr)
    gc <- io createGC

    let restriction ss cs = (fromInteger ss/fromInteger (cs gsconfig)-1)/2 :: Double
        restrictX = floor $ restriction screenWidth gs_cellwidth
        restrictY = floor $ restriction screenHeight gs_cellheight
        originPosX = floor $ (gs_originFractX gsconfig - (1/2)) * 2 * fromIntegral restrictX
        originPosY = floor $ (gs_originFractY gsconfig - (1/2)) * 2 * fromIntegral restrictY
        coords = diamondRestrict restrictX restrictY originPosX originPosY
        s = TwoDState { td_curpos = NE.head (notEmpty coords),
                        td_availSlots = coords,
                        td_elements = elements,
                        td_gsconfig = gsconfig,
                        td_font = font,
                        td_paneX = screenWidth,
                        td_paneY = screenHeight,
                        td_frame = frame,
                        td_gc = gc,
                        td_searchString = "",
                        td_searching = False,
                        td_elementmap = [] }
    m <- generateElementmap s

    -- The state lives in an IORef rather than being threaded through a loop,
    -- because there is no loop: each key arrives as a callback on the client's
    -- thread, which posts an action to the window manager's.  That action is
    -- the only thing that ever touches this ref, so no locking is needed --
    -- 'postAction' serialises everything onto one thread by construction.
    ref <- io $ newIORef s { td_elementmap = m }
    handleRef <- io $ newIORef Nothing
    done <- io $ newIORef False

    let redraw = readIORef handleRef >>= mapM_ chRedraw

        -- Tear down once and once only.  The client's own close callback fires
        -- when the compositor takes the surface away, and a selection closes
        -- it from this side; both routes land here.
        finish result = do
            alreadyDone <- io $ atomicModifyIORef' done (True,)
            unless alreadyDone $ do
                io $ readIORef handleRef >>= mapM_ chClose
                io $ freeGC gc
                io $ freePixmap frame
                releaseXMF font
                cont result

        onKey sym txt = postAction xconf $ whenX (not <$> io (readIORef done)) $ do
            st <- io (readIORef ref)
            (nav, st') <- runStateT
                (unTwoD (gs_navigate gsconfig (fromIntegral sym, txt, 0))) st
            io $ writeIORef ref st'
            case nav of
                Continue -> io redraw
                Cancel   -> finish Nothing
                Select a -> finish (Just a)

    h <- io $ startClient ClientSpec
        { csWidth  = fi (rect_width scr)
        , csHeight = fi (rect_height scr)
        , csAnchor = AnchorCentre
        , csMargin = (0, 0, 0, 0)
        , csKeyboard = True
        , csDraw   = renderDrawableInto frame
        , csOnKey  = onKey
        , csOnClose = postAction xconf (finish Nothing)
        }
    io $ writeIORef handleRef (Just h)

    -- Paint the first frame.  Upstream does this inside evalTwoD just before
    -- entering the loop; here there is no loop to enter, so it is simply the
    -- last thing this action does before returning to the event loop.
    st <- io (readIORef ref)
    st' <- execStateT (unTwoD updateAllElements) st
    io $ writeIORef ref st'
    io redraw

-- | Like `gridSelect' but with the current windows and their titles as elements
gridselectWindow :: GSConfig Window -> (Maybe Window -> X ()) -> X ()
gridselectWindow gsconf cont = windowMap >>= \ws -> gridselect gsconf ws cont

-- | Brings up a 2D grid of windows in the center of the screen, and one can
-- select a window with cursors keys. The selected window is then passed to
-- a callback function.
withSelectedWindow :: (Window -> X ()) -> GSConfig Window -> X ()
withSelectedWindow callback conf = gridselectWindow conf (`for_` callback)

windowMap :: X [(String,Window)]
windowMap = do
    ws <- gets windowset
    mapM keyValuePair (W.allWindows ws)
 where keyValuePair w = (, w) <$> decorateName' w

decorateName' :: Window -> X String
decorateName' w = do
  show <$> getName w

-- | Builds a default gs config from a colorizer function.
buildDefaultGSConfig :: (a -> Bool -> X (String,String)) -> GSConfig a
buildDefaultGSConfig col = GSConfig 50 130 10 col "xft:Sans-8" defaultNavigation noRearranger (1/2) (1/2) "white"

-- | Brings selected window to the current workspace.
bringSelected :: GSConfig Window -> X ()
bringSelected = withSelectedWindow $ \w -> do
    windows (bringWindow w)
    XMonad.focus w
    windows W.shiftMaster

-- | Switches to selected window's workspace and focuses that window.
goToSelected :: GSConfig Window -> X ()
goToSelected = withSelectedWindow $ windows . W.focusWindow

-- | Select an application to spawn from a given list
spawnSelected :: GSConfig String -> [String] -> X ()
spawnSelected conf lst = gridselect conf (zip lst lst) (`whenJust` spawn)

-- | Select an action and run it in the X monad
runSelectedAction :: GSConfig (X ()) -> [(String, X ())] -> X ()
runSelectedAction conf actions = gridselect conf actions $ \case
    Just selectedAction -> selectedAction
    Nothing -> return ()

-- | Select a workspace and view it using the given function
-- (normally 'W.view' or 'W.greedyView')
--
-- Another option is to shift the current window to the selected workspace:
--
-- > gridselectWorkspace (\ws -> W.greedyView ws . W.shift ws)
gridselectWorkspace :: GSConfig WorkspaceId ->
                          (WorkspaceId -> WindowSet -> WindowSet) -> X ()
gridselectWorkspace conf viewFunc = gridselectWorkspace' conf (windows . viewFunc)

-- | Select a workspace and run an arbitrary action on it.
gridselectWorkspace' :: GSConfig WorkspaceId -> (WorkspaceId -> X ()) -> X ()
gridselectWorkspace' conf func = withWindowSet $ \ws -> do
    let wss = map W.tag $ W.hidden ws ++ map W.workspace (W.current ws : W.visible ws)
    gridselect conf (zip wss wss) (`whenJust` func)

-- $rearrangers
--
-- Rearrangers allow for arbitrary post-filter rearranging of the grid
-- elements.
--
-- For example, to be able to switch to a new dynamic workspace by typing
-- in its name, you can use the following keybinding action:
--
-- > import XMonad.Actions.DynamicWorkspaces (addWorkspace)
-- >
-- > gridselectWorkspace' def
-- >                          { gs_navigate   = navNSearch
-- >                          , gs_rearranger = searchStringRearrangerGenerator id
-- >                          }
-- >                      addWorkspace

-- | A function taking the search string and a list of elements, and
-- returning a potentially rearranged list of elements.
type Rearranger a = String -> [(String, a)] -> X [(String, a)]

-- | A rearranger that leaves the elements unmodified.
noRearranger :: Rearranger a
noRearranger _ = return

-- | A generator for rearrangers that append a single element based on the
-- search string, if doing so would not be redundant (empty string or value
-- already present).
searchStringRearrangerGenerator :: (String -> a) -> Rearranger a
searchStringRearrangerGenerator f =
    let r "" xs                       = return xs
        r s  xs | s `elem` map fst xs = return xs
                | otherwise           = return $ xs ++ [(s, f s)]
    in r
