# List external dependencies across grim modules

deps() {
    _grim_command_param_parse "$@" || return 1

    {
        grep -rh "^\s*_grim_command_requires [a-z]" "$_GRIM_DIR/src" --include="*.bash" \
            | grep -v "_az_extension" \
            | sed 's/.*_grim_command_requires \([^|]*\).*/\1/' \
            | tr ' ' '\n' \
            | tr -d ' \t' \
            | grep -v '^$' \
            | sort -u \
            | while IFS= read -r tool; do printf "%s\tcommand\n" "$tool"; done

        grep -rh "^\s*_grim_command_requires_az_extension [a-z]" "$_GRIM_DIR/src" --include="*.bash" \
            | sed 's/.*_grim_command_requires_az_extension \([^|]*\).*/\1/' \
            | tr ' ' '\n' \
            | tr -d ' \t' \
            | grep -v '^$' \
            | sort -u \
            | while IFS= read -r ext; do printf "%s\taz-extension\n" "$ext"; done
    } | sort -u | _grim_command_output_render "dependency,type"
}

_grim_command_complete_params "deps" "List all external dependencies across grim modules"
