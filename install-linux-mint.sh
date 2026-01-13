#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
requirements_file="$script_dir/apt-requirements.txt"

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'This script is intended for Linux Mint/Ubuntu systems only.\n' >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  printf 'Unable to detect distro (missing /etc/os-release).\n' >&2
  exit 1
fi

. /etc/os-release
case "${ID-}" in
  linuxmint|ubuntu) ;;
  *)
    printf 'Unsupported distro: %s (expected linuxmint/ubuntu).\n' "${ID-unknown}" >&2
    exit 1
    ;;
esac

if ! command -v apt-get >/dev/null 2>&1; then
  printf 'apt-get not found. This script requires APT.\n' >&2
  exit 1
fi

if [[ ! -f "$requirements_file" ]]; then
  printf 'Requirements file not found at %s\n' "$requirements_file" >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    printf 'sudo not found; rerun as root or install sudo.\n' >&2
    exit 1
  fi
  SUDO=(sudo)
else
  SUDO=()
fi

readarray -t packages < <(grep -Ev '^\s*(#|$)' "$requirements_file" || true)

if [[ ${#packages[@]} -eq 0 ]]; then
  printf 'No packages listed in %s\n' "$requirements_file"
  exit 0
fi

did_update=0
missing_packages=()

for entry in "${packages[@]}"; do
  package="${entry%%#*}"
  package="${package#"${package%%[![:space:]]*}"}"
  package="${package%"${package##*[![:space:]]}"}"
  [[ -z "$package" ]] && continue

  if dpkg -s "$package" >/dev/null 2>&1; then
    printf '✓ %s already installed\n' "$package"
    continue
  fi

  if [[ "$did_update" -eq 0 ]]; then
    printf '→ Updating package lists\n'
    "${SUDO[@]}" apt-get update
    did_update=1
  fi

  printf '→ Installing %s\n' "$package"
  if ! "${SUDO[@]}" apt-get install -y "$package"; then
    missing_packages+=("$package")
    printf '⚠ Failed to install %s (will report at end)\n' "$package"
  fi
done

if [[ -f "$script_dir/install-aliasforge.sh" ]]; then
  printf '→ Installing AliasForge for Bash\n'
  SHELL="/bin/bash" bash "$script_dir/install-aliasforge.sh"
else
  printf 'install-aliasforge.sh not found at %s\n' "$script_dir" >&2
  exit 1
fi

if [[ ${#missing_packages[@]} -gt 0 ]]; then
  printf '\nMissing or failed packages:\n'
  for package in "${missing_packages[@]}"; do
    printf '  - %s\n' "$package"
  done
  exit 1
fi
