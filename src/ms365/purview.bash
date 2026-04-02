
ms365_purview_slabel_list() {
    _grim_command_requires jq || return 1
    _grim_command_description "List Purview sensitive information labels"
    _grim_command_param name   --help "Filter by name (partial match)"
    _grim_command_param parent --help "Filter to sublabels of the given parent label name"
    _grim_command_param scope  --help "Filter by scope (file, email, site, unifiedGroup)"
    _grim_command_param active --help "Filter by active status (true/false)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels") || return 1

    result=$(jq -r '.value' <<< "$result")

    [[ -n "$name" ]]   && result=$(jq --arg v "$name"   '[.[] | select(.name | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$parent" ]] && result=$(jq --arg v "$parent" '[.[] | select(.parent.name? | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$scope" ]]  && result=$(jq --arg v "$scope"  '[.[] | select(.contentFormats[]? | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")
    [[ -n "$active" ]] && result=$(jq --argjson v "$active" '[.[] | select(.isActive == $v)]' <<< "$result")

    echo "$result" \
        | jq -r '.[] | [.name, (.parent.name? // "-"), (.isActive | tostring), ([.contentFormats[]?] | join(",")), .id] | @tsv' \
        | _grim_command_output_render "NAME,PARENT,ACTIVE,SCOPE,ID"
}

ms365_purview_slabel_show() {
    _grim_command_requires jq || return 1
    _grim_command_description "Show details of a Purview sensitive information label"
    _grim_command_param name --required --positional --help "Label name (exact match)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels") || return 1

    local label
    label=$(jq --arg v "$name" '.value[] | select(.name | ascii_downcase == ($v | ascii_downcase))' <<< "$result")
    [[ -z "$label" ]] && { _grim_message_error "Label '$name' not found"; return 1; }

    echo "$label" \
        | jq -r 'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' \
        | _grim_command_output_render "FIELD,VALUE"
}

ms365_purview_slabel_add() {
    _grim_command_requires jq || return 1
    _grim_command_description "Create a new Purview sensitive information label"
    _grim_command_param name        --required --positional --help "Label display name"
    _grim_command_param description --help "Label description"
    _grim_command_param tooltip     --help "Tooltip shown to users"
    _grim_command_param color       --help "Label color as hex (e.g. #FF0000)"
    _grim_command_param parent      --help "Parent label name (makes this a sublabel)"
    _grim_command_param_parse "$@" || return 1

    local body
    body=$(jq -n \
        --arg name        "$name" \
        --arg description "$description" \
        --arg tooltip     "$tooltip" \
        --arg color       "$color" \
        '{
            name: $name,
            description: (if $description != "" then $description else null end),
            tooltip:     (if $tooltip     != "" then $tooltip     else null end),
            color:       (if $color       != "" then $color       else null end)
        } | with_entries(select(.value != null))')

    if [[ -n "$parent" ]]; then
        local labels parent_id
        labels=$(_ms365_graph_get "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels") || return 1
        parent_id=$(jq -r --arg v "$parent" '.value[] | select(.name | ascii_downcase == ($v | ascii_downcase)) | .id' <<< "$labels")
        [[ -z "$parent_id" ]] && { _grim_message_error "Parent label '$parent' not found"; return 1; }
        body=$(jq --arg pid "$parent_id" '.parentId = $pid' <<< "$body")
    fi

    local result
    result=$(_ms365_graph_post \
        "https://graph.microsoft.com/beta/security/informationProtection/sensitivityLabels" \
        "$body") || return 1

    echo "$result" \
        | jq -r 'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' \
        | _grim_command_output_render "FIELD,VALUE"
}

ms365_purview_rlabel_list() {
    _grim_command_requires jq || return 1
    _grim_command_description "List Purview retention labels"
    _grim_command_param name    --help "Filter by display name (partial match)"
    _grim_command_param trigger --help "Filter by retention trigger (dateLabeled, dateCreated, dateModified, dateOfEvent)"
    _grim_command_param action  --help "Filter by action after retention (none, delete, permanentlyDelete, startDispositionReview)"
    _grim_command_param in_use  --help "Filter by in-use status (true/false)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_ms365_graph_get "https://graph.microsoft.com/v1.0/security/labels/retentionLabels") || return 1

    result=$(jq '.value' <<< "$result")

    [[ -n "$name" ]]    && result=$(jq --arg v "$name"   '[.[] | select(.displayName | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$trigger" ]] && result=$(jq --arg v "$trigger" '[.[] | select(.retentionTrigger | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")
    [[ -n "$action" ]]  && result=$(jq --arg v "$action"  '[.[] | select(.actionAfterRetentionPeriod | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")
    [[ -n "$in_use" ]]  && result=$(jq --argjson v "$in_use" '[.[] | select(.isInUse == $v)]' <<< "$result")

    echo "$result" \
        | jq -r '.[] | [.displayName, (.retentionDuration.days? // "-" | tostring), (.retentionTrigger // "-"), (.actionAfterRetentionPeriod // "-"), (.isInUse | tostring), .id] | @tsv' \
        | _grim_command_output_render "NAME,DURATION_DAYS,TRIGGER,ACTION,IN_USE,ID"
}

ms365_purview_rlabel_show() {
    _grim_command_requires jq || return 1
    _grim_command_description "Show details of a Purview retention label"
    _grim_command_param name --required --positional --help "Label display name (exact match)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_ms365_graph_get "https://graph.microsoft.com/v1.0/security/labels/retentionLabels") || return 1

    local label
    label=$(jq --arg v "$name" '.value[] | select(.displayName | ascii_downcase == ($v | ascii_downcase))' <<< "$result")
    [[ -z "$label" ]] && { _grim_message_error "Retention label '$name' not found"; return 1; }

    echo "$label" \
        | jq -r 'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' \
        | _grim_command_output_render "FIELD,VALUE"
}

ms365_purview_rlabel_add() {
    _grim_command_requires jq || return 1
    _grim_command_description "Create a new Purview retention label"
    _grim_command_param name               --required --positional --help "Label display name"
    _grim_command_param duration           --help "Retention period in days"
    _grim_command_param trigger            --help "Retention trigger (dateLabeled, dateCreated, dateModified, dateOfEvent)"
    _grim_command_param action             --help "Action after retention (none, delete, permanentlyDelete, startDispositionReview)"
    _grim_command_param description_admins --help "Description for admins"
    _grim_command_param description_users  --help "Description for users"
    _grim_command_param_parse "$@" || return 1

    local body
    body=$(jq -n \
        --arg name               "$name" \
        --arg trigger            "$trigger" \
        --arg action             "$action" \
        --arg description_admins "$description_admins" \
        --arg description_users  "$description_users" \
        '{
            displayName:                (if $name               != "" then $name               else null end),
            retentionTrigger:           (if $trigger            != "" then $trigger            else null end),
            actionAfterRetentionPeriod: (if $action             != "" then $action             else null end),
            descriptionForAdmins:       (if $description_admins != "" then $description_admins else null end),
            descriptionForUsers:        (if $description_users  != "" then $description_users  else null end)
        } | with_entries(select(.value != null))')

    if [[ -n "$duration" ]]; then
        body=$(jq --argjson days "$duration" \
            '.retentionDuration = {"@odata.type": "#microsoft.graph.security.retentionDurationInDays", "days": $days}' <<< "$body")
    fi

    local result
    result=$(_ms365_graph_post \
        "https://graph.microsoft.com/v1.0/security/labels/retentionLabels" \
        "$body") || return 1

    echo "$result" \
        | jq -r 'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' \
        | _grim_command_output_render "FIELD,VALUE"
}

# Register completions
_grim_command_complete_params "ms365_purview_slabel_list" "name" "parent" "scope" "active"
_grim_command_complete_values "ms365_purview_slabel_list" "scope" "file" "email" "site" "unifiedGroup"
_grim_command_complete_values "ms365_purview_slabel_list" "active" "true" "false"
_grim_command_complete_params "ms365_purview_slabel_show" "name"
_grim_command_complete_params "ms365_purview_slabel_add" "name" "description" "tooltip" "color" "parent"
_grim_command_complete_params "ms365_purview_rlabel_list" "name" "trigger" "action" "in_use"
_grim_command_complete_values "ms365_purview_rlabel_list" "trigger" "dateLabeled" "dateCreated" "dateModified" "dateOfEvent"
_grim_command_complete_values "ms365_purview_rlabel_list" "action" "none" "delete" "permanentlyDelete" "startDispositionReview"
_grim_command_complete_values "ms365_purview_rlabel_list" "in_use" "true" "false"
_grim_command_complete_params "ms365_purview_rlabel_show" "name"
_grim_command_complete_params "ms365_purview_rlabel_add" "name" "duration" "trigger" "action" "description_admins" "description_users"
_grim_command_complete_values "ms365_purview_rlabel_add" "trigger" "dateLabeled" "dateCreated" "dateModified" "dateOfEvent"
_grim_command_complete_values "ms365_purview_rlabel_add" "action" "none" "delete" "permanentlyDelete" "startDispositionReview"
