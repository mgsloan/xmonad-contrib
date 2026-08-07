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

# A clean build of contrib, always.  Incremental builds only recompile what
# failed last time -- a module that succeeded produces an object file and is
# then silent -- so the log undercounts everything that works, and the survey
# reports a collapse that has not happened.  Ten minutes is worth a number
# that means something.
stack clean xmonad-contrib >/dev/null 2>&1
# Kept rather than a mktemp: when the numbers look wrong the log is the only
# way to find out why, and discarding it means re-running a ten-minute build.
log=.survey.log
stack build xmonad-contrib:lib --ghc-options="-fkeep-going" > "$log" 2>&1
python3 tests/mksurvey.py "$log"
echo "build log: $log"
