_GRIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_GRIM_PYTHON="$_GRIM_DIR/.venv/bin/python3"

# Source grim utilities first (dependencies)
for _grim_file in "$_GRIM_DIR/src/_grim"/*.bash; do
    source "$_grim_file"
done

# Source command modules from core and any GRIM_PATH entries
_grim_load_modules() {
    local _grim_src="$1"
    for _grim_dir in "$_grim_src"/*; do
        [[ -d "$_grim_dir" && "$(basename "$_grim_dir")" != "_grim" ]] || continue
        for _grim_file in "$_grim_dir"/*.bash; do
            [[ -f "$_grim_file" ]] && source "$_grim_file"
        done
    done
}

_grim_load_modules "$_GRIM_DIR/src"

if [[ -n "${GRIM_PATH:-}" ]]; then
    IFS=: read -ra _grim_paths <<< "$GRIM_PATH"
    for _grim_path in "${_grim_paths[@]}"; do
        [[ -d "$_grim_path" ]] && _grim_load_modules "$_grim_path"
    done
    unset _grim_paths _grim_path
fi

unset -f _grim_load_modules

# Source user extensions from ~/.grim/
for _grim_file in "$HOME/.grim"/*.bash; do
    [[ -f "$_grim_file" ]] && source "$_grim_file"
done

unset _grim_dir _grim_file
