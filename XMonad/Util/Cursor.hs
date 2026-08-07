----------------------------------------------------------------------------
-- |
-- Module      :  XMonad.Util.Cursor
-- Description :  Set the default mouse cursor.
-- Copyright   :  (c) 2009 Collabora Ltd
-- License     :  BSD-style (see xmonad/LICENSE)
--
-- Maintainer  :  Andres Salomon <dilinger@collabora.co.uk>
-- Stability   :  unstable
-- Portability :  unportable
--
-- A module for setting the default mouse cursor.
--
-- Under river it sets nothing.  See $river.
-----------------------------------------------------------------------------

module XMonad.Util.Cursor
    ( -- * Usage:
      -- $usage
      setDefaultCursor,
      -- * Cursor glyphs
      -- $glyphs
      Glyph,
      xC_num_glyphs, xC_X_cursor, xC_arrow, xC_based_arrow_down,
      xC_based_arrow_up, xC_boat, xC_bogosity, xC_bottom_left_corner,
      xC_bottom_right_corner, xC_bottom_side, xC_bottom_tee,
      xC_box_spiral, xC_center_ptr, xC_circle, xC_clock, xC_coffee_mug,
      xC_cross, xC_cross_reverse, xC_crosshair, xC_diamond_cross,
      xC_dot, xC_dotbox, xC_double_arrow, xC_draft_large,
      xC_draft_small, xC_draped_box, xC_exchange, xC_fleur, xC_gobbler,
      xC_gumby, xC_hand1, xC_hand2, xC_heart, xC_icon, xC_iron_cross,
      xC_left_ptr, xC_left_side, xC_left_tee, xC_leftbutton,
      xC_ll_angle, xC_lr_angle, xC_man, xC_middlebutton, xC_mouse,
      xC_pencil, xC_pirate, xC_plus, xC_question_arrow, xC_right_ptr,
      xC_right_side, xC_right_tee, xC_rightbutton, xC_rtl_logo,
      xC_sailboat, xC_sb_down_arrow, xC_sb_h_double_arrow,
      xC_sb_left_arrow, xC_sb_right_arrow, xC_sb_up_arrow,
      xC_sb_v_double_arrow, xC_shuttle, xC_sizing, xC_spider,
      xC_spraycan, xC_star, xC_target, xC_tcross, xC_top_left_arrow,
      xC_top_left_corner, xC_top_right_corner, xC_top_side, xC_top_tee,
      xC_trek, xC_ul_angle, xC_umbrella, xC_ur_angle, xC_watch, xC_xterm,
      -- * Differences under river
      -- $river
    ) where

import XMonad

-- $usage
--
-- >   setDefaultCursor xC_left_ptr
--
--   For example, to override the default gnome cursor:
--
-- >   import XMonad.Util.Cursor
-- >   main = xmonad gnomeConfig { startupHook = setDefaultCursor xC_pirate }
--
--   Arrr!

-- $river
--
-- __'setDefaultCursor' does nothing under river, and there is nothing it
-- could do.__
--
-- The X11 version created a cursor from the font glyph and set it on the root
-- window, which is what every window not overriding it inherited.  Wayland has
-- no root window and no cursor font, and the model is different in kind rather
-- than in detail: a client sets its own cursor from a theme, and the
-- compositor draws the cursor everywhere a client does not.  There is no
-- single glyph a window manager can nominate.
--
-- What river does offer is the /theme/, through
-- @river_seat_v1.set_xcursor_theme@ -- a name and a size, from which the
-- compositor picks shapes itself.  That is a different request with different
-- arguments and a different meaning, so it is not spelled as this function.
-- It lives in "XMonad.River" as @setCursorTheme@, and a config that wants to
-- choose a cursor wants that one:
--
-- > import XMonad.River (setCursorTheme)
-- > main = xmonad def { startupHook = setCursorTheme "Adwaita" 24 }
--
-- Note also, as river's own documentation does, that a window manager
-- generally wants to set @XCURSOR_THEME@ and @XCURSOR_SIZE@ in the environment
-- of the programs it starts, so that clients drawing their own cursors agree
-- with the compositor.

-- $glyphs
--
-- The X11 cursor font, kept as plain numbers.
--
-- These are re-exported from @Graphics.X11.Xlib.Cursor@ on the X11 build.
-- They are defined here instead because river has no @Graphics.X11@ to
-- re-export from, and because they are what configs actually write:
-- @setDefaultCursor xC_left_ptr@ should go on compiling, and say at the call
-- site that it no longer does anything, rather than fail to resolve a name.
--
-- They name shapes in a font that no longer exists, so nothing consumes them.

-- | A glyph in the X11 cursor font.
type Glyph = Int

-- | Set the default (root) cursor.  A no-op; see $river.
setDefaultCursor :: Glyph -> X ()
setDefaultCursor _ = pure ()
{-# DEPRECATED setDefaultCursor
      "Does nothing under river: there is no root window and no cursor font. \
      \Use XMonad.River.setCursorTheme to choose a cursor theme instead." #-}

xC_num_glyphs, xC_X_cursor, xC_arrow, xC_based_arrow_down,
  xC_based_arrow_up, xC_boat, xC_bogosity, xC_bottom_left_corner,
  xC_bottom_right_corner, xC_bottom_side, xC_bottom_tee, xC_box_spiral,
  xC_center_ptr, xC_circle, xC_clock, xC_coffee_mug, xC_cross,
  xC_cross_reverse, xC_crosshair, xC_diamond_cross, xC_dot, xC_dotbox,
  xC_double_arrow, xC_draft_large, xC_draft_small, xC_draped_box,
  xC_exchange, xC_fleur, xC_gobbler, xC_gumby, xC_hand1, xC_hand2,
  xC_heart, xC_icon, xC_iron_cross, xC_left_ptr, xC_left_side,
  xC_left_tee, xC_leftbutton, xC_ll_angle, xC_lr_angle, xC_man,
  xC_middlebutton, xC_mouse, xC_pencil, xC_pirate, xC_plus,
  xC_question_arrow, xC_right_ptr, xC_right_side, xC_right_tee,
  xC_rightbutton, xC_rtl_logo, xC_sailboat, xC_sb_down_arrow,
  xC_sb_h_double_arrow, xC_sb_left_arrow, xC_sb_right_arrow,
  xC_sb_up_arrow, xC_sb_v_double_arrow, xC_shuttle, xC_sizing, xC_spider,
  xC_spraycan, xC_star, xC_target, xC_tcross, xC_top_left_arrow,
  xC_top_left_corner, xC_top_right_corner, xC_top_side, xC_top_tee,
  xC_trek, xC_ul_angle, xC_umbrella, xC_ur_angle, xC_watch, xC_xterm
  :: Glyph
xC_num_glyphs = 154
xC_X_cursor = 0
xC_arrow = 2
xC_based_arrow_down = 4
xC_based_arrow_up = 6
xC_boat = 8
xC_bogosity = 10
xC_bottom_left_corner = 12
xC_bottom_right_corner = 14
xC_bottom_side = 16
xC_bottom_tee = 18
xC_box_spiral = 20
xC_center_ptr = 22
xC_circle = 24
xC_clock = 26
xC_coffee_mug = 28
xC_cross = 30
xC_cross_reverse = 32
xC_crosshair = 34
xC_diamond_cross = 36
xC_dot = 38
xC_dotbox = 40
xC_double_arrow = 42
xC_draft_large = 44
xC_draft_small = 46
xC_draped_box = 48
xC_exchange = 50
xC_fleur = 52
xC_gobbler = 54
xC_gumby = 56
xC_hand1 = 58
xC_hand2 = 60
xC_heart = 62
xC_icon = 64
xC_iron_cross = 66
xC_left_ptr = 68
xC_left_side = 70
xC_left_tee = 72
xC_leftbutton = 74
xC_ll_angle = 76
xC_lr_angle = 78
xC_man = 80
xC_middlebutton = 82
xC_mouse = 84
xC_pencil = 86
xC_pirate = 88
xC_plus = 90
xC_question_arrow = 92
xC_right_ptr = 94
xC_right_side = 96
xC_right_tee = 98
xC_rightbutton = 100
xC_rtl_logo = 102
xC_sailboat = 104
xC_sb_down_arrow = 106
xC_sb_h_double_arrow = 108
xC_sb_left_arrow = 110
xC_sb_right_arrow = 112
xC_sb_up_arrow = 114
xC_sb_v_double_arrow = 116
xC_shuttle = 118
xC_sizing = 120
xC_spider = 122
xC_spraycan = 124
xC_star = 126
xC_target = 128
xC_tcross = 130
xC_top_left_arrow = 132
xC_top_left_corner = 134
xC_top_right_corner = 136
xC_top_side = 138
xC_top_tee = 140
xC_trek = 142
xC_ul_angle = 144
xC_umbrella = 146
xC_ur_angle = 148
xC_watch = 150
xC_xterm = 152
