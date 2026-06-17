#!/bin/bash
# fix_cva6_verilator.sh — Definitive CVA6 Verilator compatibility patch
# Always restores from .bak before patching. Safe to re-run.

CVA6_DIR="rtl/cpu_cluster/cva6"

if [ ! -d "$CVA6_DIR" ]; then
  echo "❌ CVA6 not found at $CVA6_DIR"; exit 1
fi

echo "Patching CVA6 for Verilator compatibility..."

python3 << 'PYEOF'
import os, re

CVA6_DIR = "rtl/cpu_cluster/cva6"

def patch_file(fpath):
    bak = fpath + ".bak"
    # Restore from backup to get clean original
    if os.path.exists(bak):
        with open(bak) as f:
            content = f.read()
        print(f"  🔄 Restored from backup: {fpath}")
    elif os.path.exists(fpath):
        with open(fpath) as f:
            content = f.read()
        with open(bak, 'w') as f:
            f.write(content)
        print(f"  💾 Saved backup: {bak}")
    else:
        print(f"  ⚠️  Not found: {fpath}")
        return

    original = content

    # Process line by line, tracking multi-line assert blocks
    lines = content.split('\n')
    out = []
    i = 0
    changed = False
    
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        
        # Check if this line is a named assertion label standing alone:
        # "some_name :" with nothing else meaningful on the line
        is_label_only = bool(re.match(r'^[a-zA-Z_]\w*\s*:\s*$', stripped))
        
        # Check if next non-empty line is an assert property
        def peek_assert(idx):
            j = idx + 1
            while j < len(lines):
                s = lines[j].lstrip()
                if s:
                    return bool(re.match(r'assert\s+property', s))
                j += 1
            return False

        # Check for assert property on this line (possibly with label prefix)
        is_assert = bool(re.match(r'(?:[a-zA-Z_]\w*\s*:\s*)?assert\s+property', stripped))
        
        # Check for dangling else $fatal
        is_else_fatal = bool(re.match(r'else\s+\$fatal', stripped))
        
        if is_label_only and peek_assert(i):
            # Label line before assert - comment it out
            out.append('  // VERILATOR_COMPAT: ' + stripped)
            changed = True
        elif is_assert:
            # Comment out the assert line
            out.append('  // VERILATOR_COMPAT: ' + stripped)
            changed = True
            # Consume continuation lines until we hit the closing );
            # Count parentheses to find the end
            depth = stripped.count('(') - stripped.count(')')
            while depth > 0 and i + 1 < len(lines):
                i += 1
                out.append('  // VERILATOR_COMPAT: ' + lines[i].lstrip())
                depth += lines[i].count('(') - lines[i].count(')')
            # Now check if next line is else $fatal
            if i + 1 < len(lines):
                next_s = lines[i + 1].lstrip()
                if re.match(r'else\s+\$fatal', next_s):
                    i += 1
                    out.append('  // VERILATOR_COMPAT: ' + lines[i].lstrip())
        elif is_else_fatal:
            # Orphaned else $fatal — comment it out
            out.append('  // VERILATOR_COMPAT: ' + stripped)
            changed = True
        else:
            out.append(line)
        
        i += 1

    new_content = '\n'.join(out)
    
    if new_content != original:
        with open(fpath, 'w') as f:
            f.write(new_content)
        print(f"  ✅ Patched: {fpath}")
    else:
        print(f"  ℹ️  No changes needed: {fpath}")

files = [
    f"{CVA6_DIR}/vendor/pulp-platform/common_cells/src/fifo_v3.sv",
    f"{CVA6_DIR}/core/cva6_fifo_v3.sv",
]

for f in files:
    patch_file(f)

print("Patch complete.")
PYEOF

echo ""
echo "✅ CVA6 patches applied."
