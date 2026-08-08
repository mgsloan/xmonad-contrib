import re, collections, os, sys
log=open(sys.argv[1],errors='replace').read()
attempted=set(re.findall(r'\[\s*\d+ of \d+\] Compiling (\S+)', log))
hdr=re.compile(r'^(/\S+?\.hs):(\d+):(\d+): (error|warning)')
cur=None; blocks=collections.OrderedDict()
for l in log.split('\n'):
    m=hdr.match(l)
    if m:
        cur=(m.group(1),m.group(4))
        if cur[1]=='error': blocks.setdefault(m.group(1),[]).append([])
        continue
    if re.match(r'^\[\s*\d+ of \d+\]', l): cur=None
    if cur and cur[1]=='error' and blocks.get(cur[0]): blocks[cur[0]][-1].append(l)
first={}
for p,errs in blocks.items():
    if '/xmonad-river-contrib/' not in p: continue
    mod=p.split('/xmonad-river-contrib/')[1][:-3].replace('/','.')
    fl=[x.strip() for x in errs[0] if x.strip()][:1]
    first[mod]=(len(errs), re.sub(r'\s+',' ',fl[0]) if fl else '?')
failed=set(first)
allmods={}
for root,_,files in os.walk('XMonad'):
    for f in files:
        if f.endswith('.hs'): allmods[os.path.join(root,f)[:-3].replace('/','.')]=1
imports={}
for mod in allmods:
    src=open(mod.replace('.','/')+'.hs',errors='replace').read()
    imports[mod]={m for m in re.findall(r'^import\s+(?:qualified\s+)?(XMonad(?:\.[A-Za-z0-9_.]+)?)', src, re.M) if m in allmods}
def rc(mod, seen=None):
    if seen is None: seen=set()
    if mod in seen: return set()
    seen.add(mod)
    out=set()
    for d in imports.get(mod,()):
        if d in failed: out.add(d)
        else: out |= rc(d, seen)
    return out
skipped=sorted(set(allmods)-attempted)
def cls(msg):
    if 'Read' in msg and ('ObjectId' in msg or 'Window' in msg): return 'Read instance for Window'
    if re.search(r'FontStruct|FontSet|\bGC\b|Drawable|Color|openDisplay|xFree|Pixmap|createGC|Pixel', msg): return 'Xlib drawing and display'
    if re.search(r'ClientMessageEvent|CrossingEvent|MotionEvent|UnmapEvent|PropertyEvent|MappingNotifyEvent|ev_', msg): return 'raw X events'
    if re.search(r'\bAtom\b|TextProperty|WindowAttributes|wa_|stringProperty', msg): return 'X window properties'
    if 'Could not load module' in msg or 'Could not find module' in msg or 'does not export' in msg: return 'missing module or export'
    if 'theRoot' in msg: return 'root window'
    if re.search(r'\bPoint\b|\bnone\b|KeyCode|raiseWindow', msg): return 'small missing names'
    return 'other'
o=[]
o.append("# xmonad-contrib against the river backend\n")
o.append("Upstream `xmonad-contrib` master built with `stack build xmonad-contrib:lib`")
o.append("against `../xmonad-river` at `-f river`, with `-fkeep-going` so one failure")
o.append("does not stop the run.\n")
o.append("| | count |")
o.append("| --- | --- |")
o.append("| compiled | **%d** |" % (len(attempted)-len(failed)))
o.append("| failed | %d |" % len(failed))
o.append("| skipped behind a failure | %d |" % len(skipped))
o.append("| total | %d |\n" % len(allmods))
o.append("The skipped ones are **unmeasured, not known-bad**: GHC never attempted them,")
o.append("because a module they import failed first. The true number that would compile")
o.append("is somewhere between %d and %d.\n" % (len(attempted)-len(failed), len(allmods)-len(failed)))
o.append("""To bring this up to date after changing the backend or a module:

```
stack build                       # in ../xmonad-river, if it changed
tests/survey.sh                   # rewrites this file; ~10 min, builds all 334
python3 tests/expose-working.py   # enable/disable modules in the cabal to match
stack build xmonad-contrib:lib    # confirm the library still builds
```

The second step is not optional bookkeeping: the cabal file cannot name a
module it fails to build, so a module that starts compiling is not usable by a
config until it is enabled there. Disabled modules are commented out in place
rather than deleted, so the list below and the cabal file say the same thing.
""")
o.append("## Failing modules, by cause\n")
g=collections.defaultdict(list)
for m,(n,msg) in first.items(): g[cls(msg)].append((m,n,msg))
for k in sorted(g, key=lambda k:-len(g[k])):
    o.append("### %s — %d modules\n" % (k, len(g[k])))
    for m,n,msg in sorted(g[k]):
        o.append("- `%s` (%d) — %s" % (m, n, msg[:96]))
    o.append("")
o.append("## Skipped modules, by what blocks them\n")
by=collections.defaultdict(list)
for m in skipped:
    b=sorted(rc(m))
    key=", ".join("`%s`"%x for x in b[:2]) + ("" if len(b)<=2 else " (+%d more)"%(len(b)-2)) if b else "(no failing import found)"
    by[key].append(m)
for key in sorted(by, key=lambda k:-len(by[k])):
    o.append("### %s — %d modules\n" % (key, len(by[key])))
    o.append(", ".join("`%s`"%m for m in sorted(by[key])))
    o.append("")
open('SURVEY.md','w').write("\n".join(o)+"\n")
print("wrote SURVEY.md: %d compiled, %d failed, %d skipped" % (len(attempted)-len(failed), len(failed), len(skipped)))
