
ms365_purview_slabel_list() {
    _param_parse "$@" || return 1

    _ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels" \
        | json_tsv --path 'value' --fields 'name,parent=parent.name,active=isActive,scope=contentFormats,id' \
        | _output_render
}

ms365_purview_slabel_show() {
    _param name --required --positional --help "Label name (exact match)"
    _param_parse "$@" || return 1

    local result label_id
    result=$(_ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels") || return 1

    label_id=$(echo "$result" | json_find --path 'value' --where 'name' --equals "$name" --return 'id')
    [[ -z "$label_id" ]] && { _message_error "Label '$name' not found"; return 1; }

    _ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels/$label_id" \
        | json_kv \
        | _output_render
}

ms365_purview_slabel_add() {
    _param name        --required --positional --help "Label display name"
    _param description --help "Label description"
    _param tooltip     --help "Tooltip shown to users"
    _param color       --help "Label color as hex (e.g. #FF0000)"
    _param parent      --help "Parent label name (makes this a sublabel)"
    _param_parse "$@" || return 1

    local body
    body=$(json_build "name=$name" "description=$description" "tooltip=$tooltip" "color=$color")

    if [[ -n "$parent" ]]; then
        local labels parent_id
        labels=$(_ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels") || return 1
        parent_id=$(echo "$labels" | json_find --path 'value' --where 'name' --equals "$parent" --return 'id')
        [[ -z "$parent_id" ]] && { _message_error "Parent label '$parent' not found"; return 1; }
        body=$(json_build --base "$body" "parentId=$parent_id")
    fi

    _ms365_graph_post \
        "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels" \
        "$body" \
        | json_kv \
        | _output_render
}

ms365_purview_rlabel_list() {
    _param_parse "$@" || return 1

    _ms365_graph_get "https://graph.microsoft.com/v1.0/security/labels/retentionLabels" \
        | json_tsv --path 'value' --fields 'name=displayName,duration_days=retentionDuration.days,trigger=retentionTrigger,action=actionAfterRetentionPeriod,in_use=isInUse,id' \
        | _output_render
}

ms365_purview_rlabel_show() {
    _param name --required --positional --help "Label display name (exact match)"
    _param_parse "$@" || return 1

    local result label_id
    result=$(_ms365_graph_get "https://graph.microsoft.com/v1.0/security/labels/retentionLabels") || return 1

    label_id=$(echo "$result" | json_find --path 'value' --where 'displayName' --equals "$name" --return 'id')
    [[ -z "$label_id" ]] && { _message_error "Retention label '$name' not found"; return 1; }

    _ms365_graph_get "https://graph.microsoft.com/v1.0/security/labels/retentionLabels/$label_id" \
        | json_kv \
        | _output_render
}

ms365_purview_rlabel_add() {
    _param name               --required --positional --help "Label display name"
    _param duration           --help "Retention period in days"
    _param trigger            --help "Retention trigger (dateLabeled, dateCreated, dateModified, dateOfEvent)"
    _param action             --help "Action after retention (none, delete, permanentlyDelete, startDispositionReview)"
    _param description_admins --help "Description for admins"
    _param description_users  --help "Description for users"
    _param_parse "$@" || return 1

    local body
    body=$(json_build \
        "displayName=$name" \
        "retentionTrigger=$trigger" \
        "actionAfterRetentionPeriod=$action" \
        "descriptionForAdmins=$description_admins" \
        "descriptionForUsers=$description_users")

    if [[ -n "$duration" ]]; then
        body=$(json_build --base "$body" \
            "json:retentionDuration={\"@odata.type\": \"#microsoft.graph.security.retentionDurationInDays\", \"days\": $duration}")
    fi

    _ms365_graph_post \
        "https://graph.microsoft.com/v1.0/security/labels/retentionLabels" \
        "$body" \
        | json_kv \
        | _output_render
}

# Register completions
_complete_params "ms365_purview_slabel_list" "List Purview sensitive information labels"
_complete_params "ms365_purview_slabel_show" "Show details of a Purview sensitive information label" "name"
_complete_params "ms365_purview_slabel_add" "Create a new Purview sensitive information label" "name" "description" "tooltip" "color" "parent"
_complete_params "ms365_purview_rlabel_list" "List Purview retention labels"
_complete_params "ms365_purview_rlabel_show" "Show details of a Purview retention label" "name"
_complete_params "ms365_purview_rlabel_add" "Create a new Purview retention label" "name" "duration" "trigger" "action" "description_admins" "description_users"
_complete_values "ms365_purview_rlabel_add" "trigger" "dateLabeled" "dateCreated" "dateModified" "dateOfEvent"
_complete_values "ms365_purview_rlabel_add" "action" "none" "delete" "permanentlyDelete" "startDispositionReview"
