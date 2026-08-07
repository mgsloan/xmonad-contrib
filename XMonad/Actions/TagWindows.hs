-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Actions.TagWindows
-- Description  : Functions for tagging windows and selecting them by tags.
-- Copyright    : (c) Karsten Schoelzel <kuser@gmx.de>
-- License      : BSD
--
-- Maintainer   : Karsten Schoelzel <kuser@gmx.de>
-- Stability    : unstable
-- Portability  : unportable
--
-- Functions for tagging windows and selecting them by tags.
-----------------------------------------------------------------------------

module XMonad.Actions.TagWindows (
                 -- * Usage
                 -- $usage
                 addTag, delTag, unTag,
                 setTags, getTags, hasTag,
                 withTaggedP,  withTaggedGlobalP, withFocusedP,
                 withTagged ,  withTaggedGlobal ,
                 focusUpTagged,   focusUpTaggedGlobal,
                 focusDownTagged, focusDownTaggedGlobal,
                 shiftHere, shiftToScreen,
                 tagPrompt,
                 tagDelPrompt,
                 TagPrompt,
                 ) where

import qualified Data.Map as M
import qualified Data.Set as S

import XMonad hiding (workspaces)
import XMonad.Prelude
import XMonad.Prompt
import XMonad.StackSet hiding (filter)
import qualified XMonad.Util.ExtensibleState as XS

-- | Where the tags live.
--
-- Under X11 this module kept tags in a @_XMONAD_TAGS@ text property on the
-- window itself, which is not available here: Wayland has no window
-- properties, and river exposes a window's @app_id@ and @title@ but nothing a
-- window manager may write to.  So the map is kept in xmonad's own state
-- instead, which supports the same operations.
--
-- One behaviour does change, and it cannot be helped.  Under X11 tags survived
-- @--restart@ because they lived on the window and the window outlived the
-- window manager.  Here they do not: river hands out fresh object ids to the
-- successor process, so a serialised 'Window' would name nothing.  That is
-- also why this is a plain 'StateExtension' rather than a
-- 'PersistentExtension' -- the latter is a no-op under river for exactly this
-- reason.  Tags last for the session.
newtype TagState = TagState (M.Map Window [String])

instance ExtensionClass TagState where
    initialValue = TagState M.empty

-- $usage
--
-- To use window tags, import this module into your @xmonad.hs@:
--
-- > import XMonad.Actions.TagWindows
-- > import XMonad.Prompt    -- to use tagPrompt
--
-- and add keybindings such as the following:
--
-- >   , ((modm,                 xK_f  ), withFocused (addTag "abc"))
-- >   , ((modm .|. controlMask, xK_f  ), withFocused (delTag "abc"))
-- >   , ((modm .|. shiftMask,   xK_f  ), withTaggedGlobalP "abc" W.sink)
-- >   , ((modm,                 xK_d  ), withTaggedP "abc" (W.shiftWin "2"))
-- >   , ((modm .|. shiftMask,   xK_d  ), withTaggedGlobalP "abc" shiftHere)
-- >   , ((modm .|. controlMask, xK_d  ), focusUpTaggedGlobal "abc")
-- >   , ((modm,                 xK_g  ), tagPrompt def (\s -> withFocused (addTag s)))
-- >   , ((modm .|. controlMask, xK_g  ), tagDelPrompt def)
-- >   , ((modm .|. shiftMask,   xK_g  ), tagPrompt def (\s -> withTaggedGlobal s float))
-- >   , ((modWinMask,                xK_g  ), tagPrompt def (\s -> withTaggedP s (W.shiftWin "2")))
-- >   , ((modWinMask .|. shiftMask,  xK_g  ), tagPrompt def (\s -> withTaggedGlobalP s shiftHere))
-- >   , ((modWinMask .|. controlMask, xK_g ), tagPrompt def (\s -> focusUpTaggedGlobal s))
--
-- NOTE: Tags are saved as space separated strings and split with
--       'unwords'. Thus if you add a tag \"a b\" the window will have
--       the tags \"a\" and \"b\" but not \"a b\".
--
-- For detailed instructions on editing your key bindings, see
-- <https://xmonad.org/TUTORIAL.html#customizing-xmonad the tutorial>.

-- | set multiple tags for a window at once (overriding any previous tags)
setTags :: [String] -> Window -> X ()
setTags = setTag . unwords

-- | set a tag for a window (overriding any previous tags)
--
-- Tags are still split on whitespace, as the note above describes, so that
-- @setTag@ and @setTags@ agree with the X11 versions about what \"a b\" means.
--
-- Writing is also when stale entries are dropped.  The X11 property went away
-- with its window; a map does not, so a long session that tagged and closed
-- many windows would otherwise leak an entry per window.  Pruning against the
-- current 'windowset' costs nothing here and needs no destroy hook.
setTag :: String -> Window -> X ()
setTag s w = do
    live <- gets (S.fromList . allWindows . windowset)
    XS.modify' $ \(TagState m) -> TagState $ M.restrictKeys (upd m) (S.insert w live)
  where
    upd | null (words s) = M.delete w
        | otherwise      = M.insert w (words s)

-- | read all tags of a window
getTags :: Window -> X [String]
getTags w = XS.gets $ \(TagState m) -> M.findWithDefault [] w m

-- | check a window for the given tag
hasTag :: String -> Window -> X Bool
hasTag s w = (s `elem`) <$> getTags w

-- | add a tag to the existing ones
addTag :: String -> Window -> X ()
addTag s w = do
    tags <- getTags w
    when (s `notElem` tags) $ setTags (s:tags) w

-- | remove a tag from a window, if it exists
delTag :: String -> Window -> X ()
delTag s w = do
    tags <- getTags w
    setTags (filter (/= s) tags) w

-- | remove all tags
unTag :: Window -> X ()
unTag = setTag ""

-- | Move the focus in a group of windows, which share the same given tag.
--   The Global variants move through all workspaces, whereas the other
--   ones operate only on the current workspace
focusUpTagged, focusDownTagged, focusUpTaggedGlobal, focusDownTaggedGlobal :: String -> X ()
focusUpTagged         = focusTagged' (reverse . wsToList)
focusDownTagged       = focusTagged' wsToList
focusUpTaggedGlobal   = focusTagged' (reverse . wsToListGlobal)
focusDownTaggedGlobal = focusTagged' wsToListGlobal

wsToList :: (Ord i) => StackSet i l a s sd -> [a]
wsToList ws = crs ++ cls
    where
        (crs, cls) = (cms down, cms (reverse . up))
        cms f = maybe [] f (stack . workspace . current $ ws)

wsToListGlobal :: (Ord i) => StackSet i l a s sd -> [a]
wsToListGlobal ws = concat ([crs] ++ rws ++ lws ++ [cls])
    where
        curtag = currentTag ws
        (crs, cls) = (cms down, cms (reverse . up))
        cms f = maybe [] f (stack . workspace . current $ ws)
        (lws, rws) = (mws (<), mws (>))
        mws cmp = map (integrate' . stack) . sortByTag . filter (\w -> tag w `cmp` curtag) . workspaces $ ws
        sortByTag = sortBy (\x y -> compare (tag x) (tag y))

focusTagged' :: (WindowSet -> [Window]) -> String -> X ()
focusTagged' wl t = gets windowset >>= findM (hasTag t) . wl >>=
    maybe (return ()) (windows . focusWindow)

-- | apply a pure function to windows with a tag
withTaggedP, withTaggedGlobalP :: String -> (Window -> WindowSet -> WindowSet) -> X ()
withTaggedP       t f = withTagged'       t (winMap f)
withTaggedGlobalP t f = withTaggedGlobal' t (winMap f)

winMap :: (Window -> WindowSet -> WindowSet) -> [Window] -> X ()
winMap f tw = when (tw /= []) (windows $ foldl1 (.) (map f tw))

withTagged, withTaggedGlobal :: String -> (Window -> X ()) -> X ()
withTagged       t f = withTagged'       t (mapM_ f)
withTaggedGlobal t f = withTaggedGlobal' t (mapM_ f)

withTagged' :: String -> ([Window] -> X ()) -> X ()
withTagged' t m = gets windowset >>= filterM (hasTag t) . index >>= m

withTaggedGlobal' :: String -> ([Window] -> X ()) -> X ()
withTaggedGlobal' t m = gets windowset >>=
    filterM (hasTag t) . concatMap (integrate' . stack) . workspaces >>= m

withFocusedP :: (Window -> WindowSet -> WindowSet) -> X ()
withFocusedP f = withFocused $ windows . f

shiftHere :: (Ord a, Eq s, Eq i) => a -> StackSet i l a s sd -> StackSet i l a s sd
shiftHere w s = shiftWin (currentTag s) w s

shiftToScreen :: (Ord a, Eq s, Eq i) => s -> a -> StackSet i l a s sd -> StackSet i l a s sd
shiftToScreen sid w s = case filter (\m -> sid /= screen m) (current s:visible s) of
                                []      -> s
                                (t:_)   -> shiftWin (tag . workspace $ t) w s

data TagPrompt = TagPrompt

instance XPrompt TagPrompt where
    showXPrompt TagPrompt = "Select Tag:   "


tagPrompt :: XPConfig -> (String -> X ()) -> X ()
tagPrompt c f = do
  sc <- tagComplList
  mkXPrompt TagPrompt c (mkComplFunFromList' c sc) f

tagComplList :: X [String]
tagComplList = gets (concatMap (integrate' . stack) . workspaces . windowset)
           >>= mapM getTags
           <&> nub . concat


tagDelPrompt :: XPConfig -> X ()
tagDelPrompt c = do
  sc <- tagDelComplList
  when (sc /= []) $
    mkXPrompt TagPrompt c (mkComplFunFromList' c sc) (withFocused . delTag)

tagDelComplList :: X [String]
tagDelComplList = gets windowset >>= maybe (return []) getTags . peek
