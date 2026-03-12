
_ms_ado_app_id="499b84ac-1321-427f-aa17-267ca6975798"

ms_ado_download_latest_feed_package() {
    _grim_command_requires jq az || return 1
    
    _grim_command_init \
        package \
        path=. \
        feed="$AZURE_DEVOPS_FEED_NAME" \
        organization="$AZURE_DEVOPS_ORGANIZATION"
    _grim_command_parse "$@"
    
    _grim_command_validate package --required || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds/$feed/packages?packageNameQuery=$package&protocolType=upack&api-version=7.1-preview.1"
    local pkg
    local version

    _grim_log_info "downloading artifacts from feed: $feed..."

    pkg=$(az rest --method GET --resource "$_ms_ado_app_id" --url "$url" 2>/dev/null | \
        jq -r --arg name "$package" '.value[] | select(.name == $name)')

    [[ -z "$pkg" ]] && _grim_log_error "Package '$package' not found in feed '$feed'" && return 1

    version=$(jq -r '.versions[0].version' <<< "$pkg")
    _grim_log_info "latest version: $version"
    
    az artifacts universal download \
        --organization "https://dev.azure.com/$organization/" \
        --feed "$feed" \
        --name "$package" \
        --version "$version" \
        --path "$path/$package"
}

# Register parameters for completion
_grim_command_set_complete "ms_ado_download_latest_feed_package" "package"
_grim_command_set_complete "ms_ado_download_latest_feed_package" "path"
_grim_command_set_complete "ms_ado_download_latest_feed_package" "feed"
_grim_command_set_complete "ms_ado_download_latest_feed_package" "organization"
