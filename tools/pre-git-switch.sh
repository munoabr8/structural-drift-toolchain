#!/usr/bin/env bash
# tools/pre-git-switch.sh
# Create a dev snapshot with JSON logging before switching branches

 

 

pre_git_switch_main() {

  set -euo pipefail

  source "$(dirname "${BASH_SOURCE[0]}")/../system/source_or_fail.sh"
source_or_fail "$(dirname "${BASH_SOURCE[0]}")/../system/logger.sh"
source_or_fail "$(dirname "${BASH_SOURCE[0]}")/../system/logger_wrapper.sh"

snapshot_dir=".git/dev_snapshots"
mkdir -p "$snapshot_dir"

timestamp=$(date +"%Y%m%d_%H%M%S")
snapshot_file="$snapshot_dir/pre_switch_$timestamp.tar.gz"
log_file="$snapshot_dir/snapshot_log.json"

log_info "Creating pre-branch-switch snapshot" "$snapshot_file"

git ls-files -o -m --exclude-standard > "$snapshot_dir/tmp_file_list.txt"

if [[ ! -s "$snapshot_dir/tmp_file_list.txt" ]]; then
  log_info "No changes detected, skipping snapshot."
  exit 0
fi

if tar -czf "$snapshot_file" -T "$snapshot_dir/tmp_file_list.txt"; then
  log_success "Snapshot created" "$snapshot_file"
  printf '{"timestamp":"%s","snapshot":"%s"}\n' "$timestamp" "$snapshot_file" >> "$log_file"
else
  log_error "Snapshot creation failed" "tar_error" 77
  exit 77
fi

rm "$snapshot_dir/tmp_file_list.txt"

 
}

# Only run if script is executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pre_git_switch_main "$@"
fi

