
# Fetch all pages from a Graph API endpoint, returning a single JSON array
_azure_entra_get_all() {
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

azure_entra_license() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Azure Entra license information"
    _grim_command_param_parse "$@" || return 1

    local result
    result=$(_azure_entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1

    _grim_command_output_set "SKU,CONSUMED,ENABLED,STATUS" \
        '.[] | [.skuPartNumber, (.consumedUnits | tostring), (.prepaidUnits.enabled | tostring), .capabilityStatus] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

azure_entra_user_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Azure Entra users with license and MFA info"
    _grim_command_param filter --positional --help "OData filter expression"
    _grim_command_param_parse "$@" || return 1

    local user_url="https://graph.microsoft.com/v1.0/users?\$select=displayName,userPrincipalName,assignedLicenses,accountEnabled"
    [[ -n "$filter" ]] && user_url+="&\$filter=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$filter")"

    local skus users mfa
    skus=$(_azure_entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1
    users=$(_azure_entra_get_all "$user_url") || return 1
    mfa=$(_azure_entra_get_all "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?\$select=userPrincipalName,isMfaRegistered") || return 1

    local result
    result=$(jq -rn \
        --argjson skus "$skus" \
        --argjson users "$users" \
        --argjson mfa "$mfa" '
        ($skus | map({(.skuId): .skuPartNumber}) | add // {}) as $skuMap |
        ($mfa | map({(.userPrincipalName): .isMfaRegistered}) | add // {}) as $mfaMap |
        $users[] |
        [
            .displayName,
            .userPrincipalName,
            (if .accountEnabled then "enabled" else "disabled" end),
            (if $mfaMap[.userPrincipalName] == true then "yes" else "no" end),
            (if (.assignedLicenses | length) == 0 then "none"
             else [.assignedLicenses[].skuId | $skuMap[.] // "unknown"] | join(",") end)
        ] | @tsv
    ') || return 1

    _grim_command_output_set "NAME,UPN,ACCOUNT,MFA,LICENSES" '{print}' awk
    echo "$result" | _grim_command_output_render
}

# Register completions
_grim_command_complete_params "azure_entra_license"
_grim_command_complete_params "azure_entra_user_list" "filter"
