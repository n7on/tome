source "$(dirname "${BASH_SOURCE[0]}")/../lib/io.sh"

function az_subscription() {
    local subscription="$1"
    io_info "changing to subscription: $subscription..."
}


_az_login_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "${AZURE_SUBSCRIPTIONS}" -- "$cur"))
}


complete -o bashdefault -o default -o nospace -F _az_login_completion az_subscription