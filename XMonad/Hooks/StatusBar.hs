{-# LANGUAGE FlexibleContexts, TypeApplications, TupleSections  #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Hooks.StatusBar
-- Description :  Composable and dynamic status bars.
-- Copyright   :  (c) Yecine Megdiche <yecine.megdiche@gmail.com>
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  Yecine Megdiche <yecine.megdiche@gmail.com>
-- Stability   :  unstable
-- Portability :  unportable
--
-- xmonad calls the logHook with every internal state update, which is
-- useful for (among other things) outputting status information to an
-- external status bar program such as xmobar or dzen.
--
-- This module provides a composable interface for (re)starting these status
-- bars and logging to them through a pipe.  (Upstream also offers logging to
-- an X root window property; see "No property logging" below.)  There's also
-- "XMonad.Hooks.StatusBar.PP" which provides an abstraction and some
-- utilities for customization what is logged to a status bar. Together, these
-- are a modern replacement for "XMonad.Hooks.DynamicLog", which is now just a
-- compatibility wrapper.
--
-----------------------------------------------------------------------------

module XMonad.Hooks.StatusBar (
  -- * Usage
  -- $usage
  StatusBarConfig(..),
  withSB,

  -- * Available Configs
  -- $availableconfigs
  statusBarGeneric,
  statusBarPipe,

  -- * Multiple Status Bars
  -- $multiple

  -- * Dynamic Status Bars
  -- $dynamic
  dynamicSBs,
  dynamicEasySBs,

  -- * No property logging
  -- $noprop

  -- * Managing status bar Processes
  -- $sbprocess
  spawnStatusBar,
  killStatusBar,
  killAllStatusBars,
  startAllStatusBars,
  ) where

import Control.Exception (SomeException, try)
import Data.IORef (newIORef, readIORef, writeIORef)
import qualified Data.Map as M
import System.IO (hClose)
import System.Posix.Signals (sigTERM, signalProcessGroup)
import System.Posix.Types (ProcessID)

import XMonad
import XMonad.Prelude

import XMonad.Util.Run
import qualified XMonad.Util.ExtensibleState as XS

import XMonad.Layout.LayoutModifier
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.Rescreen
import XMonad.Hooks.StatusBar.PP
import qualified XMonad.StackSet as W

-- $usage
-- You can use this module with the following in your @xmonad.hs@:
--
-- > import XMonad
-- > import XMonad.Hooks.StatusBar
-- > import XMonad.Hooks.StatusBar.PP
--
-- The way to use this module is 'statusBarPipe' with 'withSB'; it takes care
-- of the necessary plumbing.  The bar reads what xmonad logs on its standard
-- input:
--
-- > main = do
-- >   mySB <- statusBarPipe "xmobar" (pure xmobarPP)
-- >   xmonad $ withSB mySB def
--
-- For xmobar this means the @StdinReader@ plugin in your @.xmobarrc@:
--
-- > Config { ...
-- >        , commands = [ Run StdinReader, ... ]
-- >        , template = "%StdinReader% }{ ..."
-- >        }
--
-- Note that 'statusBarPipe' returns @IO StatusBarConfig@, which is why it is
-- bound in @main@ rather than written inline.
--
-- Most users will, however, want to customize the logging and integrate it
-- into their existing custom xmonad configuration. The 'withSB'
-- function is more appropriate in this case: it doesn't touch your
-- keybindings, layout modifiers, or event hooks; instead, you're expected
-- to configure "XMonad.Hooks.ManageDocks" yourself. Here's what that might
-- look like:
--
-- > main = do
-- >   mySB <- statusBarPipe "xmobar" (pure myPP)
-- >   xmonad . withSB mySB . docks $ def {...}
--
-- Please be aware that a pipe is bug-prone: if anything goes wrong with the
-- bar, xmonad will freeze.  Upstream offers property-based logging as the
-- alternative; see "No property logging" below for why that is not here.


-- $plumbing
-- If you do not want to use any of the "batteries included" functions above,
-- you can also add all of the necessary plumbing yourself (the source of
-- 'withSB' might come in handy here).
--
-- 'XMonad.Hooks.StatusBar.PP.dynamicLogString' renders the current state, and
-- what you do with the resulting string is up to you.  Note that setting
-- 'logHook' only sets up xmonad's output; you are responsible for starting
-- your own status bar program and making sure it reads what xmonad writes.  To
-- start your bar, simply put it into your 'startupHook'.  You will also have
-- to add 'docks' and 'avoidStruts' to your config.
--
-- Doing that by hand has the problem that the bar will not get restarted
-- whenever you restart xmonad ('XMonad.Util.SpawnOnce.spawnOnce' will simply
-- prevent your chosen status bar from spawning again).  'statusBarPipe' takes
-- care of the necessary plumbing /and/ keeps track of the started status bars,
-- so they can be correctly restarted with xmonad.  This is achieved using
-- 'spawnStatusBar' to start them and 'killStatusBar' to kill previously
-- started bars.
--
-- Even if you don't use a status bar, you can still use 'dynamicLogString' to
-- show on-screen notifications in response to some events. For example, to show
-- the current layout when it changes, you could make a keybinding to cycle the
-- layout and display the current status:
--
-- > ((mod1Mask, xK_a), sendMessage NextLayout >> (dynamicLogString myPP >>= trace))
--
-- If you don't want to use the 'statusBar' function, you can, again, also
-- manually add all of the required components, like this:
--
-- > import XMonad.Util.Run (hPutStrLn, spawnPipe)
-- >
-- > main = do
-- >     h <- spawnPipe "dzen2 -options -foo -bar"
-- >     xmonad $ def {
-- >       ...
-- >       , logHook = dynamicLogWithPP $ def { ppOutput = hPutStrLn h }
-- >       ...
-- >       }
--
-- In the above, note that if you use @spawnPipe@ you need to redefine the
-- 'ppOutput' field of your pretty-printer; by default the status will be
-- printed to stdout rather than the pipe you create. This was meant to be
-- used together with running xmonad piped to a status bar like so: @xmonad |
-- dzen2@, and is what the old 'XMonad.Hooks.DynamicLog.dynamicLog' assumes,
-- but it isn't recommended in modern setups. Applications launched from
-- xmonad inherit its stdout and stderr, and will print their own garbage to
-- the status bar.


-- | This datataype abstracts a status bar to provide a common interface
-- functions like 'statusBarPipe'. Once defined, a status
-- bar can be incorporated in 'XConfig' by using 'withSB' or
-- which takes care of the necessary plumbing.
data StatusBarConfig = StatusBarConfig  { sbLogHook     :: X ()
                                        -- ^ What and how to log to the status bar.
                                        , sbStartupHook :: X ()
                                        -- ^ How to start the status bar.
                                        , sbCleanupHook :: X ()
                                        -- ^ How to kill the status bar.
                                        }

instance Semigroup StatusBarConfig where
    StatusBarConfig l s c <> StatusBarConfig l' s' c' =
      StatusBarConfig (l <> l') (s <> s') (c <> c')

instance Monoid StatusBarConfig where
    mempty = StatusBarConfig mempty mempty mempty

-- | Per default, all the hooks do nothing.
instance Default StatusBarConfig where
    def = mempty

-- | Incorporates a 'StatusBarConfig' into an 'XConfig' by taking care of the
-- necessary plumbing (starting, restarting and logging to it).
--
-- Using this function multiple times to combine status bars may result in
-- only one status bar working properly. See the section on using multiple
-- status bars for more details.
withSB :: LayoutClass l Window
       => StatusBarConfig    -- ^ The status bar config
       -> XConfig l          -- ^ The base config
       -> XConfig l
withSB (StatusBarConfig lh sh ch) conf = conf
    { logHook     = logHook conf *> lh
    , startupHook = startupHook conf *> ch *> sh
    }

-- | Like 'withSB', but takes an extra key to toggle struts. It also
-- applies the 'avoidStruts' layout modifier and the 'docks' combinator.
--
-- Using this function multiple times to combine status bars may result in
-- only one status bar working properly. See the section on using multiple
-- status bars for more details.
-- $noprop
-- Upstream also offers @statusBarProp@, @statusBarPropTo@, @xmonadPropLog@,
-- @xmonadPropLog'@ and @xmonadDefProp@.  Those log by writing a string to a
-- property -- @_XMONAD_LOG@ by default -- on the X root window, for a bar
-- configured to read it: xmobar's @XMonadLog@ plugin, and the
-- @scripts\/xmonadpropread.hs@ wrapper for bars without one.
--
-- Wayland has no root window and no properties, and river offers nothing in
-- their place, so none of them are here.  'statusBarPipe' is the way to log,
-- and it is the way that ports: the bar reads its input on stdin.  A config
-- saying
--
-- > mySB = statusBarProp "xmobar" (pure xmobarPP)
-- > main = xmonad $ withSB mySB def
--
-- becomes
--
-- > main = do
-- >   mySB <- statusBarPipe "xmobar" (pure xmobarPP)
-- >   xmonad $ withSB mySB def
--
-- and the bar's configuration changes from @XMonadLog@ to @StdinReader@.

-- | A generic 'StatusBarConfig' that launches a status bar but takes a
-- generic @X ()@ logging function instead of a 'PP'. This has several uses:
--
-- * With 'mempty' as the logging function, any dock like @trayer@ or
--   @stalonetray@ can be managed by this module.
statusBarGeneric :: String -- ^ The command line to launch the status bar
                 -> X ()   -- ^ What and how to log to the status bar ('sbLogHook')
                 -> StatusBarConfig
statusBarGeneric cmd lh = def
    { sbLogHook     = lh
    , sbStartupHook = spawnStatusBar cmd
    , sbCleanupHook = killStatusBar cmd
    }

-- | A 'StatusBarConfig' that launches a status bar and logs to it through a
-- pipe on its standard input.
statusBarPipe :: String -- ^ The command line to launch the status bar
              -> X PP   -- ^ The pretty printing options
              -> IO StatusBarConfig
statusBarPipe cmd xpp = do
    hRef <- newIORef Nothing
    return $ def
        { sbStartupHook = io (writeIORef hRef . Just =<< spawnPipe cmd)
        , sbLogHook     = do
              h' <- io (readIORef hRef)
              whenJust h' $ \h -> io . hPutStrLn h =<< dynamicLogString =<< xpp
        , sbCleanupHook = io
                          $   readIORef hRef
                          >>= (`whenJust` hClose)
                          >>  writeIORef hRef Nothing
        }


-- $multiple
-- 'StatusBarConfig' is a 'Monoid', which means that multiple status bars can
-- be combined together using '<>' or 'mconcat' and passed to 'withSB'.
--
-- Here's an example of what such declarative configuration of multiple status
-- bars may look like:
--
-- > -- Make sure to setup the xmobar configs accordingly
-- > main = do
-- >   xmobarTop    <- statusBarPipe "xmobar -x 0 ~/.config/xmobar/xmobarrc_top"    (pure ppTop)
-- >   xmobarBottom <- statusBarPipe "xmobar -x 0 ~/.config/xmobar/xmobarrc_bottom" (pure ppBottom)
-- >   xmobar1      <- statusBarPipe "xmobar -x 1 ~/.config/xmobar/xmobarrc1"       (pure pp1)
-- >   xmonad $ withSB (xmobarTop <> xmobarBottom <> xmobar1) myConfig
--
-- Each bar has its own pipe, so each gets its own content; every one of them
-- reads its input on stdin.
--
-- "XMonad.Util.Loggers" includes loggers that can be bound to specific screens,
-- like 'logCurrentOnScreen', that might be useful with multiple screens.
--
-- Long-time xmonad users will note that the above config is equivalent to
-- the following less robust and more verbose configuration that they might
-- find in their old configs:
--
-- > main = do
-- >   -- do not use this, this is an example of a deprecated config
-- >   xmproc0 <- spawnPipe "xmobar -x 0 ~/.config/xmobar/xmobarrc_top"
-- >   xmproc1 <- spawnPipe "xmobar -x 0 ~/.config/xmobar/xmobarrc_bottom"
-- >   xmproc2 <- spawnPipe "xmobar -x 1 ~/.config/xmobar/xmobarrc1"
-- >   xmonad $ def {
-- >     ...
-- >     , logHook = dynamicLogWithPP ppTop { ppOutput = hPutStrLn xmproc0 }
-- >              >> dynamicLogWithPP ppBottom { ppOutput = hPutStrLn xmproc1 }
-- >              >> dynamicLogWithPP pp1 { ppOutput = hPutStrLn xmproc2 }
-- >     ...
-- >   }
--
-- By using the new interface, the config becomes more declarative and there's
-- less room for errors.
--
-- The only *problem* now is that the status bars will not be updated when your screen
-- configuration changes (by plugging in a monitor, for example). Check the section
-- on dynamic status bars for how to do that.

-- $dynamic
-- Using multiple status bars by just combining them with '<>' works well
-- as long as the screen configuration does not change often. If it does,
-- you should use 'dynamicSBs': by providing a function that creates
-- status bars, it takes care of setting up the event hook, the log hook
-- and the startup hook necessary to make the status bars, well, dynamic.
--
-- > barSpawner :: ScreenId -> IO StatusBarConfig
-- > barSpawner 0 = do -- two bars on the main screen
-- >   top    <- statusBarPipe "xmobar -x 0 ~/.config/xmobar/xmobarrc_top"    (pure ppTop)
-- >   bottom <- statusBarPipe "xmobar -x 0 ~/.config/xmobar/xmobarrc_bottom" (pure ppBottom)
-- >   pure (top <> bottom)
-- > barSpawner 1 = statusBarPipe "xmobar -x 1 ~/.config/xmobar/xmobarrc1" (pure pp1)
-- > barSpawner _ = mempty -- nothing on the rest of the screens
-- >
-- > main = xmonad $ dynamicSBs (io . barSpawner) (def { ... })
--
-- Make sure you specify which screen to place the status bar on (in xmobar,
-- this is achieved by the @-x@ argument). In addition to making sure that your
-- status bar lands where you intended it to land, the commands are used
-- internally to keep track of the status bars.
--
-- Note also that this interface can be used with one screen, or if
-- the screen configuration doesn't change.

newtype ActiveSBs = ASB {getASBs :: [(ScreenId,  StatusBarConfig)]}

instance ExtensionClass ActiveSBs where
  initialValue = ASB []

-- | Given a function to create status bars, 'dynamicSBs'
-- adds the dynamic status bar capabilities to the config.
-- For a version of this function that applies 'docks' and
-- 'avoidStruts', check 'dynamicEasySBs'.
--
-- Heavily inspired by "XMonad.Hooks.DynamicBars"
dynamicSBs :: (ScreenId -> X StatusBarConfig) -> XConfig l -> XConfig l
dynamicSBs f conf = addAfterRescreenHook (updateSBs f) $ conf
  { startupHook = startupHook conf >> killAllStatusBars >> updateSBs f
  , logHook     = logHook conf >> logSBs
  }

-- | Like 'dynamicSBs', but applies 'docks' to the
-- resulting config and adds 'avoidStruts' to the
-- layout.
dynamicEasySBs :: LayoutClass l Window
               => (ScreenId -> X StatusBarConfig)
               -> XConfig l
               -> XConfig (ModifiedLayout AvoidStruts l)
dynamicEasySBs f conf =
  docks . dynamicSBs f $ conf { layoutHook = avoidStruts (layoutHook conf) }

-- | Given the function to create status bars, update
-- the status bars by killing those that shouldn't be
-- visible anymore and creates any missing status bars
updateSBs :: (ScreenId -> X StatusBarConfig) -> X ()
updateSBs f = do
  actualScreens    <- withWindowSet $ return . map W.screen . W.screens
  (toKeep, toKill) <-
    partition ((`elem` actualScreens) . fst) . getASBs <$> XS.get
  -- Kill the status bars
  cleanSBs (map snd toKill)
  -- Create new status bars if needed
  let missing = actualScreens \\ map fst toKeep
  added <- traverse (\s -> (s,) <$> f s) missing
  traverse_ (sbStartupHook . snd) added
  XS.put (ASB (toKeep ++ added))

-- | Run 'sbLogHook' for the saved 'StatusBarConfig's
logSBs :: X ()
logSBs = XS.get >>= traverse_ (sbLogHook . snd) . getASBs

-- | Kill the given 'StatusBarConfig's from the given
-- list
cleanSBs :: [StatusBarConfig] -> X ()
cleanSBs = traverse_ sbCleanupHook



-- This newtype wrapper, together with the ExtensionClass instance make use of
-- the extensible state to save the PIDs bewteen xmonad restarts.
newtype StatusBarPIDs = StatusBarPIDs { getPIDs :: M.Map String ProcessID }
  deriving (Show, Read)

instance ExtensionClass StatusBarPIDs where
  initialValue = StatusBarPIDs mempty
  extensionType = PersistentExtension

-- | Kills the status bar started with 'spawnStatusBar' using the given command
-- and resets the state. This could go for example at the beginning of the
-- startupHook, to kill the status bars that need to be restarted.
--
-- Concretely, this function sends a 'sigTERM' to the saved PIDs using
-- 'signalProcessGroup' to effectively terminate all processes, regardless
-- of how many were started by using  'spawnStatusBar'.
--
-- There is one caveat to keep in mind: to keep the implementation simple;
-- no checks are executed before terminating the processes. This means: if the
-- started process dies for some reason, and enough time passes for the PIDs
-- to wrap around, this function might terminate another process that happens
-- to have the same PID. However, this isn't a typical usage scenario.
killStatusBar :: String -- ^ The command used to start the status bar
                 -> X ()
killStatusBar cmd = do
    XS.gets (M.lookup cmd . getPIDs) >>= flip whenJust (io . killPid)
    XS.modify (StatusBarPIDs . M.delete cmd . getPIDs)

killPid :: ProcessID -> IO ()
killPid pidToKill = void $ try @SomeException (signalProcessGroup sigTERM pidToKill)

-- | Spawns a status bar and saves its PID together with the commands that was
-- used to start it. This is useful when the status bars should be restarted
-- with xmonad. Use this in combination with 'killStatusBar'.
--
-- Note: in some systems, multiple processes might start, even though one command is
-- provided. This means the first PID, of the group leader, is saved.
spawnStatusBar :: String -- ^ The command used to spawn the status bar
               -> X ()
spawnStatusBar cmd = do
  newPid <- spawnPID cmd
  XS.modify (StatusBarPIDs . M.insert cmd newPid . getPIDs)

-- | Kill all status bars started with 'spawnStatusBar'. Note the
-- caveats in 'cleanupStatusBar'
killAllStatusBars :: X ()
killAllStatusBars =
  XS.gets (M.elems . getPIDs) >>= io . traverse_ killPid >> XS.put (StatusBarPIDs mempty)

-- | Start all status bars. Note that you do not need this in your startup hook.
-- This can be bound to a keybinding for example to be used in tandem with
-- `killAllStatusBars`.
startAllStatusBars :: X ()
startAllStatusBars = XS.get >>= traverse_ (sbStartupHook . snd) . getASBs
