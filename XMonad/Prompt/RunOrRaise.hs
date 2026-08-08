-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Prompt.RunOrRaise
-- Description :  A prompt to run a program, open a file, or raise a running program.
-- Copyright   :  (C) 2008 Justin Bogner
-- License     :  BSD3
--
-- Maintainer  :  mail@justinbogner.com
-- Stability   :  unstable
-- Portability :  unportable
--
-- A prompt for XMonad which will run a program, open a file,
-- or raise an already running program, depending on context.
--
-----------------------------------------------------------------------------

module XMonad.Prompt.RunOrRaise
    ( -- * Usage
      -- $usage
      runOrRaisePrompt,
      RunOrRaisePrompt,
    ) where

import XMonad hiding (config)
import XMonad.Prelude
import XMonad.Prompt
import XMonad.Prompt.Shell
import XMonad.Actions.WindowGo (runOrRaise)
import qualified XMonad.Hooks.ManageHelpers as MH
import XMonad.Util.Run (runProcessWithInput)

import Control.Exception as E
import System.Directory (doesDirectoryExist, doesFileExist, executable, findExecutable, getPermissions)

econst :: Monad m => a -> IOException -> m a
econst = const . return

{- $usage
1. In your @xmonad.hs@:

> import XMonad.Prompt
> import XMonad.Prompt.RunOrRaise

2. In your keybindings add something like:

>   , ((modm .|. controlMask, xK_x), runOrRaisePrompt def)

For detailed instruction on editing the key binding see
<https://xmonad.org/TUTORIAL.html#customizing-xmonad the tutorial>.
-}

data RunOrRaisePrompt = RRP
instance XPrompt RunOrRaisePrompt where
    showXPrompt RRP = "Run or Raise: "

runOrRaisePrompt :: XPConfig -> X ()
runOrRaisePrompt c = do cmds <- io getCommands
                        mkXPrompt RRP c (getShellCompl cmds $ searchPredicate c) open
open :: String -> X ()
open path = io (isNormalFile path) >>= \b ->
            if b
            then spawn $ "xdg-open \"" ++ path ++ "\""
            else uncurry runOrRaise . getTarget $ path
    where
      isNormalFile f = do
          notCommand <- isNothing <$> findExecutable f -- not a command (executable in $PATH)
          exists <- or <$> sequence [doesDirExist f, doesFileExist f]
          case (notCommand, exists) of
              (True, True) -> notExecutable f -- not executable as a file in current dir
              _            -> pure False
      notExecutable = fmap (not . executable) . getPermissions
      doesDirExist f = ("/" `isSuffixOf` f &&) <$> doesDirectoryExist f
      getTarget x = (x,isApp x)

isApp :: String -> Query Bool
isApp "firefox"     = className =? "Firefox-bin"     <||> className =? "Firefox"
isApp "thunderbird" = className =? "Thunderbird-bin" <||> className =? "Thunderbird"
isApp x = liftA2 (==) pid $ pidof x

pidof :: String -> Query Int
pidof x = io $ (runProcessWithInput "pidof" [x] [] >>= readIO) `E.catch` econst 0

-- | The window's client process, or @-1@ when it is unknown.
--
-- The X11 version read @_NET_WM_PID@ off the window.  River reports the same
-- thing as @river_window_v1.unreliable_pid@, which
-- "XMonad.Hooks.ManageHelpers" already exposes; @-1@ stands in for its
-- 'Nothing', exactly as it stood in for a missing property before.
pid :: Query Int
pid = maybe (-1) fromIntegral <$> MH.pid
