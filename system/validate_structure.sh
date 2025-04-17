#!/usr/bin/env bash
set -e

# 🧰 Helper functions
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
  echo "Checks file and symlink integrity based on a provided structure specification."
  echo
  echo -e "\033[1;33mExample:\033[0m"
  echo "  ./validate_structure.sh system/structure.spec"
  echo
  echo "Each line in the spec should be either:"
  echo "  - A required file path"
  echo "  - A symlink in the format: symlink_path -> target_path"
  echo
}

# 🗂️ Structure Validator
SPEC_FILE="$1"

if [ -z "$SPEC_FILE" ] || [[ "$SPEC_FILE" == "--help" ]] || [[ "$SPEC_FILE" == "-h" ]]; then
  show_usage
  exit 0
fi

[ -f "$SPEC_FILE" ] || { log_error "Spec file not found: $SPEC_FILE"; exit 1; }

log_info "Reading spec: $SPEC_FILE"

while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

  if [[ "$line" == *"->"* ]]; then
    src=$(echo "$line" | awk '{print $1}')
    tgt=$(echo "$line" | awk '{print $3}')

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
  else
    # Strip leading ./ for consistency
    line="${line#./}"

    if [[ "$line" == */ ]]; then
      if [ ! -d "$line" ]; then
        log_error "Missing directory: $line"
        exit 1
      fi
      log_success "Directory OK: $line"
    else
      if [ ! -f "$line" ]; then
        log_error "Missing file: $line"
        exit 1
      fi
      log_success "File OK: $line"
    fi
  fi

done < "$SPEC_FILE"

log_success "🎉 Structure check passed."
