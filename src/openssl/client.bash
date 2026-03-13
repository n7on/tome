# Connect to a TLS server and display certificate/connection info
# Usage: openssl_client_connect --host example.com
#        openssl_client_connect --host example.com --port 587 --message "EHLO test"
#        openssl_client_connect --host example.com --output_format table
openssl_client_connect() {
    _grim_command_requires openssl || return 1

    _grim_command_init host port=443 message="" output_format=raw
    _grim_command_parse "$@"

    _grim_command_validate host --required || return 1

    local cmd=(openssl s_client -connect "${host}:${port}")

    _grim_command_output_set "SUBJECT,ISSUER,NOTBEFORE,NOTAFTER" '/subject=/{sub(/subject=/, ""); subj=$0} /issuer=/{sub(/issuer=/, ""); iss=$0} /notBefore=/{sub(/.*notBefore=/, ""); nb=$0} /notAfter=/{sub(/.*notAfter=/, ""); na=$0} /END CERTIFICATE/{printf "%s\t%s\t%s\t%s\n", subj, iss, nb, na}'
    echo -e "${message}" | _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

_grim_command_set_params "openssl_client_connect" "host" "port" "message"

_complete_openssl_messages() {
    echo '"QUIT"'
    echo '"STARTTLS"'
    echo '"EHLO test"'
    echo '"GET / HTTP/1.1\r\n"'
}
_grim_command_set_completer "openssl_client_connect" "message" _complete_openssl_messages

_grim_command_set_values "openssl_client_connect" "port" \
    "443" "8443" "587" "465" "993" "995" "636" "853" "5223" "8080"
