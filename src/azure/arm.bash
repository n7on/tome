
_azure_arm_get_subscriptions() {
    _grim_command_filter "${AZURE_SUBSCRIPTIONS}" "$1"
}

# Register parameter with completer for subscriptions
_grim_command_set_complete "azure_arm_subscription" "subscription" "_azure_arm_get_subscriptions"

azure_arm_subscription() {
    _grim_command_init subscription
    _grim_command_parse "$@"
    
    _grim_command_validate subscription --required --regex "[^0-9]" || return 1
    
    az account set --subscription "$subscription"
}
