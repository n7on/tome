# Output formatting for command results
# Supports: table, json, tsv, raw
#
# Usage: echo "$tsv_data" | _output_render "COL1,COL2,COL3"

_output_render() {
    local headers="${1:-}"
    local format="${output:-table}"

    if [[ "$format" == "raw" ]]; then
        cat
        return
    fi

    case "$format" in
        json|tsv|table|md) ;;
        *) _message_error "Invalid output format: $format (expected: raw, json, tsv, table, md)"; return 1 ;;
    esac

    local data
    data=$(cat)

    # If no headers argument, read from first line of data
    if [[ -z "$headers" ]]; then
        headers="${data%%$'\n'*}"
        data="${data#*$'\n'}"
    fi

    if [[ -z "$data" ]]; then
        _message_warn "No results found"
        return 0
    fi

    local -a args=(--headers "$headers" --format "$format")
    local term_width=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    args+=(--width "$term_width")

    [[ -n "${filter:-}" ]] && args+=(--filter "$filter")
    [[ -n "${sort:-}" ]]   && args+=(--sort "$sort")
    [[ -n "${select:-}" ]] && args+=(--select "$select")
    [[ -n "${limit:-}" ]]  && args+=(--limit "$limit")

    local _python="${_TOME_PYTHON:-python3}"
    echo "$data" | "$_python" "$_TOME_DIR/src/_output/python/render.py" "${args[@]}"
}
