if not test -e ~/.config/starship.toml
    set -gx STARSHIP_CONFIG /usr/share/crownos/starship.toml
end
starship init fish | source

function neofetch
    set -l themed ~/.config/fastfetch/crownos.jsonc
    if set -q KITTY_WINDOW_ID; and not set -q TMUX; and test -r $themed
        fastfetch --config $themed $argv
    else
        fastfetch $argv
    end
end

alias benchmark=hyperfine

if fish_is_root_user
    zoxide init fish | source
else if status is-interactive
    zoxide init fish --cmd cd | source
    alias ls='eza --tree --level=1 --icons=auto --group-directories-first'
    alias cat='bat --paging=never'
    alias find=fd
    alias grep=rg
end

if status is-interactive
    for editor in vim vi
        command -q $editor; or alias $editor=nvim
    end
    for monitor in top htop
        command -q $monitor; or alias $monitor=btop
    end
end

function y
    set tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"
    if read -z cwd <"$tmp"; and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
