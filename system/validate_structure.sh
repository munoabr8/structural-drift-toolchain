#!/usr/bin/env bash
set -euo pipefail

# === Hardened Structure Validator ===

# ✅ Color-coded log functions
log_success() {
  echo -e "\033[1;32m✅ $1\033[0m"
}

log_error() {
  echo -e "\033[1;31m❌ $1\033[0m"
}

log_info() {
  echo -e "\033[1;34mℹ️  $1\033[0m"
}

show_usage() {
  echo -e "\033[1;33mUsage:\033[0m"
  echo "  ./validate_structure.sh <structure.spec>"
  echo
  echo "Each line must be one of:"
  echo "  - A valid relative file or dir path (e.g. ./attn/context-status.sh)"
  echo "  - A line starting with: 'dir:', 'file:', or 'link:'"
  echo "    - dir: ./path"
  echo "    - file: ./path"
  echo "    - link: ./symlink -> ./target"
  echo
}

SPEC_FILE="${1:-}"

if [[ -z "$SPEC_FILE" || "$SPEC_FILE" == "--help" || "$SPEC_FILE" == "-h" ]]; then
  show_usage
  exit 0
fi

[ -f "$SPEC_FILE" ] || { log_error "Spec file not found: $SPEC_FILE"; exit 1; }

log_info "Reading structure spec: $SPEC_FILE"

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  if [[ "$line" == dir:* ]]; then
    dir_path="${line#dir: }"
    if [ ! -d "$dir_path" ]; then
      log_error "Missing directory: $dir_path"
      exit 1
    fi
    log_success "Directory OK: $dir_path"
    continue
  fi

  if [[ "$line" == file:* ]]; then
    file_path="${line#file: }"
    if [ ! -f "$file_path" ]; then
      log_error "Missing file: $file_path"
      exit 1
    fi
    log_success "File OK: $file_path"
    continue
  fi

  if [[ "$line" == link:* ]]; then
    link_def="${line#link: }"
    src=$(echo "$link_def" | awk '{print $1}')
    tgt=$(echo "$link_def" | awk '{print $3}')

    if [ ! -L "$src" ]; then
      log_error "Missing symlink: $src"
      exit 1
    fi

    actual=$(readlink "$src")
    if [ "$actual" != "$tgt" ]; then
      log_error "Symlink $src points to $actual, expected $tgt"
      exit 1
    fi

    log_success "Symlink OK: $src -> $tgt"
    continue
  fi

  # Fallback: assume it's a raw relative path
  trimmed_line="$(echo "$line" | xargs)"
if [ -f "$trimmed_line" ]; then
  log_success "File OK: $trimmed_line"
elif [ -d "$trimmed_line" ]; then
  log_success "Directory OK: $trimmed_line"
elif [ -L "$trimmed_line" ]; then
  log_success "Symlink OK (untyped): $trimmed_line -> $(readlink "$trimmed_line")"
else
  log_error "Missing or unknown path: $trimmed_line"
  exit 1
fi
done < "$SPEC_FILE"

log_success "🎉 Structure validation passed."
