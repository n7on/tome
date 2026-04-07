# Git sync utilities for directories managed by git

# Pull from remote if directory is a git repo
# Usage: git_pull --path ~/my-repo
git_pull() {
    _requires git || return 1
    _param path --default "." --positional --path dir --help "Path to git repository"
    _param_parse "$@" || return 1

    [[ -d "$path/.git" ]] || return 0
    git -C "$path" pull --quiet 2>/dev/null || _message_warn "git pull failed in $path"
}

# Stage, commit, and push changes if directory is a git repo
# Usage: git_push --path ~/my-repo --message "updated files"
git_push() {
    _requires git || return 1
    _param path    --default "." --positional --path dir --help "Path to git repository"
    _param message --required --help "Commit message"
    _param_parse "$@" || return 1

    [[ -d "$path/.git" ]] || return 0
    git -C "$path" add -A
    git -C "$path" diff --cached --quiet && return 0
    git -C "$path" commit --quiet -m "$message" 2>/dev/null || return 1
    git -C "$path" push --quiet 2>/dev/null || _message_warn "git push failed in $path"
}

# Pull, then stage+commit+push (convenience wrapper)
# Usage: git_sync --path ~/my-repo --message "updated files"
git_sync() {
    _requires git || return 1
    _param path    --default "." --positional --path dir --help "Path to git repository"
    _param message --required --help "Commit message"
    _param_parse "$@" || return 1

    git_pull --path "$path"
    git_push --path "$path" --message "$message"
}

# Show status of files in a git repo
# Usage: git_status
#        git_status --path ~/my-repo
git_status() {
    _requires git || return 1
    _param path --default "." --positional --path dir --help "Path to git repository"
    _param_parse "$@" || return 1

    git -C "$path" status --porcelain=v1 2>/dev/null \
        | awk '{
            code = substr($0, 1, 2)
            file = substr($0, 4)
            idx = substr(code, 1, 1)
            wt  = substr(code, 2, 1)

            if (code == "??")      state = "untracked"
            else if (idx != " " && wt != " ") state = "staged+modified"
            else if (idx != " ")   state = "staged"
            else                   state = "modified"

            printf "%s\t%s\n", file, state
        }' \
        | _output_render "file,status"
}

# Register completions
_complete_params "git_status" "Show status of files in a git repo" "path"
_complete_params "git_pull" "Pull from remote if directory is a git repo" "path"
_complete_params "git_push" "Stage, commit, and push changes" "path" "message"
_complete_params "git_sync" "Pull then commit and push changes" "path" "message"
