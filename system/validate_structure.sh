#!/usr/bin/env bash
set -euo pipefail

# === Hardened Structure Validator ===

# ── Exit-code constants ───────────────────────────────────────────
E_OK=0        # success
E_ERROR=1     # invariant or unknown drift
E_USAGE=64    # incorrect usage


usage() {
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
  # Exit on misuse
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage && exit $E_USAGE
}

 
SPEC_FILE="${1:-}"

if [[ -z "$SPEC_FILE" || "$SPEC_FILE" == "--help" || "$SPEC_FILE" == "-h" ]]; then
  usage
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




# --- load pattern regexes ---------------------------------------------
declare -A PATTERN                     # PATTERN[invariant] etc.
while IFS='=' read -r k v; do
  case "$k" in invariant|volatile|variant) PATTERN[$k]=$v ;; esac
done < <(grep -E '^(invariant|volatile|variant)=' "$POLICY_FILE")

# --- load severity map -------------------------------------------------
declare -A ACT                         # ACT[invariant_violation] etc.
while IFS='=' read -r k v; do
  case "$k" in
    invariant_violation|volatile_change|variant_change) ACT[$k]=$v ;;
  esac
done < <(grep -E '^(invariant_violation|volatile_change|variant_change)=' \
         "$POLICY_FILE")

severity_ec() {           # maps error|warn|ignore → 1|2|0
  case "$1" in error) echo 1 ;; warn) echo 2 ;; *) echo 0 ;; esac
}


classify_path() {
  local path=$1
  if   [[ $path =~ ${PATTERN[invariant]} ]]; then echo invariant
  elif [[ $path =~ ${PATTERN[volatile]}  ]]; then echo volatile
  elif [[ $path =~ ${PATTERN[variant]}   ]]; then echo variant
  else                                        echo unknown
  fi
}


EXIT=0
while read -r change path; do
  bucket=$(classify_path "$path")
  case "$bucket" in
    invariant)
      echo "❌ invariant drift: $path"
      EXIT=$(severity_ec "${ACT[invariant_violation]:-error}")
      ;;
    volatile)
      # optionally echo debug; ignored by default
      ;;
    variant)
      echo "⚠️  variant drift: $path"
      (( ec=$(severity_ec "${ACT[variant_change]:-warn}") > EXIT )) && EXIT=$ec
      ;;
    *)
      echo "🌀 unknown drift: $path"
      # treat unknown however you like (here: escalate to error)
      EXIT=1
      ;;
  esac
done < <(diff -urN "$SNAP" "$SPEC" | awk '/^Only in/ {print "A",$3"/"$4} /^diff/ {print "M",$4}')

exit "$EXIT"










#Can the paths to different exit codes be stream-lined for easier reasoning?

#If functions are generated, then I need to seperate between queries and commands.

#

#Needs to be adjusted so that it is easier to unit test.(Maximize testability)

#Need a main function
