entra_app_list() {
    _grim_command_requires az jq || return 1
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
    local perm_map
    perm_map=$(jq '(.scopes + .roles) | map({(.id): .value}) | add // {}' <<< "$graph_sp")

    jq -r \
        --argjson permMap "$perm_map" '
        .[] | [
            .displayName,
            .appId,
            ([ .requiredResourceAccess[].resourceAccess[] |
                $permMap[.id] // .id
            ] | join(","))
        ] | @tsv
    ' <<< "$apps" | _grim_command_output_render "NAME,CLIENT_ID,PERMISSIONS"
}

entra_permission_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Microsoft Graph OAuth permission scopes"
    _grim_command_param name --positional --help "Filter by name (partial match)"
    _grim_command_param type --help "Filter by type (delegated, application)"
    _grim_command_param_parse "$@" || return 1

    local graph_sp
    graph_sp=$(_grim_command_exec az ad sp show --id "00000003-0000-0000-c000-000000000000" --output json) || {
        _grim_message_error "Failed to fetch Microsoft Graph service principal"
        return 1
    }

    local filter_name="${name:-}"
    local filter_type="${type:-}"

    jq -r --arg name "$filter_name" --arg type "$filter_type" '
        ([ .oauth2PermissionScopes[] | {value, description: (.adminConsentDescription // "-"), type: "delegated"} ] +
         [ .appRoles[]               | {value, description: (.description // "-"), type: "application"} ])
        | .[]
        | select($name == "" or (.value | ascii_downcase | contains($name | ascii_downcase)))
        | select($type == "" or .type == $type)
        | [.value, .type, .description]
        | @tsv
    ' <<< "$graph_sp" \
        | sort \
        | _grim_command_output_render "PERMISSION,TYPE,DESCRIPTION"
}

_grim_command_complete_params entra_app_list
_grim_command_complete_params "entra_permission_list" "name" "type"
_grim_command_complete_values "entra_permission_list" "type" "delegated" "application"
