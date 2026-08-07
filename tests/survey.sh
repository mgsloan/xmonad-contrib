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

# Build against a cabal file that names every module on disk, not the ~180 the
# checked-in one names.  A library cannot list a module it fails to build, so
# the real file only ever names what already works -- and surveying that
# answers "does what works still work", which is not the question.  It can
# never report a module that has become buildable, which is the entire point.
#
# Restored on every exit path, including a Ctrl-C mid-build: leaving the
# generated file in place would be a working tree whose library silently
# fails to build.
cp xmonad-contrib.cabal .survey-cabal.bak
trap 'mv -f .survey-cabal.bak xmonad-contrib.cabal' EXIT INT TERM
python3 tests/expose-all.py xmonad-contrib.cabal

stack build xmonad-contrib:lib --ghc-options="-fkeep-going" > "$log" 2>&1
mv -f .survey-cabal.bak xmonad-contrib.cabal
trap - EXIT INT TERM

python3 tests/mksurvey.py "$log"
echo "build log: $log"
