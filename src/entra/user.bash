entra_user_list() {
    _description "List Entra users with license and MFA info"
    _requires az || return 1
    _param odata_filter --positional --help "OData filter expression"
    _param_parse "$@" || return 1

    local user_url="https://graph.microsoft.com/v1.0/users?\$select=displayName,userPrincipalName,assignedLicenses,accountEnabled"
    if [[ -n "$odata_filter" ]]; then
        local encoded
        encoded=$("$_RIG_PYTHON" -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$odata_filter")
        user_url+="&\$filter=$encoded"
    fi

    local skus users mfa
    skus=$(_exec _entra_get_all "https://graph.microsoft.com/v1.0/subscribedSkus") || return 1
    users=$(_exec _entra_get_all "$user_url") || return 1
    mfa=$(_exec _entra_get_all "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?\$select=userPrincipalName,isMfaRegistered") || return 1

    _exec_python entra user_list.py "$users" "$skus" "$mfa" \
        | _output_render
}

_complete_params "entra_user_list" "odata_filter"
