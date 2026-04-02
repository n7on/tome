
# Fetch all pages from a Graph API endpoint, returning a single JSON array
_entra_get_all() {
    local url="$1"
    local all="[]"
    local page next

    while [[ -n "$url" ]]; do
        page=$(az rest --method GET --url "$url" 2>/dev/null) || {
            _grim_message_error "Failed to fetch $url"
            return 1
        }
        all=$(jq -n --argjson all "$all" --argjson page "$page" '$all + $page.value')
        next=$(jq -r '."@odata.nextLink" // empty' <<< "$page")
        url="$next"
    done

    echo "$all"
}

entra_license() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Entra license information"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_grim_command_exec _entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1

    echo "$result" \
        | jq -r '.[] | [.skuPartNumber, (.consumedUnits | tostring), (.prepaidUnits.enabled | tostring), .capabilityStatus] | @tsv' \
        | _grim_command_output_render "SKU,CONSUMED,ENABLED,STATUS"
}

entra_license_plan_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List service plans across all subscribed Entra SKUs"
    _grim_command_param sku    --help "Filter by SKU name (partial match)"
    _grim_command_param status --help "Filter by provisioning status (e.g. Success, Disabled)"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_grim_command_exec _entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1

    [[ -n "$sku" ]]    && result=$(jq --arg v "$sku"    '[.[] | select(.skuPartNumber | ascii_downcase | contains($v | ascii_downcase))]' <<< "$result")
    [[ -n "$status" ]] && result=$(jq --arg v "$status" '[.[] | select(.servicePlans[].provisioningStatus | ascii_downcase == ($v | ascii_downcase))]' <<< "$result")

    echo "$result" \
        | jq -r '.[] | . as $sku | .servicePlans[] | [$sku.skuPartNumber, .servicePlanName, .provisioningStatus, .appliesTo] | @tsv' \
        | _grim_command_output_render "SKU,PLAN,STATUS,APPLIES_TO"
}

# Register completions
_grim_command_complete_params "entra_license"
_grim_command_complete_params "entra_license_plan_list" "sku" "status"
_grim_command_complete_values "entra_license_plan_list" "status" "Success" "Disabled" "PendingInput" "PendingProvisioning"
