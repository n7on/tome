# Module loading - idempotent, searches built-in and installed locations
declare -gA _LOADED_MODULES

_require_module() {
    local ns="$1"
    [[ -v _LOADED_MODULES["$ns"] ]] && return 0
    _LOADED_MODULES["$ns"]=1

    # Search built-in modules first
    local dir="$_TOME_DIR/src/$ns"

    # Then search installed packs
    if [[ ! -d "$dir" ]]; then
        local candidate
        for candidate in "$HOME/.tome/volume"/*/src/"$ns"; do
            if [[ -d "$candidate" ]]; then
                dir="$candidate"
                break
            fi
        done
    fi

    if [[ ! -d "$dir" ]]; then
        echo "tome: module '$ns' not found (required by ${BASH_SOURCE[1]:-unknown})" >&2
        return 1
    fi

    local f
    for f in "$dir"/*.bash; do
        [[ -f "$f" ]] && source "$f"
    done
}
