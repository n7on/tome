_azure_context_dir="$HOME/.grim/azure/contexts"

_azure_account_get_subscriptions() {
    az account list --query "[].name" -o tsv 2>/dev/null | \
        _grim_command_complete_filter "$(cat)" "$1"
}

_azure_context_get_names() {
    local names=()
    local dir
    for dir in "$_azure_context_dir"/*/; do
        [[ -d "$dir" ]] && names+=("$(basename "$dir")")
    done
    _grim_command_complete_filter "${names[*]}" "$1"
}

azure_context_list() {
    _grim_command_description "List available Azure contexts"
    _grim_command_param_parse "$@" || return 1

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
    } | _grim_command_output_render "name,user,active"
}

azure_context_add() {
    _grim_command_requires az || return 1
    _grim_command_description "Create a new Azure context and log in"
    _grim_command_param name --required --positional --help "Context name"
    _grim_command_param_parse "$@" || return 1

    local context_path="$_azure_context_dir/$name"

    if [[ -d "$context_path" ]]; then
        _grim_message_error "Context '$name' already exists"
        return 1
    fi

    mkdir -p "$context_path"
    AZURE_CONFIG_DIR="$context_path" az login
}

azure_context_switch() {
    _grim_command_description "Switch to a named Azure context (use 'default' to restore ~/.azure)"
    _grim_command_param name --required --positional --help "Context name (or 'default')"
    _grim_command_param_parse "$@" || return 1

    if [[ "$name" == "default" ]]; then
        unset AZURE_CONFIG_DIR
        return 0
    fi

    local context_path="$_azure_context_dir/$name"
    if [[ ! -d "$context_path" ]]; then
        _grim_message_error "Context '$name' not found. Use azure_context_add to create it."
        return 1
    fi

    export AZURE_CONFIG_DIR="$context_path"
}

azure_context_remove() {
    _grim_command_description "Remove a named Azure context"
    _grim_command_param name --required --positional --help "Context name"
    _grim_command_param_parse "$@" || return 1

    local context_path="$_azure_context_dir/$name"
    if [[ ! -d "$context_path" ]]; then
        _grim_message_error "Context '$name' not found"
        return 1
    fi

    local current=""
    [[ -n "${AZURE_CONFIG_DIR:-}" ]] && current=$(basename "$AZURE_CONFIG_DIR")
    if [[ "$name" == "$current" ]]; then
        _grim_message_error "Cannot remove active context '$name'. Switch away first."
        return 1
    fi

    rm -rf "$context_path"
}

_grim_command_complete_params azure_context_list
_grim_command_complete_params azure_context_add name
_grim_command_complete_params azure_context_switch name
_grim_command_complete_func  azure_context_switch name _azure_context_get_names
_grim_command_complete_params azure_context_remove name
_grim_command_complete_func  azure_context_remove name _azure_context_get_names
