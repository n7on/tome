# Bash completion script generator for the grim binary

completion_bash() {
    _grim_command_param_parse "$@" || return 1

    _grim_command_exec_python completion completion.py "$_GRIM_DIR/src"
}

_grim_command_complete_params "completion_bash" "Generate bash completion script for the grim binary"
