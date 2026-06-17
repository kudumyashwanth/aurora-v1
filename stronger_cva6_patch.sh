#!/bin/bash
echo "Applying strong CVA6 Verilator patch..."

FILES=(
  "rtl/cpu_cluster/cva6/vendor/pulp-platform/common_cells/src/fifo_v3.sv"
  "rtl/cpu_cluster/cva6/core/cva6_fifo_v3.sv"
)

for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "File not found: $f"
    continue
  fi

  cp "$f" "$f.bak"

  # Comment out every $fatal line
  sed -i 's/^\([ \t]*\)\$fatal/\1\/\/ VERILATOR_PATCH: \$fatal/' "$f"

  # Comment out assert property blocks with |->
  sed -i '/assert property.*|->/s/^/\/\/ VERILATOR_PATCH: /' "$f"
  sed -i '/else \$fatal/s/^/\/\/ VERILATOR_PATCH: /' "$f"

  # Comment out named assertions like "empty_read :"
  sed -i '/^[ \t]*[a-z_]*_read[ \t]*:/s/^/\/\/ VERILATOR_PATCH: /' "$f"

  echo "Strong patch applied to $f"
done

echo "Strong patch complete. Try build again."
