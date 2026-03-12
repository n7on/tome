source "$(dirname "${BASH_SOURCE[0]}")/../lib/io.sh"


ado_app_id="499b84ac-1321-427f-aa17-267ca6975798"

function ado_download_latest_feed_package() {
    local package_name="$1"
    local path="${2:-.}"
    local feed="${3:-$AZURE_DEVOPS_FEED_NAME}"
    local organization="${4:-$AZURE_DEVOPS_ORGANIZATION}" 

    local url="https://feeds.dev.azure.com/$organization/_apis/packaging/feeds/$feed/packages?packageNameQuery=$package_name&protocolType=upack&api-version=7.1-preview.1"
    local pkg
    local version

    io_info "downloading artifacts from feed: $feed..."

    pkg=$(az rest --method GET --resource "$ado_app_id" --url "$url" 2>/dev/null | \
        jq -r --arg name "$package_name" '.value[] | select(.name == $name)')

    [[ -z "$pkg" ]] && io_error "Package '$package_name' not found in feed '$feed'" && return 1

    version=$(echo "$pkg" | jq -r '.versions[0].version')
    io_info "Latest version: $version"
    
    az artifacts universal download \
        --organization "https://dev.azure.com/$organization/" \
        --feed $feed \
        --name $package_name \
        --version $version \
        --path "$path/$package_name"
}