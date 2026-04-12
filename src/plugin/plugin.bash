_PLUGIN_DIR="$HOME/.rig/plugin"

plugin_install() {
    _description "Install a plugin from a git repository"
    _requires git || return 1
    _param url --required --positional --help "Git repository URL"
    _param_parse "$@" || return 1

    local name
    name="$(basename "$url" .git)"
    local dest="$_PLUGIN_DIR/$name"

    if [[ -d "$dest" ]]; then
        _message_error "Plugin '$name' is already installed. Use 'rig plugin update $name' to update."
        return 1
    fi

    # Clone to a temp location first so we can check for conflicts
    local tmp
    tmp=$(mktemp -d)
    _exec git clone "$url" "$tmp/$name" || { rm -rf "$tmp"; return 1; }

    # Check for namespace conflicts with built-ins and other installed plugins
    local conflicts=()
    local ns_dir ns
    for ns_dir in "$tmp/$name/src"/*/; do
        [[ -d "$ns_dir" ]] || continue
        ns="$(basename "$ns_dir")"
        [[ "$ns" == _* ]] && continue
        if [[ -d "$_RIG_DIR/src/$ns" ]]; then
            conflicts+=("$ns (built-in)")
            continue
        fi
        local existing
        for existing in "$_PLUGIN_DIR"/*/src/"$ns"; do
            if [[ -d "$existing" ]]; then
                conflicts+=("$ns ($(basename "$(dirname "$(dirname "$existing")")")")
                break
            fi
        done
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        rm -rf "$tmp"
        _message_error "Namespace conflicts: ${conflicts[*]}"
        return 1
    fi

    mkdir -p "$_PLUGIN_DIR"
    mv "$tmp/$name" "$dest"
    rm -rf "$tmp"
    _message_warn "Installed: $name"
}

plugin_list() {
    _description "List installed plugins and their namespaces"
    _param_parse "$@" || return 1

    # Built-in namespaces
    local ns_dir ns
    for ns_dir in "$_RIG_DIR/src"/*/; do
        ns="$(basename "$ns_dir")"
        [[ "$ns" == _* ]] && continue
        printf "%s\t%s\n" "$ns" "built-in"
    done

    # Installed plugins
    local plugin_dir plugin_name
    for plugin_dir in "$_PLUGIN_DIR"/*/; do
        [[ -d "$plugin_dir/src" ]] || continue
        plugin_name="$(basename "$plugin_dir")"
        for ns_dir in "$plugin_dir/src"/*/; do
            ns="$(basename "$ns_dir")"
            [[ "$ns" == _* ]] && continue
            printf "%s\t%s\n" "$ns" "$plugin_name"
        done
    done | _output_render "namespace,plugin"
}

plugin_remove() {
    _description "Remove an installed plugin"
    _param name --required --positional --help "Plugin name"
    _param_parse "$@" || return 1

    local dest="$_PLUGIN_DIR/$name"
    if [[ ! -d "$dest" ]]; then
        _message_error "Plugin '$name' not found in $_PLUGIN_DIR"
        return 1
    fi

    rm -rf "$dest"
    _message_warn "Removed: $name"
}

plugin_update() {
    _description "Update an installed plugin"
    _requires git || return 1
    _param name --positional --help "Plugin name to update (omit for all)"
    _param_parse "$@" || return 1

    local targets=()
    if [[ -n "$name" ]]; then
        [[ -d "$_PLUGIN_DIR/$name" ]] || { _message_error "Plugin '$name' not found"; return 1; }
        targets=("$_PLUGIN_DIR/$name")
    else
        local d
        for d in "$_PLUGIN_DIR"/*/; do
            [[ -d "$d" ]] && targets+=("$d")
        done
    fi

    local dir n
    for dir in "${targets[@]}"; do
        n="$(basename "$dir")"
        if [[ ! -d "$dir/.git" ]]; then
            _message_error "'$n' is not a git repository"
            continue
        fi
        _exec git -C "$dir" pull --quiet && _message_warn "Updated: $n"
    done
}

_complete_type "plugin_install" action
_complete_params "plugin_install" "url"
_complete_params "plugin_list"
_complete_type "plugin_remove" action
_complete_params "plugin_remove" "name"
_complete_type "plugin_update" action
_complete_params "plugin_update" "name"
