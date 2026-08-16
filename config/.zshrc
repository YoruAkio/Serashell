export ZSH="$HOME/.oh-my-zsh"

DISABLE_AUTO_UPDATE="true"
# Skip magic function bindings you likely don't use (bracketed paste fixups etc).
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_UPDATE_PROMPT="true"

ZSH_THEME=""

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='micro'
else
  export EDITOR='micro'
fi

# Set personal aliases, overriding those provided by Oh My Zsh libs,
alias ff="fastfetch"
alias sudo='sudo --prompt="[🔒] password for %p: "'
alias ls="exa -l --git --icons --group-directories-first"
alias ll="ls -al"
alias la="ls -a"
alias c="codium"
alias cd="z"
alias wcc="warp-cli connect"
alias wdc="warp-cli disconnect"
alias claude="claude --dangerously-skip-permissions"
alias codex="codex --dangerously-bypass-approvals-and-sandbox"
alias agent="agent --yolo"

# tmux
alias tmn="tmux new -s"
alias tma="tmux attach -t"
alias tmd="tmux detach"
alias tmr="tmux source-file ~/.tmux.conf"

# starship config (must be set before starship init picks it up)
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

if [ -s "$HOME/.cache/starship-init.zsh" ]; then
  source "$HOME/.cache/starship-init.zsh"
elif command -v starship >/dev/null 2>&1; then
  mkdir -p "$HOME/.cache"
  starship init zsh > "$HOME/.cache/starship-init.zsh"
  source "$HOME/.cache/starship-init.zsh"
fi

if [ -s "$HOME/.cache/zoxide-init.zsh" ]; then
  source "$HOME/.cache/zoxide-init.zsh"
elif command -v zoxide >/dev/null 2>&1; then
  mkdir -p "$HOME/.cache"
  zoxide init zsh > "$HOME/.cache/zoxide-init.zsh"
  source "$HOME/.cache/zoxide-init.zsh"
fi

# bun completions
[ -s "/home/akio/.bun/_bun" ] && source "/home/akio/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
lazynvm() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { lazynvm; nvm "$@"; }
node() { lazynvm; node "$@"; }
npm()  { lazynvm; npm "$@"; }
npx()  { lazynvm; npx "$@"; }

# Added by Antigravity CLI installer
export PATH="/home/akio/.local/bin:$PATH"
