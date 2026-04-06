# Bash completion script generator for the grim binary

completion_bash() {
    _grim_command_param_parse "$@" || return 1

    _grim_command_exec_python completion completion.py "$_GRIM_DIR/src" --shell bash
}

completion_zsh() {
    _grim_command_param_parse "$@" || return 1

    _grim_command_exec_python completion completion.py "$_GRIM_DIR/src" --shell zsh
}

_grim_command_complete_params "completion_bash" "Generate bash completion script for the grim binary"
_grim_command_complete_params "completion_zsh" "Generate zsh completion script for the grim binary"
