# Display piped input in a tmux popup or pane

# Pipe input into a floating tmux popup
# Usage: some_command | tmux_popup
#        some_command | tmux_popup --title "My Output" --width 80% --height 60%
tmux_popup() {
    _grim_command_requires tmux || return 1
    _grim_command_description "Display piped input in a floating tmux popup"
    _grim_command_param title --default "grim" --help "Popup title"
    _grim_command_param width --default "80%" --help "Popup width (columns or percentage)"
    _grim_command_param height --default "60%" --help "Popup height (rows or percentage)"
    _grim_command_param_parse "$@" || return 1

    local tmp
    tmp=$(mktemp)
    cat > "$tmp"

    if [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        _grim_message_warn "No input to display"
        return 1
    fi

    tmux display-popup -T " $title " -w "$width" -h "$height" -E "less -R < '$tmp'; rm -f '$tmp'"
}

# Pipe input into a tmux split pane
# Usage: some_command | tmux_pane
#        some_command | tmux_pane --size 40% --horizontal
tmux_pane() {
    _grim_command_requires tmux || return 1
    _grim_command_description "Display piped input in a tmux split pane"
    _grim_command_param size --default "40%" --help "Pane size (rows/columns or percentage)"
    _grim_command_param horizontal --help "Split horizontally instead of vertically"
    _grim_command_param_parse "$@" || return 1

    local tmp
    tmp=$(mktemp)
    cat > "$tmp"

    if [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        _grim_message_warn "No input to display"
        return 1
    fi

    local cmd=(tmux split-window -l "$size")
    [[ "$horizontal" == "true" ]] && cmd+=(-h)
    cmd+=("less -R < '$tmp'; rm -f '$tmp'")

    "${cmd[@]}"
}

_grim_command_complete_params "tmux_popup" "title" "width" "height"
_grim_command_complete_params "tmux_pane" "size" "horizontal"
