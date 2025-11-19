# AliasForge  

**AliasForge** is a lightweight, cross-platform alias manager that ensures your favourite CLI shortcuts are always with you. It works on macOS and Linux, supporting Bash, Zsh, and Fish shells.  

## ✨ Features  
- Cross-platform: macOS and Linux  
- Multi-shell: Bash, Zsh, Fish, and NuShell support  
- Idempotent: safe to run multiple times  
- Easy to customise: edit one file, reload, done  
- Uninstall option for a clean slate  

## 🚀 Installation  

Clone or copy the script to your host

```sh
curl -fsSL https://raw.githubusercontent.com/codefitz/aliasforge/main/install-aliasforge.sh -o install-aliasforge.sh
```

Run:

```sh
chmod +x install-aliasforge.sh
./install-aliasforge.sh

This will:
	•	Install a managed alias file at ~/.aliasforge.sh
	•	Link it into your shell rc (.zshrc, .bashrc, or .profile)
	•	For Fish, create an aliasforge.fish file in ~/.config/fish/conf.d/

Reload your shell or run:

source ~/.zshrc   # Zsh  
source ~/.bashrc  # Bash  
exec fish         # Fish  

### 🍺 macOS Homebrew helpers

If you're on macOS and want the recommended prompt/tools stack, run:

```sh
./install-macos-brew.sh
```

The script installs everything listed in `brew-requirements.txt`, skipping entries that are already present. Add or remove packages by editing that file—use the `cask:` prefix (e.g. `cask:ghostty`) for apps that ship as casks.

⚙️ Customisation

All your aliases live in:
	•	Bash/Zsh → ~/.aliasforge.sh
	•	Fish → ~/.config/fish/conf.d/aliasforge.fish

Edit these files to add, remove, or change aliases.

Example entries:

alias gs='git status -sb'
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias please='sudo'

### NuShell

NuShell support is installed automatically. The script writes `~/.config/nushell/aliasforge.nu` and ensures `config.nu` sources it via a managed marker block. Reload NuShell with:

```nu
source ~/.config/nushell/config.nu
```

Inside NuShell, use the provided `reloadprofile`/`sp` helpers if you need a quick reminder of the reload command.

### 🧳 Using AliasForge with chezmoi

Chezmoi is a great way to sync your aliases across machines. AliasForge already ships with `cme`/`cma` helpers, and you can keep the install script plus the generated alias files in your chezmoi source so every new machine is ready in one `chezmoi apply`.

1. Install chezmoi (it is listed in `brew-requirements.txt`) and initialise your dotfiles repo: `chezmoi init <your-repo>`.
2. Capture the AliasForge-managed files so edits are tracked:
   ```sh
   chezmoi add ~/.aliasforge.sh
   chezmoi add ~/.config/fish/conf.d/aliasforge.fish
   chezmoi add ~/.config/nushell/aliasforge.nu
   ```
3. Drop the installer into `.chezmoiscripts` so it runs the first time you apply on each host. Running it *before* the rest of your files ensures the rc markers are ready before chezmoi writes your customised aliases:
   ```sh
   SRC="$(chezmoi source-path)"
   mkdir -p "$SRC/.chezmoiscripts"
   curl -fsSL https://raw.githubusercontent.com/codefitz/aliasforge/main/install-aliasforge.sh \
     > "$SRC/.chezmoiscripts/run_once_before_install-aliasforge.sh.tmpl"
   chmod +x "$SRC/.chezmoiscripts/run_once_before_install-aliasforge.sh.tmpl"
   chezmoi add "$SRC/.chezmoiscripts/run_once_before_install-aliasforge.sh.tmpl"
   ```
4. On a new machine, run `chezmoi apply`. Chezmoi executes the installer once (linking AliasForge into your rc files) and then writes your synced alias files, so everything is ready after a quick shell reload.
5. Use `chezmoi edit ~/.aliasforge.sh` (and the Fish/Nu files as needed) plus `chezmoi apply` to push updates to every machine.

🧹 Uninstall

To remove AliasForge and all its changes:

./install-aliasforge.sh --uninstall

This cleans up rc files and deletes the alias files (including the NuShell module).

📦 Roadmap
	•	Optional alias packs (git, docker, k8s, cloud)
	•	Configurable install directory

📜 License

MIT License — use, modify, and share freely.
