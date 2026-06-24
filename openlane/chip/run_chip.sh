#!/usr/bin/env bash
# Launch OpenLane 1 (Docker) for a tensor_cluster driver .tcl passed as $1.
set -euo pipefail
DRIVER="${1:?usage: run_tensor.sh <driver.tcl>}"
OL=/home/yashwanth/OpenLane
PDKROOT=/home/yashwanth/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af
IMAGE=ghcr.io/the-openroad-project/openlane:ff5509f65b17bfa4068d5336495ab1718987ff69-amd64
exec docker run --rm \
  --memory=18g --memory-swap=20g \
  -v "$OL":/openlane \
  -v /home/yashwanth:/home/yashwanth \
  -v "$PDKROOT":"$PDKROOT" \
  -e PDK_ROOT="$PDKROOT" \
  -e PDK=sky130B \
  -e STD_CELL_LIBRARY=sky130_fd_sc_hd \
  --user 1000:1000 \
  -w /openlane \
  "$IMAGE" \
  bash -c "./flow.tcl -interactive < $DRIVER"
