entra_app_list() {
    _grim_command_requires az || return 1
    _grim_command_description "List Entra app registrations with their permissions"
    _grim_command_param_parse "$@" || return 1

    local apps
    apps=$(_grim_command_exec az ad app list --all --output json) || {
        _grim_message_error "Failed to list app registrations"
        return 1
    }

    # Build permission GUID -> name map from Microsoft Graph (delegated + app roles)
    local graph_sp
    graph_sp=$(_grim_command_exec az ad sp show --id "00000003-0000-0000-c000-000000000000" \
        --query "{scopes:oauth2PermissionScopes[].{id:id,value:value},roles:appRoles[].{id:id,value:value}}" \
        --output json) || {
        _grim_message_error "Failed to fetch Microsoft Graph permissions"
        return 1
    }

    _grim_command_exec_python entra app_list.py "$apps" "$graph_sp" \
        | _grim_command_output_render
}

entra_permission_list() {
    _grim_command_requires az || return 1
    _grim_command_description "List Microsoft Graph OAuth permission scopes"
    _grim_command_param_parse "$@" || return 1

    local graph_sp
    graph_sp=$(_grim_command_exec az ad sp show --id "00000003-0000-0000-c000-000000000000" --output json) || {
        _grim_message_error "Failed to fetch Microsoft Graph service principal"
        return 1
    }

    echo "$graph_sp" \
        | _grim_command_exec_python entra permission_list.py \
        | _grim_command_output_render
}

_grim_command_complete_params entra_app_list
_grim_command_complete_params "entra_permission_list"
