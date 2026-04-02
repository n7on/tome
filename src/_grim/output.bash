# Output formatting for command results
# Supports: table, json, tsv, raw
#
# Usage: echo "$tsv_data" | _grim_command_output_render "COL1,COL2,COL3"

_grim_command_output_render() {
    local headers="$1"
    local format="${output_format:-table}"

    if [[ "$format" == "raw" ]]; then
        cat
        return
    fi

    case "$format" in
        json|tsv|table) ;;
        *) _grim_message_error "Invalid output format: $format (expected: raw, json, tsv, table)"; return 1 ;;
    esac

    local data
    data=$(cat)

    if [[ -z "$data" ]]; then
        _grim_message_warn "No results found"
        return 0
    fi

    local -a args=(--headers "$headers" --format "$format")
    local term_width=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    args+=(--width "$term_width")

    [[ -n "${filter:-}" ]] && args+=(--filter "$filter")
    [[ -n "${sort:-}" ]]   && args+=(--sort "$sort")
    [[ -n "${select:-}" ]] && args+=(--select "$select")
    [[ -n "${limit:-}" ]]  && args+=(--limit "$limit")

    local _python="${_GRIM_PYTHON:-python3}"
    echo "$data" | "$_python" "$_GRIM_DIR/src/_grim/python/render.py" "${args[@]}"
}
