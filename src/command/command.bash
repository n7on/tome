# Introspection commands for jig

# Collect all src dirs: core + installed packs
_command_src_dirs() {
    echo "$_JIG_DIR/src"
    local repo
    for repo in "$HOME/.jig/pack"/*/; do
        [[ -d "$repo/src" ]] && echo "$repo/src"
    done
}

# List all registered commands
command_list() {
    _description "List all registered jig commands"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py $(_command_src_dirs) --format list \
        | _output_render
}

# Show details of a specific command
command_show() {
    _description "Show parameters for a jig command"
    _param name --required --positional --help "Command name"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py $(_command_src_dirs) --format show --command "$name" \
        | _output_render
}

# Generate markdown documentation for all commands
command_docs() {
    _description "Generate markdown documentation for all jig commands"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py $(_command_src_dirs) --format docs --bin "jig"
}

# Generate a new command via AI and append it to an installed pack
command_ai_add() {
    _description "Generate a new jig command via AI and append it to a pack"
    _param name     --required --positional --regex "^[a-z][a-z0-9_]*$" --help "Function name, e.g. foo_bar_test"
    _param prompt   --required --help "Description of what the command should do"
    _param pack     --help "Target pack under ~/.jig/pack/ (default from ai.json)"
    _param provider --help "AI provider (default from ~/.jig/ai/ai.json)"
    _param yes      --help "Skip confirmation before writing"
    _param_parse "$@" || return 1

    _require_module "ai" || return 1

    local target_pack="$pack"
    [[ -z "$target_pack" ]] && target_pack=$(_config_get ai ai default_pack)
    if [[ -z "$target_pack" ]]; then
        _message_error "No target pack. Pass --pack or set 'default_pack' in ~/.jig/ai/ai.json"
        return 1
    fi

    local pack_dir="$HOME/.jig/pack/$target_pack"
    if [[ ! -d "$pack_dir" ]]; then
        _message_error "Pack '$target_pack' not found at $pack_dir"
        return 1
    fi

    local ns="${name%%_*}"
    local target_dir="$pack_dir/src/$ns"

    # File name follows jig's layout convention:
    #   <ns>_<action>              → <ns>.bash      (e.g. pack_install → pack.bash)
    #   <ns>_<group>_<action>...   → <group>.bash   (e.g. git_repo_list → repo.bash)
    local -a segments
    IFS='_' read -ra segments <<< "$name"
    local target_file
    if [[ ${#segments[@]} -le 2 ]]; then
        target_file="$target_dir/$ns.bash"
    else
        target_file="$target_dir/${segments[1]}.bash"
    fi

    local sys
    sys=$(_ai_prompt command add.md) || return 1

    local full_prompt
    full_prompt="$sys"$'\n\n---\n\n## Request\n\nWrite a jig command with function name `'"$name"$'`.\n\nDescription: '"$prompt"

    echo "Generating '$name' via AI..."
    local output
    output=$(_ai_run "$full_prompt" "$provider") || return 1

    local code
    code=$(awk '
        /^```bash[[:space:]]*$/ { inblock=1; next }
        /^```[[:space:]]*$/ && inblock { exit }
        inblock
    ' <<< "$output")

    if [[ -z "$code" ]]; then
        _message_error "No \`\`\`bash code block found in AI response"
        printf -- '--- full response ---\n%s\n' "$output" >&2
        return 1
    fi

    echo
    echo "--- generated ---"
    printf '%s\n' "$code"
    echo "--- end ---"
    echo
    echo "Target: $target_file"
    if [[ -f "$target_file" ]]; then
        echo "       (appending to existing file)"
    else
        echo "       (new file in pack '$target_pack')"
    fi

    if [[ "${yes:-}" != "true" ]]; then
        if [[ ! -t 0 ]]; then
            _message_error "Refusing to write without --yes when stdin is not a terminal"
            return 1
        fi
        local reply
        read -r -p "Write it? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
    fi

    mkdir -p "$target_dir"
    if [[ -f "$target_file" ]]; then
        printf '\n%s\n' "$code" >> "$target_file"
    else
        printf '%s\n' "$code" > "$target_file"
    fi

    echo "Wrote $target_file"
}

_command_ai_pack_complete() {
    local d
    for d in "$HOME/.jig/pack"/*/; do
        [[ -d "$d" ]] && basename "$d"
    done
}

# Locate the file defining a function. Searches core + all installed packs.
# Prints "<file>\t<start-line>\t<end-line>" on success, empty on failure.
_command_locate_function() {
    local name="$1"
    local -a roots=("$_JIG_DIR/src")
    local pack_dir
    for pack_dir in "$HOME/.jig/pack"/*/src; do
        [[ -d "$pack_dir" ]] && roots+=("$pack_dir")
    done

    local match
    match=$(grep -rnE "^${name}[[:space:]]*\([[:space:]]*\)[[:space:]]*\{" \
        --include="*.bash" "${roots[@]}" 2>/dev/null | head -1)
    [[ -z "$match" ]] && return 1

    local file start end
    file="${match%%:*}"
    start="${match#*:}"
    start="${start%%:*}"

    end=$(awk -v s="$start" 'NR>=s && /^\}[[:space:]]*$/ {print NR; exit}' "$file")
    [[ -z "$end" ]] && return 1

    printf '%s\t%s\t%s\n' "$file" "$start" "$end"
}

command_ai_edit() {
    _description "Modify an existing jig command via AI"
    _param name     --required --positional --regex "^[a-z][a-z0-9_]*$" --help "Function name to edit"
    _param prompt   --required --help "Description of the change"
    _param provider --help "AI provider (default from ~/.jig/ai/ai.json)"
    _param yes      --help "Skip confirmation before writing"
    _param_parse "$@" || return 1

    _require_module "ai" || return 1

    local locate
    locate=$(_command_locate_function "$name") || {
        _message_error "Function '$name' not found in any .bash file under core or installed packs"
        return 1
    }

    local target_file start end
    IFS=$'\t' read -r target_file start end <<< "$locate"

    if [[ "$target_file" == "$_JIG_DIR/"* ]]; then
        _message_warn "'$name' lives in the core jig repo ($target_file) — edits will modify core"
    fi

    local current
    current=$(awk -v s="$start" -v e="$end" 'NR>=s && NR<=e' "$target_file")

    local sys_add sys_edit
    sys_add=$(_ai_prompt command add.md) || return 1
    sys_edit=$(_ai_prompt command edit.md) || return 1

    local full_prompt
    full_prompt="$sys_add"$'\n\n---\n\n'"$sys_edit"$'\n\n---\n\n## Current function\n\n```bash\n'"$current"$'\n```\n\n## Requested change\n\n'"$prompt"

    echo "Editing '$name' in $target_file..."
    local output
    output=$(_ai_run "$full_prompt" "$provider") || return 1

    local new_code
    new_code=$(awk '
        /^```bash[[:space:]]*$/ { inblock=1; next }
        /^```[[:space:]]*$/ && inblock { exit }
        inblock
    ' <<< "$output")

    if [[ -z "$new_code" ]]; then
        _message_error "No \`\`\`bash code block found in AI response"
        printf -- '--- full response ---\n%s\n' "$output" >&2
        return 1
    fi

    echo
    echo "--- diff ---"
    diff -u --label "$name (current)" --label "$name (proposed)" \
        <(printf '%s\n' "$current") <(printf '%s\n' "$new_code") || true
    echo "--- end ---"
    echo

    if [[ "${yes:-}" != "true" ]]; then
        if [[ ! -t 0 ]]; then
            _message_error "Refusing to write without --yes when stdin is not a terminal"
            return 1
        fi
        local reply
        read -r -p "Apply this change to $target_file? [y/N] " reply
        [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
    fi

    local tmp
    tmp=$(mktemp)
    {
        [[ $start -gt 1 ]] && head -n $((start - 1)) "$target_file"
        printf '%s\n' "$new_code"
        tail -n +$((end + 1)) "$target_file"
    } > "$tmp" && mv "$tmp" "$target_file"

    echo "Updated $target_file (lines $start–$end replaced)"
}

_complete_params "command_list"
_complete_params "command_show" "name"
_complete_params "command_docs"
_complete_type   "command_ai_add" action
_complete_params "command_ai_add" "name" "prompt" "pack" "provider" "yes"
_complete_func   "command_ai_add" "pack" _command_ai_pack_complete
_complete_type   "command_ai_edit" action
_complete_params "command_ai_edit" "name" "prompt" "provider" "yes"

_command_show_complete() {
    # Load all namespaces to get the full command list
    local ns_dir ns
    for ns_dir in "$_JIG_DIR/src"/*/; do
        ns="$(basename "$ns_dir")"
        [[ "$ns" == _* ]] && continue
        _require_module "$ns" 2>/dev/null
    done
    for _vol in "$HOME/.jig/pack"/*/; do
        [[ -d "$_vol/src" ]] || continue
        for ns_dir in "$_vol/src"/*/; do
            ns="$(basename "$ns_dir")"
            [[ "$ns" == _* ]] && continue
            _require_module "$ns" 2>/dev/null
        done
    done

    local names="" _cmd
    local -A seen
    for _key in "${!_PARAMS[@]}"; do
        _cmd="${_key%%:*}"
        [[ -v seen[$_cmd] ]] && continue
        [[ "$_cmd" == _* ]] && continue
        seen[$_cmd]=1
        names+="$_cmd "
    done
    _complete_filter "$names" "$1"
}
_complete_func "command_show" "name" _command_show_complete
_complete_func "command_ai_edit" "name" _command_show_complete
