# Notes management - stores daily JSON notes in ~/.notes/

_NOTE_DIR="$HOME/.notes"

# Pull from remote if ~/.notes/ is a git repo
_note_git_pull() {
    [[ -d "$_NOTE_DIR/.git" ]] || return 0
    git -C "$_NOTE_DIR" pull --quiet 2>/dev/null || _grim_message_warn "git pull failed in $_NOTE_DIR"
}

# Stage, commit, and push if ~/.notes/ is a git repo
_note_git_push() {
    [[ -d "$_NOTE_DIR/.git" ]] || return 0
    git -C "$_NOTE_DIR" add -A
    git -C "$_NOTE_DIR" diff --cached --quiet && return 0
    git -C "$_NOTE_DIR" commit --quiet -m "$1" 2>/dev/null || return 1
    git -C "$_NOTE_DIR" push --quiet 2>/dev/null || _grim_message_warn "git push failed in $_NOTE_DIR"
}

# Add a new note for today
note_add() {
    _grim_command_requires jq || return 1
    _grim_command_description "Add a new note for today"
    _grim_command_param message --positional --required --help "The note text, supports #tags"
    _grim_command_param_parse "$@" || return 1

    mkdir -p "$_NOTE_DIR"
    _note_git_pull

    local today
    today=$(date +%Y-%m-%d)
    local file="$_NOTE_DIR/${today}.json"

    local id
    id=$(uuidgen | tr '[:upper:]' '[:lower:]')

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local new_note
    new_note=$(jq -n \
        --arg id "$id" \
        --arg message "$message" \
        --arg timestamp "$timestamp" \
        '{id: $id, message: $message, timestamp: $timestamp}')

    if [[ -f "$file" ]]; then
        local updated
        updated=$(jq --argjson note "$new_note" '. + [$note]' "$file") || return 1
        echo "$updated" > "$file"
    else
        echo "[$new_note]" | jq . > "$file"
    fi

    _note_git_push "add note $id"

    echo "$id"
}

# List notes for a given date (defaults to today)
note_list() {
    _grim_command_requires jq || return 1
    _grim_command_description "List notes for a given date"
    _grim_command_param date --default "$(date +%Y-%m-%d)" --positional --help "Date to list notes for"
    _grim_command_param_parse "$@" || return 1

    _note_git_pull

    local file="$_NOTE_DIR/${date}.json"

    if [[ ! -f "$file" ]]; then
        _grim_message_warn "No notes found for $date"
        return 0
    fi

    jq -r '.[] | [.id, .timestamp, .message] | @tsv' "$file" \
        | _grim_command_output_render "ID,TIMESTAMP,MESSAGE"
}

# Delete a note by id
note_delete() {
    _grim_command_requires jq || return 1
    _grim_command_description "Delete a note by id"
    _grim_command_param id --positional --required --help "The note id to delete"
    _grim_command_param_parse "$@" || return 1

    _note_git_pull

    local found=0

    for file in "$_NOTE_DIR"/*.json; do
        [[ -f "$file" ]] || continue

        if jq -e --arg id "$id" 'map(select(.id == $id)) | length > 0' "$file" &>/dev/null; then
            local updated
            updated=$(jq --arg id "$id" 'map(select(.id != $id))' "$file")

            if [[ $(echo "$updated" | jq 'length') -eq 0 ]]; then
                rm "$file"
            else
                echo "$updated" > "$file"
            fi

            found=1
            break
        fi
    done

    if [[ $found -eq 0 ]]; then
        _grim_message_error "Note not found: $id"
        return 1
    fi

    _note_git_push "delete note $id"
}

# Completion: list available date files
_note_complete_dates() {
    local cur="$1"
    for file in "$_NOTE_DIR"/*.json; do
        [[ -f "$file" ]] || continue
        basename "$file" .json
    done
}

# Register completions
_grim_command_complete_params "note_add" "message"
_grim_command_complete_params "note_list" "date"
_grim_command_complete_params "note_delete" "id"
_grim_command_complete_func "note_list" "date" _note_complete_dates
