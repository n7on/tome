_azure_context_dir="$HOME/.tome/azure/contexts"

_azure_account_get_subscriptions() {
    az account list --query "[].name" -o tsv 2>/dev/null | \
        _complete_filter "$(cat)" "$1"
}

_azure_context_get_names() {
    local names=()
    local dir
    for dir in "$_azure_context_dir"/*/; do
        [[ -d "$dir" ]] && names+=("$(basename "$dir")")
    done
    _complete_filter "${names[*]}" "$1"
}

azure_context_list() {
    _param_parse "$@" || return 1

    local current=""
    [[ -n "${AZURE_CONFIG_DIR:-}" ]] && current=$(basename "$AZURE_CONFIG_DIR")

    local dir
    {
        for dir in "$_azure_context_dir"/*/; do
            [[ -d "$dir" ]] || continue
            local name user active="-"
            name=$(basename "$dir")
            user=$(cat "$dir/azureProfile.json" 2>/dev/null | json_get --path 'subscriptions.0.user.name' 2>/dev/null || echo "-")
            [[ "$name" == "$current" ]] && active="*"
            printf "%s\t%s\t%s\n" "$name" "$user" "$active"
        done
    } | _output_render "name,user,active"
}

azure_context_add() {
    _requires az || return 1
    _param name --required --positional --help "Context name"
    _param_parse "$@" || return 1

    local context_path="$_azure_context_dir/$name"

    if [[ -d "$context_path" ]]; then
        _message_error "Context '$name' already exists"
        return 1
    fi

    mkdir -p "$context_path"
    AZURE_CONFIG_DIR="$context_path" az login
}

azure_context_switch() {
    _param name --required --positional --help "Context name (or 'default')"
    _param_parse "$@" || return 1

    if [[ "$name" == "default" ]]; then
        unset AZURE_CONFIG_DIR
        return 0
    fi

    local context_path="$_azure_context_dir/$name"
    if [[ ! -d "$context_path" ]]; then
        _message_error "Context '$name' not found. Use azure_context_add to create it."
        return 1
    fi

    export AZURE_CONFIG_DIR="$context_path"
}

azure_context_remove() {
    _param name --required --positional --help "Context name"
    _param_parse "$@" || return 1

    local context_path="$_azure_context_dir/$name"
    if [[ ! -d "$context_path" ]]; then
        _message_error "Context '$name' not found"
        return 1
    fi

    local current=""
    [[ -n "${AZURE_CONFIG_DIR:-}" ]] && current=$(basename "$AZURE_CONFIG_DIR")
    if [[ "$name" == "$current" ]]; then
        _message_error "Cannot remove active context '$name'. Switch away first."
        return 1
    fi

    rm -rf "$context_path"
}

_complete_params "azure_context_list" "List available Azure contexts"
_complete_params "azure_context_add" "Create a new Azure context and log in" name
_complete_params "azure_context_switch" "Switch to a named Azure context (use 'default' to restore ~/.azure)" name
_complete_func  azure_context_switch name _azure_context_get_names
_complete_params "azure_context_remove" "Remove a named Azure context" name
_complete_func  azure_context_remove name _azure_context_get_names
