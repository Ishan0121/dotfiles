#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# ~/.zshrc — Specter's Dev Shell
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# 🛠️ USER CONFIGURATION — The Master Toggles
# ─────────────────────────────────────────────────────────────────────────────
# Set any of these to 'false' to disable the feature entirely.

# ── 1. Theming ──
ENABLE_P10K=false            # true = Powerlevel10k (fast instant prompt, heavy theme) | false = Standard OMZ Theme

if [[ -f "$HOME/.zsh_theme" ]]; then
  ZSH_ACTIVE_THEME="$(<"$HOME/.zsh_theme")"
else
  ZSH_ACTIVE_THEME="robbyrussell" # Active Oh-My-Zsh theme (used if ENABLE_P10K is false)
fi

# ── 2. Visuals & System Info ──
ENABLE_FIGLET=true           # Show large 'NOCTURNE' text on startup
FIGLET_EVERY_SESSION=true    # true = every new terminal | false = only once per day
FIGLET_IN_MULTIPLEXER=false  # true = show in tmux/zellij | false = disable in tmux/zellij

ENABLE_FETCH=true            # Show system info (fastfetch/neofetch) with anime PNG
FETCH_EVERY_SESSION=true     # true = every new terminal | false = only once per day
FETCH_IN_MULTIPLEXER=false   # true = show in tmux/zellij | false = disable in tmux/zellij

# ── 3. Greetings & Anime ──
ENABLE_GREETING=true         # Show the anime-style text greeting and quote
GREETING_EVERY_SESSION=false # true = every new terminal | false = only once per day
ENABLE_ANIME_ALIASES=true    # Enable aliases like 'nani', 'yamete', 'sugoi'
USE_AI_GREETER=false         # Use Aetheris AI to generate the greeting text
ENABLE_TTS=true              # Enable text-to-speech for the greeting

# ── 4. Dev Tools & Integrations ──
ENABLE_ZOXIDE=true           # Enable zoxide (smarter cd)
ENABLE_FZF=true              # Enable fuzzy finder integration
ENABLE_PYENV=true            # Enable pyenv Python version manager
ENABLE_NVM=true              # Enable Node Version Manager (lazy-loaded)

# ── 5. Utilities ──
ENABLE_EZA=true              # Replace 'ls' with 'eza' (icons and colors)
ENABLE_SYSTEM_CLEANER=true   # Enable the 'decache'/'nuke' Arch Linux cleaner tool

# ─────────────────────────────────────────────────────────────────────────────
# QUIET MODE FOR NON-INTERACTIVE SHELLS
# ─────────────────────────────────────────────────────────────────────────────
# If not interactive, stop here (avoid sourcing heavy stuff for background scripts)
case $- in
  *i*) ;;  # interactive
  *) return 0 ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# ENVIRONMENT
# ─────────────────────────────────────────────────────────────────────────────
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export EDITOR='nvim'
export VISUAL='nvim'
export PAGER='less'
export GOPATH="$HOME/go"

# ── PATH (typeset -U deduplicates automatically) ──────────────────────────────
typeset -U path
path=(
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  "$HOME/.cargo/bin"
  "$GOPATH/bin"
  /usr/local/bin
  /usr/bin
  /bin
  $path
)

# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS & GREETING LOGIC
# ─────────────────────────────────────────────────────────────────────────────

# Helper: runs command exactly once per day per user
_check_first_time_today() {
  local feature_name="$1"
  local marker="$HOME/.zsh_marker_${feature_name}_today"
  local today=$(date +%Y-%m-%d)
  if [[ ! -f "$marker" || $(<"$marker") != "$today" ]]; then
    echo "$today" > "$marker"
    return 0
  fi
  return 1
}

typewriter() {
  local text="$1" delay="${2:-0.02}" i
  for (( i = 0; i < ${#text}; i++ )); do
    printf '%s' "${text:$i:1}"
    sleep "$delay"
  done
  printf '\n'
}

time_greeting() {
  local h=$(date +%H)
  if   (( h < 12 )); then echo "Good morning,"
  elif (( h < 18 )); then echo "Good afternoon,"
  elif (( h < 21 )); then echo "Good evening,"
  else                    echo "Good night,"
  fi
}

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

welcome_messages=(
  "👋 Hey, ready to conquer the terminal?"
  "🔥 Yo! Let’s get things done."
  "💻 Greetings. The matrix awaits."
  "🚀 another day, another mission."
  "🔮 your digital realm awaits."
  "🎯 Time to hit your targets."
  "⚡ Let’s spark some magic."
  "📜 the code scroll is ready to be written."
  "🛰️ Hello transmission established."
  "🌌 Welcome, to the void."
  "🛠️ Let’s build something legendary."
  "🔥 Another line of code, another step to glory."
  "🧠 Engage brain mode."
  "🎮, the game is on."
  "💎, shine like perfect code."
  "🖤 The shadows welcome you."
  "🛡️ Armor up, debugging awaits."
  "🐉 Summon the dragons of logic."
  "🕹️ Player 1 ready —."
  "📡 Signals locked."
  "🎨 Let’s paint in code."
  "🧩 The puzzle awaits."
  "⚙️ Grinding gears of progress."
  "🔍 Let’s hunt some bugs."
  "📖 Time to write today’s story."
  "🪐 Orbiting success."
  "📂 New session unlocked."
  "🎙️ Welcome to another episode."
  "📊 Data awaits your touch."
  "🕵️ Detecting brilliance in progress,."
  "🌿 Keep growing."
  "💬 Ready for some terminal chatter?"
  "🦊 Stay sharp."
  "🧬 Code like DNA."
  "🔓 Unlocking creativity mode."
  "🎲 Roll for inspiration."
  "⚔️ Draw your keyboard."
  "☁️ Uploading ideas."
  "🌙 The night is yours."
  "🪄 Casting code spells."
  "📡 Initiating signal boost."
  "💣 Explosive productivity ahead."
  "🦾 Engage cyber mode."
  "🔭 Scanning horizons."
  "🌟 Shine through the syntax."
  "🖋️ Ink your code."
  "🎧 Code with rhythm."
  "🕹️ Player 1 ready —."
  "🌟 Greetings-san! Your domain awaits."
  "💻 Boot sequence complete online."
)

anime_quotes=(
  "『A lesson without pain is meaningless.』 – FMAB"
  "『Power comes in response to a need, not a desire.』 – DBZ"
  "『I am the hope of the universe!』 – Goku"
  "『I want to eat your pancreas.』 – Title quote lol"
  "『Great power comes with great responsibility.』 – Someone wise"
  "『Whatever you lose, you’ll find it again. But what you throw away you’ll never get back.』 – Kenshin"
  "『Fear is not evil. It tells you what your weakness is.』 – Gildarts, Fairy Tail"
  "『A lesson in chasing dreams: Go beyond your limits.』 – My Hero Academia"
  "『When you give up, your dreams and everything else are gone.』 – Naruto"
  "『The world isn’t perfect, but it’s there for us.』 – FMAB"
  "『An empty stomach is the best weapon.』 – One Piece"
  "『Forgetting is like a wound. The wound may heal, but it has already left a scar.』 – One Piece"
  "『To protect something, another must be sacrificed.』 – Code Geass"
  "『Being alone is not synonymous with being lonely.』 – A Silent Voice"
  "『You can’t change the past, but you can change yourself.』 – Erased"
  "『It’s not the face that makes someone a monster; it’s the choices they make.』 – Tokyo Ghoul"
  "『When you give up, that’s when the game is over.』 – Nana"
  "『You can’t sit around envying other people’s worlds.』 – My Hero Academia"
  "『When you meet someone, you never forget them.』 – Spirited Away"
)

greet_me() {
  setopt localoptions no_notify no_monitor
  local greeting quote speech_greeting ai_output ai_pid
  local venv_python="$HOME/Documents/Codes/Aetheris/AI/.venv/bin/python3"
  local tmp_file="/tmp/ai_greeting_$$"

  if [[ "$USE_AI_GREETER" == "true" ]]; then
    (
      if [[ -x "$venv_python" ]]; then
        "$venv_python" "$HOME/Documents/Codes/Aetheris/AI/modules/ai_greeter/greeter.py" > "$tmp_file" 2>/dev/null
      else
        python3 "$HOME/Documents/Codes/Aetheris/AI/modules/ai_greeter/greeter.py" > "$tmp_file" 2>/dev/null
      fi
    ) &
    ai_pid=$!
  fi

  echo
  echo -e "${CYAN}Initializing system protocols...${RESET}"
  sleep 0.15
  echo -e "${GREEN}Boot sequence complete.${RESET}"
  sleep 0.1
  echo -e "${YELLOW}Loading personal greeting module...${RESET}"
  sleep 0.1
  echo

  if [[ -n "$ai_pid" ]]; then
    local count=0
    # Wait for up to 5 seconds
    while kill -0 $ai_pid 2>/dev/null && (( count < 50 )); do
      sleep 0.1
      ((count++))
    done
    if kill -0 $ai_pid 2>/dev/null; then
      kill $ai_pid 2>/dev/null
    fi
  fi

  if [[ -f "$tmp_file" ]]; then
    ai_output=$(<"$tmp_file")
    rm -f "$tmp_file"
  fi

  if [[ -n "$ai_output" ]]; then
    greeting="$ai_output"
  else
    greeting="${welcome_messages[$RANDOM % ${#welcome_messages[@]}]}"
  fi

  speech_greeting=$(echo "$greeting" | sed 's/^[^a-zA-Z0-9]*//')
  quote="${anime_quotes[$RANDOM % ${#anime_quotes[@]}]}"

  echo -ne "${CYAN}";   typewriter "$(time_greeting) $USER." 0.005; echo -ne "${RESET}"
  typewriter "$greeting" 0.005
  echo -ne "${YELLOW}"; typewriter "Today is $(date '+%A, %d %B %Y')" 0.005; echo -ne "${RESET}"
  echo -ne "${MAGENTA}"; typewriter "🗯️  ${quote}" 0.01; echo -ne "${RESET}"
  echo

  if [[ "$ENABLE_TTS" == "true" ]]; then
    command -v say >/dev/null 2>&1 \
      && (say "$(time_greeting) $USER. $speech_greeting" &>/dev/null &)
  fi
}

toggle_ai() {
  if [[ "$USE_AI_GREETER" == "true" ]]; then
    export USE_AI_GREETER=false; echo "AI Greeter: [OFF]"
  else
    export USE_AI_GREETER=true;  echo "AI Greeter: [ON]"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# STARTUP VISUALS (Printed BEFORE p10k instant prompt so they aren't swallowed)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$TERM_PROGRAM" != "vscode" ]] && [[ -t 1 ]]; then

  # ── Figlet word art ──
  if [[ "$ENABLE_FIGLET" == "true" ]] && { [[ "$FIGLET_IN_MULTIPLEXER" == "true" ]] || { [[ -z "$TMUX" ]] && [[ -z "$ZELLIJ" ]]; } }; then
    if [[ "$FIGLET_EVERY_SESSION" == "true" ]] || _check_first_time_today "figlet"; then
      if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
        figlet -w "${COLUMNS:-$(tput cols)}" \
               -f "$HOME/.local/share/figlet-fonts/Delta_Corps_Priest_1.flf" \
               "$(hostname | tr 'a-z' 'A-Z')" 2>/dev/null | lolcat --force
      fi
    fi
  fi

  # ── System fetch ──
  if [[ "$ENABLE_FETCH" == "true" ]] && { [[ "$FETCH_IN_MULTIPLEXER" == "true" ]] || { [[ -z "$TMUX" ]] && [[ -z "$ZELLIJ" ]]; } }; then
    if [[ "$FETCH_EVERY_SESSION" == "true" ]] || _check_first_time_today "fetch"; then
      if command -v fastfetch >/dev/null 2>&1; then
        _ff_png_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/pngs"
        _ff_logo=""
        [[ -d "$_ff_png_dir" ]] && _ff_logo=$(find "$_ff_png_dir" -maxdepth 1 -name "*.png" | shuf -n 1 2>/dev/null)
        [[ -n "$_ff_logo" ]] && fastfetch --logo "$_ff_logo" || fastfetch
        unset _ff_png_dir _ff_logo
      elif command -v neofetch >/dev/null 2>&1; then
        neofetch
      fi
    fi
  fi

  # ── Greeting ──
  if [[ "$ENABLE_GREETING" == "true" ]]; then
    if [[ "$GREETING_EVERY_SESSION" == "true" ]] || _check_first_time_today "greeting"; then
      greet_me
    fi
  fi

fi

# ─────────────────────────────────────────────────────────────────────────────
# P10K INSTANT PROMPT (Must be loaded early if enabled)
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$ENABLE_P10K" == "true" ]]; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# OH-MY-ZSH
# ─────────────────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
if [[ -d "$ZSH" && -f "$ZSH/oh-my-zsh.sh" ]]; then
  
  if [[ "$ENABLE_P10K" == "true" ]]; then
    ZSH_THEME="powerlevel10k/powerlevel10k"
  else
    ZSH_THEME="$ZSH_ACTIVE_THEME"
  fi

  plugins=(
    git
    zsh-completions
    zsh-autosuggestions
    zsh-syntax-highlighting
    colored-man-pages
    history-substring-search
    extract
    sudo
    copypath
    copyfile
    copybuffer
    dirhistory
  )

  source "$ZSH/oh-my-zsh.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
# HISTORY
# ─────────────────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY APPEND_HISTORY HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS

# ─────────────────────────────────────────────────────────────────────────────
# COMPLETION
# ─────────────────────────────────────────────────────────────────────────────
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS CORRECT


# Visuals and Greetings have been moved to the top of the file.

# ─────────────────────────────────────────────────────────────────────────────
# EXTERNAL TOOLS
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$ENABLE_ZOXIDE" == "true" ]] && command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ── FZF ──
if [[ "$ENABLE_FZF" == "true" ]]; then
  if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f 2>/dev/null || find . -type f'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d 2>/dev/null || find . -type d'
    source <(fzf --zsh 2>/dev/null)
  fi
fi

# ── Pyenv ──
if [[ "$ENABLE_PYENV" == "true" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  if [[ -d "$PYENV_ROOT" ]]; then
    export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
    # Lazily initialize pyenv shell integration
    function pyenv() {
      unset -f pyenv
      eval "$(command pyenv init -)"
      pyenv "$@"
    }
  fi
fi

# ── NVM ──
if [[ "$ENABLE_NVM" == "true" ]]; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # Lazy load NVM
  function nvm node npm npx pnpm yarn {
    local cmd="$0"
    unset -f nvm node npm npx pnpm yarn
    if [ -s "$NVM_DIR/nvm.sh" ]; then
      source "$NVM_DIR/nvm.sh"
      [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    fi
    if command -v "$cmd" >/dev/null 2>&1 || typeset -f "$cmd" >/dev/null 2>&1; then
      "$cmd" "$@"
    else
      echo "zsh: command not found: $cmd"
      return 127
    fi
  }
fi

# ─────────────────────────────────────────────────────────────────────────────
# VIRTUALENV AUTO-ACTIVATION
# ─────────────────────────────────────────────────────────────────────────────
auto_venv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    if [[ "$VIRTUAL_ENV" != "$_AUTO_VENV_PATH" ]]; then
      _AUTO_VENV_PATH=""
      return
    fi
    local project_dir="${VIRTUAL_ENV%/*}"
    if [[ "$PWD/" != "$project_dir/"* ]]; then
      deactivate 2>/dev/null
      _AUTO_VENV_PATH=""
    else
      return
    fi
  fi
  if [[ -f ".venv/bin/activate" ]]; then
    source ".venv/bin/activate"
    _AUTO_VENV_PATH="$VIRTUAL_ENV"
  elif [[ -f "venv/bin/activate" ]]; then
    source "venv/bin/activate"
    _AUTO_VENV_PATH="$VIRTUAL_ENV"
  fi
}
chpwd() { auto_venv }
auto_venv  # Run once for the shell's starting directory

# ─────────────────────────────────────────────────────────────────────────────
# ALIASES & SHORTCUTS
# ─────────────────────────────────────────────────────────────────────────────

if [[ "$ENABLE_EZA" == "true" ]] && command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -l --icons --group-directories-first'
  alias la='eza -la --icons --group-directories-first'
  alias l='eza -l --icons --group-directories-first'
fi

# ── Dev ───────────────────────────────────────────────────────────────────────
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias serve='python3 -m http.server'
alias v='nvim'

# ── Git shortcuts ─────────────────────────────────────────────────────────────
alias gst='git status'
alias gaa='git add --all'
alias gcm='git commit -m'
alias gco='git checkout'
alias gp='git push'
alias gl='git pull'

# ── Anime ─────────────────────────────────────────────────────────────────────
if [[ "$ENABLE_ANIME_ALIASES" == "true" ]]; then
  alias nani='echo "NANI?! 💥 Something broke!"'
  alias senpai='sudo'
  alias sugoi='echo "✨ Sugoi desu ne~ ✨"'
  alias yamete='killall'
  alias dattebayo='echo "Believe it, dattebayo! 🍥"'
  alias ganbatte='echo "💪 Ganbatte kudasai! 💪"'
  alias omae='whoami && echo "wa mou shindeiru... 💀"'
  alias sayonara='exit'

  check_phrase() {
    local phrase="${(L)*}"
    case "$phrase" in
      "am back"|"am home"|"am here"|"is home") greet_me ;;
      *) echo "zsh: command not found: $*" ;;
    esac
  }
  alias i=check_phrase
  alias daddy=check_phrase
  alias iamback=greet_me
  alias iamhome=greet_me
  alias iamhere=greet_me
fi

# ── Personal tools ────────────────────────────────────────────────────────────
alias sayllama="$HOME/bin/sayllama"
alias nocturne="$HOME/Documents/Codes/Aetheris/AI/Nocturne/.venv/bin/python $HOME/Documents/Codes/Aetheris/AI/Nocturne/nocturne.py"
alias hello='echo "Hello! $USER....."'

# ─────────────────────────────────────────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }


killp() {
  if [[ -z "$1" ]]; then echo "Usage: killp <pattern>"; return 2; fi
  local pids
  pids=$(pgrep -if -- "$1")
  if [[ -z "$pids" ]]; then
    echo "No processes matching '$1' found."
    return 1
  fi
  echo "Terminating the following processes:"
  pgrep -ilf -- "$1" | sed 's/^/  /'
  echo "$pids" | xargs -r kill
}

missing_tools() {
  local tools=(starship fastfetch fzf zoxide pyenv figlet lolcat eza)
  local miss=()
  for t in "${tools[@]}"; do
    command -v "$t" >/dev/null 2>&1 || miss+=("$t")
  done
  if [[ ${#miss[@]} -eq 0 ]]; then
    echo "All recommended tools present."
  else
    echo "Missing tools: ${miss[*]}"
  fi
}

fetch_help() {
  echo "Install fastfetch or neofetch for a system info summary on startup."
}

# ─────────────────────────────────────────────────────────────────────────────
# PERSONAL SCRIPTS / ASSISTANTS
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$ENABLE_TTS" == "true" ]]; then
  [[ -f "$HOME/Documents/Codes/Aetheris/AI/TTS/tts_manager.sh" ]] \
    && source "$HOME/Documents/Codes/Aetheris/AI/TTS/tts_manager.sh"
fi

lunara() { (cd "$HOME/Documents/Codes/Aetheris/AI" && python3 modules/voice_assistant/main.py); }
alias aisha=lunara

# ─────────────────────────────────────────────────────────────────────────────
# SYSTEM CLEANING
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$ENABLE_SYSTEM_CLEANER" == "true" ]]; then
  decache() {
    local distro_id=""
    [[ -f /etc/os-release ]] && distro_id=$(. /etc/os-release && echo "${ID_LIKE:-$ID}")

    if [[ "$distro_id" != *arch* ]] && ! command -v pacman >/dev/null 2>&1; then
      echo "${YELLOW}⚠  decache is designed for Arch-based systems (pacman)."
      echo "   Please adapt it for your distribution's package manager.${RESET}"
      return 1
    fi

    echo "${BOLD}${MAGENTA}System Cleaning Utility  [Arch / pacman]${RESET}"

    local _avail() { df -k "$1" | awk 'NR==2 {print $4}'; }
    local root_before=$(_avail /) home_before=$(_avail "$HOME")

    echo "\n${BOLD}${CYAN}[1/5] Pacman Cache${RESET}"
    echo -n "Clear pacman package cache? [y/N]: "
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]] && sudo pacman -Sc || echo "Skipped."

    echo "\n${BOLD}${CYAN}[2/5] AUR Helper Caches${RESET}"
    local -A aur_cmds=( yay "yay -Sc"  paru "paru -Sc"  pikaur "pikaur -Sc"
                        trizen "trizen -Sc"  aura "sudo aura -Cc"  pamac "pamac clean" )
    local found_helper=false
    for bin cmd in "${(@kv)aur_cmds}"; do
      if command -v "$bin" >/dev/null 2>&1; then
        found_helper=true
        echo -n "Found '${BOLD}$bin${RESET}'. Clear its cache? [y/N]: "
        read -r reply
        [[ "$reply" =~ ^[Yy]$ ]] && eval "$cmd" || echo "Skipped $bin."
      fi
    done
    [[ "$found_helper" == false ]] && echo "No AUR helpers found."

    echo "\n${BOLD}${CYAN}[3/5] Orphaned Packages${RESET}"
    local orphans=$(pacman -Qtdq 2>/dev/null)
    if [[ -n "$orphans" ]]; then
      local count=$(echo "$orphans" | wc -l)
      echo "${YELLOW}Found $count orphaned packages.${RESET}"
      echo -n "List them? [y/N]: "
      read -r reply
      [[ "$reply" =~ ^[Yy]$ ]] && echo "$orphans" | column && echo ""
      echo -n "Remove them? [y/N]: "
      read -r reply
      if [[ "$reply" =~ ^[Yy]$ ]]; then
        echo "$orphans" | xargs sudo pacman -Rns
      else
        echo "Skipped."
      fi
    else
      echo "No orphans found."
    fi

    echo "\n${BOLD}${CYAN}[4/5] System Journal${RESET}"
    echo -n "Vacuum journal to last 1 week? [y/N]: "
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]] && sudo journalctl --vacuum-time=1weeks || echo "Skipped."

    echo "\n${BOLD}${CYAN}[5/5] User Cache (~/.cache)${RESET}"
    echo "${RED}WARNING: Deletes everything in ~/.cache — apps will rebuild caches.${RESET}"
    echo -n "Proceed? [y/N]: "
    read -r reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
      find "$HOME/.cache" -mindepth 1 -delete 2>/dev/null
      echo "Done."
    else
      echo "Skipped."
    fi

    echo "\n${BOLD}${GREEN}Cleanup Complete!${RESET}"
    local root_after=$(_avail /) home_after=$(_avail "$HOME")
    unset -f _avail

    local freed=$(( root_after - root_before ))
    local root_dev=$(df / | awk 'NR==2{print $1}')
    local home_dev=$(df "$HOME" | awk 'NR==2{print $1}')
    [[ "$root_dev" != "$home_dev" ]] && freed=$(( freed + home_after - home_before ))
    (( freed < 0 )) && freed=0

    if   (( freed > 1024 * 1024 )); then printf "${BOLD}${YELLOW}Freed: %.2f GB${RESET}\n" $(( freed / 1024.0 / 1024.0 ))
    elif (( freed > 1024 ));        then printf "${BOLD}${YELLOW}Freed: %.2f MB${RESET}\n" $(( freed / 1024.0 ))
    else                                 printf "${BOLD}${YELLOW}Freed: %d KB${RESET}\n"   $freed
    fi
  }
  alias nuke='decache'
fi

# ─────────────────────────────────────────────────────────────────────────────
# THEME SWITCHER
# ─────────────────────────────────────────────────────────────────────────────
theme() {
  local -a choices=(agnoster robbyrussell jnrowe)
  if [[ -z "$1" ]]; then
    echo "Usage: theme <name>"
    echo "Available: ${choices[*]}"
    return 1
  fi
  if (( ${choices[(Ie)$1]} )); then
    echo "$1" >| "$HOME/.zsh_theme"
    echo "Theme saved to ~/.zsh_theme. It will be loaded in new sessions."
  else
    echo "Unknown theme '$1' (p10k is toggled via ENABLE_P10K in ~/.zshrc). Available: ${choices[*]}"
    return 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# FINAL SOURCING
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$ENABLE_P10K" == "true" ]] && [[ -f "$HOME/.p10k.zsh" ]]; then
  source "$HOME/.p10k.zsh"
fi
export GTK_THEME="Colloid-Dark-Nord"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
