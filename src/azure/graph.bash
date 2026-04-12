_require_module "json"

_azure_graph_queries_dir="$(dirname "${BASH_SOURCE[0]}")/kql/graph"
_azure_graph_user_queries_dir="$HOME/.rig/kql/azure/graph"

_azure_graph_get_query_names() {
    local -A seen
    local names=()
    local dir file name

    for dir in "$_azure_graph_user_queries_dir" "$_azure_graph_queries_dir"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r file; do
            name="${file%.kql}"
            [[ -n "${seen[$name]}" ]] && continue
            seen[$name]=1
            names+=("$name")
        done < <(find "$dir" -name "*.kql" -printf "%P\n" 2>/dev/null)
    done

    _complete_filter "${names[*]}" "$1"
}

_azure_graph_load_query() {
    local name="$1"
    local dir file

    for dir in "$_azure_graph_user_queries_dir" "$_azure_graph_queries_dir"; do
        [[ -d "$dir" ]] || continue
        file="$dir/${name}.kql"
        if [[ -f "$file" ]]; then
            cat "$file"
            return 0
        fi
    done

    _message_error "Query '$name' not found"
    return 1
}

azure_graph_query() {
    _description "Query Azure Resource Graph using a saved KQL file"
    _requires az || return 1
    _param name          --required --positional --help "Query name (from queries/graph/)"
    _param subscriptions --help "Comma-separated list of subscription IDs to scope the query"
    _param_parse "$@" || return 1

    local kql
    kql=$(_azure_graph_load_query "$name") || return 1

    local cmd=(az graph query -q "$kql" --output json)
    if [[ -n "$subscriptions" ]]; then
        IFS=',' read -ra subs <<< "$subscriptions"
        cmd+=(--subscriptions "${subs[@]}")
    fi

    local result
    result=$(_exec "${cmd[@]}") || { _message_error "Graph query failed"; return 1; }

    echo "$result" \
        | json_tsv --path 'data' --fields 'name,resource_group=resourceGroup,location,kind,subscription_id=subscriptionId' \
        | _output_render
}

# Register completions
_complete_params "azure_graph_query" "name" "subscriptions"
_complete_func "azure_graph_query" "name" _azure_graph_get_query_names
_complete_func "azure_graph_query" "subscriptions" _azure_account_get_subscriptions
