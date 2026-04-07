# List external dependencies across tome modules

deps() {
    _param_parse "$@" || return 1

    {
        grep -rh "^\s*_requires [a-z]" "$_TOME_DIR/src" --include="*.bash" \
            | grep -v "_az_extension" \
            | sed 's/.*_requires \([^|]*\).*/\1/' \
            | tr ' ' '\n' \
            | tr -d ' \t' \
            | grep -v '^$' \
            | sort -u \
            | while IFS= read -r tool; do printf "%s\tcommand\n" "$tool"; done

        grep -rh "^\s*_requires_az_extension [a-z]" "$_TOME_DIR/src" --include="*.bash" \
            | sed 's/.*_requires_az_extension \([^|]*\).*/\1/' \
            | tr ' ' '\n' \
            | tr -d ' \t' \
            | grep -v '^$' \
            | sort -u \
            | while IFS= read -r ext; do printf "%s\taz-extension\n" "$ext"; done
    } | sort -u | _output_render "dependency,type"
}

_complete_params "deps" "List all external dependencies across tome modules"
