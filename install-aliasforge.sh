#!/usr/bin/env sh
set -eu

MARK_BEGIN="### BEGIN ALIASFORGE"
MARK_END="### END ALIASFORGE"
ALIAS_SH="$HOME/.aliasforge.sh"
FISH_DIR="$HOME/.config/fish/conf.d"
FISH_FILE="$FISH_DIR/aliasforge.fish"
NU_DIR="$HOME/.config/nushell"
NU_FILE="$NU_DIR/aliasforge.nu"
NU_CONFIG="$NU_DIR/config.nu"

LAST_LINKED_RC=""
SUGGEST_CMD=""
NU_LINKED_CONFIG=""
ACTION="install"

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

usage() {
  cat <<'EOF'
Usage: install-aliasforge.sh [--uninstall]

Options:
  --uninstall       Remove AliasForge artifacts (Zsh/Bash/Fish/NuShell)
  -h, --help        Show this help message
EOF
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

link_into_nushell_if_missing() {
  [ -d "$NU_DIR" ] || mkdir -p "$NU_DIR"
  [ -f "$NU_CONFIG" ] || : >"$NU_CONFIG"
  if ! has_marker "$NU_CONFIG"; then
    append_if_missing "$NU_CONFIG" "$NU_FILE" \
"$MARK_BEGIN
source \"$NU_FILE\"
$MARK_END"
    NU_LINKED_CONFIG="$NU_CONFIG"
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
aliasforge__detect_profile_file() {
  shell_name="${SHELL##*/}"
  os="$(uname -s 2>/dev/null || echo Unknown)"
  case "$shell_name" in
    zsh)
      [ -f "$HOME/.zshrc" ] && { printf '%s\n' "$HOME/.zshrc"; return 0; }
      ;;
    bash)
      if [ "$os" = "Darwin" ] && [ -f "$HOME/.bash_profile" ]; then
        printf '%s\n' "$HOME/.bash_profile"
        return 0
      fi
      [ -f "$HOME/.bashrc" ] && { printf '%s\n' "$HOME/.bashrc"; return 0; }
      ;;
    ksh)
      [ -f "$HOME/.kshrc" ] && { printf '%s\n' "$HOME/.kshrc"; return 0; }
      ;;
  esac
  for fallback in "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$fallback" ]; then
      printf '%s\n' "$fallback"
      return 0
    fi
  done
  return 1
}
aliasforge_reload_profile() {
  rc="$(aliasforge__detect_profile_file 2>/dev/null || true)"
  if [ -n "$rc" ]; then
    # shellcheck disable=SC1090
    . "$rc"
    printf "Reloaded %s\n" "$rc"
  else
    echo "AliasForge reload: no profile file found to source."
  fi
}
alias reloadprofile='aliasforge_reload_profile'
alias sp='aliasforge_reload_profile'

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
function __aliasforge_detect_fish_profile
    set -l candidates ~/.config/fish/config.fish ~/.config/fish/conf.d/aliasforge.fish
    for rc in $candidates
        if test -f "$rc"
            echo "$rc"
            return 0
        end
    end
    return 1
end
function aliasforge_reload_profile
    set -l rc (__aliasforge_detect_fish_profile)
    if test -n "$rc"
        source "$rc"
        printf "Reloaded %s\n" "$rc"
    else
        echo "AliasForge reload: no profile file found to source."
    end
end
function reloadprofile; aliasforge_reload_profile; end
function sp; aliasforge_reload_profile; end

# project helpers (customise)
# function proj; cd ~/projects/project; code .; end
EOF
}

write_alias_block_nu() {
  mkdir -p "$NU_DIR"
  cat >"$NU_FILE" <<'EOF'
# AliasForge for NuShell (auto-generated)

# nav/listing
alias .. = cd ..
alias ... = cd ../..
alias ll = ^ls -lah
alias la = ^ls -A
alias l = ^ls -CF
def hgrep [pattern: string] {
    if (($pattern | str length) == 0) {
        print "Usage: hgrep <pattern>"
    } else {
        history | where command =~ $pattern
    }
}

# git
alias gs = ^git status -sb
alias gl = ^git log --oneline --graph --decorate -n 20
alias ga = ^git add -A
alias gc = ^git commit -m
alias gp = ^git push
alias gco = ^git checkout
alias gb = ^git branch
alias gpl = ^git pull --ff-only

# docker / k8s helpers
alias dps = ^docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
alias dcu = ^docker compose up -d
alias dcd = ^docker compose down
alias k = ^kubectl
alias kgp = ^kubectl get pods -A
alias kgs = ^kubectl get svc -A
alias kctx = ^kubectl config get-contexts
alias kus = ^kubectl config use-context

# networking
def wanip [] {
    mut ip = (try { ^curl -fsS https://ifconfig.me } catch { "" })
    if (($ip | str length) == 0) {
        $ip = (try { ^curl -fsS https://ipecho.net/plain } catch { "" })
    }
    if (($ip | str length) == 0) {
        print "Unable to detect external IP"
    } else {
        print ($ip | str trim)
    }
}

def lanip [] {
    mut internal = ""
    if ((which ipconfig | length) > 0) {
        $internal = (try { ^ipconfig getifaddr en0 } catch { "" })
        if (($internal | str length) == 0) {
            $internal = (try { ^ipconfig getifaddr en1 } catch { "" })
        }
    } else if ((which hostname | length) > 0) {
        let ips = (try { ^hostname -I } catch { "" })
        if (($ips | str length) > 0) {
            $internal = ($ips | str trim | split row ' ' | get 0)
        }
    }
    if (($internal | str length) == 0) {
        print "Unable to detect internal IP"
    } else {
        print ($internal | str trim)
    }
}

def ports [] {
    ^lsof -i -P -n
    | lines
    | where {|line| ($line | str contains 'LISTEN') }
}

# system helpers
def path [] {
    $env.PATH
    | split row (char path_sep)
    | each {|segment|
        print $segment
    }
}

def please [...cmd] {
    if (($cmd | length) == 0) {
        print "Usage: please <command>"
    } else {
        ^sudo ...$cmd
    }
}

def whichshell [] {
    let os = (try { ^uname -s } catch { "Unknown" })
    print $"Shell: nu | OS: ($os)"
}

def aliasforge_reload_profile [] {
    print "Reload NuShell aliases with: source ~/.config/nushell/config.nu"
}

alias reloadprofile = aliasforge_reload_profile
alias sp = aliasforge_reload_profile

# project helpers placeholder
# alias proj = ^cd ~/projects/project && ^code .
EOF
}

# --- main ---
main() {
  OS="$(detect_os)"
  SHELL_NAME="$(detect_shell)"

  # Always (re)write our managed files
  write_alias_block_sh
  write_alias_block_fish
  write_alias_block_nu
  link_into_nushell_if_missing

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
    nu)   SUGGEST_CMD="source ~/.config/nushell/config.nu" ;;
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
  printf "NuShell aliases:  %s\n" "$NU_FILE"
  if [ -n "$NU_LINKED_CONFIG" ]; then
    printf "NuShell config updated: %s\n" "$NU_LINKED_CONFIG"
  else
    printf "NuShell config already sourcing AliasForge: %s\n" "$NU_CONFIG"
  fi
  printf "\nReload now with:\n  %s\n" "$SUGGEST_CMD"
  printf "  NuShell: source %s\n" "$NU_CONFIG"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --uninstall)
      ACTION="uninstall"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$ACTION" = "uninstall" ]; then
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    [ -f "$rc" ] && strip_marker_block "$rc" || true
  done
  [ -f "$NU_CONFIG" ] && strip_marker_block "$NU_CONFIG" || true
  rm -f "$ALIAS_SH" "$FISH_FILE" "$NU_FILE"
  echo "AliasForge removed."
  exit 0
fi

main
