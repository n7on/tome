# Connect to a TLS server and display certificate/connection info
openssl_client_connect() {
    _grim_command_requires openssl || return 1
    _grim_command_description "Connect to a TLS server and display certificate info"
    _grim_command_param host --required --positional --help "Target hostname"
    _grim_command_param port --default 443 --help "Target port"
    _grim_command_param message --default "" --help "Message to send after connect"
    _grim_command_param output_format --default raw
    _grim_command_param_parse "$@" || return 1

    local cmd=(openssl s_client -connect "${host}:${port}")

    echo -e "${message}" | _grim_command_exec "${cmd[@]}" \
        | awk '/subject=/{sub(/subject=/, ""); subj=$0}
               /issuer=/{sub(/issuer=/, ""); iss=$0}
               /notBefore=/{sub(/.*notBefore=/, ""); nb=$0}
               /notAfter=/{sub(/.*notAfter=/, ""); na=$0}
               /END CERTIFICATE/{printf "%s\t%s\t%s\t%s\n", subj, iss, nb, na}' \
        | _grim_command_output_render "SUBJECT,ISSUER,NOTBEFORE,NOTAFTER"
}

_openssl_complete_messages() {
    echo '"QUIT"'
    echo '"STARTTLS"'
    echo '"EHLO test"'
    echo '"GET / HTTP/1.1\r\n"'
}

# Register completions
_grim_command_complete_params "openssl_client_connect" "host" "port" "message"
_grim_command_complete_values "openssl_client_connect" "port" "443" "8443" "587" "465" "993" "995" "636" "853" "5223" "8080"
_grim_command_complete_func "openssl_client_connect" "message" _openssl_complete_messages
