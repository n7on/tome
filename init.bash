_TOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TOME_PYTHON="$_TOME_DIR/.venv/bin/python3"

# Source tome utilities first (all _* dirs, in sorted order)
for _tome_dir in "$_TOME_DIR/src"/_*/; do
    for _tome_file in "$_tome_dir"*.bash; do
        [[ -f "$_tome_file" ]] && source "$_tome_file"
    done
done

# Source command modules from core and any TOME_PATH entries
_tome_load_modules() {
    local _tome_src="$1"
    for _tome_dir in "$_tome_src"/*; do
        [[ -d "$_tome_dir" && "$(basename "$_tome_dir")" != _* ]] || continue
        for _tome_file in "$_tome_dir"/*.bash; do
            [[ -f "$_tome_file" ]] && source "$_tome_file"
        done
    done
}

_tome_load_modules "$_TOME_DIR/src"

if [[ -n "${TOME_PATH:-}" ]]; then
    IFS=: read -ra _tome_paths <<< "$TOME_PATH"
    for _tome_path in "${_tome_paths[@]}"; do
        [[ -d "$_tome_path" ]] && _tome_load_modules "$_tome_path"
    done
    unset _tome_paths _tome_path
fi

unset -f _tome_load_modules

# Source user extensions from ~/.tome/
for _tome_file in "$HOME/.tome"/*.bash; do
    [[ -f "$_tome_file" ]] && source "$_tome_file"
done

unset _tome_dir _tome_file
