# AliasForge  

**AliasForge** is a lightweight, cross-platform alias manager that ensures your favourite CLI shortcuts are always with you. It works on macOS and Linux, supporting Bash, Zsh, and Fish shells.  

## ✨ Features  
- Cross-platform: macOS and Linux  
- Multi-shell: Bash, Zsh, and Fish support  
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

⚙️ Customisation

All your aliases live in:
	•	Bash/Zsh → ~/.aliasforge.sh
	•	Fish → ~/.config/fish/conf.d/aliasforge.fish

Edit these files to add, remove, or change aliases.

Example entries:

alias gs='git status -sb'
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias please='sudo'

🧹 Uninstall

To remove AliasForge and all its changes:

./install-aliasforge.sh --uninstall

This cleans up rc files and deletes the alias files.

📦 Roadmap
	•	Remote sync (share aliases across machines)
	•	Optional alias packs (git, docker, k8s, cloud)
	•	Configurable install directory

📜 License

MIT License — use, modify, and share freely.