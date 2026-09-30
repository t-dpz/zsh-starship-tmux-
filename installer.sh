#!/usr/bin/env bash
#
# setup-terminal.sh — Zsh + Starship + Tmux with a HackTheBox-style theme
#
# HTB palette:
#   Node black   #141d2b   (background)
#   Deep navy    #1a2332   (surfaces)
#   Hacker green #9fef00   (primary accent)
#   Hacker grey  #a4b1cd   (text)
#   Aquamarine   #2ee7b6
#   Azure        #0086ff
#   Nugget       #ffaf00
#   Vivid purple #9f00ff
#   Malware red  #ff3e3e
#
# Safe to re-run: existing configs are backed up, .zshrc is only touched once.

set -euo pipefail

GREEN=$'\e[38;2;159;239;0m'; GREY=$'\e[38;2;164;177;205m'; RESET=$'\e[0m'
step() { echo "${GREEN}[$1]${RESET} ${GREY}$2${RESET}"; }

backup() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"
    fi
}

echo "${GREEN}=== HTB Terminal Environment Setup ===${RESET}"

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
step "1/5" "Installing zsh, tmux, curl, unzip and zsh plugins..."
sudo apt update
sudo apt install -y zsh tmux curl unzip iproute2 ncurses-term \
    zsh-autosuggestions zsh-syntax-highlighting

# ---------------------------------------------------------------------------
# 2. Default shell
# ---------------------------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
step "2/5" "Setting zsh as default shell for $USER..."
if [ "${SHELL:-}" != "$ZSH_PATH" ]; then
    sudo chsh -s "$ZSH_PATH" "$USER"
fi

# ---------------------------------------------------------------------------
# 3. Starship
# ---------------------------------------------------------------------------
step "3/5" "Installing and theming Starship..."
if ! command -v starship >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

mkdir -p "$HOME/.config"
backup "$HOME/.config/starship.toml"

cat << 'EOF' > "$HOME/.config/starship.toml"
# HackTheBox-style prompt
#  ┌──[user@host]─[~/path] on ⎇ main [!?] [vpn 10.10.14.x]
#  └──╼ ❯
add_newline = true

format = '''
[┌──\[](bold #9fef00)$username[@](#a4b1cd)$hostname[\]─\[](bold #9fef00)$directory[\]](bold #9fef00)$git_branch$git_status$python$docker_context${custom.vpn}$cmd_duration$status
[└──╼ ](bold #9fef00)$character'''

[username]
show_always = true
style_user  = "bold #9fef00"
style_root  = "bold #ff3e3e"
format      = "[$user]($style)"

[hostname]
ssh_only   = false
ssh_symbol = "🌐 "
style      = "bold #2ee7b6"
format     = "[$ssh_symbol$hostname]($style)"

[directory]
style             = "bold #0086ff"
read_only         = " 🔒"
read_only_style   = "#ff3e3e"
truncation_length = 4
truncate_to_repo  = false
format            = "[$path]($style)[$read_only]($read_only_style)"

[git_branch]
symbol = "⎇ "
style  = "bold #9f00ff"
format = ' [on](#a4b1cd) [$symbol$branch]($style)'

[git_status]
style  = "bold #ffaf00"
format = '( [\[$all_status$ahead_behind\]]($style))'

[python]
symbol = "py "
style  = "#ffaf00"
format = ' [$symbol$version( \($virtualenv\))]($style)'

[docker_context]
symbol = "docker "
style  = "#0086ff"
format = ' [$symbol$context]($style)'

# Shows your HTB VPN address (tun0) when connected
[custom.vpn]
command = "ip -4 -o addr show tun0 | awk '{print $4}' | cut -d/ -f1"
when    = "ip link show tun0 >/dev/null 2>&1"
shell   = ["bash", "--noprofile", "--norc"]
style   = "bold #9fef00"
format  = ' [\[vpn $output\]]($style)'

[cmd_duration]
min_time = 2000
style    = "#a4b1cd"
format   = ' [took $duration]($style)'

[status]
disabled = false
style    = "bold #ff3e3e"
format   = ' [✘ $status]($style)'

[character]
success_symbol = "[❯](bold #9fef00)"
error_symbol   = "[❯](bold #ff3e3e)"
vimcmd_symbol  = "[❮](bold #2ee7b6)"
EOF

# ---------------------------------------------------------------------------
# 4. Zsh
# ---------------------------------------------------------------------------
step "4/5" "Writing HTB zsh config..."
mkdir -p "$HOME/.config/zsh"
backup "$HOME/.config/zsh/htb.zsh"

cat << 'EOF' > "$HOME/.config/zsh/htb.zsh"
# ---- HTB zsh theme (managed by setup-terminal.sh) ----

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history inc_append_history hist_ignore_dups hist_ignore_space
setopt autocd interactive_comments no_beep

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# Colors for ls / completion — HTB accents on top of dircolors defaults
eval "$(dircolors -b)"
export LS_COLORS="${LS_COLORS}:di=1;38;2;159;239;0:ln=38;2;46;231;182:ex=1;38;2;255;175;0:or=1;38;2;255;62;62"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format $'%{\e[1;38;2;159;239;0m%}-- %d --%{\e[0m%}'

# Keybindings (emacs mode, ctrl+arrows, prefix history search)
bindkey -e
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ip='ip -c'
alias vpnip="ip -4 -o addr show tun0 2>/dev/null | awk '{print \$4}' | cut -d/ -f1"

# Autosuggestions
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#4f5d75'
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Prompt
eval "$(starship init zsh)"

# Syntax highlighting (must be sourced last)
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_STYLES[command]='fg=#9fef00'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=#9fef00'
    ZSH_HIGHLIGHT_STYLES[function]='fg=#9fef00'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=#2ee7b6'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=#2ee7b6,underline'
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#9f00ff'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff3e3e,bold'
    ZSH_HIGHLIGHT_STYLES[path]='fg=#a4b1cd,underline'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#0086ff'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffaf00'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffaf00'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#ffaf00'
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#a4b1cd'
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#a4b1cd'
    ZSH_HIGHLIGHT_STYLES[comment]='fg=#4f5d75'
fi
EOF

touch "$HOME/.zshrc"
if ! grep -q 'config/zsh/htb.zsh' "$HOME/.zshrc"; then
    backup "$HOME/.zshrc"
    # Drop a bare starship init from an earlier run; htb.zsh handles it now
    sed -i '/^eval "\$(starship init zsh)"$/d' "$HOME/.zshrc"
    printf '\n# HTB theme\n[ -f "$HOME/.config/zsh/htb.zsh" ] && source "$HOME/.config/zsh/htb.zsh"\n' >> "$HOME/.zshrc"
fi

# ---------------------------------------------------------------------------
# 5. Tmux
# ---------------------------------------------------------------------------
step "5/5" "Writing HTB tmux config..."
backup "$HOME/.tmux.conf"

cat << 'EOF' > "$HOME/.tmux.conf"
# ---- General ----
set -g mouse on
set -s escape-time 10                     # fixes ^[[>0;10;1c bleed
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc" # truecolor passthrough
set -g default-shell "$SHELL"
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g focus-events on
setw -g mode-keys vi

# ---- Keys ----
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
bind c new-window -c "#{pane_current_path}"
bind r source-file ~/.tmux.conf \; display "config reloaded"
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel

# ---- HTB theme ----
set -g status-position bottom
set -g status-interval 5
set -g status-style "bg=#141d2b,fg=#a4b1cd"

set -g status-left-length 40
set -g status-left "#[bg=#9fef00,fg=#141d2b,bold] #S #[bg=#141d2b,fg=#9fef00] "

set -g status-right-length 80
set -g status-right '#[fg=#9fef00]#(ip -4 -o addr show tun0 2>/dev/null | awk "{print \$4}" | cut -d/ -f1 | sed "s/^/vpn /") #[fg=#4f5d75]│ #[fg=#2ee7b6]#(whoami)@#H #[fg=#4f5d75]│ #[fg=#ffaf00]%Y-%m-%d %H:%M '

setw -g window-status-format "#[fg=#a4b1cd] #I:#W "
setw -g window-status-current-format "#[bg=#1a2332,fg=#9fef00,bold] #I:#W#{?window_zoomed_flag, [Z],} "
setw -g window-status-separator ""
setw -g window-status-activity-style "fg=#ffaf00"
setw -g window-status-bell-style "fg=#ff3e3e,bold"

set -g pane-border-style "fg=#2a3a52"
set -g pane-active-border-style "fg=#9fef00"
set -g display-panes-active-colour "#9fef00"
set -g display-panes-colour "#a4b1cd"

set -g message-style "bg=#9fef00,fg=#141d2b,bold"
set -g message-command-style "bg=#1a2332,fg=#9fef00"
setw -g mode-style "bg=#9fef00,fg=#141d2b"
setw -g clock-mode-colour "#9fef00"
EOF

# Reload tmux if a server is already running
if tmux info >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf" || true
fi

echo ""
echo "${GREEN}=== Setup Complete! ===${RESET}"
echo "${GREY}To apply changes:${RESET}"
echo "  1. Log out and back in (or run 'zsh') to enter your new shell."
echo "  2. Start tmux with 'tmux' (prefix + r reloads config)."
echo "  3. Set your terminal background to #141d2b for the full effect."
echo "  Old configs were backed up as *.bak.<timestamp>."