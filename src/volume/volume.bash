_VOLUME_DIR="$HOME/.tome/volume"

volume_install() {
    _description "Install a volume from a git repository"
    _requires git || return 1
    _param url --required --positional --help "Git repository URL"
    _param_parse "$@" || return 1

    local name
    name="$(basename "$url" .git)"
    local dest="$_VOLUME_DIR/$name"

    if [[ -d "$dest" ]]; then
        _message_error "Volume '$name' is already installed. Use 'tome volume update $name' to update."
        return 1
    fi

    # Clone to a temp location first so we can check for conflicts
    local tmp
    tmp=$(mktemp -d)
    _exec git clone "$url" "$tmp/$name" || { rm -rf "$tmp"; return 1; }

    # Check for namespace conflicts with built-ins and other installed volumes
    local conflicts=()
    local ns_dir ns
    for ns_dir in "$tmp/$name/src"/*/; do
        [[ -d "$ns_dir" ]] || continue
        ns="$(basename "$ns_dir")"
        [[ "$ns" == _* ]] && continue
        if [[ -d "$_TOME_DIR/src/$ns" ]]; then
            conflicts+=("$ns (built-in)")
            continue
        fi
        local existing
        for existing in "$_VOLUME_DIR"/*/src/"$ns"; do
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

    mkdir -p "$_VOLUME_DIR"
    mv "$tmp/$name" "$dest"
    rm -rf "$tmp"
    _message_warn "Installed: $name"
}

volume_list() {
    _description "List installed volumes and their namespaces"
    _param_parse "$@" || return 1

    # Built-in namespaces
    local ns_dir ns
    for ns_dir in "$_TOME_DIR/src"/*/; do
        ns="$(basename "$ns_dir")"
        [[ "$ns" == _* ]] && continue
        printf "%s\t%s\n" "$ns" "built-in"
    done

    # Installed volumes
    local vol_dir vol_name
    for vol_dir in "$_VOLUME_DIR"/*/; do
        [[ -d "$vol_dir/src" ]] || continue
        vol_name="$(basename "$vol_dir")"
        for ns_dir in "$vol_dir/src"/*/; do
            ns="$(basename "$ns_dir")"
            [[ "$ns" == _* ]] && continue
            printf "%s\t%s\n" "$ns" "$vol_name"
        done
    done | _output_render "namespace,volume"
}

volume_remove() {
    _description "Remove an installed volume"
    _param name --required --positional --help "Volume name"
    _param_parse "$@" || return 1

    local dest="$_VOLUME_DIR/$name"
    if [[ ! -d "$dest" ]]; then
        _message_error "Volume '$name' not found in $_VOLUME_DIR"
        return 1
    fi

    rm -rf "$dest"
    _message_warn "Removed: $name"
}

volume_update() {
    _description "Update an installed volume"
    _requires git || return 1
    _param name --positional --help "Volume name to update (omit for all)"
    _param_parse "$@" || return 1

    local targets=()
    if [[ -n "$name" ]]; then
        [[ -d "$_VOLUME_DIR/$name" ]] || { _message_error "Volume '$name' not found"; return 1; }
        targets=("$_VOLUME_DIR/$name")
    else
        local d
        for d in "$_VOLUME_DIR"/*/; do
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

_complete_type "volume_install" action
_complete_params "volume_install" "url"
_complete_params "volume_list"
_complete_type "volume_remove" action
_complete_params "volume_remove" "name"
_complete_type "volume_update" action
_complete_params "volume_update" "name"
