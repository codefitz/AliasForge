# Linux Nerd Fonts (Mint/Ubuntu)

These fonts are Nerd Fonts equivalents of the macOS casks. On Linux the
recommended path is to download the Nerd Fonts release archives and install
them into your local font directory, then refresh the font cache.

System-wide install (recommended):

```sh
./install-linux-fonts.sh
```

Local user install (manual):

```sh
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
```

Download the fonts you want (examples below), then run:

```sh
fc-cache -fv
```

## Nerd Fonts release names

Each entry shows the Nerd Fonts release archive name to use with:

```sh
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/<NAME>.tar.xz
```

- Hack Nerd Font -> Hack
- Ubuntu Mono Nerd Font -> UbuntuMono
- Agave Nerd Font -> Agave
- JetBrains Mono Nerd Font -> JetBrainsMono
- DejaVu Sans Mono Nerd Font -> DejaVuSansMono
- Meslo LG Nerd Font -> Meslo
- Fira Code Nerd Font -> FiraCode
- Sauce Code Pro Nerd Font -> SourceCodePro

Example:

```sh
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
tar -xf JetBrainsMono.tar.xz
fc-cache -fv
```

## Notes

- Some APT packages provide the non-Nerd version of these fonts, but the Nerd
  variants are best installed from the Nerd Fonts releases.
- If you want system-wide installation instead, extract into
  `/usr/local/share/fonts` with `sudo` and then run `sudo fc-cache -fv`.
