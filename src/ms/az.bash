
_ms_az_get_subscriptions() {
    _grim_command_filter "${AZURE_SUBSCRIPTIONS}" "$1"
}

# Register parameter with completer for subscriptions
_grim_command_set_complete "ms_az_subscription" "subscription" "_ms_az_get_subscriptions"

ms_az_subscription() {
    _grim_command_init subscription
    _grim_command_parse "$@"
    
    _grim_command_validate subscription --required --regex "[^0-9]" || return 1
    
    _grim_log_info "changing to subscription: $subscription..."
}
