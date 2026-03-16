#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apt_requirements_file="$script_dir/apt-requirements.txt"
pacman_requirements_file="$script_dir/pacman-requirements.txt"

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'This script is intended for Linux systems only.\n' >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  printf 'Unable to detect distro (missing /etc/os-release).\n' >&2
  exit 1
fi

. /etc/os-release

os_matches() {
  local candidate="$1"
  local value

  for value in "${ID-}" ${ID_LIKE-}; do
    [[ "$value" == "$candidate" ]] && return 0
  done

  return 1
}

if os_matches arch || os_matches endeavouros; then
  package_manager="pacman"
  requirements_file="$pacman_requirements_file"
elif os_matches linuxmint || os_matches ubuntu || os_matches debian; then
  package_manager="apt"
  requirements_file="$apt_requirements_file"
else
  printf 'Unsupported distro: %s (supported families: arch/endeavouros and linuxmint/ubuntu/debian-like).\n' "${ID-unknown}" >&2
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

trim_package_name() {
  local package="$1"

  package="${package%%#*}"
  package="${package#"${package%%[![:space:]]*}"}"
  package="${package%"${package##*[![:space:]]}"}"
  printf '%s\n' "$package"
}

run_aliasforge_install() {
  if [[ -f "$script_dir/install-aliasforge.sh" ]]; then
    printf '→ Installing AliasForge for Bash\n'
    SHELL="/bin/bash" bash "$script_dir/install-aliasforge.sh"
  else
    printf 'install-aliasforge.sh not found at %s\n' "$script_dir" >&2
    exit 1
  fi
}

install_with_apt() {
  local did_update=0
  local pkg
  local missing_packages=()

  if ! command -v apt-get >/dev/null 2>&1; then
    printf 'apt-get not found. This distro requires APT.\n' >&2
    exit 1
  fi

  apt_update_once() {
    if [[ "$did_update" -eq 0 ]]; then
      printf '→ Updating package lists\n'
      "${SUDO[@]}" apt-get update
      did_update=1
    fi
  }

  install_apt_package() {
    local pkg="$1"

    if dpkg -s "$pkg" >/dev/null 2>&1; then
      printf '✓ %s already installed\n' "$pkg"
      return 0
    fi

    apt_update_once

    if ! apt-cache show "$pkg" >/dev/null 2>&1; then
      missing_packages+=("$pkg (not in APT cache)")
      printf '⚠ %s not available in APT (skipping)\n' "$pkg"
      return 1
    fi

    printf '→ Installing %s\n' "$pkg"
    if ! "${SUDO[@]}" apt-get install -y "$pkg"; then
      missing_packages+=("$pkg")
      printf '⚠ Failed to install %s (will report at end)\n' "$pkg"
      return 1
    fi

    return 0
  }

  readarray -t packages < <(grep -Ev '^\s*(#|$)' "$requirements_file" || true)

  if [[ ${#packages[@]} -eq 0 ]]; then
    printf 'No packages listed in %s\n' "$requirements_file"
    return 0
  fi

  for entry in "${packages[@]}"; do
    pkg="$(trim_package_name "$entry")"
    [[ -z "$pkg" ]] && continue
    install_apt_package "$pkg"
  done

  run_aliasforge_install

  if [[ ${#missing_packages[@]} -gt 0 ]]; then
    printf '\nMissing or failed packages:\n'
    for pkg in "${missing_packages[@]}"; do
      printf '  - %s\n' "$pkg"
    done
    exit 1
  fi
}

install_with_pacman() {
  local did_sync=0
  local aur_helper=""
  local pkg
  local missing_packages=()

  if ! command -v pacman >/dev/null 2>&1; then
    printf 'pacman not found. This distro requires pacman.\n' >&2
    exit 1
  fi

  if command -v yay >/dev/null 2>&1; then
    aur_helper="yay"
  elif command -v paru >/dev/null 2>&1; then
    aur_helper="paru"
  fi

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

  readarray -t packages < <(grep -Ev '^\s*(#|$)' "$requirements_file" || true)

  if [[ ${#packages[@]} -eq 0 ]]; then
    printf 'No packages listed in %s\n' "$requirements_file"
    return 0
  fi

  for entry in "${packages[@]}"; do
    pkg="$(trim_package_name "$entry")"
    [[ -z "$pkg" ]] && continue

    if [[ "$pkg" == aur:* ]]; then
      install_aur_package "${pkg#aur:}"
    else
      install_pacman_package "$pkg"
    fi
  done

  run_aliasforge_install

  if [[ ${#missing_packages[@]} -gt 0 ]]; then
    printf '\nMissing or failed packages:\n'
    for pkg in "${missing_packages[@]}"; do
      printf '  - %s\n' "$pkg"
    done
    exit 1
  fi
}

case "$package_manager" in
  apt)
    install_with_apt
    ;;
  pacman)
    install_with_pacman
    ;;
esac
