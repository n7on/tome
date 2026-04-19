git_repo_list() {
    _description "Show git status for all repos under a directory"
    _requires git || return 1
    _param path --default "." --positional --path dir --help "Parent directory to scan"
    _param_parse "$@" || return 1

    local repo found=0 rows=""
    for repo in "$path"/*/; do
        [[ -d "$repo/.git" ]] || continue
        local name
        name="$(basename "$repo")"
        local changes
        changes=$(git -C "$repo" status --porcelain=v1 2>/dev/null)
        if [[ -n "$changes" ]]; then
            local count
            count=$(echo "$changes" | wc -l | tr -d ' ')
            rows+="$(printf "%s\t%s\n" "$name" "$count changed")"$'\n'
        else
            rows+="$(printf "%s\t%s\n" "$name" "clean")"$'\n'
        fi
        found=1
    done

    (( found )) || { _message_warn "No git repositories found in $path"; return 1; }
    echo -n "$rows" | _output_render "repo,status"
}

_complete_params "git_repo_list" "path"
_complete_path "git_repo_list" "path" dir
