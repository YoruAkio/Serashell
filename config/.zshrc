# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
fpath=("$HOME/.grok/completions/zsh" $fpath)

# Set name of the theme to load --- if set to "random", it will
ZSH_THEME="agnoster"

# Which plugins would you like to load?
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
# alias ls="ls -l"
alias ls="exa -l --git --icons --group-directories-first"
alias ll="ls -al"
alias la="ls -a"
alias h="history"
alias cls="clear"
alias c="codium"
alias zconf="micro ~/.zshrc"
alias cd="z"
alias wcc="warp-cli connect"
alias wdc="warp-cli disconnect"
alias zc="zeroclaw"
alias claude="claude --dangerously-skip-permissions"
alias codex="codex --dangerously-bypass-approvals-and-sandbox"
alias agent="agent --yolo"
alias zed="zeditor"
alias oc="opencode --auto"

# tmux
alias tmn="tmux new -s"
alias tma="tmux attach -t"
alias tmd="tmux detach"

# starship
eval "$(starship init zsh)"

# zoxide
eval "$(zoxide init zsh)"

# starship config
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# bun completions
[ -s "/home/akio/.bun/_bun" ] && source "/home/akio/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# go binary
# export PATH=$PATH:$(go env GOPATH)/bin

# android studio
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
# export QT_QPA_PLATFORM=xcb
export CAPACITOR_ANDROID_STUDIO_PATH=/opt/android-studio/bin/studio

# opencode, local/bin
export PATH=/home/akio/.opencode/bin:/home/akio/.local/bin:$PATH

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# rust
. "$HOME/.cargo/env"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
# <<< grok installer <<<
