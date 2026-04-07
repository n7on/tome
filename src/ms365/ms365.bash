# MS365 app registration and authentication
# The "_tome" app supports both:
#   - Application permissions (client credentials) — for APIs like sensitivity labels
#   - Delegated permissions (device code flow) — for APIs needing user context

_MS365_APP_NAME="_tome"
_MS365_GRAPH_ID="00000003-0000-0000-c000-000000000000"
_MS365_TOKEN_DIR="$HOME/.tome/ms365"
_MS365_APP_TOKEN_FILE="$_MS365_TOKEN_DIR/.app_token"
_MS365_USER_TOKEN_FILE="$_MS365_TOKEN_DIR/.user_token"

# Application permissions (app-only, client credentials)
_MS365_APP_PERMISSIONS=(
    "InformationProtectionPolicy.Read.All"
)

# Delegated permissions (user context, device code flow)
_MS365_DELEGATED_PERMISSIONS=(
    "InformationProtectionPolicy.Read"
)

ms365_app_setup() {
    _requires az || return 1
    _param_parse "$@" || return 1

    local graph_sp
    graph_sp=$(_exec az ad sp show --id "$_MS365_GRAPH_ID" --output json) || {
        _message_error "Failed to fetch Microsoft Graph service principal"
        return 1
    }

    # Build resource access: application permissions (Role) + delegated (Scope)
    local perm_specs=()
    for perm in "${_MS365_APP_PERMISSIONS[@]}"; do
        perm_specs+=("$perm:Role")
    done
    for perm in "${_MS365_DELEGATED_PERMISSIONS[@]}"; do
        perm_specs+=("$perm:Scope")
    done

    local required_resource_access
    required_resource_access=$(_exec_python ms365 build_resource_access.py "$graph_sp" "${perm_specs[@]}") || return 1

    # Create or update app
    local app app_id
    app=$(az ad app list --display-name "$_MS365_APP_NAME" --output json 2>/dev/null | json_find --path '.' --where 'displayName' --equals "$_MS365_APP_NAME")

    if [[ -n "$app" ]]; then
        app_id=$(echo "$app" | json_get --path 'appId')
        _exec az ad app update --id "$app_id" \
            --required-resource-accesses "$required_resource_access" \
            --is-fallback-public-client true >/dev/null || {
            _message_error "Failed to update app '$_MS365_APP_NAME'"
            return 1
        }
        _message_warn "Updated app '$_MS365_APP_NAME' ($app_id)"
    else
        local new_app
        new_app=$(_exec az ad app create \
            --display-name "$_MS365_APP_NAME" \
            --required-resource-accesses "$required_resource_access" \
            --is-fallback-public-client true \
            --output json) || {
            _message_error "Failed to create app '$_MS365_APP_NAME'"
            return 1
        }
        app_id=$(echo "$new_app" | json_get --path 'appId')
        _message_warn "Created app '$_MS365_APP_NAME' ($app_id)"
    fi

    # Ensure service principal exists
    _exec az ad sp create --id "$app_id" >/dev/null 2>&1 || true

    local sp_id graph_sp_id
    sp_id=$(_exec az ad sp show --id "$app_id" --query id -o tsv)
    graph_sp_id=$(_exec az ad sp show --id "$_MS365_GRAPH_ID" --query id -o tsv)

    # Grant admin consent for application permissions (appRoleAssignments)
    for perm in "${_MS365_APP_PERMISSIONS[@]}"; do
        local role_id
        role_id=$(echo "$graph_sp" | json_find --path 'appRoles' --where 'value' --equals "$perm" --return 'id')
        _exec az rest --method POST \
            --url "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignments" \
            --body "{\"principalId\":\"$sp_id\",\"resourceId\":\"$graph_sp_id\",\"appRoleId\":\"$role_id\"}" \
            >/dev/null 2>&1 || true
    done

    # Grant admin consent for delegated permissions (oauth2PermissionGrants)
    local scope_ids=""
    for perm in "${_MS365_DELEGATED_PERMISSIONS[@]}"; do
        local scope_id
        scope_id=$(echo "$graph_sp" | json_find --path 'oauth2PermissionScopes' --where 'value' --equals "$perm" --return 'id')
        [[ -n "$scope_ids" ]] && scope_ids+=" "
        scope_ids+="$scope_id"
    done

    local existing_grant
    existing_grant=$(_exec az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '$sp_id' and resourceId eq '$graph_sp_id'" \
        | json_get --path 'value.0.id')

    if [[ -n "$existing_grant" ]]; then
        _exec az rest --method PATCH \
            --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$existing_grant" \
            --body "{\"scope\":\"${scope_ids}\"}" >/dev/null || {
            _message_error "Failed to grant admin consent (requires Global Admin or Privileged Role Admin)"
            return 1
        }
    else
        _exec az rest --method POST \
            --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" \
            --body "{\"clientId\":\"$sp_id\",\"consentType\":\"AllPrincipals\",\"resourceId\":\"$graph_sp_id\",\"scope\":\"${scope_ids}\"}" \
            >/dev/null || {
            _message_error "Failed to grant admin consent (requires Global Admin or Privileged Role Admin)"
            return 1
        }
    fi

    _message_warn "Admin consent granted"

    # Create client secret for application permissions
    local secret_result
    secret_result=$(_exec az ad app credential reset \
        --id "$app_id" --display-name "tome" --output json) || {
        _message_error "Failed to create client secret"
        return 1
    }

    local secret tenant
    secret=$(echo "$secret_result" | json_get --path 'password')
    tenant=$(echo "$secret_result" | json_get --path 'tenant')

    # Save config
    mkdir -p "$_MS365_TOKEN_DIR"
    json_build "app_id=$app_id" "secret=$secret" "tenant=$tenant" \
        > "$_MS365_TOKEN_DIR/app.json"

    _message_warn "Setup complete."
    _message_warn "  App permissions: ready (client credentials)"
    _message_warn "  Delegated permissions: run ms365_login to authenticate"
}

ms365_app_show() {
    _requires az || return 1
    _param_parse "$@" || return 1

    local app
    app=$(az ad app list --display-name "$_MS365_APP_NAME" --output json 2>/dev/null \
        | json_find --path '.' --where 'displayName' --equals "$_MS365_APP_NAME")
    [[ -z "$app" ]] && { _message_error "App '$_MS365_APP_NAME' not found. Run ms365_app_setup first."; return 1; }

    local graph_sp
    graph_sp=$(_exec az ad sp show --id "$_MS365_GRAPH_ID" --output json) || return 1

    _exec_python ms365 app_show.py "$app" "$graph_sp" \
        | _output_render
}

# --- Delegated auth (device code flow, user context) ---

ms365_login() {
    _requires curl || return 1
    _param_parse "$@" || return 1

    local config="$_MS365_TOKEN_DIR/app.json"
    [[ -f "$config" ]] || { _message_error "App not configured. Run ms365_app_setup first."; return 1; }

    local app_id tenant
    app_id=$(cat "$config" | json_get --path 'app_id')
    tenant=$(cat "$config" | json_get --path 'tenant')

    local scopes=""
    for perm in "${_MS365_DELEGATED_PERMISSIONS[@]}"; do
        [[ -n "$scopes" ]] && scopes+=" "
        scopes+="https://graph.microsoft.com/$perm"
    done
    scopes+=" offline_access"

    local device_response
    device_response=$(curl -s -X POST \
        "https://login.microsoftonline.com/$tenant/oauth2/v2.0/devicecode" \
        -d "client_id=$app_id" \
        -d "scope=$scopes")

    local device_code interval message
    device_code=$(echo "$device_response" | json_get --path 'device_code')
    interval=$(echo "$device_response" | json_get --path 'interval')
    message=$(echo "$device_response" | json_get --path 'message')

    if [[ -z "$device_code" ]]; then
        local err_msg
        err_msg=$(echo "$device_response" | json_get --path 'error_description')
        [[ "$err_msg" == "-" ]] && err_msg=$(echo "$device_response" | json_get --path 'error')
        _message_error "Failed to start device code flow: $err_msg"
        return 1
    fi

    echo "$message"

    while true; do
        sleep "$interval"
        local token_response
        token_response=$(curl -s -X POST \
            "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" \
            -d "client_id=$app_id" \
            -d "device_code=$device_code" \
            -d "grant_type=urn:ietf:params:oauth:grant-type:device_code")

        local error
        error=$(echo "$token_response" | json_get --path 'error')

        case "$error" in
            authorization_pending) continue ;;
            slow_down) interval=$((interval + 5)); continue ;;
            "")
                mkdir -p "$_MS365_TOKEN_DIR"
                _exec_python ms365 save_token.py "$token_response" "$_MS365_USER_TOKEN_FILE" --with-refresh
                _message_warn "Login successful"
                return 0
                ;;
            *)
                local err_msg
                err_msg=$(echo "$token_response" | json_get --path 'error_description')
                [[ "$err_msg" == "-" ]] && err_msg=$(echo "$token_response" | json_get --path 'error')
                _message_error "Login failed: $err_msg"
                return 1
                ;;
        esac
    done
}

# Get a delegated (user) token, refreshing if needed
_ms365_get_user_token() {
    local config="$_MS365_TOKEN_DIR/app.json"
    [[ -f "$config" ]] || { _message_error "App not configured. Run ms365_app_setup first."; return 1; }
    [[ -f "$_MS365_USER_TOKEN_FILE" ]] || { _message_error "Not logged in. Run ms365_login first."; return 1; }

    local expires_on
    expires_on=$(cat "$_MS365_USER_TOKEN_FILE" | json_get --path 'expires_on')
    if [[ $(date +%s) -lt ${expires_on:-0} ]]; then
        cat "$_MS365_USER_TOKEN_FILE" | json_get --path 'access_token'
        return 0
    fi

    local app_id tenant refresh_token
    app_id=$(cat "$config" | json_get --path 'app_id')
    tenant=$(cat "$config" | json_get --path 'tenant')
    refresh_token=$(cat "$_MS365_USER_TOKEN_FILE" | json_get --path 'refresh_token')

    [[ -z "$refresh_token" ]] && { _message_error "Session expired. Run ms365_login to re-authenticate."; return 1; }

    local response
    response=$(curl -s -X POST \
        "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" \
        -d "client_id=$app_id" \
        -d "refresh_token=$refresh_token" \
        -d "grant_type=refresh_token")

    local token
    token=$(echo "$response" | json_get --path 'access_token')
    if [[ -z "$token" ]]; then
        _message_error "Token refresh failed. Run ms365_login to re-authenticate."
        rm -f "$_MS365_USER_TOKEN_FILE"
        return 1
    fi

    _exec_python ms365 save_token.py "$response" "$_MS365_USER_TOKEN_FILE" --with-refresh

    echo "$token"
}

# --- Application auth (client credentials, app-only) ---

# Get an application token using client credentials
_ms365_get_app_token() {
    local config="$_MS365_TOKEN_DIR/app.json"
    [[ -f "$config" ]] || { _message_error "App not configured. Run ms365_app_setup first."; return 1; }

    # Check cached token
    if [[ -f "$_MS365_APP_TOKEN_FILE" ]]; then
        local expires_on
        expires_on=$(cat "$_MS365_APP_TOKEN_FILE" | json_get --path 'expires_on')
        if [[ $(date +%s) -lt ${expires_on:-0} ]]; then
            cat "$_MS365_APP_TOKEN_FILE" | json_get --path 'access_token'
            return 0
        fi
    fi

    local app_id secret tenant
    app_id=$(cat "$config" | json_get --path 'app_id')
    secret=$(cat "$config" | json_get --path 'secret')
    tenant=$(cat "$config" | json_get --path 'tenant')

    [[ -z "$secret" ]] && { _message_error "No client secret. Re-run ms365_app_setup."; return 1; }

    local response
    response=$(curl -s -X POST \
        "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" \
        -d "client_id=$app_id" \
        -d "client_secret=$secret" \
        -d "scope=https://graph.microsoft.com/.default" \
        -d "grant_type=client_credentials")

    local token
    token=$(echo "$response" | json_get --path 'access_token')
    if [[ -z "$token" ]]; then
        local err_msg
        err_msg=$(echo "$response" | json_get --path 'error_description')
        [[ "$err_msg" == "-" ]] && err_msg=$(echo "$response" | json_get --path 'error')
        _message_error "Failed to get app token: $err_msg"
        return 1
    fi

    mkdir -p "$_MS365_TOKEN_DIR"
    _exec_python ms365 save_token.py "$response" "$_MS365_APP_TOKEN_FILE"

    echo "$token"
}

# --- Graph API helpers ---

# Check Graph API response for errors
_ms365_graph_check() {
    local response="$1"
    local error
    error=$(echo "$response" | json_get --path 'error.message' 2>/dev/null)
    if [[ -n "$error" && "$error" != "-" ]]; then
        local code
        code=$(echo "$response" | json_get --path 'error.code' 2>/dev/null)
        _message_error "$code: $error"
        return 1
    fi
}

# App-only GET request to Microsoft Graph (client credentials)
_ms365_graph_get() {
    local url="$1"
    local token
    token=$(_ms365_get_app_token) || return 1
    local response
    response=$(curl -s -H "Authorization: Bearer $token" "$url")
    _ms365_graph_check "$response" || return 1
    echo "$response"
}

# App-only POST request to Microsoft Graph (client credentials)
_ms365_graph_post() {
    local url="$1"
    local body="$2"
    local token
    token=$(_ms365_get_app_token) || return 1
    local response
    response=$(curl -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
        -X POST -d "$body" "$url")
    _ms365_graph_check "$response" || return 1
    echo "$response"
}

# Delegated GET request to Microsoft Graph (user context)
_ms365_graph_get_delegated() {
    local url="$1"
    local token
    token=$(_ms365_get_user_token) || return 1
    local response
    response=$(curl -s -H "Authorization: Bearer $token" "$url")
    _ms365_graph_check "$response" || return 1
    echo "$response"
}

# Delegated POST request to Microsoft Graph (user context)
_ms365_graph_post_delegated() {
    local url="$1"
    local body="$2"
    local token
    token=$(_ms365_get_user_token) || return 1
    local response
    response=$(curl -s -H "Authorization: Bearer $token" -H "Content-Type: application/json" \
        -X POST -d "$body" "$url")
    _ms365_graph_check "$response" || return 1
    echo "$response"
}

# Register completions
_complete_params "ms365_app_setup" "Create or update the _tome app registration with required MS365 permissions"
_complete_params "ms365_app_show" "Show the _tome app registration and its permissions"
_complete_params "ms365_login" "Authenticate with the _tome app using device code flow"
