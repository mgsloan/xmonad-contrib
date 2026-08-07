#!/usr/bin/env bash
#
# Measure how much of xmonad-contrib compiles against the river backend.
#
# Usage: tests/survey.sh          (writes SURVEY.md)
#
# -fkeep-going lets GHC continue past a failing module, but modules that
# *import* a failed one are skipped, so a single chokepoint hides everything
# behind it -- XMonad.Prelude alone gates ~285 of the 328.  The report
# therefore separates "failed" from "skipped", and the skipped list says which
# failure blocks each one, so it is clear what fixing any given module buys.
set -uo pipefail
cd "$(dirname "$0")/.."
stack build xmonad >/dev/null 2>&1
log=$(mktemp); trap 'rm -f "$log"' EXIT
stack build xmonad-contrib:lib --ghc-options="-fkeep-going" > "$log" 2>&1
python3 tests/mksurvey.py "$log"
