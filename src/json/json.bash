# JSON utilities - pipe and file operations

_json_python="$_RIG_DIR/src/json/python"

# Get a single value from JSON by path
# Usage: echo "$json" | json_get --path 'appId'
#        echo "$json" | json_get --path 'subscriptions.0.user.name'
json_get() {
    _description "Get a single value from JSON by path"
    _param path --required --positional --help "Dotted path to the value"
    _param_parse "$@" || return 1

    "$_RIG_PYTHON" "$_json_python/get.py" "$path"
}

# Extract fields from a JSON array as TSV
# Usage: echo "$json" | json_tsv --path 'value' --fields 'name=displayName,id'
json_tsv() {
    _description "Extract fields from a JSON array as TSV"
    _param path   --required --positional --help "Dotted path to the array"
    _param fields --required --help "Comma-separated fields (col=path or just path)"
    _param_parse "$@" || return 1

    "$_RIG_PYTHON" "$_json_python/tsv.py" "$path" "$fields"
}

# Flatten a JSON object to key/value TSV rows
# Usage: echo "$json" | json_kv --path '.'
json_kv() {
    _description "Flatten a JSON object to key/value rows"
    _param path --default '.' --positional --help "Dotted path to the object"
    _param_parse "$@" || return 1

    "$_RIG_PYTHON" "$_json_python/kv.py" "$path"
}

# Find first matching item in a JSON array
# Usage: echo "$json" | json_find --path 'appRoles' --where 'value' --equals 'User.Read' --return 'id'
json_find() {
    _description "Find first matching item in a JSON array"
    _param path   --required --positional --help "Dotted path to the array"
    _param where  --required --help "Field to match on"
    _param equals --required --help "Value to match (case-insensitive)"
    _param return --help "Field to return (omit for whole object)"
    _param_parse "$@" || return 1

    local args=("$path" "$where" "$equals")
    [[ -n "$return" ]] && args+=("$return")

    "$_RIG_PYTHON" "$_json_python/find.py" "${args[@]}"
}

# Build a JSON object from key=value pairs
# Usage: json_build 'name=foo' 'int:count=42'
#        json_build --base "$existing" 'extra=bar'
json_build() {
    _description "Build a JSON object from key=value arguments"
    "$_RIG_PYTHON" "$_json_python/build.py" "$@"
}

# Set a key/value in a JSON file
# Usage: json_set --file config.json --key 'host' --value 'localhost'
json_set() {
    _description "Set a key/value in a JSON file"
    _param file  --required --path file --help "JSON file to update"
    _param key   --required --help "Key to set"
    _param value --required --help "Value to set"
    _param_parse "$@" || return 1

    "$_RIG_PYTHON" "$_json_python/set.py" "$file" "$key" "$value"
}

# Append a JSON object to an array in a file
# Usage: json_append --file data.json --item '{"id": "abc"}'
json_append() {
    _description "Append a JSON object to an array in a file"
    _param file --required --help "JSON file (created if missing)"
    _param item --required --help "JSON object to append"
    _param_parse "$@" || return 1

    "$_RIG_PYTHON" "$_json_python/append.py" "$file" "$item"
}

# Remove items from a JSON array in a file by matching a field
# Usage: json_remove --file data.json --match 'id' --value 'abc'
json_remove() {
    _description "Remove matching items from a JSON array in a file"
    _param file  --required --path file --help "JSON file to update"
    _param match --required --help "Field to match on"
    _param value --required --help "Value to match for removal"
    _param_parse "$@" || return 1

    "$_RIG_PYTHON" "$_json_python/remove.py" "$file" "$match" "$value"
}

# Register completions
_complete_params "json_build"
_complete_params "json_get" "path"
_complete_params "json_tsv" "path" "fields"
_complete_params "json_kv" "path"
_complete_params "json_find" "path" "where" "equals" "return"
_complete_type "json_set" action
_complete_params "json_set" "file" "key" "value"
_complete_type "json_append" action
_complete_params "json_append" "file" "item"
_complete_type "json_remove" action
_complete_params "json_remove" "file" "match" "value"
