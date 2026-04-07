entra_app_list() {
    _requires az || return 1
    _param_parse "$@" || return 1

    local apps
    apps=$(_exec az ad app list --all --output json) || {
        _message_error "Failed to list app registrations"
        return 1
    }

    # Build permission GUID -> name map from Microsoft Graph (delegated + app roles)
    local graph_sp
    graph_sp=$(_exec az ad sp show --id "00000003-0000-0000-c000-000000000000" \
        --query "{scopes:oauth2PermissionScopes[].{id:id,value:value},roles:appRoles[].{id:id,value:value}}" \
        --output json) || {
        _message_error "Failed to fetch Microsoft Graph permissions"
        return 1
    }

    _exec_python entra app_list.py "$apps" "$graph_sp" \
        | _output_render
}

entra_permission_list() {
    _requires az || return 1
    _param_parse "$@" || return 1

    local graph_sp
    graph_sp=$(_exec az ad sp show --id "00000003-0000-0000-c000-000000000000" --output json) || {
        _message_error "Failed to fetch Microsoft Graph service principal"
        return 1
    }

    echo "$graph_sp" \
        | _exec_python entra permission_list.py \
        | _output_render
}

_complete_params "entra_app_list" "List Entra app registrations with their permissions"
_complete_params "entra_permission_list" "List Microsoft Graph OAuth permission scopes"
