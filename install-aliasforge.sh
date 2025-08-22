#!/usr/bin/env sh
set -eu

MARK_BEGIN="### BEGIN ALIASFORGE"
MARK_END="### END ALIASFORGE"
ALIAS_SH="$HOME/.aliasforge.sh"
FISH_DIR="$HOME/.config/fish/conf.d"
FISH_FILE="$FISH_DIR/aliasforge.fish"

LAST_LINKED_RC=""
SUGGEST_CMD=""

# --- detection helpers (needed by main) ---
detect_os() {
  case "$(uname -s 2>/dev/null || echo Unknown)" in
    Darwin) echo "macOS" ;;
    Linux)  echo "Linux" ;;
    *)      echo "Other" ;;
  esac
}

detect_shell() {
  if [ -n "${SHELL-}" ]; then
    echo "${SHELL##*/}"
  else
    ps -p "$$" -o comm= 2>/dev/null | awk -F/ '{print $NF}'
  fi
}

# --- file helpers ---
append_if_missing() {
  f="$1"; needle="$2"; line="$3"
  [ -f "$f" ] || : >"$f"
  if ! grep -Fqs "$needle" "$f"; then
    printf '%s\n' "$line" >> "$f"
  fi
}

has_marker() {
  f="$1"
  [ -f "$f" ] && grep -Fqs "$MARK_BEGIN" "$f"
}

link_into_rc_if_missing() {
  rc="$1"
  [ -f "$rc" ] || : >"$rc"
  if ! has_marker "$rc"; then
    append_if_missing "$rc" "$ALIAS_SH" \
"$MARK_BEGIN
[ -f \"$ALIAS_SH\" ] && . \"$ALIAS_SH\"
$MARK_END"
    LAST_LINKED_RC="$rc"
  fi
}

strip_marker_block() {
  rc="$1"
  [ -f "$rc" ] || return 0
  awk 'BEGIN{skip=0}
       $0~/'"$MARK_BEGIN"'/ {skip=1; next}
       $0~/'"$MARK_END"'/   {skip=0; next}
       skip==0 {print}' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
}

# --- content writers (AliasForge-managed files) ---
write_alias_block_sh() {
  cat >"$ALIAS_SH" <<'EOF'
# AliasForge: POSIX-friendly aliases (Bash/Zsh/Dash)

# Basic nav/listing
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias hgrep='history | grep'

# Git
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -n 20'
alias ga='git add -A'
alias gc='git commit -m'
alias gp='git push'
alias gco='git checkout'
alias gb='git branch'
alias gpl='git pull --ff-only'

# Docker / Compose / K8s
alias dps='docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias k='kubectl'
alias kgp='kubectl get pods -A'
alias kgs='kubectl get svc -A'
alias kctx='kubectl config get-contexts'
alias kus='kubectl config use-context'

# Networking
alias wanip='curl -fsS https://ifconfig.me || curl -fsS https://ipecho.net/plain; echo'

lanip() {
  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null
  elif command -v hostname >/dev/null 2>&1; then
    hostname -I | awk "{print \$1}"
  else
    echo "Unable to detect internal IP"
  fi
}

alias ports='lsof -i -P -n | grep LISTEN'

# System
alias path='echo "$PATH" | tr ":" "\n"'
please() {
  if [ $# -eq 0 ]; then
    sudo $(history -p !!)
  else
    sudo "$@"
  fi
}
whichshell() {
  os="$(uname -s 2>/dev/null || echo Unknown)"
  shell_name="$(ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}')"
  echo "Shell: $shell_name | OS: $os"
}

# Project helpers (customise as needed)
# alias tw='cd ~/projects/traversys && code .'
EOF
}

write_alias_block_fish() {
  mkdir -p "$FISH_DIR"
  cat >"$FISH_FILE" <<'EOF'
# AliasForge for Fish (loaded automatically from conf.d)

# nav/listing
function ..;  cd ..; end
function ...; cd ../..; end
function ll;  command ls -lah; end
function la;  command ls -A; end
function l;   command ls -CF; end
function hgrep; command history | grep; end

# git
function gs;  command git status -sb; end
function gl;  command git log --oneline --graph --decorate -n 20; end
function ga;  command git add -A; end
function gc;  command git commit -m $argv; end
function gp;  command git push $argv; end
function gco; command git checkout $argv; end
function gb;  command git branch $argv; end
function gpl; command git pull --ff-only $argv; end

# docker / compose / k8s
function dps; command docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"; end
function dcu; command docker compose up -d $argv; end
function dcd; command docker compose down $argv; end
function k;   command kubectl $argv; end
function kgp; command kubectl get pods -A; end
function kgs; command kubectl get svc -A; end
function kctx;command kubectl config get-contexts; end
function kus; command kubectl config use-context $argv; end

# networking
function wanip
    command curl -fsS https://ifconfig.me || command curl -fsS https://ipecho.net/plain
    echo
end

function lanip
    if type -q ipconfig
        ipconfig getifaddr en0 ^/dev/null; or ipconfig getifaddr en1 ^/dev/null
    else if type -q hostname
        hostname -I | awk '{print $1}'
    else
        echo "Unable to detect internal IP"
    end
end

function ports; command lsof -i -P -n | grep LISTEN; end

# system
function path; printf "%s\n" $PATH; end
function please
    if test (count $argv) -eq 0
        eval sudo $history[1]
    else
        sudo $argv
    end
end
function whichshell
    set os (uname -s ^/dev/null)
    set shell_name (ps -p %self -o comm= ^/dev/null | awk -F/ '{print $NF}')
    echo "Shell: $shell_name | OS: $os"
end

# project helpers (customise)
# function proj; cd ~/projects/project; code .; end
EOF
}

# --- main ---
main() {
  OS="$(detect_os)"
  SHELL_NAME="$(detect_shell)"

  # Always (re)write our managed files
  write_alias_block_sh
  write_alias_block_fish

  created_any=0
  [ -f "$HOME/.zshrc" ] && { link_into_rc_if_missing "$HOME/.zshrc"; created_any=1; }
  [ -f "$HOME/.bashrc" ] && { link_into_rc_if_missing "$HOME/.bashrc"; created_any=1; }
  [ "$OS" = "macOS" ] && [ -f "$HOME/.bash_profile" ] && { link_into_rc_if_missing "$HOME/.bash_profile"; created_any=1; }

  if [ "$created_any" -eq 0 ]; then
    case "$SHELL_NAME" in
      zsh)  link_into_rc_if_missing "$HOME/.zshrc" ;;
      bash)
        if [ "$OS" = "macOS" ]; then
          link_into_rc_if_missing "$HOME/.bash_profile"
        else
          link_into_rc_if_missing "$HOME/.bashrc"
        fi
        ;;
      *)    link_into_rc_if_missing "$HOME/.profile" ;;
    esac
  fi

  case "$SHELL_NAME" in
    fish) SUGGEST_CMD="exec fish" ;;
    zsh|bash|sh|ksh)
      if [ -n "$LAST_LINKED_RC" ]; then
        SUGGEST_CMD="source $LAST_LINKED_RC"
      else
        case "$SHELL_NAME" in
          zsh)  SUGGEST_CMD="source ~/.zshrc" ;;
          bash) SUGGEST_CMD="[ \"$OS\" = macOS ] && source ~/.bash_profile || source ~/.bashrc" ;;
          *)    SUGGEST_CMD="source ~/.profile" ;;
        esac
      fi
      ;;
    *) SUGGEST_CMD="open a new shell session" ;;
  esac

  printf "AliasForge installed on %s with shell: %s\n" "$OS" "$SHELL_NAME"
  printf "Bash/Zsh aliases: %s (sourced via rc marker)\n" "$ALIAS_SH"
  printf "Fish functions:   %s\n" "$FISH_FILE"
  printf "\nReload now with:\n  %s\n" "$SUGGEST_CMD"
}

if [ "${1-}" = "--uninstall" ]; then
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    [ -f "$rc" ] && strip_marker_block "$rc" || true
  done
  rm -f "$ALIAS_SH" "$FISH_FILE"
  echo "AliasForge removed."
  exit 0
fi

main