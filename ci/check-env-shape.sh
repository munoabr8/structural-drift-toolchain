#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
baseline="$script_dir/env-shape.baseline"

# Ignore noisy vars; tune as needed.
ignore_re=${ENV_IGNORE_RE:-'^(PWD|SHLVL|_|OLDPWD|TMPDIR|GITHUB_.*|CI=)'}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 -r | awk '{print $1}'
  else echo "no sha256 backend" >&2; return 127
  fi
}

digest() {
  LC_ALL=C env | sort | grep -vE "$ignore_re" | awk -F= '{print $1}' | sha256
}

new="$(digest)" || exit $?
if [[ -f "$baseline" ]]; then
  old="$(<"$baseline")"
  if [[ "$new" == "$old" ]]; then
    echo "env-shape: unchanged ($new)"
    exit 0
  else
    echo "env-shape: CHANGED" >&2
    echo " old: $old" >&2
    echo " new: $new" >&2
    LC_ALL=C env | sort | grep -vE "$ignore_re" > "$script_dir/env-shape.latest"
    echo "Saved current names to $script_dir/env-shape.latest" >&2
    exit 1
  fi
else
  echo "$new" > "$baseline"
  echo "initialized baseline: $new"
fi

