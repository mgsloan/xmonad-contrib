"""Rewrite the library's exposed-modules to exactly what the last survey built.

A cabal file that names a module it cannot compile fails to build at all, so
the exposed list has to be the set that works -- and keeping that in step by
hand is how modules end up ported but unusable, which is the whole point of
porting them.

Reads .survey.log, so run tests/survey.sh first.
"""
import os, re, sys

log = open('.survey.log', errors='replace').read()
attempted = set(re.findall(r'\[\s*\d+ of \d+\] Compiling (\S+)', log))

# A module is broken if any error block names its file.  Warnings do not count,
# and neither does an error in a module that merely imports it: -fkeep-going
# reports each failure against its own file.
broken = set()
for path in re.findall(r'^(/\S+?\.hs):\d+:\d+: error', log, re.M):
    if '/xmonad-contrib-river/' in path:
        broken.add(path.split('/xmonad-contrib-river/')[1][:-3].replace('/', '.'))

working = sorted(m for m in attempted if m.startswith('XMonad.') and m not in broken)

src = open('xmonad-contrib.cabal').read()
start = src.index('    exposed-modules:')
end = src.index('\ntest-suite tests')
was = len(re.findall(r'^\s+(XMonad\.[\w.]+)\s*$', src[start:end], re.M))

body = '    exposed-modules:    ' + '\n'.join(
    ('' if i == 0 else ' ' * 24) + m for i, m in enumerate(working)) + '\n'
open('xmonad-contrib.cabal', 'w').write(src[:start] + body + src[end:])
print(f'exposed-modules: {was} -> {len(working)}', file=sys.stderr)
