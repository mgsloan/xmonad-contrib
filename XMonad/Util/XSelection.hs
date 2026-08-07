{- |
Module      :  XMonad.Util.XSelection
Description :  A module for accessing and manipulating the primary selection.
Copyright   :  (C) 2007 Andrea Rossato, Matthew Sackman
License     :  BSD3

Maintainer  : Gwern Branwen <gwern0@gmail.com>
Stability   :  unstable
Portability :  unportable

Access to the selection and the clipboard, via @wl-paste@.

The river implementation.  Every signature is upstream's, which is unusually
easy here: nothing in this module's interface mentions an X11 type, so a
change of mechanism is invisible to callers.  What changes is everything
behind it.

== Why an external program

Upstream opens its own display, creates a window, and does a synchronous
selection transfer -- a small X client hiding inside a function.  The direct
translation would be @wl_data_device@, and it does not work: the protocol says
a @selection@ event is delivered

> immediately before receiving keyboard focus and when a new selection is set
> while the client has keyboard focus

and a window manager has no keyboard-focused surface.  It is not in the focus
chain at all, so a @wl_data_device@ it bound would simply never be told about
a selection.  The primary selection is worse still: it is
@zwp_primary_selection_v1@, an entirely separate protocol.

@wl-paste@ solves this by being a real client that can take focus for the
instant it needs to.  Shelling out to it is what every Wayland tool does, and
it is the same approach the prototype took for prompts.

== The cost

A runtime dependency on @wl-clipboard@, which is not a build dependency and so
cannot be checked for at compile time.  If it is missing these functions say
so once, on stderr, rather than returning an empty string -- a paste binding
that quietly does nothing is indistinguishable from a broken config, and the
backend is the last place anyone would look.

-}

module XMonad.Util.XSelection (  -- * Usage
                                 getSelection,
                                 getClipboard,
                                 promptSelection,
                                 safePromptSelection,
                                 transformPromptSelection,
                                 transformSafePromptSelection) where

import Control.Exception as E (SomeException (..), try)
import System.Process (readProcess)
import XMonad
import XMonad.River (warnUnimplemented)
import XMonad.Util.Run (safeSpawn, unsafeSpawn)

{- $usage
   Add @import XMonad.Util.XSelection@ to the top of Config.hs

   If one wanted to run Firefox with the selection as an argument (perhaps
   the selection string is an URL you just highlighted), then one could add
   to the xmonad.hs a line like thus:

   > , ((modm .|. shiftMask, xK_b), promptSelection "firefox")

   To add a 'paste' keybinding in your prompts, use:

   > prompt_extra_bindings = [
   >   ((mod1Mask, xK_v), getClipboard >>= insertString) -- Alt+v to paste
   >   ]

   Requires @wl-clipboard@ to be installed.
-}

-- | Read one selection through @wl-paste@.
--
-- Trailing newlines are suppressed: @wl-paste@ adds one by default, which
-- would otherwise end up in every URL handed to a browser.
wlPaste :: [String] -> IO String
wlPaste args = do
  r <- E.try (readProcess "wl-paste" ("--no-newline" : args) "")
  case r of
    Right s -> pure s
    Left (SomeException _) -> do
      warnUnimplemented "XMonad.Util.XSelection"
        "wl-paste could not be run, so the selection is empty.  Install \
        \wl-clipboard; a window manager cannot read the selection itself, \
        \because Wayland only offers it to the client holding keyboard focus."
      pure ""

-- | The primary selection -- what a middle-click pastes.
getSelection :: MonadIO m => m String
getSelection = io (wlPaste ["--primary"])

-- | The clipboard -- what an explicit copy puts there.
getClipboard :: MonadIO m => m String
getClipboard = io (wlPaste [])

-- Upstream also offers getSecondarySelection.  X11 had three selections;
-- Wayland has two, and there is no secondary to read.  It is absent rather
-- than returning "", so code that wants it fails at the call site instead of
-- silently pasting nothing.

{- | A wrapper around 'getSelection'. Makes it convenient to run a program with the current selection as an argument.
  This is convenient for handling URLs, in particular. For example, in your Config.hs you could bind a key to
         @promptSelection \"firefox\"@;
  this would allow you to highlight a URL string and then immediately open it up in Firefox.

  'promptSelection' passes strings through the system shell, \/bin\/sh; if you do not wish your selected text
  to be interpreted or mangled by the shell, use 'safePromptSelection'. safePromptSelection will bypass the
  shell using 'safeSpawn' from "XMonad.Util.Run"; see its documentation for more
  details on the advantages and disadvantages of using safeSpawn. -}
promptSelection, safePromptSelection, unsafePromptSelection :: String -> X ()
promptSelection = unsafePromptSelection
safePromptSelection app = safeSpawn app . return =<< getSelection
unsafePromptSelection app = unsafeSpawn . (\x -> app ++ " " ++ x) =<< getSelection

{- | A wrapper around 'promptSelection' and its safe variant. They take two parameters, the
     first is a function that transforms strings, and the second is the application to run.
     The transformer essentially transforms the selection in X.
     One example is to wrap code, such as a command line action copied out of the browser
     to be run as @"sudo" ++ cmd@ or @"su - -c \""++ cmd ++"\""@. -}
transformPromptSelection, transformSafePromptSelection :: (String -> String) -> String -> X ()
transformPromptSelection f app = (safeSpawn app . return . f) =<< getSelection
transformSafePromptSelection f app = unsafeSpawn . (\x -> app ++ " " ++ x) . f =<< getSelection
