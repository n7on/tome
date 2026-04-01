
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
    result=$(_entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1

    _grim_command_output_set "SKU,CONSUMED,ENABLED,STATUS" \
        '.[] | [.skuPartNumber, (.consumedUnits | tostring), (.prepaidUnits.enabled | tostring), .capabilityStatus] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

# Register completions
_grim_command_complete_params "entra_license"
