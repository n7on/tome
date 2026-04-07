# Connect to a TLS server and display certificate/connection info
openssl_client_connect() {
    _requires openssl || return 1
    _param host --required --positional --help "Target hostname"
    _param port --default 443 --help "Target port"
    _param message --default "" --help "Message to send after connect"
    _param output --default raw
    _param_parse "$@" || return 1

    local cmd=(openssl s_client -connect "${host}:${port}")

    echo -e "${message}" | _exec "${cmd[@]}" \
        | awk '/subject=/{sub(/subject=/, ""); subj=$0}
               /issuer=/{sub(/issuer=/, ""); iss=$0}
               /notBefore=/{sub(/.*notBefore=/, ""); nb=$0}
               /notAfter=/{sub(/.*notAfter=/, ""); na=$0}
               /END CERTIFICATE/{printf "%s\t%s\t%s\t%s\n", subj, iss, nb, na}' \
        | _output_render "subject,issuer,notbefore,notafter"
}

_openssl_complete_messages() {
    echo '"QUIT"'
    echo '"STARTTLS"'
    echo '"EHLO test"'
    echo '"GET / HTTP/1.1\r\n"'
}

# Register completions
_complete_params "openssl_client_connect" "Connect to a TLS server and display certificate info" "host" "port" "message"
_complete_values "openssl_client_connect" "port" "443" "8443" "587" "465" "993" "995" "636" "853" "5223" "8080"
_complete_func "openssl_client_connect" "message" _openssl_complete_messages
