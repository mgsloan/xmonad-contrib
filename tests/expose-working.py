"""Enable exactly the modules the last survey built; comment out the rest.

Run tests/survey.sh first -- this reads .survey.log.

A cabal file cannot name a module it fails to build, so the library has to
list only what works. Deleting the other lines would work too, and is what
this used to do, but it threw away three things worth keeping:

  * the diff against upstream's cabal file. Rewriting the list re-sorted it,
    so every rebase or upstream pull conflicted across all 330 lines instead
    of the handful that actually moved.
  * the record of where a module belongs, for when it starts building.
  * the list of what is missing, which had to live somewhere else and go
    stale. Commented out, it is the list, in the file it describes.

So this only ever toggles the `-- ` prefix. Module order is never touched,
and a module unknown to the file is an error rather than something silently
appended -- if a genuinely new module appears, it should be added
deliberately, in upstream's ordering.
"""

import re
import sys

MODULE = re.compile(r'^(\s*(?:exposed-modules:\s*)?)(--\s*)?(XMonad\.[\w.]+)\s*$')

log = open('.survey.log', errors='replace').read()
attempted = set(re.findall(r'\[\s*\d+ of \d+\] Compiling (\S+)', log))

# A module is broken if an error block names its file. Warnings do not count,
# and neither does an error in a module that merely imports it: -fkeep-going
# reports each failure against its own file.
broken = {
    path.split('/xmonad-contrib-river/')[1][:-3].replace('/', '.')
    for path in re.findall(r'^(/\S+?\.hs):\d+:\d+: error', log, re.M)
    if '/xmonad-contrib-river/' in path
}
working = {m for m in attempted if m.startswith('XMonad.') and m not in broken}

src = open('xmonad-contrib.cabal').read()
start = src.index('    exposed-modules:')
end = src.index('\ntest-suite tests')

out, enabled, disabled, changed = [], 0, 0, 0
for line in src[start:end].split('\n'):
    m = MODULE.match(line)
    if not m:
        out.append(line)
        continue
    lead, was_disabled, mod = m.group(1), m.group(2) is not None, m.group(3)
    # The prefix is fixed width either way, so enabling and disabling a line
    # leaves the column alignment alone.
    field = lead.rstrip() + ' ' if lead.strip() else ''
    indent = ' ' * (24 - len(field)) if len(field) < 24 else ''
    if mod in working:
        out.append(field + indent + mod)
        enabled += 1
    else:
        out.append(field + indent[:-3] + '-- ' + mod)
        disabled += 1
    changed += (mod in working) == was_disabled

open('xmonad-contrib.cabal', 'w').write(src[:start] + '\n'.join(out) + src[end:])

unknown = working - {m for m in re.findall(r'XMonad\.[\w.]+', src[start:end])}
if unknown:
    print('not listed in the cabal file, add them by hand: '
          + ', '.join(sorted(unknown)), file=sys.stderr)
    sys.exit(1)

print(f'{enabled} enabled, {disabled} disabled ({changed} changed)',
      file=sys.stderr)
