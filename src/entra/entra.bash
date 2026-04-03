
# Fetch all pages from a Graph API endpoint, returning a single JSON array
_entra_get_all() {
    local url="$1"
    local all="[]"
    local page result

    while [[ -n "$url" ]]; do
        page=$(az rest --method GET --url "$url" 2>/dev/null) || {
            _grim_message_error "Failed to fetch $url"
            return 1
        }
        result=$(echo "$page" | _grim_command_exec_python entra paginate.py "$all")
        all=$(echo "$result" | head -1)
        url=$(echo "$result" | tail -1)
    done

    echo "$all"
}

entra_license() {
    _grim_command_requires az || return 1
    _grim_command_description "List Entra license information"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_grim_command_exec _entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1

    echo "$result" \
        | json_tsv --path '.' --fields 'sku=skuPartNumber,consumed=consumedUnits,enabled=prepaidUnits.enabled,status=capabilityStatus' \
        | _grim_command_output_render
}

entra_license_plan_list() {
    _grim_command_requires az || return 1
    _grim_command_description "List service plans across all subscribed Entra SKUs"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_grim_command_exec _entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1

    echo "$result" \
        | _grim_command_exec_python entra license_plans.py \
        | _grim_command_output_render
}

# Register completions
_grim_command_complete_params "entra_license"
_grim_command_complete_params "entra_license_plan_list"
