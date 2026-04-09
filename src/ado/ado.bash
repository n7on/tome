_require_module "json"

_ado_app_id="499b84ac-1321-427f-aa17-267ca6975798"

_config_init ado config

_ado_get_feeds() {
    local feeds
    feeds=$(ado_feed_list --output tsv 2>/dev/null | awk '{print $1}')
    _complete_filter "$feeds" "$1"
}

_ado_get_packages() {
    local packages
    packages=$(ado_feed_package_list --output tsv 2>/dev/null | awk '{print $1}')
    _complete_filter "$packages" "$1"
}

ado_feed_list() {
    _description "List Azure DevOps feeds"
    _requires az || return 1
    _param organization --default "$(_config_get ado config organization)" --help "Azure DevOps organization"
    _param_parse "$@" || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds?api-version=7.1-preview.1"

    local result
    result=$(_exec az rest --method GET --resource "$_ado_app_id" --url "$url") || {
        _message_error "Failed to fetch feeds for organization '$organization'"
        return 1
    }

    echo "$result" \
        | json_tsv --path 'value' --fields 'name,id' \
        | _output_render
}

ado_feed_package_list() {
    _description "List packages in an Azure DevOps feed"
    _requires az || return 1
    _param feed         --required --help "Feed name"
    _param organization --default "$(_config_get ado config organization)" --help "Azure DevOps organization"
    _param_parse "$@" || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds/$feed/packages?protocolType=upack&api-version=7.1-preview.1"

    local result
    result=$(_exec az rest --method GET --resource "$_ado_app_id" --url "$url") || {
        _message_error "Failed to fetch packages from feed '$feed'"
        return 1
    }

    echo "$result" \
        | json_tsv --path 'value' --fields 'name,version=versions.0.version' \
        | _output_render
}

ado_feed_package_download() {
    _description "Download latest package from Azure DevOps feed"
    _requires az || return 1
    _param package      --required --positional --help "Package name"
    _param path         --default "." --help "Download path"
    _param feed         --required --help "Feed name"
    _param organization --default "$(_config_get ado config organization)" --help "Azure DevOps organization"
    _param_parse "$@" || return 1

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds/$feed/packages?packageNameQuery=$package&protocolType=upack&api-version=7.1-preview.1"

    local result
    result=$(az rest --method GET --resource "$_ado_app_id" --url "$url" 2>/dev/null) || {
        _message_error "Failed to fetch package '$package' from feed '$feed'"
        return 1
    }

    local version
    version=$(echo "$result" | json_find --path 'value' --where 'name' --equals "$package" --return 'versions.0.version')
    [[ -z "$version" ]] && { _message_error "Package '$package' not found in feed '$feed'"; return 1; }

    az artifacts universal download \
        --organization "https://dev.azure.com/$organization/" \
        --feed "$feed" \
        --name "$package" \
        --version "$version" \
        --path "$path/$package"
}

# Register completions
_complete_params "ado_feed_list" "organization"
_complete_params "ado_feed_package_list" "feed" "organization"
_complete_func  "ado_feed_package_list" "feed" _ado_get_feeds
_complete_type "ado_feed_package_download" action
_complete_params "ado_feed_package_download" "package" "path" "feed" "organization"
_complete_func  "ado_feed_package_download" "feed" _ado_get_feeds
_complete_func  "ado_feed_package_download" "package" _ado_get_packages
