
_azure_ado_app_id="499b84ac-1321-427f-aa17-267ca6975798"

_azure_ado_get_feeds() {
    local feeds
    feeds=$(azure_ado_feed_list --output_format tsv 2>/dev/null | awk '{print $1}')
    _grim_command_complete_filter "$feeds" "$1"
}

_azure_ado_get_packages() {
    local packages
    packages=$(azure_ado_feed_package_list --output_format tsv 2>/dev/null | awk '{print $1}')
    _grim_command_complete_filter "$packages" "$1"
}

azure_ado_feed_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List Azure DevOps feeds"
    _grim_command_param organization --default "$AZURE_DEVOPS_ORGANIZATION" --help "Azure DevOps organization"
    _grim_command_param_parse "$@" || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds?api-version=7.1-preview.1"

    local result
    result=$(az rest --method GET --resource "$_azure_ado_app_id" --url "$url" 2>/dev/null) || {
        _grim_message_error "Failed to fetch feeds for organization '$organization'"
        return 1
    }

    _grim_command_output_set "NAME,ID" \
        '.value[] | [.name, .id] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

azure_ado_feed_package_list() {
    _grim_command_requires az jq || return 1
    _grim_command_description "List packages in an Azure DevOps feed"
    _grim_command_param feed         --default "$AZURE_DEVOPS_FEED_NAME" --help "Feed name"
    _grim_command_param organization --default "$AZURE_DEVOPS_ORGANIZATION" --help "Azure DevOps organization"
    _grim_command_param_parse "$@" || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds/$feed/packages?protocolType=upack&api-version=7.1-preview.1"

    local result
    result=$(az rest --method GET --resource "$_azure_ado_app_id" --url "$url" 2>/dev/null) || {
        _grim_message_error "Failed to fetch packages from feed '$feed'"
        return 1
    }

    _grim_command_output_set "NAME,VERSION" \
        '.value[] | [.name, .versions[0].version] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

azure_ado_download_latest_feed_package() {
    _grim_command_requires az jq || return 1
    _grim_command_description "Download latest package from Azure DevOps feed"
    _grim_command_param package      --required --positional --help "Package name"
    _grim_command_param path         --default "." --help "Download path"
    _grim_command_param feed         --default "$AZURE_DEVOPS_FEED_NAME" --help "Feed name"
    _grim_command_param organization --default "$AZURE_DEVOPS_ORGANIZATION" --help "Azure DevOps organization"
    _grim_command_param_parse "$@" || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds/$feed/packages?packageNameQuery=$package&protocolType=upack&api-version=7.1-preview.1"

    local pkg
    pkg=$(az rest --method GET --resource "$_azure_ado_app_id" --url "$url" 2>/dev/null | \
        jq -r --arg name "$package" '.value[] | select(.name == $name)') || {
        _grim_message_error "Failed to fetch package '$package' from feed '$feed'"
        return 1
    }

    [[ -z "$pkg" ]] && _grim_message_error "Package '$package' not found in feed '$feed'" && return 1

    local version
    version=$(jq -r '.versions[0].version' <<< "$pkg")

    az artifacts universal download \
        --organization "https://dev.azure.com/$organization/" \
        --feed "$feed" \
        --name "$package" \
        --version "$version" \
        --path "$path/$package"
}

# Register completions
_grim_command_complete_params "azure_ado_feed_list" "organization"
_grim_command_complete_params "azure_ado_feed_package_list" "feed" "organization"
_grim_command_complete_func "azure_ado_feed_package_list" "feed" _azure_ado_get_feeds
_grim_command_complete_params "azure_ado_download_latest_feed_package" "package" "path" "feed" "organization"
_grim_command_complete_func "azure_ado_download_latest_feed_package" "feed" _azure_ado_get_feeds
_grim_command_complete_func "azure_ado_download_latest_feed_package" "package" _azure_ado_get_packages
