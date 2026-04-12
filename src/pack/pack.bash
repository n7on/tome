_PACK_DIR="$HOME/.rig/pack"

_pack_install_dir() {
    local name="$1" url="$2" dest="$3"

    # Clone to a temp location first so we can check for conflicts
    local tmp
    tmp=$(mktemp -d)
    _exec git clone "$url" "$tmp/$name" || { rm -rf "$tmp"; return 1; }

    # Check for namespace conflicts with built-ins and other installed packs
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
        for existing in "$_PACK_DIR"/*/src/"$ns"; do
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

    mv "$tmp/$name" "$dest"
    rm -rf "$tmp"

    if [[ -f "$dest/requirements.txt" ]]; then
        echo "Installing Python dependencies for $name..."
        "$HOME/.rig/.venv/bin/pip" install --quiet --disable-pip-version-check \
            -r "$dest/requirements.txt"
    fi
}

pack_install() {
    _description "Install a pack from a git repository"
    _requires git || return 1
    _param url --required --positional --help "Git repository URL"
    _param_parse "$@" || return 1

    local name
    name="$(basename "$url" .git)"
    local dest="$_PACK_DIR/$name"

    if [[ -d "$dest" ]]; then
        _message_error "Pack '$name' is already installed. Use 'rig pack update $name' to update."
        return 1
    fi

    mkdir -p "$_PACK_DIR"
    _pack_install_dir "$name" "$url" "$dest" || return 1

    _config_append "pack" "packs" "$(json_build "name=$name" "url=$url")"
    _message_warn "Installed: $name"
}

pack_list() {
    _description "List installed packs and their namespaces"
    _param_parse "$@" || return 1

    {
        # Built-in namespaces
        local ns_dir ns
        for ns_dir in "$_RIG_DIR/src"/*/; do
            ns="$(basename "$ns_dir")"
            [[ "$ns" == _* ]] && continue
            printf "%s\t%s\n" "$ns" "built-in"
        done

        # Installed packs
        local pack_dir pack_name
        for pack_dir in "$_PACK_DIR"/*/; do
            [[ -d "$pack_dir/src" ]] || continue
            pack_name="$(basename "$pack_dir")"
            for ns_dir in "$pack_dir/src"/*/; do
                ns="$(basename "$ns_dir")"
                [[ "$ns" == _* ]] && continue
                printf "%s\t%s\n" "$ns" "$pack_name"
            done
        done
    } | _output_render "namespace,pack"
}

pack_remove() {
    _description "Remove an installed pack"
    _param name --required --positional --help "Pack name"
    _param_parse "$@" || return 1

    local dest="$_PACK_DIR/$name"
    if [[ ! -d "$dest" ]]; then
        _message_error "Pack '$name' not found in $_PACK_DIR"
        return 1
    fi

    rm -rf "$dest"
    _config_remove "pack" "packs" "name" "$name"
    _message_warn "Removed: $name"
}

pack_update() {
    _description "Update an installed pack"
    _requires git || return 1
    _param name --positional --help "Pack name to update (omit for all)"
    _param_parse "$@" || return 1

    local targets=()
    if [[ -n "$name" ]]; then
        [[ -d "$_PACK_DIR/$name" ]] || { _message_error "Pack '$name' not found"; return 1; }
        targets=("$_PACK_DIR/$name")
    else
        local d
        for d in "$_PACK_DIR"/*/; do
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
        if _exec git -C "$dir" pull --quiet; then
            if [[ -f "$dir/requirements.txt" ]]; then
                "$HOME/.rig/.venv/bin/pip" install --quiet --disable-pip-version-check \
                    -r "$dir/requirements.txt"
            fi
            _message_warn "Updated: $n"
        fi
    done
}

_complete_type "pack_install" action
_complete_params "pack_install" "url"
_complete_params "pack_list"
_complete_type "pack_remove" action
_complete_params "pack_remove" "name"
_complete_type "pack_update" action
_complete_params "pack_update" "name"
