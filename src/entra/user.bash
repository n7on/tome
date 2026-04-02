entra_user_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Entra users with license and MFA info"
    _grim_command_param filter --positional --help "OData filter expression"
    _grim_command_param_parse "$@" || return 1

    local user_url="https://graph.microsoft.com/v1.0/users?\$select=displayName,userPrincipalName,assignedLicenses,accountEnabled"
    [[ -n "$filter" ]] && user_url+="&\$filter=$(jq -rn --arg s "$filter" '$s | @uri')"

    local skus users mfa
    skus=$(_grim_command_exec _entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1
    users=$(_grim_command_exec _entra_get_all "$user_url") || return 1
    mfa=$(_grim_command_exec _entra_get_all "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?\$select=userPrincipalName,isMfaRegistered") || return 1

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

    echo "$result" | _grim_command_output_render "NAME,UPN,ACCOUNT,MFA,LICENSES"
}

_grim_command_complete_params "entra_user_list" "filter"
