
azure_purview_slabel_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Purview sensitive information labels"
    _grim_command_param name   --help "Filter by name (partial match)"
    _grim_command_param parent --help "Filter to sublabels of the given parent label name"
    _grim_command_param scope  --help "Filter by scope (file, email, site, unifiedGroup)"
    _grim_command_param active --help "Filter by active status (true/false)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/security/informationProtection/sensitivityLabels" \
        2>/dev/null) || { _grim_message_error "Failed to fetch sensitivity labels"; return 1; }

    result=$(jq -r '.value' <<< "$result")

    [[ -n "$name" ]]   && result=$(jq --arg v "$name"   '[.[] | select(.name | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$parent" ]] && result=$(jq --arg v "$parent" '[.[] | select(.parent.name? | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$scope" ]]  && result=$(jq --arg v "$scope"  '[.[] | select(.contentFormats[]? | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")
    [[ -n "$active" ]] && result=$(jq --argjson v "$active" '[.[] | select(.isActive == $v)]' <<< "$result")

    _grim_command_output_set "NAME,PARENT,ACTIVE,SCOPE,ID" \
        '.[] | [.name, (.parent.name? // "-"), (.isActive | tostring), ([.contentFormats[]?] | join(",")), .id] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

azure_purview_slabel_show() {
    _grim_command_requires az jq || return 1
    _grim_command_description "Show details of a Purview sensitive information label"
    _grim_command_param name --required --positional --help "Label name (exact match)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/security/informationProtection/sensitivityLabels" \
        2>/dev/null) || { _grim_message_error "Failed to fetch sensitivity labels"; return 1; }

    local label
    label=$(jq --arg v "$name" '.value[] | select(.name | ascii_downcase == ($v | ascii_downcase))' <<< "$result")
    [[ -z "$label" ]] && { _grim_message_error "Label '$name' not found"; return 1; }

    _grim_command_output_set "FIELD,VALUE" \
        'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' jq

    echo "$label" | _grim_command_output_render
}

azure_purview_slabel_add() {
    _grim_command_requires az jq || return 1
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
        labels=$(az rest --method GET \
            --url "https://graph.microsoft.com/v1.0/security/informationProtection/sensitivityLabels" \
            2>/dev/null) || { _grim_message_error "Failed to fetch labels for parent lookup"; return 1; }
        parent_id=$(jq -r --arg v "$parent" '.value[] | select(.name | ascii_downcase == ($v | ascii_downcase)) | .id' <<< "$labels")
        [[ -z "$parent_id" ]] && { _grim_message_error "Parent label '$parent' not found"; return 1; }
        body=$(jq --arg pid "$parent_id" '.parentId = $pid' <<< "$body")
    fi

    local result
    result=$(az rest --method POST \
        --url "https://graph.microsoft.com/v1.0/security/informationProtection/sensitivityLabels" \
        --body "$body" \
        2>/dev/null) || { _grim_message_error "Failed to create label '$name'"; return 1; }

    _grim_command_output_set "FIELD,VALUE" \
        'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

azure_purview_rlabel_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Purview retention labels"
    _grim_command_param name    --help "Filter by display name (partial match)"
    _grim_command_param trigger --help "Filter by retention trigger (dateLabeled, dateCreated, dateModified, dateOfEvent)"
    _grim_command_param action  --help "Filter by action after retention (none, delete, permanentlyDelete, startDispositionReview)"
    _grim_command_param in_use  --help "Filter by in-use status (true/false)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/security/labels/retentionLabels" \
        2>/dev/null) || { _grim_message_error "Failed to fetch retention labels"; return 1; }

    result=$(jq '.value' <<< "$result")

    [[ -n "$name" ]]    && result=$(jq --arg v "$name"   '[.[] | select(.displayName | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$trigger" ]] && result=$(jq --arg v "$trigger" '[.[] | select(.retentionTrigger | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")
    [[ -n "$action" ]]  && result=$(jq --arg v "$action"  '[.[] | select(.actionAfterRetentionPeriod | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")
    [[ -n "$in_use" ]]  && result=$(jq --argjson v "$in_use" '[.[] | select(.isInUse == $v)]' <<< "$result")

    _grim_command_output_set "NAME,DURATION_DAYS,TRIGGER,ACTION,IN_USE,ID" \
        '.[] | [.displayName, (.retentionDuration.days? // "-" | tostring), (.retentionTrigger // "-"), (.actionAfterRetentionPeriod // "-"), (.isInUse | tostring), .id] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

azure_purview_rlabel_show() {
    _grim_command_requires az jq || return 1
    _grim_command_description "Show details of a Purview retention label"
    _grim_command_param name --required --positional --help "Label display name (exact match)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/security/labels/retentionLabels" \
        2>/dev/null) || { _grim_message_error "Failed to fetch retention labels"; return 1; }

    local label
    label=$(jq --arg v "$name" '.value[] | select(.displayName | ascii_downcase == ($v | ascii_downcase))' <<< "$result")
    [[ -z "$label" ]] && { _grim_message_error "Retention label '$name' not found"; return 1; }

    _grim_command_output_set "FIELD,VALUE" \
        'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' jq

    echo "$label" | _grim_command_output_render
}

azure_purview_rlabel_add() {
    _grim_command_requires az jq || return 1
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
    result=$(az rest --method POST \
        --url "https://graph.microsoft.com/v1.0/security/labels/retentionLabels" \
        --body "$body" \
        2>/dev/null) || { _grim_message_error "Failed to create retention label '$name'"; return 1; }

    _grim_command_output_set "FIELD,VALUE" \
        'to_entries[] | [.key, (.value | if type == "array" then join(", ") elif type == "object" then tojson else tostring end)] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

# Register completions
_grim_command_complete_params "azure_purview_slabel_list" "name" "parent" "scope" "active"
_grim_command_complete_values "azure_purview_slabel_list" "scope" "file" "email" "site" "unifiedGroup"
_grim_command_complete_values "azure_purview_slabel_list" "active" "true" "false"
_grim_command_complete_params "azure_purview_slabel_show" "name"
_grim_command_complete_params "azure_purview_slabel_add" "name" "description" "tooltip" "color" "parent"
_grim_command_complete_params "azure_purview_rlabel_list" "name" "trigger" "action" "in_use"
_grim_command_complete_values "azure_purview_rlabel_list" "trigger" "dateLabeled" "dateCreated" "dateModified" "dateOfEvent"
_grim_command_complete_values "azure_purview_rlabel_list" "action" "none" "delete" "permanentlyDelete" "startDispositionReview"
_grim_command_complete_values "azure_purview_rlabel_list" "in_use" "true" "false"
_grim_command_complete_params "azure_purview_rlabel_show" "name"
_grim_command_complete_params "azure_purview_rlabel_add" "name" "duration" "trigger" "action" "description_admins" "description_users"
_grim_command_complete_values "azure_purview_rlabel_add" "trigger" "dateLabeled" "dateCreated" "dateModified" "dateOfEvent"
_grim_command_complete_values "azure_purview_rlabel_add" "action" "none" "delete" "permanentlyDelete" "startDispositionReview"
