_require_module "json"

_config_init ai ai

# Read a prompt file shipped in <module>/prompts/<filename>.
# Usage: _ai_prompt <namespace> <filename>
_ai_prompt() {
    local ns="$1" name="$2"
    local dir="${_MODULE_PATH[$ns]:-$_JIG_DIR/src/$ns}"
    local path="$dir/prompts/$name"
    if [[ ! -f "$path" ]]; then
        _message_error "Prompt file not found: $path"
        return 1
    fi
    cat "$path"
}

# Run the configured AI provider with a prompt string.
# Emits the provider's full output on stdout.
# Usage: _ai_run <prompt> [provider]
_ai_run() {
    local prompt="$1"
    local provider="${2:-}"

    [[ -z "$provider" ]] && provider=$(_config_get ai ai default)
    if [[ -z "$provider" ]]; then
        _message_error "No AI provider configured. Edit ~/.jig/ai/ai.json or pass --provider."
        return 1
    fi

    local cmd
    cmd=$(_config_get ai ai "providers.$provider.cmd")
    if [[ -z "$cmd" ]]; then
        _message_error "Provider '$provider' not found in ~/.jig/ai/ai.json"
        return 1
    fi

    printf '%s' "$prompt" | eval "$cmd" 2>&1
    local rc=${PIPESTATUS[1]}

    if [[ $rc -ne 0 ]]; then
        _message_error "AI provider '$provider' exited with $rc"
        return 1
    fi
}

ai_ask() {
    _description "Send a prompt to the configured AI provider"
    _param prompt   --required --positional --help "Prompt text"
    _param context  --path file --help "Context file to prepend"
    _param provider --help "Provider name (default from ~/.jig/ai/ai.json)"
    _param_parse "$@" || return 1

    local payload="$prompt"
    if [[ -n "$context" && -f "$context" ]]; then
        payload=$(cat "$context")$'\n\n---\n\n'"$prompt"
    fi

    _ai_run "$payload" "$provider"
}

_ai_providers_complete() {
    local f="$HOME/.jig/ai/ai.json"
    [[ -f "$f" ]] || return 0
    "$_JIG_PYTHON" -c 'import json,sys;d=json.load(open(sys.argv[1]));print("\n".join(d.get("providers",{}).keys()))' "$f" 2>/dev/null
}

_complete_type "ai_ask" action
_complete_params "ai_ask" "prompt" "context" "provider"
_complete_path "ai_ask" "context" file
_complete_func "ai_ask" "provider" _ai_providers_complete
