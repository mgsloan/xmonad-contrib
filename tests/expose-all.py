"""Rewrite the library's exposed-modules to every module on disk.

The survey needs GHC to *attempt* all 334 modules; the checked-in cabal file
names only the ~180 known to compile, because a library that names a module it
cannot build does not build at all.  Measuring against that file answers "does
what already works still work", which is not the question -- it can never
discover a module that has become buildable.

Writes to the path given as argv[1].  Order is preserved for the modules
already listed, so a diff against the original shows only additions.
"""
import os, re, sys

src = open('xmonad-contrib.cabal').read()
start = src.index('    exposed-modules:')
end = src.index('\ntest-suite tests')

listed = re.findall(r'^\s+(XMonad\.[\w.]+)\s*$', src[start:end], re.M)
def declared(path):
    m = re.search(r'^module\s+([\w.]+)', open(path, errors='replace').read(), re.M)
    return m.group(1) if m else None

# A file whose module header disagrees with its path is a hard error that stops
# the build outright, before -fkeep-going can carry on past it -- so one such
# file would take the whole survey with it.  XMonad/Config/Example.hs is
# `module Main`, on purpose: it is a worked example of a config, not a library
# module, and upstream's cabal file does not list it either.
on_disk = sorted(
    m for m in (
        os.path.join(r, f)[:-3].replace('/', '.')
        for r, _, fs in os.walk('XMonad') for f in fs if f.endswith('.hs'))
    if declared(m.replace('.', '/') + '.hs') == m
)
extra = [m for m in on_disk if m not in set(listed)]

body = '    exposed-modules:    ' + '\n'.join(
    ('' if i == 0 else ' ' * 24) + m for i, m in enumerate(listed + extra)
) + '\n'
open(sys.argv[1], 'w').write(src[:start] + body + src[end:])
print(f'{len(listed)} listed + {len(extra)} unlisted = {len(listed) + len(extra)}',
      file=sys.stderr)
