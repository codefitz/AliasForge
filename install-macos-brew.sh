#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
requirements_file="$script_dir/brew-requirements.txt"

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This script is intended for macOS systems only.\n' >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew is not installed. Install it from https://brew.sh and rerun this script.\n' >&2
  exit 1
fi

if [[ ! -f "$requirements_file" ]]; then
  printf 'Requirements file not found at %s\n' "$requirements_file" >&2
  exit 1
fi

readarray -t packages < <(grep -Ev '^\s*(#|$)' "$requirements_file" || true)

if [[ ${#packages[@]} -eq 0 ]]; then
  printf 'No packages listed in %s\n' "$requirements_file"
  exit 0
fi

for entry in "${packages[@]}"; do
  package="${entry%%#*}"
  # Trim leading/trailing whitespace
  package="${package#"${package%%[![:space:]]*}"}"
  package="${package%"${package##*[![:space:]]}"}"
  [[ -z "$package" ]] && continue

  if [[ "$package" == cask:* ]]; then
    target="${package#cask:}"
    if brew list --cask "$target" >/dev/null 2>&1; then
      printf '✓ %s (cask) already installed\n' "$target"
      continue
    fi
    printf '→ Installing cask %s\n' "$target"
    brew install --cask "$target"
  else
    if brew list --versions "$package" >/dev/null 2>&1; then
      printf '✓ %s already installed\n' "$package"
      continue
    fi
    printf '→ Installing %s\n' "$package"
    brew install "$package"
  fi
done
