-----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Hooks.ManageDebug
-- Description :  A manageHook and associated logHook for debugging ManageHooks.
-- Copyright   :  (c) Brandon S Allbery KF8NH, 2014
-- License     :  BSD3-style (see LICENSE)
--
-- Maintainer  :  allbery.b@gmail.com
-- Stability   :  unstable
-- Portability :  not portable
--
-- A @manageHook@ and associated @logHook@ for debugging 'ManageHook's.
-- Simplest usage: wrap your xmonad config in the @debugManageHook@ combinator.
-- Or use @debugManageHookOn@ for a triggerable version, specifying the
-- triggering key sequence in "XMonad.Util.EZConfig" syntax. Or use the
-- individual hooks in whatever way you see fit.
--
-----------------------------------------------------------------------------
--
--

module XMonad.Hooks.ManageDebug (debugManageHook
                                ,debugManageHookOn
                                ,manageDebug
                                ,manageDebug'
                                ,maybeManageDebug
                                ,manageDebugLogHook
                                ,debugNextManagedWindow
                                ) where

import           XMonad
import           XMonad.Hooks.DebugStack
import           XMonad.Util.DebugWindow
import           XMonad.Util.EZConfig
import qualified XMonad.Util.ExtensibleState as XS

import           Control.Monad       (when)
import           System.IO
import           System.Process

-- state for manageHook debugging to trigger logHook debugging
data MSDFinal = DoLogHook Handle Bool | SkipLogHook deriving Show
data MSDTrigger = MSDActivated Handle Bool | MSDInactive deriving Show
data ManageStackDebug = MSD MSDFinal MSDTrigger deriving Show
instance ExtensionClass ManageStackDebug where
  initialValue = MSD SkipLogHook MSDInactive

-- | A combinator to add full 'ManageHook' debugging in a single operation.
debugManageHook :: XConfig l -> XConfig l
debugManageHook cf = cf {logHook    = manageDebugLogHook <> logHook    cf
                        ,manageHook = manageDebug        <> manageHook cf
                        }

-- | A combinator to add triggerable 'ManageHook' debugging in a single operation.
--   Specify a key sequence as a string in "XMonad.Util.EZConfig" syntax; press
--   this key before opening the window to get just that logged.
debugManageHookOn :: String -> XConfig l -> XConfig l
debugManageHookOn key cf = cf {logHook    = manageDebugLogHook <> logHook    cf
                              ,manageHook = maybeManageDebug   <> manageHook cf
                              }
                           `additionalKeysP`
                           [(key,debugNextManagedWindow)]

-- | Place this at the start of a 'ManageHook', or possibly other places for a
--   more limited view. It will show the current 'StackSet' state and the new
--   window, and set a flag so that @manageDebugLogHook@ will display the
--   final 'StackSet' state.
--
--   Note that the initial state shows only the current workspace; the final
--   one shows all workspaces, since your 'manageHook' might use e.g. 'doShift'.
--
--   This logs to 'stderr' because there's no way to pass it a message handle,
--   and to maintain backward compatibility. See @manageDebug'@ for an
--   alternative that accepts a 'Handle'.
manageDebug :: ManageHook
manageDebug = manageDebug' stderr False

-- | @manageDebug@ to a 'Handle'. The flag specifies whether the 'Handle' should
--   be closed after logging. @debugNextManagedWindow@ uses this to log to
--   'xmessage', but it can be used to log to any chosen process or file.
--
--   Logging is incremental, so if your 'Handle' is to something that can show
--   output before the 'logHook' prints the final 'StackSet' and optionally
--   closes it, you can see it before it completes.
--
--   You should be careful to pass 'False' if you are logging to 'stdout' or
--   'stderr', and to pass 'True' if you are logging to a process. Also remember
--   that 'xmonad' subprocesses are auto-reaped, so don't try to wait for one.
manageDebug' :: Handle -> Bool -> ManageHook
manageDebug' h cp = do
  w <- ask
  liftX $ do
    io $ hPutStrLn h "\n== manageHook; current stack =="
    debugStackString >>= io . hPutStrLn h
    ws <- debugWindow w
    io $ hPutStrLn h $ "\nnew window:\n  " ++ ws
    XS.modify $ \(MSD _ go) -> MSD (DoLogHook h cp) go
  idHook

-- | @manageDebug@ only if the user requested it with @debugNextManagedWindow@.
maybeManageDebug :: ManageHook
maybeManageDebug = do
  go <- liftX $ do
    MSD _ go' <- XS.get
    -- leave it active, as we may manage multiple windows before the 'logHook'
    -- so we now deactivate it there
    return go'
  case go of
    MSDActivated h cp -> manageDebug' h cp
    _                 -> idHook

-- | If @manageDebug'@ has set the debug-stack flag, show the stack.
manageDebugLogHook :: X ()
manageDebugLogHook = do
                       MSD log' _ <- XS.get
                       case log' of
                         DoLogHook h cp -> do
                                            io $ hPutStrLn h "\n== manageHook; final stack =="
                                            debugStackFullString >>= io . hPutStrLn h
                                            when cp $ io $ hClose h
                                            -- see comment in maybeManageDebug
                                            XS.put $ MSD SkipLogHook MSDInactive
                         _              -> idHook

-- | Request that the next window to be managed be @manageDebug@-ed. This can
--   be used anywhere an X action can, such as key bindings, mouse bindings
--   (presumably with 'const'), 'startupHook', etc. The output is sent to
--   '$XMONAD_XMESSAGE' or 'xmessage'.
debugNextManagedWindow :: X ()
debugNextManagedWindow = do
  let cpd = (shell "${XMONAD_XMESSAGE:-xmessage} \
                      \-file - \
                      \-default okay \
                      \-xrm '*international:true' \
                      \-xrm '*fontSet:-*-fixed-medium-r-normal-*-18-*-*-*-*-*-*-*,\
                                     \-*-fixed-*-*-*-*-18-*-*-*-*-*-*-*,\
                                     \-*-*-*-*-*-*-18-*-*-*-*-*-*-*'"){std_in = CreatePipe}
  hs <- catchX (fmap Just $ io $ createProcess cpd) (return Nothing)
  case hs of
    Just (Just h, _, _, _) -> do
                                io $ hSetBuffering h LineBuffering
                                XS.modify $ \(MSD log' _) -> MSD log' (MSDActivated h True)
    _                      -> return ()
