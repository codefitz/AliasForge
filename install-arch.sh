#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
requirements_file="$script_dir/pacman-requirements.txt"

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'This script is intended for Arch Linux / EndeavourOS systems only.\n' >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  printf 'Unable to detect distro (missing /etc/os-release).\n' >&2
  exit 1
fi

. /etc/os-release
case "${ID-}" in
  arch|endeavouros) ;;
  *)
    printf 'Unsupported distro: %s (expected arch/endeavouros).\n' "${ID-unknown}" >&2
    exit 1
    ;;
esac

if ! command -v pacman >/dev/null 2>&1; then
  printf 'pacman not found. This script requires pacman.\n' >&2
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

aur_helper=""
if command -v yay >/dev/null 2>&1; then
  aur_helper="yay"
elif command -v paru >/dev/null 2>&1; then
  aur_helper="paru"
fi

readarray -t packages < <(grep -Ev '^\s*(#|$)' "$requirements_file" || true)

if [[ ${#packages[@]} -eq 0 ]]; then
  printf 'No packages listed in %s\n' "$requirements_file"
  exit 0
fi

did_sync=0
missing_packages=()

sync_pacman_db() {
  if [[ "$did_sync" -eq 0 ]]; then
    printf '→ Refreshing pacman package databases\n'
    "${SUDO[@]}" pacman -Sy --noconfirm
    did_sync=1
  fi
}

install_pacman_package() {
  local pkg="$1"

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    printf '✓ %s already installed\n' "$pkg"
    return 0
  fi

  sync_pacman_db

  if ! pacman -Si "$pkg" >/dev/null 2>&1; then
    missing_packages+=("$pkg (not in pacman repos)")
    printf '⚠ %s not available in pacman (skipping)\n' "$pkg"
    return 1
  fi

  printf '→ Installing %s\n' "$pkg"
  if ! "${SUDO[@]}" pacman -S --needed --noconfirm "$pkg"; then
    missing_packages+=("$pkg")
    printf '⚠ Failed to install %s (will report at end)\n' "$pkg"
    return 1
  fi

  return 0
}

install_aur_package() {
  local pkg="$1"

  if [[ -z "$aur_helper" ]]; then
    missing_packages+=("$pkg (AUR helper required; install yay or paru)")
    printf '⚠ %s requires an AUR helper (yay/paru) and none was found\n' "$pkg"
    return 1
  fi

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    printf '✓ %s already installed\n' "$pkg"
    return 0
  fi

  printf '→ Installing AUR package %s via %s\n' "$pkg" "$aur_helper"
  if ! "$aur_helper" -S --needed --noconfirm "$pkg"; then
    missing_packages+=("$pkg")
    printf '⚠ Failed to install %s from AUR (will report at end)\n' "$pkg"
    return 1
  fi

  return 0
}

for entry in "${packages[@]}"; do
  package="${entry%%#*}"
  package="${package#"${package%%[![:space:]]*}"}"
  package="${package%"${package##*[![:space:]]}"}"
  [[ -z "$package" ]] && continue

  if [[ "$package" == aur:* ]]; then
    install_aur_package "${package#aur:}"
  else
    install_pacman_package "$package"
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
