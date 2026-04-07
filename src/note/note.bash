# Notes management - stores daily JSON notes in ~/.notes/

_NOTE_DIR="$HOME/.notes"

# Add a new note for today
note_add() {
    _param message --positional --required --help "The note text, supports #tags"
    _param_parse "$@" || return 1

    mkdir -p "$_NOTE_DIR"
    git_pull --path "$_NOTE_DIR"

    local today
    today=$(date +%Y-%m-%d)
    local file="$_NOTE_DIR/${today}.json"

    local id
    id=$(uuidgen | tr '[:upper:]' '[:lower:]')

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local new_note
    new_note=$(json_build "id=$id" "message=$message" "timestamp=$timestamp")

    json_append --file "$file" --item "$new_note"

    git_push --path "$_NOTE_DIR" --message "add note $id"

    echo "$id"
}

# List notes for a given date (defaults to today)
note_list() {
    _param date --default "$(date +%Y-%m-%d)" --positional --help "Date to list notes for"
    _param_parse "$@" || return 1

    git_pull --path "$_NOTE_DIR"

    local file="$_NOTE_DIR/${date}.json"

    if [[ ! -f "$file" ]]; then
        _message_warn "No notes found for $date"
        return 0
    fi

    cat "$file" \
        | json_tsv --path '.' --fields 'id,timestamp,message' \
        | _output_render
}

# Delete a note by id
note_delete() {
    _param id --positional --required --help "The note id to delete"
    _param_parse "$@" || return 1

    git_pull --path "$_NOTE_DIR"

    local found=0

    for file in "$_NOTE_DIR"/*.json; do
        [[ -f "$file" ]] || continue

        if json_remove --file "$file" --match 'id' --value "$id" 2>/dev/null; then
            found=1
            break
        fi
    done

    if [[ $found -eq 0 ]]; then
        _message_error "Note not found: $id"
        return 1
    fi

    git_push --path "$_NOTE_DIR" --message "delete note $id"
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
_complete_params "note_add" "Add a new note for today" "message"
_complete_params "note_list" "List notes for a given date" "date"
_complete_params "note_delete" "Delete a note by id" "id"
_complete_func "note_list" "date" _note_complete_dates
