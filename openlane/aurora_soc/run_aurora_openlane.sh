#!/usr/bin/env bash
# =============================================================================
# run_aurora_openlane.sh
# Full OpenLane synthesis run for Aurora SoC
# =============================================================================
set -euo pipefail

AURORA_ROOT="${HOME}/aurora_v1"
OPENLANE_DIR="${AURORA_ROOT}/openlane/aurora_soc"
OPENLANE_ROOT="${HOME}/OpenLane"   # adjust if installed elsewhere

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${CYAN}[AURORA]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

# ── 1. Sanity checks ──────────────────────────────────────────────────────────
log "Checking environment..."

[[ -d "$AURORA_ROOT" ]]    || err "Aurora project not found at $AURORA_ROOT"
[[ -d "$OPENLANE_ROOT" ]]  || err "OpenLane not found at $OPENLANE_ROOT — set OPENLANE_ROOT"

command -v python3 >/dev/null || err "python3 not found"
command -v docker  >/dev/null && HAVE_DOCKER=1 || HAVE_DOCKER=0

ok "Environment OK (docker=${HAVE_DOCKER})"

# ── 2. Create OpenLane design directory ───────────────────────────────────────
log "Setting up OpenLane design directory: $OPENLANE_DIR"

mkdir -p "${OPENLANE_DIR}/src"

# Copy config files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "${SCRIPT_DIR}/config.json"            "${OPENLANE_DIR}/"
cp "${SCRIPT_DIR}/aurora_constraints.sdc" "${OPENLANE_DIR}/src/"

# Add SDC reference to config
# (OpenLane picks it up via EXTRA_SCRIPTS or we patch config)
python3 - <<'PYEOF'
import json, sys
cfg_path = "${OPENLANE_DIR}/config.json"
with open(cfg_path) as f:
    cfg = json.load(f)
cfg["BASE_SDC_FILE"] = "dir::src/aurora_constraints.sdc"
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2)
print("  Patched config.json with SDC path")
PYEOF

ok "Config files copied"

# ── 3. Generate filelist ──────────────────────────────────────────────────────
log "Generating RTL filelist..."

python3 "${SCRIPT_DIR}/generate_filelist.py"

# Copy filelist into OpenLane src
cp "${OPENLANE_DIR}/src/filelist.f" "${OPENLANE_DIR}/src/filelist.f" 2>/dev/null || true

ok "Filelist generated"

# ── 4. Memory check ───────────────────────────────────────────────────────────
TOTAL_MEM_GB=$(awk '/MemTotal/{printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "?")
log "System RAM: ${TOTAL_MEM_GB} GB"

if [[ "$TOTAL_MEM_GB" != "?" && "$TOTAL_MEM_GB" -lt 16 ]]; then
    warn "Full SoC synthesis may OOM with <16GB RAM."
    warn "Consider: export SYNTH_MAX_FANOUT=8 to reduce memory pressure."
fi

# ── 5. Disk space check ───────────────────────────────────────────────────────
AVAIL_GB=$(df -BG "${AURORA_ROOT}" | awk 'NR==2{gsub("G",""); print $4}')
log "Available disk: ${AVAIL_GB} GB"
[[ "${AVAIL_GB}" -lt 20 ]] && warn "Full GDSII may need 20–50 GB disk space"

# ── 6. Run OpenLane ───────────────────────────────────────────────────────────
log "Starting OpenLane flow..."
log "Design: aurora_soc_top | PDK: gf180mcuD | Clock: 50MHz"
log "This will run: Synthesis → Floorplan → Placement → CTS → Routing → DRC → LVS"
echo ""
warn "Expected runtime: 4–20 hours depending on your CPU"
warn "Log file: ${OPENLANE_DIR}/runs/aurora_run_*/logs/"
echo ""

cd "$OPENLANE_ROOT"

# Determine run method
if [[ "$HAVE_DOCKER" -eq 1 ]]; then
    log "Running via Docker..."
    flow_script="./flow.tcl"
    
    make mount \
        DESIGN_PATH="${OPENLANE_DIR}" \
        DESIGN_NAME="aurora_soc_top" \
        IMAGE_NAME="efabless/openlane:latest" \
        &

    # Alternative: direct docker run
    docker run --rm -it \
        -v "${OPENLANE_ROOT}:/openLANE_flow" \
        -v "${PDK_ROOT:-${HOME}/pdks}:/root/.volare" \
        -v "${OPENLANE_DIR}:/openLANE_flow/designs/aurora_soc" \
        -e "PDK=gf180mcuD" \
        -e "STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0" \
        --user $(id -u):$(id -g) \
        efabless/openlane:latest \
        bash -c "cd /openLANE_flow && ./flow.tcl -design aurora_soc -tag aurora_run_$(date +%Y%m%d_%H%M) -overwrite 2>&1 | tee /openLANE_flow/designs/aurora_soc/aurora_run.log"
else
    log "Running without Docker (native OpenLane)..."
    
    # Check for nix/conda-based OpenLane 2
    if command -v openlane >/dev/null 2>&1; then
        log "Found OpenLane 2 CLI"
        openlane --pdk gf180mcuD \
                 --pdk-root "${PDK_ROOT:-${HOME}/pdks}" \
                 "${OPENLANE_DIR}/config.json" \
            2>&1 | tee "${OPENLANE_DIR}/aurora_run.log"
    
    elif [[ -f "${OPENLANE_ROOT}/flow.tcl" ]]; then
        log "Found OpenLane 1 flow.tcl"
        export PDK=gf180mcuD
        export STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0
        
        tclsh "${OPENLANE_ROOT}/flow.tcl" \
            -design "${OPENLANE_DIR}" \
            -tag "aurora_run_$(date +%Y%m%d_%H%M)" \
            -overwrite \
            2>&1 | tee "${OPENLANE_DIR}/aurora_run.log"
    else
        err "Cannot find OpenLane flow entry point. Check OPENLANE_ROOT=${OPENLANE_ROOT}"
    fi
fi

# ── 7. Post-run summary ───────────────────────────────────────────────────────
LATEST_RUN=$(ls -td "${OPENLANE_DIR}/runs/"* 2>/dev/null | head -1)

if [[ -n "$LATEST_RUN" ]]; then
    echo ""
    ok "Run completed. Results in: $LATEST_RUN"
    
    # Print final summary if exists
    SUMMARY="${LATEST_RUN}/reports/final_summary_report.csv"
    if [[ -f "$SUMMARY" ]]; then
        echo ""
        log "=== FINAL SUMMARY ==="
        cat "$SUMMARY"
    fi
    
    # Print timing
    TIMING="${LATEST_RUN}/reports/signoff/25-sta-rcx_nom/multi_corner_sta.summary.rpt"
    if [[ -f "$TIMING" ]]; then
        echo ""
        log "=== TIMING SUMMARY ==="
        grep -A5 "wns\|tns\|VIOLATED\|MET" "$TIMING" | head -30
    fi
fi
