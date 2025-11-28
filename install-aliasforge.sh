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
cd() {
  if command -v z >/dev/null 2>&1; then
    z "$@"
  else
    command cd "$@"
  fi
}
ls() {
  if command -v eza >/dev/null 2>&1; then
    command eza "$@"
  else
    command ls "$@"
  fi
}
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
tree() {
  if command -v eza >/dev/null 2>&1; then
    command eza --tree "$@"
  else
    command tree "$@" 2>/dev/null || command ls "$@"
  fi
}
alias hgrep='history | grep'

# File viewing
cat() {
  if command -v bat >/dev/null 2>&1; then
    command bat --paging=never --plain "$@"
  else
    command cat "$@"
  fi
}

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
triage_env() {
  echo "=== HOSTNAME ==="
  hostname

  echo
  echo "=== PWD ==="
  pwd

  echo
  echo "=== SHELL / VERSION ==="
  echo "${SHELL-}"
  if [ -n "${SHELL-}" ]; then
    "$SHELL" --version 2>&1 | head -n 1
  fi

  echo
  echo "=== PATH (first 10 entries) ==="
  printf "%s" "$PATH" | tr ':' '\n' | head -n 10

  echo
  echo "=== GIT STATUS (if repo) ==="
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git status -sb
  else
    echo "Not a git repo"
  fi
}
aliasforge_list_aliases() {
  if alias 1>/dev/null 2>&1; then
    alias | sed -E "s/^alias[[:space:]]+([^=]+)=['\"]?(.*)['\"]?$/\\1: \\2/"
  fi
  cat <<'AF_ALIASES'
cd: function wrapper (prefers z, fallback cd)
ls: function wrapper (prefers eza, fallback ls)
tree: function wrapper (prefers eza --tree, fallback tree/ls)
cat: function wrapper (prefers bat --paging=never --plain)
lanip: function wrapper showing internal IP
please: function wrapper to sudo the last or provided command
whichshell: function wrapper printing shell and OS
triage_env: function wrapper showing host context
afupdate: function wrapper updating AliasForge
aliasforge_reload_profile: function wrapper reloading the detected profile
AF_ALIASES
}
alias afaliases='aliasforge_list_aliases'
alias afa='aliasforge_list_aliases'
afupdate() {
  tmp="$(mktemp -t aliasforge.XXXXXX)" || return 1
  if [ -z "${tmp-}" ]; then
    echo "mktemp failed"
    return 1
  fi
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/codefitz/aliasforge/main/install-aliasforge.sh -o "$tmp" &&
      sh "$tmp"
  else
    echo "curl not found; cannot update"
  fi
  rm -f "$tmp"
}
alias afu='afupdate'
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

# Homebrew
alias bi='brew install'
alias bu='brew update'
alias bup='brew upgrade'
alias bun='brew uninstall'
alias bls='brew list'

# Chezmoi helpers
alias cme='chezmoi edit'
alias cma='chezmoi apply'
alias cmu='chezmoi update'
alias cmd='chezmoi diff'

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
function cd
    if type -q z
        z $argv
    else
        builtin cd $argv
    end
end
function ls
    if type -q eza
        command eza $argv
    else
        command ls $argv
    end
end
function ll;  ls -lah $argv; end
function la;  ls -A $argv; end
function l;   ls -CF $argv; end
function tree
    if type -q eza
        command eza --tree $argv
    else if type -q tree
        command tree $argv
    else
        command ls $argv
    end
end
function hgrep; command history | grep; end

# file viewing
function cat
    if type -q bat
        command bat --paging=never --plain $argv
    else
        command cat $argv
    end
end

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
function triage_env
    echo "=== HOSTNAME ==="
    hostname

    echo
    echo "=== PWD ==="
    pwd

    echo
    echo "=== SHELL / VERSION ==="
    echo "$SHELL"
    if test -n "$SHELL"
        $SHELL --version 2>&1 | head -n 1
    end

    echo
    echo "=== PATH (first 10 entries) ==="
    printf "%s\n" $PATH | head -n 10

    echo
    echo "=== GIT STATUS (if repo) ==="
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        git status -sb
    else
        echo "Not a git repo"
    end
end
function __aliasforge_print_alias_list
    set -l aliasforge_pairs \
        "..|cd .." \
        "...|cd ../.." \
        "cd|function wrapper (prefers z, fallback cd)" \
        "ls|function wrapper (prefers eza, fallback ls)" \
        "ll|ls -lah" \
        "la|ls -A" \
        "l|ls -CF" \
        "tree|function wrapper (prefers eza --tree, fallback tree/ls)" \
        "hgrep|history | grep" \
        "cat|function wrapper (prefers bat --paging=never --plain)" \
        "gs|git status -sb" \
        "gl|git log --oneline --graph --decorate -n 20" \
        "ga|git add -A" \
        "gc|git commit -m" \
        "gp|git push" \
        "gco|git checkout" \
        "gb|git branch" \
        "gpl|git pull --ff-only" \
        "dps|docker ps --format 'table {{.Names}} {{.Image}} {{.Status}} {{.Ports}}'" \
        "dcu|docker compose up -d" \
        "dcd|docker compose down" \
        "k|kubectl" \
        "kgp|kubectl get pods -A" \
        "kgs|kubectl get svc -A" \
        "kctx|kubectl config get-contexts" \
        "kus|kubectl config use-context" \
        "wanip|external IP via curl" \
        "lanip|internal IP via ipconfig/hostname" \
        "ports|lsof -i -P -n | grep LISTEN" \
        "path|print PATH entries" \
        "please|sudo last command or args" \
        "whichshell|Shell and OS info" \
        "triage_env|Quick host/env snapshot" \
        "afupdate|Update AliasForge from GitHub" \
        "afu|Alias for afupdate" \
        "aliasforge_reload_profile|Source detected Fish profile" \
        "reloadprofile|Alias for aliasforge_reload_profile" \
        "sp|Alias for aliasforge_reload_profile" \
        "bi|brew install" \
        "bu|brew update" \
        "bup|brew upgrade" \
        "bun|brew uninstall" \
        "bls|brew list" \
        "cme|chezmoi edit" \
        "cma|chezmoi apply" \
        "cmu|chezmoi update" \
        "cmd|chezmoi diff"
    for pair in $aliasforge_pairs
        set -l parts (string split -m1 '|' $pair)
        set -l name $parts[1]
        set -l cmd $parts[2]
        printf "%s: %s\n" $name $cmd
    end
end
function __aliasforge_print_native_aliases
    if not type -q alias
        return
    end
    alias | while read -l line
        set line (string trim $line)
        if test -z "$line"
            continue
        end
        set line (string replace -r '^alias[ \t]+' '' -- $line)
        set -l parts (string split -m1 '=' $line)
        set -l name $parts[1]
        set -l cmd ""
        if test (count $parts) -gt 1
            set cmd (string trim --chars \"' $parts[2])
        end
        if test -n "$name"
            if test -n "$cmd"
                printf "%s: %s\n" $name $cmd
            else
                printf "%s\n" $name
            end
        end
    end
end
function afaliases
    __aliasforge_print_native_aliases
    __aliasforge_print_alias_list
end
function afa; afaliases; end
function afupdate
    set tmp (mktemp -t aliasforge.XXXXXX)
    if test -z "$tmp"
        echo "mktemp failed"
        return 1
    end
    if type -q curl
        curl -fsSL https://raw.githubusercontent.com/codefitz/aliasforge/main/install-aliasforge.sh -o $tmp; and sh $tmp
    else
        echo "curl not found; cannot update"
    end
    rm -f $tmp
end
function afu; afupdate; end
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

# homebrew
function bi;  command brew install $argv; end
function bu;  command brew update $argv; end
function bup; command brew upgrade $argv; end
function bun; command brew uninstall $argv; end
function bls; command brew list $argv; end

# chezmoi helpers
function cme; command chezmoi edit $argv; end
function cma; command chezmoi apply $argv; end
function cmu; command chezmoi update $argv; end
function cmd; command chezmoi diff $argv; end

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
if ((which z | length) > 0) {
    alias cd = z
}
def --wrapped ls [...args] {
    if ((which eza | length) > 0) {
        ^eza ...$args
    } else {
        ^ls ...$args
    }
}
alias ll = ls -lah
alias la = ls -A
alias l = ls -CF
def tree [...args] {
    if ((which eza | length) > 0) {
        ^eza --tree ...$args
    } else if ((which tree | length) > 0) {
        ^tree ...$args
    } else {
        ls ...$args
    }
}
def hgrep [pattern: string] {
    if (($pattern | str length) == 0) {
        print "Usage: hgrep <pattern>"
    } else {
        history | where command =~ $pattern
    }
}

# file viewing
def --wrapped cat [...args] {
    if ((which bat | length) > 0) {
        ^bat --paging=never --plain ...$args
    } else {
        ^cat ...$args
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

def triage_env [] {
    print "=== HOSTNAME ==="
    try {
        ^hostname
        | lines
        | each {|line| print $line}
    } catch {|_| {}}

    print "\n=== PWD ==="
    print (pwd)

    print "\n=== SHELL / VERSION ==="
    let shell = ($env.SHELL? | default "")
    print $shell
    if ($shell | str length) > 0 {
        try {
            run-external $shell "--version"
            | lines
            | first 1
            | each {|line| print $line}
        } catch {|_| {}}
    }

    print "\n=== PATH (first 10 entries) ==="
    $env.PATH
    | split row (char path_sep)
    | take 10
    | each {|segment| print $segment}

    print "\n=== GIT STATUS (if repo) ==="
    if ((which git | length) == 0) {
        print "git not installed"
    } else {
        try {
            ^git status -sb
            | lines
            | each {|line| print $line}
        } catch {|_| print "Not a git repo"}
    }
}

def afupdate [] {
    let tmp = (mktemp -t aliasforge.XXXXXX | str trim)
    if (($tmp | str length) == 0) {
        print "mktemp failed"
        return
    }
    if ((which curl | length) == 0) {
        print "curl not found; cannot update"
        rm $tmp
        return
    }
    try {
        curl -fsSL https://raw.githubusercontent.com/codefitz/aliasforge/main/install-aliasforge.sh | save -f $tmp
        sh $tmp
    } catch {|_| print "update failed"}
    rm $tmp
}

def aliasforge_reload_profile [] {
    print "Reload NuShell aliases with: source ~/.config/nushell/config.nu"
}

alias reloadprofile = aliasforge_reload_profile
alias sp = aliasforge_reload_profile
alias afu = afupdate
def afaliases [] {
    let native_aliases = (try { $nu.scope.aliases } catch {|_| [] })
    $native_aliases
    | each {|a|
        let expansion = (try { $a.expansion } catch {|_| "" })
        if ($expansion | str length) > 0 {
            print $"($a.name): ($expansion)"
        }
    }

    let function_aliases = [
        {name: "cd", cmd: "function wrapper (prefers z, fallback cd)"},
        {name: "ls", cmd: "function wrapper (prefers eza, fallback ls)"},
        {name: "tree", cmd: "function wrapper (prefers eza --tree, fallback tree/ls)"},
        {name: "hgrep", cmd: "history filter helper"},
        {name: "cat", cmd: "function wrapper (prefers bat --paging=never --plain)"},
        {name: "wanip", cmd: "external IP via curl"},
        {name: "lanip", cmd: "internal IP via ipconfig/hostname"},
        {name: "ports", cmd: "lsof LISTEN filter"},
        {name: "path", cmd: "print PATH entries"},
        {name: "please", cmd: "sudo passthrough"},
        {name: "whichshell", cmd: "Shell and OS info"},
        {name: "triage_env", cmd: "Quick host/env snapshot"},
        {name: "afupdate", cmd: "Update AliasForge from GitHub"},
        {name: "aliasforge_reload_profile", cmd: "Reload NuShell config message"}
    ]
    $function_aliases | each {|row| print $"($row.name): ($row.cmd)"}
}
alias afa = afaliases

# homebrew
alias bi = ^brew install
alias bu = ^brew update
alias bup = ^brew upgrade
alias bun = ^brew uninstall
alias bls = ^brew list

# chezmoi helpers
alias cme = ^chezmoi edit
alias cma = ^chezmoi apply
alias cmu = ^chezmoi update
alias cmd = ^chezmoi diff

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
