#!/usr/bin/env python3
"""
fix_fifo.py — Surgical fix for cva6_fifo_v3.sv named assertion syntax
Run from ~/aurora_v1:  python3 fix_fifo.py
"""
import re, os, sys, shutil

TARGET = "rtl/cpu_cluster/cva6/core/cva6_fifo_v3.sv"
BAK    = TARGET + ".bak"

# Load: prefer .bak as the clean original
src = BAK if os.path.exists(BAK) else TARGET
if not os.path.exists(src):
    sys.exit(f"ERROR: cannot find {TARGET} or its .bak")

with open(src) as f:
    content = f.read()

print(f"Loaded from: {src} ({len(content)} chars)")

# Save backup if we loaded the live file
if src == TARGET and not os.path.exists(BAK):
    shutil.copy(TARGET, BAK)
    print(f"Saved backup: {BAK}")

original = content

# ── Strategy: remove ALL named assertion blocks ───────────────────────────────
# Pattern covers:
#   label :              (optional — label on its own line)
#   assert property (    (possibly same line as label)
#     ...multi-line...
#   ) ;                  or )) ;
#   else $fatal(...) ;   (optional)
#
# We use a two-pass approach:
# Pass 1: Remove complete assert property blocks (with optional label prefix on same line)
# Pass 2: Remove orphaned label-only lines that precede an assert property

# Pass 1: assert property with optional inline label
p1 = re.compile(
    r'[ \t]*(?:[a-zA-Z_]\w*\s*:\s*)?'  # optional inline label
    r'assert\s+property\s*\('           # assert property (
    r'(?:[^()]*|\([^()]*\))*'           # content (handles one level of nesting)
    r'\)\s*\)\s*;'                       # closing )) ;
    r'(?:\s*\n\s*else\s+\$fatal[^\n]*)?', # optional else $fatal on next line
    re.DOTALL
)
content = p1.sub('  // VERILATOR: assert property removed', content)

# Pass 2: remove label-only lines followed (eventually) by assert property
lines = content.split('\n')
out = []
i = 0
while i < len(lines):
    l = lines[i]
    s = l.lstrip()
    # Detect label-only line: "word :" with nothing else
    if re.match(r'^[a-zA-Z_]\w*\s*:\s*$', s):
        # Look ahead for assert property
        j = i + 1
        while j < len(lines) and not lines[j].strip():
            j += 1
        if j < len(lines) and re.match(r'\s*(?:assert\s+property|//\s*VERILATOR)', lines[j]):
            out.append('  // VERILATOR: ' + s.rstrip())
            i += 1
            continue
    # Remove orphaned else $fatal lines
    if re.match(r'else\s+\$fatal', s):
        out.append('  // VERILATOR: ' + s.rstrip())
        i += 1
        continue
    out.append(l)
    i += 1

content = '\n'.join(out)

if content == original:
    print("WARNING: No changes made — check the file manually")
else:
    with open(TARGET, 'w') as f:
        f.write(content)
    changed = sum(1 for a,b in zip(original.split('\n'), content.split('\n')) if a != b)
    print(f"✅ Fixed {TARGET} ({changed} lines changed)")

print("Done — run: make clean && make sim")
