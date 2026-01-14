#!/usr/bin/env bash
set -euo pipefail

fonts=(
  "Hack"
  "UbuntuMono"
  "Agave"
  "JetBrainsMono"
  "DejaVuSansMono"
  "Meslo"
  "FiraCode"
  "SourceCodePro"
)

dest_dir="/usr/local/share/fonts/nerd-fonts"

if [[ "$(uname -s)" != "Linux" ]]; then
  printf 'This script is intended for Linux systems only.\n' >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  printf 'curl not found. Install curl and rerun.\n' >&2
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  printf 'tar not found. Install tar and rerun.\n' >&2
  exit 1
fi

if ! command -v fc-cache >/dev/null 2>&1; then
  printf 'fc-cache not found. Install fontconfig and rerun.\n' >&2
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

tmp_root="$(mktemp -d -t aliasforge-fonts.XXXXXX)"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

failed_fonts=()

"${SUDO[@]}" mkdir -p "$dest_dir"

for font in "${fonts[@]}"; do
  font_dir="$dest_dir/$font"
  if [[ -d "$font_dir" ]] && compgen -G "$font_dir/*" >/dev/null; then
    printf '✓ %s already installed (dir: %s)\n' "$font" "$font_dir"
    continue
  fi

  archive="$tmp_root/$font.tar.xz"
  url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$font.tar.xz"
  printf '→ Downloading %s\n' "$font"
  if ! curl -fL "$url" -o "$archive"; then
    printf '⚠ Failed to download %s\n' "$font"
    failed_fonts+=("$font (download failed)")
    continue
  fi

  "${SUDO[@]}" mkdir -p "$font_dir"
  printf '→ Installing %s to %s\n' "$font" "$font_dir"
  if ! "${SUDO[@]}" tar -xf "$archive" -C "$font_dir"; then
    printf '⚠ Failed to extract %s\n' "$font"
    failed_fonts+=("$font (extract failed)")
    continue
  fi
done

printf '→ Refreshing font cache\n'
"${SUDO[@]}" fc-cache -fv

if [[ ${#failed_fonts[@]} -gt 0 ]]; then
  printf '\nMissing or failed fonts:\n'
  for font in "${failed_fonts[@]}"; do
    printf '  - %s\n' "$font"
  done
  exit 1
fi
