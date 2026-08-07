{-# LANGUAGE FlexibleContexts, MultiParamTypeClasses, FlexibleInstances #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Hooks.UrgencyHook
-- Description :  Configure an action to occur when a window demands your attention.
-- Copyright   :  Devin Mullins <me@twifkak.com>
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  Devin Mullins <me@twifkak.com>
-- Stability   :  unstable
-- Portability :  unportable
--
-- UrgencyHook lets you configure an action to occur when a window demands
-- your attention. (In traditional WMs, this takes the form of \"flashing\"
-- on your \"taskbar.\" Blech.)
--
-----------------------------------------------------------------------------

module XMonad.Hooks.UrgencyHook (
                                 -- * Usage
                                 -- $usage

                                 -- ** Pop up a temporary dzen
                                 -- $temporary

                                 -- ** Highlight in existing dzen
                                 -- $existing

                                 -- ** Useful keybinding
                                 -- $keybinding

                                 -- * Differences under river
                                 -- $river

                                 -- * Stuff for your config file:
                                 withUrgencyHook, withUrgencyHookC,
                                 UrgencyConfig(..), urgencyConfig,
                                 SuppressWhen(..), RemindWhen(..),
                                 focusUrgent, clearUrgents,
                                 dzenUrgencyHook,
                                 DzenUrgencyHook(..),
                                 NoUrgencyHook(..),
                                 BorderUrgencyHook(..),
                                 FocusHook(..),
                                 filterUrgencyHook, filterUrgencyHook',
                                 minutes, seconds,
                                 askUrgent, doAskUrgent,
                                 -- * Stuff for developers:
                                 readUrgents, withUrgents, clearUrgents',
                                 StdoutUrgencyHook(..),
                                 SpawnUrgencyHook(..),
                                 UrgencyHook(urgencyHook),
                                 Interval,
                                 borderUrgencyHook, focusHook, spawnUrgencyHook, stdoutUrgencyHook
                                 ) where

import XMonad
import XMonad.Prelude (delete, listToMaybe, maybeToList, (\\))
import qualified XMonad.StackSet as W

import XMonad.Hooks.ManageHelpers (windowTag)
import XMonad.Util.Dzen (dzenWithArgs, seconds)
import qualified XMonad.Util.ExtensibleConf as XC
import qualified XMonad.Util.ExtensibleState as XS
import XMonad.Util.NamedWindows (getName)
import XMonad.Util.Timer (TimerId, startTimer, handleTimer)
import XMonad.River (parseColorMaybe)

import qualified Data.Set as S
import System.IO (hPutStrLn, stderr)

-- $usage
--
-- To wire this up, first add:
--
-- > import XMonad.Hooks.UrgencyHook
--
-- to your import list in your config file. Now, you have a decision to make:
-- When a window deems itself urgent, do you want to pop up a temporary dzen
-- bar telling you so, or do you have an existing dzen wherein you would like to
-- highlight urgent workspaces?

-- $temporary
--
-- Enable your urgency hook by wrapping your config record in a call to
-- 'withUrgencyHook'. For example:
--
-- > main = xmonad $ withUrgencyHook dzenUrgencyHook { args = ["-bg", "darkgreen", "-xs", "1"] }
-- >               $ def
--
-- This will pop up a dzen bar for five seconds telling you you've got an
-- urgent window.

-- $existing
--
-- In order for xmonad to track urgent windows, you must install an urgency hook.
-- You can use the above 'dzenUrgencyHook', or if you're not interested in the
-- extra popup, install NoUrgencyHook, as so:
--
-- > main = xmonad $ withUrgencyHook NoUrgencyHook
-- >               $ def
--
-- Now, your "XMonad.Hooks.StatusBar.PP" must be set up to display the urgent
-- windows. If you're using the 'dzen' (from "XMonad.Hooks.DynamicLog") or
-- 'dzenPP' functions from that module, then you should be good. Otherwise,
-- you want to figure out how to set 'ppUrgent'.

-- $keybinding
--
-- You can set up a keybinding to jump to the window that was recently marked
-- urgent. See an example at 'focusUrgent'.

-- $river
--
-- Under river, __a window cannot mark itself urgent.__  Only the config can,
-- by calling 'askUrgent' or using 'doAskUrgent' in a manage hook.
--
-- Everything else in this module is unchanged and works exactly as it always
-- did: the list of urgent windows, 'SuppressWhen', 'RemindWhen' and its
-- timers, every 'UrgencyHook' instance, 'focusUrgent', 'clearUrgents', and
-- 'readUrgents' -- which is all that "XMonad.Layout.Decoration" and
-- "XMonad.Hooks.StatusBar.PP" ever wanted from here.  The list also survives a
-- restart now, since it is a 'PersistentExtension' and river has a state file
-- again.
--
-- What is missing is the /input/, and it is missing at the compositor rather
-- than here.  X11 gave a client two ways to raise its hand:
--
-- * the urgency flag in @WM_HINTS@, which xmonad saw as a @PropertyNotify@, and
-- * a @_NET_WM_STATE_DEMANDS_ATTENTION@ client message.
--
-- Wayland's equivalent is @xdg-activation-v1@, and river implements it -- but
-- when the surface being activated is a window, river's @handleRequestActivate@
-- does nothing at all, with the comment @TODO support xdg-activation with a rwm
-- extension protocol@.  So the request reaches the compositor and stops there;
-- there is no event for a window manager to receive.  Nothing in this module
-- can fix that, and when river grows the extension, the fix here is one event
-- handler calling 'markUrgent'.
--
-- The practical consequence is narrow: the bell-in-a-terminal workflow the
-- sections upstream documents here no longer reaches xmonad. Anything the config
-- decides for itself -- a manage hook marking new windows from a particular
-- application, a keybinding, a script calling into the config -- works as
-- before.

-- | This is the method to enable an urgency hook. It uses the default
-- 'urgencyConfig' to control behavior. To change this, use 'withUrgencyHookC'
-- instead.
withUrgencyHook :: (LayoutClass l Window, UrgencyHook h) =>
                   h -> XConfig l -> XConfig l
withUrgencyHook hook = withUrgencyHookC hook def

-- | This lets you modify the defaults set in 'urgencyConfig'. An example:
--
-- > withUrgencyHookC dzenUrgencyHook { ... } def { suppressWhen = Focused }
--
-- (Don't type the @...@, you dolt.) See 'UrgencyConfig' for details on configuration.
withUrgencyHookC :: (LayoutClass l Window, UrgencyHook h) =>
                    h -> UrgencyConfig -> XConfig l -> XConfig l
withUrgencyHookC hook urgConf conf = XC.once id (MarkUrgent (markUrgent wuh)) conf {
        handleEventHook = \e -> handleEvent wuh e >> handleEventHook conf e,
        logHook = cleanupUrgents (suppressWhen urgConf) >> logHook conf,
        startupHook = cleanupStaleUrgents >> startupHook conf
    }
  where wuh = WithUrgencyHook hook urgConf

-- | How 'askUrgent' reaches the configured hook.
--
-- Under X11 'askUrgent' sent itself a @_NET_WM_STATE@ client message and let
-- 'handleEvent' pick it up, so that the configured 'SuppressWhen' was
-- respected.  There is no such round trip here -- river delivers no client
-- messages -- so the marker is stashed in the config and invoked directly.
-- That is what upstream's comment on 'askUrgent' says it would do given
-- "XMonad.Util.ExtensibleConf", which now exists.
--
-- 'XC.once' means several 'withUrgencyHook' applications leave the first one's
-- marker in place, matching the old behaviour: the outermost 'handleEvent' saw
-- the message first and marked the window before any other could.
newtype MarkUrgent = MarkUrgent (Window -> X ())

instance Semigroup MarkUrgent where
    a <> _ = a

newtype Urgents = Urgents { fromUrgents :: [Window] } deriving (Read,Show)

onUrgents :: ([Window] -> [Window]) -> Urgents -> Urgents
onUrgents f = Urgents . f . fromUrgents

instance ExtensionClass Urgents where
    initialValue = Urgents []
    extensionType = PersistentExtension

-- | Global configuration, applied to all types of 'UrgencyHook'. See
-- 'urgencyConfig' for the defaults.
data UrgencyConfig = UrgencyConfig
    { suppressWhen :: SuppressWhen -- ^ when to trigger the urgency hook
    , remindWhen   :: RemindWhen   -- ^ when to re-trigger the urgency hook
    } deriving (Read, Show)

-- | A set of choices as to /when/ you should (or rather, shouldn't) be notified of an urgent window.
-- The default is 'Visible'. Prefix each of the following with \"don't bug me when\":
data SuppressWhen = Visible  -- ^ the window is currently visible
                  | OnScreen -- ^ the window is on the currently focused physical screen
                  | Focused  -- ^ the window is currently focused
                  | Never    -- ^ ... aww, heck, go ahead and bug me, just in case.
                  deriving (Read, Show)

-- | A set of choices as to when you want to be re-notified of an urgent
-- window. Perhaps you focused on something and you miss the dzen popup bar. Or
-- you're AFK. Or you feel the need to be more distracted. I don't care.
--
-- The interval arguments are in seconds. See the 'minutes' helper.
data RemindWhen = Dont                    -- ^ triggering once is enough
                | Repeatedly Int Interval -- ^ repeat \<arg1\> times every \<arg2\> seconds
                | Every Interval          -- ^ repeat every \<arg1\> until the urgency hint is cleared
                deriving (Read, Show)

-- | A prettified way of multiplying by 60. Use like: @(5 `minutes`)@.
minutes :: Rational -> Rational
minutes secs = secs * 60

-- | The default 'UrgencyConfig': @urgencyConfig = 'def'@.
urgencyConfig :: UrgencyConfig
urgencyConfig = def
{-# DEPRECATED urgencyConfig "Use def insetad." #-}

-- | The default 'UrgencyConfig': @suppressWhen = 'Visible', remindWhen = 'Dont'@.
-- Use a variation of this in your config just as you would use any
-- other instance of 'def'.
instance Default UrgencyConfig where
  def = UrgencyConfig { suppressWhen = Visible, remindWhen = Dont }

-- | Focuses the most recently urgent window. Good for what ails ya -- I mean, your keybindings.
-- Example keybinding:
--
-- > , ((modm              , xK_BackSpace), focusUrgent)
focusUrgent :: X ()
focusUrgent = withUrgents $ flip whenJust (windows . W.focusWindow) . listToMaybe

-- | Just makes the urgents go away.
-- Example keybinding:
--
-- > , ((modm .|. shiftMask, xK_BackSpace), clearUrgents)
clearUrgents :: X ()
clearUrgents = withUrgents clearUrgents'

-- | X action that returns a list of currently urgent windows. You might use
-- it, or 'withUrgents', in your custom logHook, to display the workspaces that
-- contain urgent windows.
readUrgents :: X [Window]
readUrgents = XS.gets fromUrgents

-- | An HOF version of 'readUrgents', for those who prefer that sort of thing.
withUrgents :: ([Window] -> X a) -> X a
withUrgents f = readUrgents >>= f

-- | Cleanup urgency and reminders for windows that no longer exist.
cleanupStaleUrgents :: X ()
cleanupStaleUrgents = withWindowSet $ \ws -> do
    adjustUrgents (filter (`W.member` ws))
    adjustReminders (filter ((`W.member` ws) . window))

adjustUrgents :: ([Window] -> [Window]) -> X ()
adjustUrgents = XS.modify . onUrgents

type Interval = Rational

-- | An urgency reminder, as reified for 'RemindWhen'.
-- The last value is the countdown number, for 'Repeatedly'.
data Reminder = Reminder { timer     :: TimerId
                         , window    :: Window
                         , interval  :: Interval
                         , remaining :: Maybe Int
                         } deriving (Show,Read,Eq)

instance ExtensionClass [Reminder] where
    initialValue = []
    extensionType = PersistentExtension

-- | Stores the list of urgency reminders.

readReminders :: X [Reminder]
readReminders = XS.get

adjustReminders :: ([Reminder] -> [Reminder]) -> X ()
adjustReminders = XS.modify


data WithUrgencyHook h = WithUrgencyHook h UrgencyConfig
    deriving (Read, Show)

-- The Non-ICCCM Manifesto:
-- Note: Some non-standard choices have been made in this implementation to
-- account for the fact that things are different in a tiling window manager:
--   1. In normal window managers, windows may overlap, so clients wait for focus to
--      be set before urgency is cleared. In a tiling WM, it's sufficient to be able
--      see the window, since we know that means you can see it completely.
--   2. The urgentOnBell setting in rxvt-unicode sets urgency even when the window
--      has focus, and won't clear until it loses and regains focus. This is stupid.
-- In order to account for these quirks, we track the list of urgent windows
-- ourselves, allowing us to clear urgency when a window is visible, and not to
-- set urgency if a window is visible. If you have a better idea, please, let us
-- know!
--
-- Tracking the list ourselves is also what lets this module work at all under
-- river; see $river.
handleEvent :: UrgencyHook h => WithUrgencyHook h -> Event -> X ()
handleEvent wuh event =
    case event of
      -- Window destroyed.  An urgent window that has gone away must not stay
      -- in the list: river recycles object ids, so a stale entry would come
      -- back attached to some unrelated window.
      DestroyWindowEvent {ev_window = w} ->
          markNotUrgent w
      _ ->
          mapM_ handleReminder =<< readReminders
      where handleReminder reminder = handleTimer (timer reminder) event $ reminderHook wuh reminder
            markNotUrgent w =
                adjustUrgents (delete w) >> adjustReminders (filter $ (w /=) . window)
                  >> (userCodeDef () =<< asks (logHook . config))

-- | Add a window to the urgent list and run the hook for it.
--
-- Under X11 this was local to 'handleEvent', reached only by an incoming
-- @WM_HINTS@ change or @_NET_WM_STATE@ message.  Neither exists here, so it is
-- named and reachable from 'askUrgent' instead -- which is the only way a
-- window becomes urgent under river.  See $river.
markUrgent :: UrgencyHook h => WithUrgencyHook h -> Window -> X ()
markUrgent wuh w = do
    adjustUrgents (\ws -> if w `elem` ws then ws else w : ws)
    callUrgencyHook wuh w
    userCodeDef () =<< asks (logHook . config)

callUrgencyHook :: UrgencyHook h => WithUrgencyHook h -> Window -> X ()
callUrgencyHook (WithUrgencyHook hook UrgencyConfig { suppressWhen = sw, remindWhen = rw }) w =
    whenX (not <$> shouldSuppress sw w) $ do
        userCodeDef () $ urgencyHook hook w
        case rw of
            Repeatedly times int -> addReminder w int $ Just times
            Every int            -> addReminder w int Nothing
            Dont                 -> return ()

addReminder :: Window -> Rational -> Maybe Int -> X ()
addReminder w int times = do
    timerId <- startTimer int
    let reminder = Reminder timerId w int times
    adjustReminders (\rs -> if w `elem` map window rs then rs else reminder : rs)

reminderHook :: UrgencyHook h => WithUrgencyHook h -> Reminder -> X (Maybe a)
reminderHook (WithUrgencyHook hook _) reminder = do
    case remaining reminder of
        Just x | x > 0 -> remind $ Just (x - 1)
        Just _         -> adjustReminders $ delete reminder
        Nothing        -> remind Nothing
    return Nothing
  where remind remaining' = do userCode $ urgencyHook hook (window reminder)
                               adjustReminders $ delete reminder
                               addReminder (window reminder) (interval reminder) remaining'

shouldSuppress :: SuppressWhen -> Window -> X Bool
shouldSuppress sw w = elem w <$> suppressibleWindows sw

cleanupUrgents :: SuppressWhen -> X ()
cleanupUrgents sw = clearUrgents' =<< suppressibleWindows sw

-- | Clear urgency status of selected windows.
--
-- X11 also cleared @_NET_WM_STATE_DEMANDS_ATTENTION@ on each window, so that a
-- pager reading the property agreed with xmonad about what was urgent.  There
-- is no such property here and no pager reading one: the list this keeps is
-- the only record, which makes it the authority rather than a cache.
clearUrgents' :: [Window] -> X ()
clearUrgents' ws =
    adjustUrgents (\\ ws) >> adjustReminders (filter ((`notElem` ws) . window))

suppressibleWindows :: SuppressWhen -> X [Window]
suppressibleWindows Visible  = gets $ S.toList . mapped
suppressibleWindows OnScreen = gets $ W.index . windowset
suppressibleWindows Focused  = gets $ maybeToList . W.peek . windowset
suppressibleWindows Never    = return []

--------------------------------------------------------------------------------
-- Urgency Hooks

-- | The class definition, and some pre-defined instances.

class UrgencyHook h where
    urgencyHook :: h -> Window -> X ()

instance UrgencyHook (Window -> X ()) where
    urgencyHook = id

data NoUrgencyHook = NoUrgencyHook deriving (Read, Show)

instance UrgencyHook NoUrgencyHook where
    urgencyHook _ _ = return ()

-- | Your set of options for configuring a dzenUrgencyHook.
data DzenUrgencyHook = DzenUrgencyHook {
                         duration :: Int, -- ^ number of microseconds to display the dzen
                                          --   (hence, you'll probably want to use 'seconds')
                         args :: [String] -- ^ list of extra args (as 'String's) to pass to dzen
                       }
    deriving (Read, Show)

instance UrgencyHook DzenUrgencyHook where
    urgencyHook DzenUrgencyHook { duration = d, args = a } w = do
        name <- getName w
        ws <- gets windowset
        whenJust (W.findTag w ws) (flash name)
      where flash name index =
                  dzenWithArgs (show name ++ " requests your attention on workspace " ++ index) a d

{- | A hook which will automatically send you to anything which sets the urgent
  flag (as opposed to printing some sort of message. You would use this as
  usual, eg.

  > withUrgencyHook FocusHook $ myconfig { ...
-}
focusHook :: Window -> X ()
focusHook = urgencyHook FocusHook
data FocusHook = FocusHook deriving (Read, Show)

instance UrgencyHook FocusHook where
    urgencyHook _ _ = focusUrgent

-- | A hook that sets the border color of an urgent window.  The color
--   will remain until the next time the window gains or loses focus, at
--   which point the standard border color from the XConfig will be applied.
--   You may want to use suppressWhen = Never with this:
--
--   > withUrgencyHookC BorderUrgencyHook { urgencyBorderColor = "#ff0000" } urgencyConfig { suppressWhen = Never } ...
--
--   (This should be @urgentBorderColor@ but that breaks "XMonad.Layout.Decoration".
--   @borderColor@ breaks anyone using 'XPConfig' from "XMonad.Prompt".  We need to
--   think a bit more about namespacing issues, maybe.)

borderUrgencyHook :: String -> Window -> X ()
borderUrgencyHook = urgencyHook . BorderUrgencyHook
newtype BorderUrgencyHook = BorderUrgencyHook { urgencyBorderColor :: String }
                       deriving (Read, Show)

instance UrgencyHook BorderUrgencyHook where
  urgencyHook BorderUrgencyHook { urgencyBorderColor = cs } w =
    withDisplay $ \dpy ->
      case parseColorMaybe cs of
        Just c  -> setWindowBorderWithFallback dpy w cs c
        Nothing -> io $ hPutStrLn stderr $ concat ["Warning: bad urgentBorderColor "
                                                  ,show cs
                                                  ," in BorderUrgencyHook"
                                                  ]

-- The X11 version resolved the colour with initColor, which asked the server
-- to allocate it, and passed the result as the fallback to
-- setWindowBorderWithFallback -- so the fallback was the same colour, and the
-- whole dance existed to detect a bad colour name.  parseColorMaybe answers
-- that question directly.
--
-- The border set here stays until something else sets it.  Under X11 the next
-- 'windows' call reset every visible window's border, so this reverted on the
-- next focus or layout change; river reapplies borders from a stored override
-- instead, and an override that any render sequence could clear would not
-- survive long enough to be seen.  'clearUrgents' does not reset it either --
-- it did not under X11 -- so a config that wants the colour back should say
-- so.

-- | Flashes when a window requests your attention and you can't see it.
-- Defaults to a duration of five seconds, and no extra args to dzen.
-- See 'DzenUrgencyHook'.
dzenUrgencyHook :: DzenUrgencyHook
dzenUrgencyHook = def

-- | @'def' = 'dzenUrgencyHook'@.
instance Default DzenUrgencyHook where
  def = DzenUrgencyHook { duration = seconds 5, args = [] }

-- | Spawn a commandline thing, appending the window id to the prefix string
-- you provide. (Make sure to add a space if you need it.) Do your crazy
-- xcompmgr/compositor thing.
spawnUrgencyHook :: String -> Window -> X ()
spawnUrgencyHook = urgencyHook . SpawnUrgencyHook
newtype SpawnUrgencyHook = SpawnUrgencyHook String deriving (Read, Show)

instance UrgencyHook SpawnUrgencyHook where
    urgencyHook (SpawnUrgencyHook prefix) w = spawn $ prefix ++ show w

-- | For debugging purposes, really.
stdoutUrgencyHook :: Window -> X ()
stdoutUrgencyHook = urgencyHook StdoutUrgencyHook
data StdoutUrgencyHook = StdoutUrgencyHook deriving (Read, Show)

instance UrgencyHook StdoutUrgencyHook where
    urgencyHook    _ w = io $ putStrLn $ "Urgent: " ++ show w

-- | urgencyhook such that windows on certain workspaces
-- never get urgency set.
--
-- Useful for scratchpad workspaces perhaps:
--
-- > main = xmonad (withUrgencyHook (filterUrgencyHook ["NSP", "SP"]) def)
filterUrgencyHook :: [WorkspaceId] -> Window -> X ()
filterUrgencyHook skips = filterUrgencyHook' $ maybe False (`elem` skips) <$> windowTag

-- | 'filterUrgencyHook' that takes a generic 'Query' to select which windows
-- should never be marked urgent.
filterUrgencyHook' :: Query Bool -> Window -> X ()
filterUrgencyHook' q w = whenX (runQuery q w) (clearUrgents' [w])

-- | Mark the given window urgent.
--
-- __Under river this is the only way a window becomes urgent.__  X11 had two
-- others and neither has a counterpart here: a client set the urgency flag in
-- @WM_HINTS@ and xmonad noticed the property change, or it sent a
-- @_NET_WM_STATE_DEMANDS_ATTENTION@ client message.  See $river.
--
-- The window still goes through the configured 'SuppressWhen' and
-- 'RemindWhen', so a config that asks for a window it can already see to be
-- left alone still gets that.
askUrgent :: Window -> X ()
askUrgent w = XC.with $ \(MarkUrgent mark) -> mark w

-- | Helper for 'ManageHook' that marks the window as urgent (unless
-- suppressed, see 'SuppressWhen'). Useful in
-- 'XMonad.Hooks.EwmhDesktops.setEwmhActivateHook' and also in combination
-- with "XMonad.Hooks.InsertPosition", "XMonad.Hooks.Focus".
doAskUrgent :: ManageHook
doAskUrgent = ask >>= \w -> liftX (askUrgent w) >> mempty
