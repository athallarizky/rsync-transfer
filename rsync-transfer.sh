#!/bin/bash
# =============================================================================
# rsync-transfer — Reusable data transfer script with rsync
# =============================================================================
# Usage:
#   # Agent mode (pass source and dest as arguments)
#   ./rsync-transfer.sh /path/to/source /path/to/destination
#
#   # Manual mode (edit variables at the top of this script)
#   ./rsync-transfer.sh --manual
#
#   # Preview only (no actual transfer)
#   ./rsync-transfer.sh --dry-run /path/to/source /path/to/destination
#
#   ./rsync-transfer.sh --help
# =============================================================================

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"

# ============================== CONFIGURATION ===============================
# Manual mode: edit these variables and run ./rsync-transfer.sh --manual
# =============================================================================
MANUAL_SOURCE=""
MANUAL_DEST=""

# Additional rsync options (optional)
RSYNC_EXTRA=""

# Exclude patterns (one per line using --exclude)
# Example: EXCLUDES="--exclude='*.tmp' --exclude='node_modules'"
EXCLUDES=""
# =============================================================================

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Default rsync options
RSYNC_BASE="-avh --progress --partial --stats"

log()    { echo -e "${GREEN}[✓]${NC} $1"; }
info()   { echo -e "${BLUE}[i]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[✗]${NC} $1" && exit 1; }
header() { echo -e "\n${BOLD}$1${NC}"; echo "────────────────────────────────────────"; }

show_help() {
  cat <<HELP
${BOLD}rsync-transfer v$VERSION${NC} — Reusable data transfer script

${BOLD}Usage:${NC}
  $(basename "$0") <source> <dest>              Transfer with full progress
  $(basename "$0") --dry-run <source> <dest>    Preview only (no transfer)
  $(basename "$0") --manual                     Edit variables in script, then run
  $(basename "$0") --help                       Show this help

${BOLD}Features:${NC}
  • Resumable transfers (rsync --partial)
  • Real-time progress per file
  • Pre-flight validation (source exists, disk space)
  • Handles folder names with trailing spaces
  • Detailed logging to logs/ directory
  • Dry-run mode for preview
  • File count and size summary

${BOLD}Examples:${NC}
  $(basename "$0") ~/Photos /Volumes/Backup/Photos
  $(basename "$0") --dry-run /path/to/source /path/to/dest
  $(basename "$0") --manual

${BOLD}Hint for LLM Agent:${NC}
  Call this script with source and dest as positional arguments.
  Source must exist. Dest parent directory must exist.
  Exit code 0 = success, non-zero = failure.
HELP
  exit 0
}

check_deps() {
  command -v rsync &>/dev/null || error "rsync is not installed"
}

validate_paths() {
  local src="$1" dst="$2"
  local __src_result="$3" __dst_result="$4"

  # Handle trailing spaces in source folder names
  if [ ! -d "$src" ] && [ -d "${src% }" ]; then
    warn "Source has trailing space, using: ${src% }"
    src="${src% }"
  fi

  # Source validation
  [ -e "$src" ] || error "Source does not exist: $src"

  # Dest parent directory must exist
  local dest_parent
  if [ -d "$dst" ]; then
    dest_parent="$dst"
  else
    dest_parent="$(dirname "$dst")"
  fi

  [ -d "$dest_parent" ] || error "Destination parent directory does not exist: $dest_parent"

  eval "$__src_result='$src'"
  eval "$__dst_result='$dst'"
}

check_disk_space() {
  local src="$1" dst="$2"
  info "Checking disk space..."

  local src_size src_size_h
  if [ -f "$src" ]; then
    src_size=$(stat -f%z "$src" 2>/dev/null || echo "0")
  else
    src_size=$(du -sb "$src" 2>/dev/null | awk '{print $1}' || echo "0")
  fi
  src_size_h=$(numfmt --to=iec "$src_size" 2>/dev/null || echo "$src_size bytes")

  local dest_parent
  if [ -d "$dst" ]; then
    dest_parent="$dst"
  else
    dest_parent="$(dirname "$dst")"
  fi

  local avail avail_h
  avail=$(df "$dest_parent" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
  if [[ "$(uname)" == "Darwin" ]]; then
    avail=$((avail * 512))
  fi
  avail_h=$(numfmt --to=iec "$avail" 2>/dev/null || echo "$avail bytes")

  log "Source size: $src_size_h"
  log "Available at destination: $avail_h"

  [ "$avail" -lt "$((src_size * 12 / 10))" ] && warn "Low disk space! Need ~$src_size_h" && return 1
  return 0
}

show_preflight() {
  local src="$1" dst="$2" dry_run="$3"
  header "Pre-flight Summary"
  echo "  Source:      $src"
  echo "  Destination: $dst"
  echo "  Dry run:     $([ "$dry_run" = true ] && echo "Yes" || echo "No")"

  if [ -d "$src" ]; then
    local file_count=$(find "$src" -type f ! -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
    local size=$(du -sh "$src" 2>/dev/null | awk '{print $1}')
    echo "  Files:       $file_count"
    echo "  Size:        $size"
  elif [ -f "$src" ]; then
    local size=$(stat -f%z "$src" 2>/dev/null)
    echo "  Size:        $(numfmt --to=iec "$size" 2>/dev/null || echo "$size bytes")"
  fi
  echo ""
}

run_transfer() {
  local src="$1" dst="$2" dry_run="$3" log_file="$4"
  local rsync_opts="$RSYNC_BASE $RSYNC_EXTRA $EXCLUDES"

  [ "$dry_run" = true ] && rsync_opts="$rsync_opts --dry-run"

  mkdir -p "$LOG_DIR"

  # Ensure trailing slash for directory contents
  [ -d "$src" ] && [[ "$src" != */ ]] && src="$src/"

  header "Starting transfer"
  info "Log: $log_file"
  echo ""

  if [ "$dry_run" = true ]; then
    rsync $rsync_opts "$src" "$dst" 2>&1 | tee "$log_file"
    log "Dry-run complete."
  else
    rsync $rsync_opts "$src" "$dst" 2>&1 | tee "$log_file"
    local exit_code="${PIPESTATUS[0]}"

    if [ "$exit_code" -eq 0 ]; then
      log "Transfer complete!"
      tail -5 "$log_file" | grep -E "sent|total size" | head -2
    else
      warn "rsync exited with code $exit_code (resumable — run again)"
      fix_trailing_spaces "$dst"
      return 1
    fi
  fi

  [ "$dry_run" != true ] && [ -d "$dst" ] && fix_trailing_spaces "$dst"
}

fix_trailing_spaces() {
  local base_dir="$1"
  find "$base_dir" -maxdepth 1 -type d -name '* ' 2>/dev/null | while read -r dir; do
    local new_name="${dir% }"
    [ -e "$new_name" ] && continue
    mv "$dir" "$new_name" 2>/dev/null && log "Fixed: $(basename "$dir") -> $(basename "$new_name")"
  done
}

# ============================== AGENT MODE ==================================
agent_mode() {
  local src="$1" dst="$2" dry_run="${3:-false}"
  local log_file="$LOG_DIR/transfer-$(date +%Y%m%d-%H%M%S).log"
  local src_fixed dst_fixed

  check_deps
  validate_paths "$src" "$dst" src_fixed dst_fixed
  show_preflight "$src_fixed" "$dst_fixed" "$dry_run"

  if [ "$dry_run" != true ]; then
    check_disk_space "$src_fixed" "$dst_fixed" || warn "Proceeding anyway..."
  fi

  run_transfer "$src_fixed" "$dst_fixed" "$dry_run" "$log_file"
}

# ============================== MANUAL MODE ================================
manual_mode() {
  echo ""
  header "rsync-transfer — Manual Mode"
  echo ""

  if [ -z "$MANUAL_SOURCE" ] || [ -z "$MANUAL_DEST" ]; then
    warn "MANUAL_SOURCE and MANUAL_DEST not configured."
    echo ""
    info "Open this script and set:"
    echo "  MANUAL_SOURCE=\"/path/to/source\""
    echo "  MANUAL_DEST=\"/path/to/destination\""
    echo ""
    info "Then run: $(basename "$0") --manual"
    echo ""

    echo -n "Enter source path: "; read -r input_src
    echo -n "Enter dest path:  "; read -r input_dst
    [ -z "$input_src" ] || [ -z "$input_dst" ] && error "Both source and dest are required"

    MANUAL_SOURCE="$input_src"
    MANUAL_DEST="$input_dst"
  fi

  agent_mode "$MANUAL_SOURCE" "$MANUAL_DEST"
}

# ============================== MAIN ========================================
main() {
  local mode="agent"
  local dry_run=false

  case "${1:-}" in
    --help|-h) show_help ;;
    --manual|-m) manual_mode; exit 0 ;;
    --dry-run|-n) dry_run=true; shift ;;
  esac

  [ $# -lt 2 ] && show_help
  agent_mode "$1" "$2" "$dry_run"
}

main "$@"
