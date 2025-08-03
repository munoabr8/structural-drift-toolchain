source_or_fail() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing required file: $file" >&2
    exit 100
  fi
  source "$file"
}

source_or_fail_many() {
  for file in "$@"; do
    source_or_fail "$file"
  done
}


