# Cache management for tome commands
_CACHE_DIR="${HOME}/.tome/.cache"

# Generate a cache key from arguments
# Usage: _cache_key "func_name" "arg1" "arg2"
_cache_key() {
    local IFS=$'\x1f'
    if command -v md5sum &>/dev/null; then
        echo -n "$*" | md5sum | cut -d' ' -f1
    else
        echo -n "$*" | md5
    fi
}

# Wrap a command with caching support
# Usage: _cache_wrap <ttl> command arg1 arg2
_CACHE_DEFAULT_TTL=300

_cache_wrap() {
    local cache_ttl="${1:-0}"
    shift

    # --cache without a value is parsed as "true"; use default TTL
    [[ "$cache_ttl" == "true" ]] && cache_ttl="$_CACHE_DEFAULT_TTL"

    if [[ "$cache_ttl" -le 0 ]]; then
        "$@"
        return
    fi

    local key
    key=$(_cache_key "${FUNCNAME[2]}" "$@")
    local cache_file="${_CACHE_DIR}/${key}"

    mkdir -p "$_CACHE_DIR"

    if [[ -f "$cache_file" ]]; then
        local mtime
        if stat --version &>/dev/null; then
            mtime=$(stat -c %Y "$cache_file")
        else
            mtime=$(stat -f%m "$cache_file")
        fi
        local age=$(( $(date +%s) - mtime ))
        if (( age < cache_ttl )); then
            cat "$cache_file"
            return 0
        fi
    fi

    local output rc
    output=$("$@")
    rc=$?

    if [[ $rc -eq 0 && -n "$output" ]]; then
        echo "$output" > "$cache_file"
    fi
    echo "$output"
    return "$rc"
}
